import 'package:flutter/material.dart';

/// Detects rapid repeated taps (Android developer-options style).
class SecretTapDetector extends StatefulWidget {
  const SecretTapDetector({
    super.key,
    required this.child,
    required this.onActivated,
    this.requiredTaps = 10,
    this.resetAfter = const Duration(seconds: 3),
  });

  final Widget child;
  final VoidCallback onActivated;
  final int requiredTaps;
  final Duration resetAfter;

  @override
  State<SecretTapDetector> createState() => _SecretTapDetectorState();
}

class _SecretTapDetectorState extends State<SecretTapDetector> {
  int _tapCount = 0;
  DateTime? _firstTapAt;

  void _onTap() {
    final now = DateTime.now();
    if (_firstTapAt == null ||
        now.difference(_firstTapAt!) > widget.resetAfter) {
      _firstTapAt = now;
      _tapCount = 1;
    } else {
      _tapCount++;
    }

    if (_tapCount >= widget.requiredTaps) {
      _tapCount = 0;
      _firstTapAt = null;
      widget.onActivated();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: widget.child,
    );
  }
}
