import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConsumptionAlertService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> checkConsumptionAndAlert() async {
    debugPrint("DEBUG: checkConsumptionAndAlert() called.");

    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      debugPrint("DEBUG: No user logged in. Exiting checkConsumptionAndAlert().");
      return;
    }

    debugPrint("DEBUG: Current user UID: ${currentUser.uid}");
    String userId = currentUser.uid;

    DocumentSnapshot userData = await _firestore.collection('users').doc(userId).get();
    if (!userData.exists) {
      debugPrint("DEBUG: User doc doesn't exist. Exiting checkConsumptionAndAlert().");
      return;
    }

    var userMap = userData.data() as Map<String, dynamic>;
    debugPrint("DEBUG: userMap: $userMap");

    if (userMap['isWattsLimitEnabled'] != true) {
      debugPrint("DEBUG: isWattsLimitEnabled is not true. Exiting checkConsumptionAndAlert().");
      return;
    }

    var today = DateTime.now();
    String dateString = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    debugPrint("DEBUG: Querying appliances for date: $dateString");

    double totalConsumption = 0.0;

    QuerySnapshot appliancesData = await _firestore
        .collection('users')
        .doc(userId)
        .collection('appliances')
        .where('date', isEqualTo: dateString)
        .get();

    debugPrint("DEBUG: Fetched ${appliancesData.docs.length} appliances for date $dateString");

    for (var doc in appliancesData.docs) {
      var data = doc.data() as Map<String, dynamic>;
      double consumption = (data['consumption'] is num) ? (data['consumption'] as num).toDouble() : 0.0;
      debugPrint("DEBUG: Appliance ${doc.id}, consumption = $consumption");
      totalConsumption += consumption;
    }

    debugPrint("DEBUG: Total consumption so far: $totalConsumption");

    double wattsLimit = (userMap['wattsLimit'] as num?)?.toDouble() ?? 0.0;
    debugPrint("DEBUG: User's daily wattsLimit: $wattsLimit");

    // Show alert if total consumption exceeds the limit
    if (totalConsumption >= wattsLimit) {
      debugPrint("DEBUG: totalConsumption > wattsLimit. Showing alert...");
      _showAlert(totalConsumption, wattsLimit);
    } else {
      debugPrint("DEBUG: totalConsumption <= wattsLimit. No alert triggered.");
    }
  }

  void _showAlert(double totalConsumption, double limit) {
    debugPrint("DEBUG: _showAlert() called with totalConsumption=$totalConsumption, limit=$limit");
    String message =
        "⚠ Alert: You have exceeded your daily limit of $limit watts. "
        "Your current total is $totalConsumption watts.";
    html.window.alert(message);
  }
}
