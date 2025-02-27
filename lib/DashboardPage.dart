import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_flutter_web_app/consumption_alert_service.dart';
import 'package:my_flutter_web_app/app_theme.dart';
import 'package:my_flutter_web_app/watt_timer.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ConsumptionAlertService _consumptionAlertService = ConsumptionAlertService();
  final TextEditingController _applianceController = TextEditingController();
  final TextEditingController _wattsController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  double _wattsLimit = 0.0;
  bool _isLoading = true;

  // Create a ScrollController for horizontal scrolling.
  final ScrollController _tableScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchWattsLimit();
  }

  @override
  void dispose() {
    _applianceController.dispose();
    _wattsController.dispose();
    _tableScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchWattsLimit() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      DocumentSnapshot userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userData.exists) {
        setState(() {
          _wattsLimit = (userData['wattsLimit'] as num?)?.toDouble() ?? 0.0;
          _isLoading = false;
        });
        _consumptionAlertService.checkConsumptionAndAlert();
      }
    }
  }

  void _openTimerPage(String docId, Map<String, dynamic> applianceData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TimerPage(
          docId: docId,
          applianceName: applianceData['appliance'] ?? 'Unknown Appliance',
          wattRating: (applianceData['watts'] ?? 0).toDouble(),
        ),
      ),
    );
  }

  void _showAddApplianceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Add Appliance"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: _applianceController,
                      decoration: const InputDecoration(labelText: 'Appliance'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _wattsController,
                      decoration: const InputDecoration(labelText: 'Watts'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      title: const Text('Select Time'),
                      subtitle: Text(
                        _selectedTime != null
                            ? "${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}"
                            : 'No time chosen',
                      ),
                      onTap: () async {
                        TimeOfDay? pickedTime = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime ?? const TimeOfDay(hour: 0, minute: 0),
                          builder: (BuildContext context, Widget? child) {
                            return MediaQuery(
                              data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                              child: child ?? const SizedBox(),
                            );
                          },
                        );
                        if (pickedTime != null) {
                          setDialogState(() {
                            _selectedTime = pickedTime;
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: const Text('Select Date'),
                      subtitle: Text(
                        _selectedDate != null
                            ? "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}"
                            : 'No date chosen',
                      ),
                      onTap: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) {
                          setDialogState(() {
                            _selectedDate = pickedDate;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Save'),
                  onPressed: () {
                    saveApplianceData();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteAppliance(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('appliances')
          .doc(docId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appliance deleted.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  void saveApplianceData() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      double watts = double.tryParse(_wattsController.text) ?? 0;
      double hoursUsed = _selectedTime != null
          ? _selectedTime!.hour + (_selectedTime!.minute / 60)
          : 0;
      double consumption = (watts / 1000) * hoursUsed;

      String formattedTime = _selectedTime != null
          ? "${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}"
          : '';
      String formattedDate = _selectedDate != null
          ? "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}"
          : '';

      Map<String, dynamic> applianceData = {
        'appliance': _applianceController.text,
        'watts': watts.toDouble(),
        'time': formattedTime,
        'date': formattedDate,
        'consumption': consumption.toDouble(),
      };

      FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('appliances')
          .add(applianceData)
          .then((docRef) {
        debugPrint("Document written with ID: ${docRef.id}");
      }).catchError((error) {
        debugPrint("Error adding document: $error");
      });
    } else {
      debugPrint("No user logged in.");
    }
  }

  Future<bool> _showLogoutConfirmationDialog(BuildContext context) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            child: const Text("Logout"),
          ),
        ],
      ),
    ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        FirebaseAuth.instance.signOut();
        Navigator.of(context).pop();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ElecTrack', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.black,
          elevation: 5,
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              Container(
                height: 100,
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: Colors.black),
                child: const Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    'ElecTrack Menu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Add Appliance'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddApplianceDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Profile'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/profile');
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () async {
                  Navigator.pop(context); // Close the drawer
                  bool shouldLogout = await _showLogoutConfirmationDialog(context);
                  if (shouldLogout) {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pushReplacementNamed(context, '/');
                  }
                },
              ),
            ],
          ),
        ),
        body: Stack(
          children: [
            // Full-screen background layer
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/ElecTrack.png'),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Colors.white.withOpacity(0.7),
                      BlendMode.lighten,
                    ),
                  ),
                ),
              ),
            ),
            // Main content with both horizontal and vertical scrolling
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth,
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: _buildMainContent(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddApplianceDialog(context),
          backgroundColor: AppTheme.lightGreen,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser?.uid)
                  .collection('appliances')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Something went wrong'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No appliances found",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;
                return Scrollbar(
                  controller: _tableScrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  child: SingleChildScrollView(
                    controller: _tableScrollController,
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 1200),
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(AppTheme.lightGreen),
                        headingTextStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        columns: const [
                          DataColumn(label: Text('Appliance')),
                          DataColumn(label: Text('Watts')),
                          DataColumn(label: Text('Time')),
                          DataColumn(label: Text('Consumption')),
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: docs.map((doc) {
                          final docId = doc.id;
                          final data = doc.data() as Map<String, dynamic>;
                          return DataRow(
                            cells: [
                              DataCell(Text(data['appliance'] ?? '')),
                              DataCell(Text((data['watts'] ?? 0).toString())),
                              DataCell(Text(data['time'] ?? '')),
                              DataCell(Text((data['consumption'] ?? 0).toStringAsFixed(2))),
                              DataCell(Text(data['date'] ?? '')),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteAppliance(docId),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.timer, color: Colors.blue),
                                      onPressed: () => _openTimerPage(docId, data),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class TimerPage extends StatelessWidget {
  final String docId;
  final String applianceName;
  final double wattRating;

  const TimerPage({
    Key? key,
    required this.docId,
    required this.applianceName,
    required this.wattRating,
  }) : super(key: key);

  void _onTimerStop(double consumption) {
    debugPrint('Timer stopped. Consumption: $consumption kWh');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Timer for $applianceName'),
      ),
      body: Center(
        child: WattTimer(
          docId: docId,
          wattRating: wattRating,
          applianceName: applianceName,
          onTimerStop: _onTimerStop,
        ),
      ),
    );
  }
}
