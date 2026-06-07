enum VolumeUnit {
  liters,
  usGallons;

  String get label {
    switch (this) {
      case VolumeUnit.liters:
        return 'Liters';
      case VolumeUnit.usGallons:
        return 'US Gallons';
    }
  }

  String get symbol {
    switch (this) {
      case VolumeUnit.liters:
        return 'L';
      case VolumeUnit.usGallons:
        return 'gal';
    }
  }

  static VolumeUnit fromStorage(String? value) {
    switch (value) {
      case 'usGallons':
        return VolumeUnit.usGallons;
      default:
        return VolumeUnit.liters;
    }
  }

  String toStorage() {
    switch (this) {
      case VolumeUnit.liters:
        return 'liters';
      case VolumeUnit.usGallons:
        return 'usGallons';
    }
  }
}

class VolumeFormatter {
  VolumeFormatter._();

  static const _litersPerUsGallon = 3.785411784;

  static double fromLiters(double liters, VolumeUnit unit) {
    switch (unit) {
      case VolumeUnit.liters:
        return liters;
      case VolumeUnit.usGallons:
        return liters / _litersPerUsGallon;
    }
  }

  static String format(double liters, VolumeUnit unit, {int decimals = 1}) {
    final value = fromLiters(liters, unit);
    return '${value.toStringAsFixed(decimals)} ${unit.symbol}';
  }

  static String formatCompact(double liters, VolumeUnit unit) {
    final value = fromLiters(liters, unit);
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k ${unit.symbol}';
    }
    return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} ${unit.symbol}';
  }
}
