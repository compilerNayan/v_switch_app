import 'package:intl/intl.dart';

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

/// Primary + optional compact labels for dashboard stat tiles.
class VolumeDisplay {
  const VolumeDisplay({
    required this.amount,
    required this.unit,
    this.compact,
  });

  /// Formatted numeric portion, e.g. `1,420.33` or `45,000,000.00`.
  final String amount;

  /// Unit suffix, e.g. `L`.
  final String unit;

  /// Shorthand such as `1.4k L` shown below the full figure.
  final String? compact;

  String get primary => '$amount $unit';
}

class VolumeFormatter {
  VolumeFormatter._();

  static const _litersPerUsGallon = 3.785411784;
  static final NumberFormat _dashboardFull = NumberFormat('#,##0.00');
  static final NumberFormat _dashboardCompactK = NumberFormat('#,##0.0');

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

  /// Full precision for dashboard totals; compact k-label when large.
  static VolumeDisplay formatDashboard(double liters, VolumeUnit unit) {
    final value = fromLiters(liters, unit);
    final amount = _dashboardFull.format(value);
    final String? compact;
    if (value.abs() >= 1000) {
      compact = '${_dashboardCompactK.format(value / 1000)}k ${unit.symbol}';
    } else {
      compact = null;
    }
    return VolumeDisplay(amount: amount, unit: unit.symbol, compact: compact);
  }

  static String formatCompact(double liters, VolumeUnit unit) {
    final value = fromLiters(liters, unit);
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k ${unit.symbol}';
    }
    return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} ${unit.symbol}';
  }
}
