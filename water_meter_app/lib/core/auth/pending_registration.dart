class PendingRegistration {
  const PendingRegistration({
    required this.email,
    required this.password,
    required this.phone,
    required this.firstName,
    required this.lastName,
  });

  final String email;
  final String password;
  final String phone;
  final String firstName;
  final String lastName;
}
