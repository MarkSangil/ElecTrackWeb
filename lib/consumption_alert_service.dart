import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConsumptionAlertService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> checkConsumptionAndAlert() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      print("No user logged in.");
      return;
    }

    String userId = currentUser.uid;
    DocumentSnapshot userData =
    await _firestore.collection('users').doc(userId).get();

    if (userData.data() == null) {
      print("User data not found.");
      return;
    }

    var user = userData.data() as Map<String, dynamic>;

    if (user['isWattsLimitEnabled'] != true) {
      print("Watts limit is not enabled.");
      return;
    }

    var today = DateTime.now();
    String dateString =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    double totalConsumption = 0.0;

    QuerySnapshot appliancesData = await _firestore
        .collection('users')
        .doc(userId)
        .collection('appliances')
        .where('date', isEqualTo: dateString)
        .get();

    print("Fetched ${appliancesData.docs.length} appliances for date $dateString");

    for (var doc in appliancesData.docs) {
      var data = doc.data() as Map<String, dynamic>;

      double consumption = (data['consumption'] is num)
          ? (data['consumption'] as num).toDouble()
          : 0.0;
      totalConsumption += consumption;
    }

    print("Total consumption for the day: $totalConsumption");

    double wattsLimit = (user['wattsLimit'] as num).toDouble();
    if (totalConsumption > wattsLimit) {
      print("Total consumption exceeds limit.");
      _showAlert(totalConsumption, wattsLimit);
    }
  }

  void _showAlert(double totalConsumption, double limit) {
    String message =
        "⚠ Alert: You have exceeded your daily limit of $limit watts. Your current total is $totalConsumption watts.";
    html.window.alert(message);
  }
}
