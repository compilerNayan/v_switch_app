class TariffConfig {
  const TariffConfig({
    this.currencySymbol = '₹',
    this.costPerLiter = 0.05,
  });

  factory TariffConfig.fromJson(Map<String, dynamic> json) {
    return TariffConfig(
      currencySymbol: json['currencySymbol'] as String? ?? '₹',
      costPerLiter: (json['costPerLiter'] as num?)?.toDouble() ?? 0.05,
    );
  }

  final String currencySymbol;
  final double costPerLiter;

  double costForLiters(double liters) => liters * costPerLiter;

  Map<String, dynamic> toJson() => {
        'currencySymbol': currencySymbol,
        'costPerLiter': costPerLiter,
      };

  TariffConfig copyWith({
    String? currencySymbol,
    double? costPerLiter,
  }) {
    return TariffConfig(
      currencySymbol: currencySymbol ?? this.currencySymbol,
      costPerLiter: costPerLiter ?? this.costPerLiter,
    );
  }
}
