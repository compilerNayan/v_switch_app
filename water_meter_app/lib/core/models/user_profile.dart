class UserProfile {
  const UserProfile({
    required this.userId,
    required this.email,
    required this.displayName,
    this.tenantId,
    this.onboardingComplete = false,
    this.isTenantOwner = false,
    this.idToken,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['userId'] as String,
      email: json['email'] as String? ?? '',
      displayName:
          json['displayName'] as String? ?? json['email'] as String? ?? '',
      tenantId: json['tenantId'] as String?,
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      isTenantOwner: json['isTenantOwner'] as bool? ?? false,
    );
  }

  final String userId;
  final String email;
  final String displayName;
  final String? tenantId;
  final bool onboardingComplete;
  final bool isTenantOwner;
  final String? idToken;

  bool get isAuthenticated => userId.isNotEmpty;

  bool get needsOnboarding => !onboardingComplete || tenantId == null;

  UserProfile copyWith({
    String? userId,
    String? email,
    String? displayName,
    String? tenantId,
    bool? onboardingComplete,
    bool? isTenantOwner,
    String? idToken,
    bool clearTenantId = false,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      tenantId: clearTenantId ? null : (tenantId ?? this.tenantId),
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      isTenantOwner: isTenantOwner ?? this.isTenantOwner,
      idToken: idToken ?? this.idToken,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'email': email,
        'displayName': displayName,
        if (tenantId != null) 'tenantId': tenantId,
        'onboardingComplete': onboardingComplete,
        'isTenantOwner': isTenantOwner,
      };
}
