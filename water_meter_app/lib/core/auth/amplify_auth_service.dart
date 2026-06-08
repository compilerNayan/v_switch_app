import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

import '../config/app_config.dart';
import '../models/user_profile.dart' as app;
import 'auth_service.dart';

class AmplifyAuthService implements AuthService {
  bool _configured = false;

  @override
  Future<void> initialize() async {
    if (_configured || !AppConfig.isAmplifyConfigured) return;

    try {
      await Amplify.addPlugin(AmplifyAuthCognito());
      await Amplify.configure(_amplifyConfig);
      _configured = true;
    } on AmplifyAlreadyConfiguredException {
      _configured = true;
    }
  }

  @override
  Future<app.UserProfile?> getCurrentUser() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession(
        options: const FetchAuthSessionOptions(forceRefresh: false),
      );
      if (!session.isSignedIn) return null;

      final cognitoSession = session as CognitoAuthSession;
      final idToken = cognitoSession.userPoolTokensResult.value.idToken.raw;
      final attrs = await Amplify.Auth.fetchUserAttributes();
      return _profileFromAttributes(attrs, idToken);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> getIdToken() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession(
        options: const FetchAuthSessionOptions(forceRefresh: false),
      );
      if (!session.isSignedIn) return null;
      final cognitoSession = session as CognitoAuthSession;
      return cognitoSession.userPoolTokensResult.value.idToken.raw;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<app.UserProfile> signInWithGoogle() async {
    final result = await Amplify.Auth.signInWithWebUI(
      provider: AuthProvider.google,
      options: const SignInWithWebUIOptions(
        pluginOptions: CognitoSignInWithWebUIPluginOptions(
          isPreferPrivateSession: true,
        ),
      ),
    );
    if (!result.isSignedIn) {
      throw Exception('Google sign-in was not completed');
    }
    final profile = await getCurrentUser();
    if (profile == null) throw Exception('Failed to load user profile');
    return profile;
  }

  @override
  Future<void> signOut() async {
    await Amplify.Auth.signOut(
      options: const SignOutOptions(globalSignOut: true),
    );
  }

  @override
  Future<void> refreshProfile() async {
    await Amplify.Auth.fetchAuthSession(
      options: const FetchAuthSessionOptions(forceRefresh: true),
    );
  }

  app.UserProfile _profileFromAttributes(
    List<AuthUserAttribute> attrs,
    String idToken,
  ) {
    String? email;
    String? name;
    String? tenantId;
    String? onboardingComplete;
    String? isTenantOwner;
    String? sub;

    for (final attr in attrs) {
      switch (attr.userAttributeKey.key) {
        case 'email':
          email = attr.value;
        case 'name':
          name = attr.value;
        case 'sub':
          sub = attr.value;
        case 'custom:tenant_id':
          tenantId = attr.value.isEmpty ? null : attr.value;
        case 'custom:onboarding_complete':
          onboardingComplete = attr.value;
        case 'custom:is_tenant_owner':
          isTenantOwner = attr.value;
      }
    }

    return app.UserProfile(
      userId: sub ?? '',
      email: email ?? '',
      displayName: name ?? email ?? '',
      tenantId: tenantId,
      onboardingComplete: onboardingComplete == 'true',
      isTenantOwner: isTenantOwner == 'true',
      idToken: idToken,
    );
  }

  String get _amplifyConfig => '''
{
  "auth": {
    "plugins": {
      "awsCognitoAuthPlugin": {
        "UserAgent": "aws-amplify-flutter",
        "Version": "1.0.0",
        "CognitoUserPool": {
          "Default": {
            "PoolId": "${AppConfig.cognitoUserPoolId}",
            "AppClientId": "${AppConfig.cognitoClientId}",
            "Region": "${AppConfig.cognitoRegion}"
          }
        },
        "Auth": {
          "Default": {
            "OAuth": {
              "WebDomain": "${AppConfig.cognitoDomain}",
              "AppClientId": "${AppConfig.cognitoClientId}",
              "SignInRedirectURI": "${AppConfig.oauthRedirectUri}",
              "SignOutRedirectURI": "${AppConfig.oauthSignOutUri}",
              "Scopes": ["email", "openid", "profile"],
              "ResponseType": "code"
            },
            "authenticationFlowType": "USER_SRP_AUTH",
            "socialProviders": ["GOOGLE"]
          }
        }
      }
    }
  }
}
''';
}
