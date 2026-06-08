class UserProfile {
  const UserProfile({
    required this.userId,
    required this.email,
    required this.displayName,
    this.phone,
    this.firstName,
    this.lastName,
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
      phone: json['phone'] as String?,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      tenantId: json['tenantId'] as String?,
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      isTenantOwner: json['isTenantOwner'] as bool? ?? false,
    );
  }

  final String userId;
  final String email;
  final String displayName;
  final String? phone;
  final String? firstName;
  final String? lastName;
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
    String? phone,
    String? firstName,
    String? lastName,
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
      phone: phone ?? this.phone,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
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
        if (phone != null) 'phone': phone,
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
        if (tenantId != null) 'tenantId': tenantId,
        'onboardingComplete': onboardingComplete,
        'isTenantOwner': isTenantOwner,
      };
}
