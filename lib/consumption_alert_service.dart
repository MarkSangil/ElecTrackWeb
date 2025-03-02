import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConsumptionAlertService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> checkConsumptionAndAlert() async {

    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      return;
    }

    String userId = currentUser.uid;

    DocumentSnapshot userData = await _firestore.collection('users').doc(userId).get();
    if (!userData.exists) {
      return;
    }

    var userMap = userData.data() as Map<String, dynamic>;

    if (userMap['isWattsLimitEnabled'] != true) {
      return;
    }

    var today = DateTime.now();
    String dateString = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    double totalConsumption = 0.0;

    QuerySnapshot appliancesData = await _firestore
        .collection('users')
        .doc(userId)
        .collection('appliances')
        .where('date', isEqualTo: dateString)
        .get();


    for (var doc in appliancesData.docs) {
      var data = doc.data() as Map<String, dynamic>;
      double consumption = (data['consumption'] is num) ? (data['consumption'] as num).toDouble() : 0.0;
      totalConsumption += consumption;
    }


    double wattsLimit = (userMap['wattsLimit'] as num?)?.toDouble() ?? 0.0;

    // Show alert if total consumption exceeds the limit
    if (totalConsumption >= wattsLimit) {
      _showAlert(totalConsumption, wattsLimit);
    } else {
    }
  }

  void _showAlert(double totalConsumption, double limit) {
    String message =
        "⚠ Alert: You have exceeded your daily limit of $limit watts. "
        "Your current total is $totalConsumption watts.";
    html.window.alert(message);
  }
}
