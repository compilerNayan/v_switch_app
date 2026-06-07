import * as cdk from 'aws-cdk-lib';
import * as apigwv2 from 'aws-cdk-lib/aws-apigatewayv2';
import * as apigwIntegrations from 'aws-cdk-lib/aws-apigatewayv2-integrations';
import * as apigwAuthorizers from 'aws-cdk-lib/aws-apigatewayv2-authorizers';
import * as cognito from 'aws-cdk-lib/aws-cognito';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as lambdaNodejs from 'aws-cdk-lib/aws-lambda-nodejs';
import * as iam from 'aws-cdk-lib/aws-iam';
import { Construct } from 'constructs';
import * as path from 'path';

export interface WaterMeterStackProps extends cdk.StackProps {
  /** Google OAuth Web client ID (for Cognito federated IdP). Leave empty to configure manually. */
  googleClientId?: string;
  /** Google OAuth Web client secret. Leave empty to configure manually. */
  googleClientSecret?: string;
}

export class WaterMeterStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: WaterMeterStackProps) {
    super(scope, id, props);

    const googleClientId = props?.googleClientId ?? process.env.GOOGLE_CLIENT_ID ?? '';
    const googleClientSecret =
      props?.googleClientSecret ?? process.env.GOOGLE_CLIENT_SECRET ?? '';

    // --- Cognito User Pool ---
    const userPool = new cognito.UserPool(this, 'WaterMeterUserPool', {
      userPoolName: 'water-meter-users',
      selfSignUpEnabled: true,
      signInAliases: { email: true },
      autoVerify: { email: true },
      standardAttributes: {
        email: { required: true, mutable: true },
      },
      customAttributes: {
        tenant_id: new cognito.StringAttribute({ mutable: true }),
        role: new cognito.StringAttribute({ mutable: true }),
        onboarding_complete: new cognito.StringAttribute({ mutable: true }),
      },
      passwordPolicy: {
        minLength: 8,
        requireLowercase: true,
        requireUppercase: true,
        requireDigits: true,
      },
      accountRecovery: cognito.AccountRecovery.EMAIL_ONLY,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    if (googleClientId && googleClientSecret) {
      new cognito.UserPoolIdentityProviderGoogle(this, 'GoogleIdP', {
        userPool,
        clientId: googleClientId,
        clientSecretValue: cdk.SecretValue.unsafePlainText(googleClientSecret),
        scopes: ['email', 'profile', 'openid'],
        attributeMapping: {
          email: cognito.ProviderAttribute.GOOGLE_EMAIL,
          givenName: cognito.ProviderAttribute.GOOGLE_GIVEN_NAME,
          familyName: cognito.ProviderAttribute.GOOGLE_FAMILY_NAME,
        },
      });
    }

    const userPoolClient = userPool.addClient('WaterMeterAppClient', {
      userPoolClientName: 'water-meter-mobile',
      authFlows: {
        userPassword: false,
        userSrp: false,
      },
      oAuth: {
        flows: { authorizationCodeGrant: true },
        scopes: [
          cognito.OAuthScope.EMAIL,
          cognito.OAuthScope.OPENID,
          cognito.OAuthScope.PROFILE,
        ],
        callbackUrls: [
          'com.vswitch.watermeter://callback/',
          'http://localhost:3000/callback/',
        ],
        logoutUrls: [
          'com.vswitch.watermeter://signout/',
          'http://localhost:3000/signout/',
        ],
      },
      supportedIdentityProviders: googleClientId
        ? [
            cognito.UserPoolClientIdentityProvider.GOOGLE,
            cognito.UserPoolClientIdentityProvider.COGNITO,
          ]
        : [cognito.UserPoolClientIdentityProvider.COGNITO],
      generateSecret: false,
      preventUserExistenceErrors: true,
    });

    const domain = userPool.addDomain('WaterMeterDomain', {
      cognitoDomain: {
        domainPrefix: `water-meter-${cdk.Aws.ACCOUNT_ID}`,
      },
    });

    // --- DynamoDB ---
    const tenantsTable = new dynamodb.Table(this, 'TenantsTable', {
      tableName: 'WaterMeterTenants',
      partitionKey: { name: 'tenantId', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    tenantsTable.addGlobalSecondaryIndex({
      indexName: 'InviteCodeIndex',
      partitionKey: { name: 'inviteCode', type: dynamodb.AttributeType.STRING },
      projectionType: dynamodb.ProjectionType.ALL,
    });

    const membersTable = new dynamodb.Table(this, 'MembersTable', {
      tableName: 'WaterMeterTenantMembers',
      partitionKey: { name: 'tenantId', type: dynamodb.AttributeType.STRING },
      sortKey: { name: 'userId', type: dynamodb.AttributeType.STRING },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
    });

    // --- Lambda ---
    const tenantServiceFn = new lambdaNodejs.NodejsFunction(
      this,
      'TenantServiceFn',
      {
        entry: path.join(__dirname, '../lambda/tenant-service/index.ts'),
        handler: 'handler',
        runtime: lambda.Runtime.NODEJS_20_X,
        timeout: cdk.Duration.seconds(30),
        environment: {
          TENANTS_TABLE: tenantsTable.tableName,
          MEMBERS_TABLE: membersTable.tableName,
          USER_POOL_ID: userPool.userPoolId,
        },
        bundling: { minify: true, sourceMap: true },
      },
    );

    tenantsTable.grantReadWriteData(tenantServiceFn);
    membersTable.grantReadWriteData(tenantServiceFn);
    tenantServiceFn.addToRolePolicy(
      new iam.PolicyStatement({
        actions: ['cognito-idp:AdminUpdateUserAttributes'],
        resources: [userPool.userPoolArn],
      }),
    );

    // --- API Gateway HTTP API ---
    const httpApi = new apigwv2.HttpApi(this, 'WaterMeterHttpApi', {
      apiName: 'water-meter-api',
      corsPreflight: {
        allowHeaders: ['Authorization', 'Content-Type'],
        allowMethods: [
          apigwv2.CorsHttpMethod.GET,
          apigwv2.CorsHttpMethod.POST,
          apigwv2.CorsHttpMethod.OPTIONS,
        ],
        allowOrigins: ['*'],
      },
    });

    const authorizer = new apigwAuthorizers.HttpJwtAuthorizer(
      'CognitoAuthorizer',
      `https://cognito-idp.${cdk.Aws.REGION}.amazonaws.com/${userPool.userPoolId}`,
      {
        jwtAudience: [userPoolClient.userPoolClientId],
      },
    );

    const lambdaIntegration = new apigwIntegrations.HttpLambdaIntegration(
      'TenantServiceIntegration',
      tenantServiceFn,
    );

    const routes = [
      { path: '/users/me', methods: [apigwv2.HttpMethod.GET] },
      { path: '/users/role', methods: [apigwv2.HttpMethod.POST] },
      { path: '/tenants', methods: [apigwv2.HttpMethod.POST] },
      { path: '/tenants/join', methods: [apigwv2.HttpMethod.POST] },
    ];

    for (const route of routes) {
      httpApi.addRoutes({
        path: route.path,
        methods: route.methods,
        integration: lambdaIntegration,
        authorizer,
      });
    }

    // --- Outputs ---
    new cdk.CfnOutput(this, 'UserPoolId', { value: userPool.userPoolId });
    new cdk.CfnOutput(this, 'UserPoolClientId', {
      value: userPoolClient.userPoolClientId,
    });
    new cdk.CfnOutput(this, 'CognitoDomain', {
      value: domain.baseUrl(),
    });
    new cdk.CfnOutput(this, 'ApiUrl', {
      value: httpApi.apiEndpoint,
    });
    new cdk.CfnOutput(this, 'Region', { value: cdk.Aws.REGION });
  }
}
