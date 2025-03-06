import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DashboardService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch the user's wattsLimit (and possibly other fields) from Firestore
  Future<double> fetchWattsLimit() async {
    final user = _auth.currentUser;
    if (user == null) return 0.0;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return 0.0;

    final data = userDoc.data() as Map<String, dynamic>? ?? {};
    final limit = (data['wattsLimit'] as num?)?.toDouble() ?? 0.0;
    return limit;
  }

  /// Add a new appliance document
  Future<void> addAppliance({
    required String applianceName,
    required double watts,
    required String time,
    required String date,
    required double consumption,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final applianceData = {
      'appliance': applianceName.trim(),
      'watts': watts,
      'time': time,
      'date': date,
      'consumption': consumption,
    };

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('appliances')
        .add(applianceData);
  }

  /// Delete an appliance
  Future<void> deleteAppliance(String docId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('appliances')
        .doc(docId)
        .delete();
  }
}