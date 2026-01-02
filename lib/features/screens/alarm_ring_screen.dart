
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:wake_up_new/features/provider/alarm_provider.dart';
import 'package:wake_up_new/features/provider/alarm_ring_provider.dart';

class AlarmRingScreen extends StatelessWidget {
  final int alarmId;
  const AlarmRingScreen({super.key, required this.alarmId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AlarmRingProvider(
        alarmId: alarmId,
        alarmProvider: Provider.of<AlarmProvider>(context, listen: false),
      ),
      child: const _AlarmRingScreenContent(),
    );
  }
}

class _AlarmRingScreenContent extends StatelessWidget {
  const _AlarmRingScreenContent();

  @override
  Widget build(BuildContext context) {
    return Consumer<AlarmRingProvider>(
      builder: (context, provider, child) {
        return PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Auto-snooze warning
                      if (!provider.autoSnoozed &&
                          provider.manualCheckEnabled &&
                          provider.remainingBeforeSnooze <= 30)
                        _AutoSnoozeWarning(
                          remainingSeconds: provider.remainingBeforeSnooze,
                        ),

                      // Camera preview
                      if (provider.showCamera &&
                          provider.cameraController != null &&
                          provider.cameraController!.value.isInitialized)
                        _CameraPreview(
                          controller: provider.cameraController!,
                          sleepinessScore: provider.sleepinessScore,
                        ),

                      if (provider.showCamera)
                        const SizedBox(height: 20),

                      // Status title
                      _StatusTitle(
                        showCamera: provider.showCamera,
                        prepComplete: provider.prepComplete,
                      ),

                      const SizedBox(height: 12),

                      // Countdown timer
                      if (!provider.prepComplete && !provider.showCamera)
                        _CountdownTimer(
                          remainingSeconds: provider.remainingSeconds,
                        ),

                      // Sleepiness indicator
                      if (provider.showCamera)
                        _SleepinessIndicator(
                          level: provider.sleepinessLevel,
                          score: provider.sleepinessScore,
                        ),

                      const SizedBox(height: 20),

                      // Status text
                      Text(
                        provider.statusText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Action buttons
                      _ActionButtons(
                        checking: provider.checking,
                        manualCheckEnabled: provider.manualCheckEnabled,
                        autoSnoozed: provider.autoSnoozed,
                        remainingSeconds: provider.remainingSeconds,
                        onCheckAwake: () async {
                          final success = await provider.checkAwake();
                          if (success && context.mounted) {
                            await provider.dismissAlarm();
                            Navigator.of(context).popUntil((r) => r.isFirst);
                          }
                        },
                        onDismiss: () async {
                          await provider.dismissAlarm();
                          if (context.mounted) {
                            Navigator.of(context).popUntil((r) => r.isFirst);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ==================== UI COMPONENTS ====================

class _AutoSnoozeWarning extends StatelessWidget {
  final int remainingSeconds;

  const _AutoSnoozeWarning({required this.remainingSeconds});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red, width: 2),
          ),
          child: Text(
            '⚠️ New alarm in ${remainingSeconds}s',
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _CameraPreview extends StatelessWidget {
  final CameraController controller;
  final double sleepinessScore;

  const _CameraPreview({
    required this.controller,
    required this.sleepinessScore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 240,
      decoration: BoxDecoration(
        border: Border.all(
          color: sleepinessScore > 0.7
              ? Colors.red
              : sleepinessScore > 0.5
              ? Colors.orange
              : Colors.green,
          width: 3,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: CameraPreview(controller),
      ),
    );
  }
}

class _StatusTitle extends StatelessWidget {
  final bool showCamera;
  final bool prepComplete;

  const _StatusTitle({
    required this.showCamera,
    required this.prepComplete,
  });

  @override
  Widget build(BuildContext context) {
    String text;
    if (showCamera) {
      text = 'SCANNING...';
    } else if (prepComplete) {
      text = 'READY!';
    } else {
      text = 'Get Ready...';
    }

    return Text(
      text,
      style: const TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 2,
      ),
    );
  }
}

class _CountdownTimer extends StatelessWidget {
  final int remainingSeconds;

  const _CountdownTimer({required this.remainingSeconds});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$remainingSeconds',
          style: const TextStyle(
            fontSize: 52,
            fontWeight: FontWeight.bold,
            color: Colors.orangeAccent,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SleepinessIndicator extends StatelessWidget {
  final String level;
  final double score;

  const _SleepinessIndicator({
    required this.level,
    required this.score,
  });

  Color get _indicatorColor {
    if (score > 0.7) return Colors.red;
    if (score > 0.5) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _indicatorColor, width: 2),
      ),
      child: Column(
        children: [
          const Text(
            'Alertness Level',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            level,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _indicatorColor,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: 1.0 - score,
              minHeight: 10,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation(_indicatorColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final bool checking;
  final bool manualCheckEnabled;
  final bool autoSnoozed;
  final int remainingSeconds;
  final VoidCallback onCheckAwake;
  final VoidCallback onDismiss;

  const _ActionButtons({
    required this.checking,
    required this.manualCheckEnabled,
    required this.autoSnoozed,
    required this.remainingSeconds,
    required this.onCheckAwake,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: (checking || !manualCheckEnabled || autoSnoozed)
              ? null
              : onCheckAwake,
          style: ElevatedButton.styleFrom(
            backgroundColor: manualCheckEnabled ? Colors.green : Colors.grey,
            padding: const EdgeInsets.symmetric(
              horizontal: 36,
              vertical: 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
          child: checking
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          )
              : Text(
            manualCheckEnabled
                ? 'I am awake'
                : 'Available in ${remainingSeconds}s',
            style: const TextStyle(fontSize: 16),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: autoSnoozed ? null : onDismiss,
          child: const Text(
            'Dismiss (Emergency)',
            style: TextStyle(color: Colors.redAccent),
          ),
        ),
      ],
    );
  }
}