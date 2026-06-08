class PendingRegistration {
  const PendingRegistration({
    required this.email,
    required this.password,
    required this.phone,
    required this.firstName,
    required this.lastName,
    required this.tenantName,
  });

  final String email;
  final String password;
  final String phone;
  final String firstName;
  final String lastName;
  final String tenantName;
}
