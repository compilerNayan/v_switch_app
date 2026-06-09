import 'dart:math';

const _base36 = '0123456789abcdefghijklmnopqrstuvwxyz';

String generateTenantId({int length = 7, Random? random}) {
  final rng = random ?? Random.secure();
  return List.generate(length, (_) => _base36[rng.nextInt(_base36.length)]).join();
}
