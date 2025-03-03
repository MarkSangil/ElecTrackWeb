import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_flutter_web_app/ConsumptionCalculatorModal.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _wattsLimitController = TextEditingController();

  bool _isWattsLimitEnabled = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _avatarBase64;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _showConsumptionCalculator(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => ConsumptionCalculatorModal(),
    );
  }

  Future<void> _loadUserData() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final userDoc =
      await _firestore.collection('users').doc(currentUser.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _nameController.text = data['name'] ?? '';
          _wattsLimitController.text = data['wattsLimit']?.toString() ?? '';
          _isWattsLimitEnabled = data['isWattsLimitEnabled'] ?? false;
          _avatarBase64 = data['avatarBase64'];
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _pickAvatarImage() async {
    try {
      final picker = ImagePicker();
      final pickedImage = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );
      if (pickedImage == null) return;

      final bytes = await File(pickedImage.path).readAsBytes();
      final base64String = base64Encode(bytes);

      setState(() {
        _avatarBase64 = base64String;
      });

      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _firestore.collection('users').doc(currentUser.uid).update({
          'avatarBase64': base64String,
        });
      }
    } catch (e) {
      debugPrint('Error picking avatar: $e');
    }
  }

  Future<void> _saveProfile() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _firestore.collection('users').doc(currentUser.uid).set(
        {
          'name': _nameController.text.trim(),
          'wattsLimit': int.tryParse(_wattsLimitController.text) ?? 0,
          'isWattsLimitEnabled': _isWattsLimitEnabled,
          'email': currentUser.email,
        },
        SetOptions(merge: true),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update profile'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget avatarWidget;
    if (_avatarBase64 != null && _avatarBase64!.isNotEmpty) {
      final decodedBytes = base64Decode(_avatarBase64!);
      avatarWidget = CircleAvatar(
        radius: 60,
        backgroundColor: Colors.grey.shade300,
        child: ClipOval(
          child: Image.memory(
            decodedBytes,
            fit: BoxFit.cover,
            width: 120,
            height: 120,
          ),
        ),
      );
    } else {
      avatarWidget = const CircleAvatar(
        radius: 60,
        backgroundColor: Colors.grey,
        child: Icon(
          Icons.person,
          size: 60,
          color: Colors.white,
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          avatarWidget,
                          IconButton(
                            icon: const Icon(
                                Icons.camera_alt, color: Colors.white),
                            onPressed: _pickAvatarImage,
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),

                      Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        elevation: 5,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              TextField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  labelText: 'Name',
                                  prefixIcon: const Icon(Icons.person),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 15),
                              Row(
                                children: [
                                  const Icon(Icons.email, color: Colors.grey),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _auth.currentUser?.email ??
                                          "Not available",
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 5,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Power Settings',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 15),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _wattsLimitController,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      enabled: _isWattsLimitEnabled,
                                      decoration: InputDecoration(
                                        labelText: 'Consumption Limit (W)',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Switch(
                                    value: _isWattsLimitEnabled,
                                    onChanged: (value) {
                                      setState(() {
                                        _isWattsLimitEnabled = value;
                                        if (!value) {
                                          _wattsLimitController.clear();
                                        }
                                      });
                                    },
                                    activeColor: Colors.green,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 15),

                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => _showConsumptionCalculator(context),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    backgroundColor: Colors.orange,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'Open Consumption Calculator',
                                    style: TextStyle(fontSize: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 20),
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saveProfile,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            backgroundColor: Colors.blueAccent,
                          ),
                          child: const Text(
                            'Save Profile',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
