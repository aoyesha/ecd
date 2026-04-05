import 'dart:async';
import 'package:flutter/material.dart';

class OtpCountdown extends StatefulWidget {
  final DateTime expiresAt;

  const OtpCountdown({
    super.key,
    required this.expiresAt,
  });

  @override
  State<OtpCountdown> createState() => _OtpCountdownState();
}

class _OtpCountdownState extends State<OtpCountdown> {
  late Duration remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant OtpCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.expiresAt != widget.expiresAt) {
      _timer?.cancel();
      _startTimer();
    }
  }

  void _startTimer() {
    _updateRemaining();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
    });
  }

  void _updateRemaining() {
    final diff = widget.expiresAt.difference(DateTime.now());

    if (diff.isNegative) {
      _timer?.cancel();
      setState(() => remaining = Duration.zero);
    } else {
      setState(() => remaining = diff);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      'Expires at ${format(remaining)}',
      style: const TextStyle(
        color: Color(0xFF999999),
        fontSize: 12,
      ),
    );
  }
}