class UserDevice {
  const UserDevice({
    required this.id,
    required this.typeId,
    required this.name,
    required this.deviceId,
  });

  factory UserDevice.fromJson(Map<String, dynamic> json) {
    return UserDevice(
      id: json['id'] as String,
      typeId: json['typeId'] as String,
      name: json['name'] as String,
      deviceId: json['deviceId'] as String,
    );
  }

  final String id;
  final String typeId;
  final String name;
  final String deviceId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'typeId': typeId,
        'name': name,
        'deviceId': deviceId,
      };

  UserDevice copyWith({
    String? id,
    String? typeId,
    String? name,
    String? deviceId,
  }) {
    return UserDevice(
      id: id ?? this.id,
      typeId: typeId ?? this.typeId,
      name: name ?? this.name,
      deviceId: deviceId ?? this.deviceId,
    );
  }
}
