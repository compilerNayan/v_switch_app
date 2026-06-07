import 'quota_config.dart';

class QuotaTemplate {
  const QuotaTemplate({
    required this.id,
    required this.name,
    required this.dailyLimitLiters,
    required this.steps,
  });

  static const defaults = [
    QuotaTemplate(
      id: 'standard',
      name: 'Standard 500L',
      dailyLimitLiters: 500,
      steps: [
        QuotaStep(atLitersUsed: 300, action: QuotaStepAction.reducePressure, value: 20),
        QuotaStep(atLitersUsed: 400, action: QuotaStepAction.reducePressure, value: 20),
        QuotaStep(atLitersUsed: 500, action: QuotaStepAction.turnOff),
      ],
    ),
    QuotaTemplate(
      id: 'studio',
      name: 'Studio 300L',
      dailyLimitLiters: 300,
      steps: [
        QuotaStep(atLitersUsed: 200, action: QuotaStepAction.reducePressure, value: 30),
        QuotaStep(atLitersUsed: 300, action: QuotaStepAction.turnOff),
      ],
    ),
    QuotaTemplate(
      id: 'generous',
      name: 'Generous 800L',
      dailyLimitLiters: 800,
      steps: [
        QuotaStep(atLitersUsed: 600, action: QuotaStepAction.reducePressure, value: 20),
        QuotaStep(atLitersUsed: 800, action: QuotaStepAction.turnOff),
      ],
    ),
  ];

  factory QuotaTemplate.fromJson(Map<String, dynamic> json) {
    return QuotaTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      dailyLimitLiters: (json['dailyLimitLiters'] as num).toDouble(),
      steps: (json['steps'] as List<dynamic>)
          .map((e) => QuotaStep.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String name;
  final double dailyLimitLiters;
  final List<QuotaStep> steps;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dailyLimitLiters': dailyLimitLiters,
        'steps': steps.map((s) => s.toJson()).toList(),
      };
}
