import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

import '../config/app_config.dart';
import '../models/user_profile.dart' as app;
import 'auth_service.dart' show AuthService, AuthSignUpResult;

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
  Future<AuthSignUpResult> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    final result = await Amplify.Auth.signUp(
      username: email.trim(),
      password: password,
      options: SignUpOptions(
        userAttributes: {
          AuthUserAttributeKey.email: email.trim(),
          AuthUserAttributeKey.phoneNumber: phone.trim(),
          AuthUserAttributeKey.givenName: firstName.trim(),
          AuthUserAttributeKey.familyName: lastName.trim(),
        },
      ),
    );
    return AuthSignUpResult(
      requiresConfirmation:
          result.nextStep.signUpStep == AuthSignUpStep.confirmSignUp,
    );
  }

  @override
  Future<void> confirmSignUp({
    required String email,
    required String code,
  }) async {
    await Amplify.Auth.confirmSignUp(
      username: email.trim(),
      confirmationCode: code.trim(),
    );
  }

  @override
  Future<void> resendSignUpCode({required String email}) async {
    await Amplify.Auth.resendSignUpCode(username: email.trim());
  }

  @override
  Future<app.UserProfile> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final result = await Amplify.Auth.signIn(
      username: email.trim(),
      password: password,
    );
    if (!result.isSignedIn) {
      throw Exception('Sign-in was not completed');
    }
    final profile = await getCurrentUser();
    if (profile == null) {
      throw Exception('Failed to load user profile');
    }
    return profile;
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
    String? givenName;
    String? familyName;
    String? phone;
    String? sub;

    for (final attr in attrs) {
      switch (attr.userAttributeKey.key) {
        case 'email':
          email = attr.value;
        case 'name':
          name = attr.value;
        case 'given_name':
          givenName = attr.value;
        case 'family_name':
          familyName = attr.value;
        case 'phone_number':
          phone = attr.value;
        case 'sub':
          sub = attr.value;
      }
    }

    final displayName = name ??
        [givenName, familyName].where((part) => part != null && part.isNotEmpty).join(' ').trim();

    return app.UserProfile(
      userId: sub ?? '',
      email: email ?? '',
      displayName: displayName.isNotEmpty ? displayName : (email ?? ''),
      phone: phone,
      firstName: givenName,
      lastName: familyName,
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
            "authenticationFlowType": "USER_SRP_AUTH"
          }
        }
      }
    }
  }
}
''';
}
