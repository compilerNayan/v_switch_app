class DummyDeviceEnrollmentDraft {
  const DummyDeviceEnrollmentDraft({
    required this.serialNumber,
    required this.name,
    required this.flatNumber,
    required this.floor,
    required this.block,
    required this.wing,
    required this.residentName,
    required this.phoneNumber,
  });

  final String serialNumber;
  final String name;
  final String flatNumber;
  final String floor;
  final String block;
  final String wing;
  final String residentName;
  final String phoneNumber;

  Map<String, dynamic> toJson() => {
        'serialNumber': serialNumber,
        'name': name,
        'flatNumber': flatNumber,
        'floor': floor,
        'block': block,
        'wing': wing,
        'residentName': residentName,
        'phoneNumber': phoneNumber,
      };
}
