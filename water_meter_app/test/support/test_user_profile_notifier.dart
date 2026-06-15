import 'package:water_meter_app/core/models/user_profile.dart';
import 'package:water_meter_app/core/providers/app_providers.dart';

class TestUserProfileNotifier extends UserProfileNotifier {
  TestUserProfileNotifier(this.profile);

  final UserProfile? profile;

  @override
  Future<UserProfile?> build() async => profile;
}
