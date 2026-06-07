import { randomBytes } from 'crypto';
import {
  AdminUpdateUserAttributesCommand,
  CognitoIdentityProviderClient,
} from '@aws-sdk/client-cognito-identity-provider';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import {
  DynamoDBDocumentClient,
  GetCommand,
  PutCommand,
  QueryCommand,
} from '@aws-sdk/lib-dynamodb';
import type {
  APIGatewayProxyEventV2WithJWTAuthorizer,
  APIGatewayProxyResultV2,
} from 'aws-lambda';

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const cognito = new CognitoIdentityProviderClient({});

const TENANTS_TABLE = process.env.TENANTS_TABLE!;
const MEMBERS_TABLE = process.env.MEMBERS_TABLE!;
const USER_POOL_ID = process.env.USER_POOL_ID!;

type Role = 'admin' | 'readonly';

interface JwtClaims {
  sub: string;
  email?: string;
  'custom:tenant_id'?: string;
  'custom:role'?: string;
  'custom:onboarding_complete'?: string;
}

function response(statusCode: number, body: unknown): APIGatewayProxyResultV2 {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
    body: JSON.stringify(body),
  };
}

function claims(event: APIGatewayProxyEventV2WithJWTAuthorizer): JwtClaims {
  return event.requestContext.authorizer.jwt.claims as unknown as JwtClaims;
}

function generateInviteCode(): string {
  const raw = randomBytes(4).toString('hex').toUpperCase();
  return `${raw.slice(0, 4)}-${raw.slice(4, 8)}`;
}

function generateTenantId(): string {
  return randomBytes(16).toString('hex');
}

async function updateCognitoAttributes(
  username: string,
  attrs: Record<string, string>,
): Promise<void> {
  await cognito.send(
    new AdminUpdateUserAttributesCommand({
      UserPoolId: USER_POOL_ID,
      Username: username,
      UserAttributes: Object.entries(attrs).map(([Name, Value]) => ({
        Name,
        Value,
      })),
    }),
  );
}

async function getMember(tenantId: string, userId: string) {
  const result = await ddb.send(
    new GetCommand({
      TableName: MEMBERS_TABLE,
      Key: { tenantId, userId },
    }),
  );
  return result.Item;
}

async function handleGetMe(event: APIGatewayProxyEventV2WithJWTAuthorizer) {
  const jwt = claims(event);
  const userId = jwt.sub;
  const tenantId = jwt['custom:tenant_id'] ?? '';
  const role = (jwt['custom:role'] ?? '') as Role | '';
  const onboardingComplete = jwt['custom:onboarding_complete'] === 'true';

  let inviteCode: string | undefined;
  if (tenantId && role === 'admin') {
    const tenant = await ddb.send(
      new GetCommand({
        TableName: TENANTS_TABLE,
        Key: { tenantId },
      }),
    );
    inviteCode = tenant.Item?.inviteCode as string | undefined;
  }

  return response(200, {
    userId,
    email: jwt.email ?? '',
    role: role || null,
    tenantId: tenantId || null,
    onboardingComplete,
    inviteCode: inviteCode ?? null,
  });
}

async function handleCreateTenant(event: APIGatewayProxyEventV2WithJWTAuthorizer) {
  const jwt = claims(event);
  const userId = jwt.sub;
  const email = jwt.email ?? '';
  const existingTenantId = jwt['custom:tenant_id'];

  if (existingTenantId) {
    const tenant = await ddb.send(
      new GetCommand({
        TableName: TENANTS_TABLE,
        Key: { tenantId: existingTenantId },
      }),
    );
    return response(200, {
      tenantId: existingTenantId,
      inviteCode: tenant.Item?.inviteCode ?? null,
      alreadyExists: true,
    });
  }

  const body = event.body ? JSON.parse(event.body) : {};
  const role = (body.role ?? jwt['custom:role']) as Role;
  if (role !== 'admin') {
    return response(403, {
      error: { code: 'FORBIDDEN', message: 'Only admins can create tenants' },
    });
  }

  const tenantId = generateTenantId();
  const inviteCode = generateInviteCode();
  const now = new Date().toISOString();

  await ddb.send(
    new PutCommand({
      TableName: TENANTS_TABLE,
      Item: {
        tenantId,
        adminUserId: userId,
        inviteCode,
        createdAt: now,
      },
      ConditionExpression: 'attribute_not_exists(tenantId)',
    }),
  );

  await ddb.send(
    new PutCommand({
      TableName: MEMBERS_TABLE,
      Item: {
        tenantId,
        userId,
        role: 'admin',
        email,
        joinedAt: now,
      },
    }),
  );

  await updateCognitoAttributes(userId, {
    'custom:tenant_id': tenantId,
    'custom:role': 'admin',
    'custom:onboarding_complete': 'true',
  });

  return response(201, { tenantId, inviteCode });
}

async function handleJoinTenant(event: APIGatewayProxyEventV2WithJWTAuthorizer) {
  const jwt = claims(event);
  const userId = jwt.sub;
  const email = jwt.email ?? '';

  if (jwt['custom:tenant_id']) {
    return response(200, {
      tenantId: jwt['custom:tenant_id'],
      alreadyJoined: true,
    });
  }

  const body = event.body ? JSON.parse(event.body) : {};
  const inviteCode = (body.inviteCode ?? '').toString().trim().toUpperCase();
  if (!inviteCode) {
    return response(400, {
      error: { code: 'INVALID_REQUEST', message: 'inviteCode is required' },
    });
  }

  const tenants = await ddb.send(
    new QueryCommand({
      TableName: TENANTS_TABLE,
      IndexName: 'InviteCodeIndex',
      KeyConditionExpression: 'inviteCode = :code',
      ExpressionAttributeValues: { ':code': inviteCode },
      Limit: 1,
    }),
  );

  const tenant = tenants.Items?.[0];
  if (!tenant) {
    return response(404, {
      error: { code: 'INVALID_INVITE', message: 'Invite code not found' },
    });
  }

  const tenantId = tenant.tenantId as string;
  const now = new Date().toISOString();
  const role: Role = 'readonly';

  await ddb.send(
    new PutCommand({
      TableName: MEMBERS_TABLE,
      Item: {
        tenantId,
        userId,
        role,
        email,
        joinedAt: now,
      },
      ConditionExpression: 'attribute_not_exists(userId)',
    }),
  );

  await updateCognitoAttributes(userId, {
    'custom:tenant_id': tenantId,
    'custom:role': role,
    'custom:onboarding_complete': 'true',
  });

  return response(200, { tenantId, role });
}

async function handleSetRole(event: APIGatewayProxyEventV2WithJWTAuthorizer) {
  const jwt = claims(event);
  const userId = jwt.sub;
  const body = event.body ? JSON.parse(event.body) : {};
  const role = body.role as Role;

  if (role !== 'admin' && role !== 'readonly') {
    return response(400, {
      error: { code: 'INVALID_ROLE', message: 'role must be admin or readonly' },
    });
  }

  if (jwt['custom:onboarding_complete'] === 'true') {
    return response(200, {
      role: jwt['custom:role'],
      tenantId: jwt['custom:tenant_id'] ?? null,
      alreadySet: true,
    });
  }

  await updateCognitoAttributes(userId, {
    'custom:role': role,
  });

  if (role === 'admin') {
    return handleCreateTenant({
      ...event,
      body: JSON.stringify({ role: 'admin' }),
    });
  }

  return response(200, { role, requiresInviteCode: true });
}

export async function handler(
  event: APIGatewayProxyEventV2WithJWTAuthorizer,
): Promise<APIGatewayProxyResultV2> {
  try {
    const method = event.requestContext.http.method;
    const path = event.rawPath;

    if (method === 'GET' && path === '/users/me') {
      return handleGetMe(event);
    }
    if (method === 'POST' && path === '/tenants') {
      return handleCreateTenant(event);
    }
    if (method === 'POST' && path === '/tenants/join') {
      return handleJoinTenant(event);
    }
    if (method === 'POST' && path === '/users/role') {
      return handleSetRole(event);
    }

    return response(404, {
      error: { code: 'NOT_FOUND', message: `Route not found: ${method} ${path}` },
    });
  } catch (err) {
    console.error(err);
    return response(500, {
      error: { code: 'INTERNAL_ERROR', message: 'Internal server error' },
    });
  }
}
