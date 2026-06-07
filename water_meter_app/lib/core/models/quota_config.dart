/// Daily quota rules: steps sorted by [QuotaStep.atLitersUsed].
/// Each `reduce_pressure` step subtracts [QuotaStep.value] percentage points
/// from a 100% baseline (cumulative). `turn_off` sets cap to 0%.
enum QuotaStepAction {
  reducePressure,
  turnOff;

  static QuotaStepAction fromJson(String value) {
    switch (value) {
      case 'turn_off':
        return QuotaStepAction.turnOff;
      case 'reduce_pressure':
      default:
        return QuotaStepAction.reducePressure;
    }
  }

  String toJson() {
    switch (this) {
      case QuotaStepAction.reducePressure:
        return 'reduce_pressure';
      case QuotaStepAction.turnOff:
        return 'turn_off';
    }
  }

  String get label {
    switch (this) {
      case QuotaStepAction.reducePressure:
        return 'Reduce pressure';
      case QuotaStepAction.turnOff:
        return 'Turn off';
    }
  }
}

class QuotaStep {
  const QuotaStep({
    required this.atLitersUsed,
    required this.action,
    this.value,
  });

  factory QuotaStep.fromJson(Map<String, dynamic> json) {
    return QuotaStep(
      atLitersUsed: (json['atLitersUsed'] as num).toDouble(),
      action: QuotaStepAction.fromJson(json['action'] as String),
      value: json['value'] == null ? null : (json['value'] as num).toDouble(),
    );
  }

  final double atLitersUsed;
  final QuotaStepAction action;
  final double? value;

  Map<String, dynamic> toJson() => {
        'atLitersUsed': atLitersUsed,
        'action': action.toJson(),
        if (value != null) 'value': value,
      };

  QuotaStep copyWith({
    double? atLitersUsed,
    QuotaStepAction? action,
    double? value,
    bool clearValue = false,
  }) {
    return QuotaStep(
      atLitersUsed: atLitersUsed ?? this.atLitersUsed,
      action: action ?? this.action,
      value: clearValue ? null : (value ?? this.value),
    );
  }
}

class QuotaStatus {
  const QuotaStatus({
    required this.date,
    required this.usedLiters,
    required this.activeStepIndex,
    this.quotaCapPercent,
    required this.remainingLiters,
    this.nextStepAtLiters,
  });

  factory QuotaStatus.fromJson(Map<String, dynamic> json) {
    return QuotaStatus(
      date: DateTime.parse(json['date'] as String),
      usedLiters: (json['usedLiters'] as num).toDouble(),
      activeStepIndex: json['activeStepIndex'] as int,
      quotaCapPercent: json['quotaCapPercent'] == null
          ? null
          : (json['quotaCapPercent'] as num).toDouble(),
      remainingLiters: (json['remainingLiters'] as num).toDouble(),
      nextStepAtLiters: json['nextStepAtLiters'] == null
          ? null
          : (json['nextStepAtLiters'] as num).toDouble(),
    );
  }

  final DateTime date;
  final double usedLiters;
  final int activeStepIndex;
  final double? quotaCapPercent;
  final double remainingLiters;
  final double? nextStepAtLiters;

  Map<String, dynamic> toJson() => {
        'date':
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'usedLiters': usedLiters,
        'activeStepIndex': activeStepIndex,
        'quotaCapPercent': quotaCapPercent,
        'remainingLiters': remainingLiters,
        'nextStepAtLiters': nextStepAtLiters,
      };
}

class QuotaResponse {
  const QuotaResponse({
    required this.deviceId,
    required this.enabled,
    required this.dailyLimitLiters,
    required this.timezone,
    required this.steps,
    required this.status,
  });

  factory QuotaResponse.fromJson(Map<String, dynamic> json) {
    return QuotaResponse(
      deviceId: json['deviceId'] as String,
      enabled: json['enabled'] as bool,
      dailyLimitLiters: (json['dailyLimitLiters'] as num).toDouble(),
      timezone: json['timezone'] as String,
      steps: (json['steps'] as List<dynamic>)
          .map((e) => QuotaStep.fromJson(e as Map<String, dynamic>))
          .toList(),
      status: QuotaStatus.fromJson(json['status'] as Map<String, dynamic>),
    );
  }

  final String deviceId;
  final bool enabled;
  final double dailyLimitLiters;
  final String timezone;
  final List<QuotaStep> steps;
  final QuotaStatus status;

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'enabled': enabled,
        'dailyLimitLiters': dailyLimitLiters,
        'timezone': timezone,
        'steps': steps.map((s) => s.toJson()).toList(),
        'status': status.toJson(),
      };
}

class QuotaUpdateRequest {
  const QuotaUpdateRequest({
    required this.enabled,
    required this.dailyLimitLiters,
    required this.steps,
  });

  final bool enabled;
  final double dailyLimitLiters;
  final List<QuotaStep> steps;

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'dailyLimitLiters': dailyLimitLiters,
        'steps': steps.map((s) => s.toJson()).toList(),
      };
}

/// Computes quota pressure cap from triggered steps.
class QuotaCalculator {
  QuotaCalculator._();

  static QuotaCapResult computeCap({
    required List<QuotaStep> steps,
    required double usedLiters,
    required double dailyLimitLiters,
  }) {
    final sorted = List<QuotaStep>.from(steps)
      ..sort((a, b) => a.atLitersUsed.compareTo(b.atLitersUsed));

    var cap = 100.0;
    var activeIndex = -1;
    double? nextStepAt;

    for (var i = 0; i < sorted.length; i++) {
      final step = sorted[i];
      if (usedLiters < step.atLitersUsed) {
        nextStepAt ??= step.atLitersUsed;
        break;
      }
      activeIndex = i;
      if (step.action == QuotaStepAction.turnOff) {
        cap = 0;
      } else if (step.action == QuotaStepAction.reducePressure) {
        cap -= step.value ?? 0;
      }
      if (i + 1 < sorted.length) {
        nextStepAt = sorted[i + 1].atLitersUsed;
      } else {
        nextStepAt = null;
      }
    }

    cap = cap.clamp(0, 100).toDouble();
    final remaining =
        (dailyLimitLiters - usedLiters).clamp(0, dailyLimitLiters).toDouble();

    return QuotaCapResult(
      capPercent: cap,
      activeStepIndex: activeIndex,
      nextStepAtLiters: nextStepAt,
      remainingLiters: remaining,
    );
  }
}

class QuotaCapResult {
  const QuotaCapResult({
    required this.capPercent,
    required this.activeStepIndex,
    this.nextStepAtLiters,
    required this.remainingLiters,
  });

  final double capPercent;
  final int activeStepIndex;
  final double? nextStepAtLiters;
  final double remainingLiters;
}
