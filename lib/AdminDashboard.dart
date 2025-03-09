import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Admin Dashboard Page with Logout Button
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({Key? key}) : super(key: key);

  @override
  _AdminDashboardPageState createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('conversations').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No conversations yet.'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final conversationId = doc.id;
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text('Conversation: $conversationId'),
                  subtitle: const Text('Tap to open chat'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AdminChatScreen(conversationId: conversationId),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      // ADD A FLOATING BUTTON TO OPEN THE RATES PAGE
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.settings),
        onPressed: () {
          // Navigate to a new AdminRatesPage
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminRatesPage()),
          );
        },
      ),
    );
  }
}

/// Chat screen for the admin to view and send messages
class AdminChatScreen extends StatefulWidget {
  final String conversationId;
  const AdminChatScreen({Key? key, required this.conversationId})
      : super(key: key);

  @override
  _AdminChatScreenState createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen> {
  final _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final messagesQuery = _firestore
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false);
    return Scaffold(
      appBar: AppBar(title: Text('Chat: ${widget.conversationId}')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: messagesQuery.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final msgDocs = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: msgDocs.length,
                  itemBuilder: (context, index) {
                    final data =
                    msgDocs[index].data() as Map<String, dynamic>;
                    final sender = data['sender'] ?? 'Unknown';
                    final text = data['text'] ?? '';
                    final ts = data['timestamp'];
                    return ListTile(
                      title: Text('$sender: $text'),
                      subtitle: ts == null
                          ? null
                          : Text(ts.toDate().toString()),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    try {
      await _firestore
          .collection('conversations')
          .doc(widget.conversationId)
          .collection('messages')
          .add({
        'sender': 'admin',
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _messageController.clear();
    } catch (e) {
      print('Error sending message: $e');
    }
  }
}

class AdminRatesPage extends StatefulWidget {
  const AdminRatesPage({Key? key}) : super(key: key);

  @override
  _AdminRatesPageState createState() => _AdminRatesPageState();
}

class _AdminRatesPageState extends State<AdminRatesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<TierData> _tiers = [];
  final List<TextEditingController> _minControllers = [];
  final List<TextEditingController> _maxControllers = [];
  final List<TextEditingController> _rateControllers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentRates();
  }

  @override
  void dispose() {
    for (final c in _minControllers) c.dispose();
    for (final c in _maxControllers) c.dispose();
    for (final c in _rateControllers) c.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentRates() async {
    setState(() => _isLoading = true);
    try {
      final tiersSnapshot = await _firestore
          .collection('admin')
          .doc('JiLwbnNdP0FwBKGmDSiD')
          .collection('conversion')
          .doc('currentRates')
          .collection('tiers')
          .orderBy('tierNumber')
          .get();

      if (tiersSnapshot.docs.isEmpty) {
        _tiers.addAll([
          TierData(tierNumber: 1, minKwh: 1, maxKwh: 200, rate: 12.03),
          TierData(tierNumber: 2, minKwh: 201, maxKwh: 400, rate: 12.64),
          TierData(tierNumber: 3, minKwh: 401, maxKwh: 800, rate: 13.20),
        ]);
      } else {
        for (var doc in tiersSnapshot.docs) {
          final data = doc.data();
          _tiers.add(TierData(
            id: doc.id,
            tierNumber: data['tierNumber'] ?? 0,
            minKwh: data['minKwh'] ?? 0,
            maxKwh: data['maxKwh'] ?? 0,
            rate: (data['rate'] ?? 0.0).toDouble(),
          ));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading rates: $e')),
      );
      _tiers.addAll([
        TierData(tierNumber: 1, minKwh: 1, maxKwh: 200, rate: 12.03),
        TierData(tierNumber: 2, minKwh: 201, maxKwh: 400, rate: 12.64),
        TierData(tierNumber: 3, minKwh: 401, maxKwh: 800, rate: 13.20),
      ]);
    }

    _minControllers.clear();
    _maxControllers.clear();
    _rateControllers.clear();
    for (var t in _tiers) {
      _minControllers.add(TextEditingController(text: t.minKwh.toString()));
      _maxControllers.add(TextEditingController(text: t.maxKwh.toString()));
      _rateControllers.add(TextEditingController(text: t.rate.toString()));
    }

    setState(() => _isLoading = false);
  }

  Future<bool> _promptAdminCredentials(BuildContext context) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Admin Login'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Login'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return false;

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      return true;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid credentials: $e')),
      );
      return false;
    }
  }

  Future<void> _saveRates(BuildContext context, FirebaseFirestore firestore) async {
    final ok = await _promptAdminCredentials(context);
    if (!ok) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user is logged in.')),
      );
      return;
    }

    try {
      final adminDoc = await firestore.collection('admin').doc('JiLwbnNdP0FwBKGmDSiD').get();
      final ownerUid = adminDoc.data()?['ownerUid'];
      if (ownerUid != user.uid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You do not have permission to save rates.')),
        );
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reading admin doc: $e')),
      );
      return;
    }

    if (!_validateTiers()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid tier data. Please check the values.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentRatesDoc = firestore
          .collection('admin')
          .doc('JiLwbnNdP0FwBKGmDSiD')
          .collection('conversion')
          .doc('currentRates');

      await currentRatesDoc.set({
        'lastUpdated': FieldValue.serverTimestamp(),
        'tierCount': _tiers.length,
      });

      final existingTiers = await currentRatesDoc.collection('tiers').get();
      for (final doc in existingTiers.docs) {
        await doc.reference.delete();
      }

      for (final t in _tiers) {
        final tierRef = currentRatesDoc.collection('tiers').doc();
        await tierRef.set({
          'tierNumber': t.tierNumber,
          'minKwh': t.minKwh,
          'maxKwh': t.maxKwh,
          'rate': t.rate,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rates saved successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving rates: $e')),
      );
    }

    setState(() => _isLoading = false);
  }

  bool _validateTiers() {
    if (_tiers.isEmpty) return false;
    for (int i = 0; i < _tiers.length; i++) {
      if (_tiers[i].tierNumber != i + 1) return false;
    }
    for (int i = 0; i < _tiers.length; i++) {
      if (_tiers[i].minKwh >= _tiers[i].maxKwh) return false;
      if (i > 0 && _tiers[i].minKwh != _tiers[i - 1].maxKwh + 1) return false;
      if (i == 0 && _tiers[i].minKwh != 1) return false;
    }
    return true;
  }

  void _addTier() {
    final newTierNumber = _tiers.length + 1;
    int startKwh = 1;
    if (_tiers.isNotEmpty) {
      startKwh = _tiers.last.maxKwh + 1;
    }
    final newTier = TierData(
      tierNumber: newTierNumber,
      minKwh: startKwh,
      maxKwh: startKwh + 199,
      rate: 13.00,
    );
    setState(() {
      _tiers.add(newTier);
      _minControllers.add(TextEditingController(text: newTier.minKwh.toString()));
      _maxControllers.add(TextEditingController(text: newTier.maxKwh.toString()));
      _rateControllers.add(TextEditingController(text: newTier.rate.toString()));
    });
  }

  void _removeTier(int index) {
    if (_tiers.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot remove the last tier')),
      );
      return;
    }
    setState(() {
      _tiers.removeAt(index);
      _minControllers[index].dispose();
      _maxControllers[index].dispose();
      _rateControllers[index].dispose();
      _minControllers.removeAt(index);
      _maxControllers.removeAt(index);
      _rateControllers.removeAt(index);
      for (int i = 0; i < _tiers.length; i++) {
        _tiers[i].tierNumber = i + 1;
      }
      for (int i = 1; i < _tiers.length; i++) {
        _tiers[i].minKwh = _tiers[i - 1].maxKwh + 1;
        _minControllers[i].text = _tiers[i].minKwh.toString();
      }
    });
  }

  List<Widget> _buildTierWidgets() {
    return _tiers.asMap().entries.map((entry) {
      final i = entry.key;
      final t = entry.value;
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Tier ${t.tierNumber}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removeTier(i)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _minControllers[i],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Min (kWh)'),
                    enabled: i != 0,
                    onChanged: (v) {
                      final val = int.tryParse(v) ?? t.minKwh;
                      setState(() {
                        t.minKwh = val;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _maxControllers[i],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Max (kWh)'),
                    onChanged: (v) {
                      final val = int.tryParse(v) ?? t.maxKwh;
                      setState(() {
                        t.maxKwh = val;
                        if (i < _tiers.length - 1) {
                          _tiers[i + 1].minKwh = val + 1;
                          _minControllers[i + 1].text = (val + 1).toString();
                        }
                      });
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              TextField(
                controller: _rateControllers[i],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Rate (₱/kWh)'),
                onChanged: (v) {
                  final val = double.tryParse(v) ?? t.rate;
                  setState(() {
                    t.rate = val;
                  });
                },
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set Electricity Rates')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Configure Electricity Rate Tiers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Set consumption ranges and rates for each tier', style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 20),
            ..._buildTierWidgets(),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: _addTier,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Tier'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _saveRates(context, _firestore);
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TierData {
  String? id;
  int tierNumber;
  int minKwh;
  int maxKwh;
  double rate;

  TierData({
    this.id,
    required this.tierNumber,
    required this.minKwh,
    required this.maxKwh,
    required this.rate,
  });
}
