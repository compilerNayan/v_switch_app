enum UserRole {
  admin,
  readonly;

  static UserRole? fromString(String? value) {
    switch (value) {
      case 'admin':
        return UserRole.admin;
      case 'readonly':
        return UserRole.readonly;
      default:
        return null;
    }
  }

  String toApiValue() {
    switch (this) {
      case UserRole.admin:
        return 'admin';
      case UserRole.readonly:
        return 'readonly';
    }
  }

  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.readonly:
        return 'Read-only';
    }
  }
}

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.email,
    required this.displayName,
    this.role,
    this.tenantId,
    this.inviteCode,
    this.onboardingComplete = false,
    this.idToken,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['userId'] as String,
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? json['email'] as String? ?? '',
      role: UserRole.fromString(json['role'] as String?),
      tenantId: json['tenantId'] as String?,
      inviteCode: json['inviteCode'] as String?,
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
    );
  }

  final String userId;
  final String email;
  final String displayName;
  final UserRole? role;
  final String? tenantId;
  final String? inviteCode;
  final bool onboardingComplete;
  final String? idToken;

  bool get isAuthenticated => userId.isNotEmpty;
  bool get needsRoleSelection => !onboardingComplete && role == null;
  bool get needsTenantJoin =>
      !onboardingComplete && role == UserRole.readonly && tenantId == null;
  bool get needsTenantCreation =>
      !onboardingComplete && role == UserRole.admin && tenantId == null;

  UserProfile copyWith({
    String? userId,
    String? email,
    String? displayName,
    UserRole? role,
    String? tenantId,
    String? inviteCode,
    bool? onboardingComplete,
    String? idToken,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      tenantId: tenantId ?? this.tenantId,
      inviteCode: inviteCode ?? this.inviteCode,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      idToken: idToken ?? this.idToken,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'email': email,
        'displayName': displayName,
        'role': role?.toApiValue(),
        'tenantId': tenantId,
        'inviteCode': inviteCode,
        'onboardingComplete': onboardingComplete,
      };
}
