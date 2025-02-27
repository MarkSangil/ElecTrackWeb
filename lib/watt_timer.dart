import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WattTimer extends StatefulWidget {
  final String docId;        // ID of the Firestore document to update
  final double wattRating;   // e.g., 1000 for a 1000W appliance.
  final String applianceName;
  final void Function(double consumption)? onTimerStop;

  const WattTimer({
    Key? key,
    required this.docId,
    required this.wattRating,
    required this.applianceName,
    this.onTimerStop,
  }) : super(key: key);

  @override
  _WattTimerState createState() => _WattTimerState();
}

class _WattTimerState extends State<WattTimer> {
  bool _isRunning = false;
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsed += const Duration(seconds: 1);
      });
    });
  }

  /// If you want to save the final usage on STOP instead, do so here.
  Future<void> _stopTimer() async {
    _timer?.cancel();
    setState(() => _isRunning = false);

    final usage = currentConsumption;
    debugPrint('Stop pressed. usage = $usage');

    // 1) Save usage if > 0
    if (usage > 0) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('appliances')
            .doc(widget.docId);

        await docRef.update({
          'consumption': FieldValue.increment(usage),
        }).catchError((error) {
          debugPrint('Error updating consumption: $error');
        });
      }
    }

    // 2) Optional callback
    if (widget.onTimerStop != null) {
      widget.onTimerStop!(usage);
    }

    // 3) Reset the local timer so the next Start is fresh
    setState(() {
      _elapsed = Duration.zero;
    });
  }

  /// When resetting, we increment the existing 'consumption' in the doc.
  Future<void> _resetTimer() async {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });

    final usage = currentConsumption;
    debugPrint('Reset pressed. currentConsumption: $usage');

    // Only update if there's some usage
    if (usage > 0) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('appliances')
            .doc(widget.docId);

        // If you want to *overwrite* consumption instead of incrementing:
        // await docRef.update({'consumption': usage});
        //
        // If you want to add the usage to the existing consumption:
        await docRef.update({
          'consumption': FieldValue.increment(usage),
        }).catchError((error) {
          debugPrint('Error updating consumption: $error');
        });
      }
    }

    // Finally reset local timer
    setState(() => _elapsed = Duration.zero);
  }

  /// Compute consumption in kWh: (wattRating / 1000) * hours.
  double get currentConsumption {
    final hours = _elapsed.inSeconds / 3600.0;
    return (widget.wattRating / 1000.0) * hours;
  }

  @override
  Widget build(BuildContext context) {
    final hours = _elapsed.inHours.toString().padLeft(2, '0');
    final minutes = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.applianceName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '$hours:$minutes:$seconds',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Consumption: ${currentConsumption.toStringAsFixed(4)} kWh',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _isRunning ? null : _startTimer,
                  child: const Text('Start'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isRunning ? _stopTimer : null,
                  child: const Text('Stop'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _resetTimer,
                  child: const Text('Reset'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}