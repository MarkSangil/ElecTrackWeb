import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_flutter_web_app/consumption_alert_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  TextEditingController _applianceController = TextEditingController();
  TextEditingController _wattsController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final ConsumptionAlertService _consumptionAlertService = ConsumptionAlertService();
  double _wattsLimit = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchWattsLimit();
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
          _isLoading = false; // ✅ Finish loading
        });
        _consumptionAlertService.checkConsumptionAndAlert(); // ✅ Run check
      }
    }
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
                child: ListBody(
                  children: <Widget>[
                    TextField(
                      controller: _applianceController,
                      decoration: const InputDecoration(labelText: 'Appliance'),
                    ),
                    TextField(
                      controller: _wattsController,
                      decoration: const InputDecoration(labelText: 'Watts'),
                      keyboardType: TextInputType.number,
                    ),
                    ListTile(
                      title: const Text('Select Time'),
                      subtitle: Text(_selectedTime != null
                          ? "${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}"
                          : 'No time chosen'),
                      onTap: () async {
                        TimeOfDay? pickedTime = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime ?? const TimeOfDay(hour: 0, minute: 0),
                          builder: (BuildContext context, Widget? child) {
                            return MediaQuery(
                              data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                              child: child ?? const Text(""),
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
                      subtitle: Text(_selectedDate != null
                          ? "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}"
                          : 'No date chosen'),
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

  void saveApplianceData() async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      double watts = double.tryParse(_wattsController.text) ?? 0;
      double hoursUsed = _selectedTime != null
          ? _selectedTime!.hour + (_selectedTime!.minute / 60)
          : 0;
      double consumption = (watts / 1000) * hoursUsed; // kWh calculation

      String formattedTime = _selectedTime != null
          ? "${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}"
          : '';
      String formattedDate = _selectedDate != null
          ? "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}"
          : '';

      Map<String, dynamic> applianceData = {
        'appliance': _applianceController.text,
        'watts': watts.toDouble(),  // Ensure it's always stored as double
        'time': formattedTime,
        'date': formattedDate,
        'consumption': consumption.toDouble()  // Ensure it's always stored as double
      };

      FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('appliances')
          .add(applianceData)
          .then((docRef) {
        print("Document written with ID: ${docRef.id}");
      }).catchError((error) {
        print("Error adding document: $error");
      });
    } else {
      print("No user logged in.");
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
    ) ?? false;
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

        // ✅ Add this after appBar
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
                  Navigator.pop(context); // Close drawer
                  _showAddApplianceDialog(context); // ✅ Call function
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
                  bool shouldLogout = await _showLogoutConfirmationDialog(context); // ✅ Call function
                  if (shouldLogout) {
                    FirebaseAuth.instance.signOut();
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Stack(
              children: [
          // ✅ Background Image Layer
          Positioned.fill(
          child: Container(
          decoration: BoxDecoration(
          image: DecorationImage(
          image: AssetImage('assets/ElecTrack.png'), // ✅ Replace with your image
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.white.withOpacity(0.7),
            BlendMode.lighten, // ✅ Adjust blend mode if needed
          ),
        ),
      ),
    ),
    ),

    _isLoading
              ? const Center(child: CircularProgressIndicator()) // ✅ Show loader while fetching data
              : StreamBuilder<QuerySnapshot>(
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
                  child: Text("No appliances found",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                );
              }

              return Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1.5),
                        1: FlexColumnWidth(),
                        2: FlexColumnWidth(),
                        3: FlexColumnWidth(),
                        4: FlexColumnWidth(1.5),
                      },
                      border: TableBorder.all(color: Colors.grey, width: 1),
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.grey[300]),
                          children: const [
                            TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('Appliance', style: TextStyle(fontWeight: FontWeight.bold)))),
                            TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('Watts', style: TextStyle(fontWeight: FontWeight.bold)))),
                            TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('Time', style: TextStyle(fontWeight: FontWeight.bold)))),
                            TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('Consumption', style: TextStyle(fontWeight: FontWeight.bold)))),
                            TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold)))),
                          ],
                        ),
                        ...snapshot.data!.docs.map((DocumentSnapshot document) {
                          Map<String, dynamic> data = document.data() as Map<String, dynamic>;

                          double consumption = (data['consumption'] is num)
                              ? (data['consumption'] as num).toDouble()
                              : 0.0;

                          bool exceedsLimit = consumption > _wattsLimit; // ✅ Check if exceeding limit

                          return TableRow(
                            children: [
                              _buildTableCell(data['appliance'] ?? '', false),
                              _buildTableCell((data['watts'] ?? 0).toString(), false),
                              _buildTableCell(data['time'] ?? '', false),
                              _buildTableCell(
                                consumption.toStringAsFixed(2),
                                exceedsLimit, // ✅ Highlights if exceeding limit
                              ),
                              _buildTableCell(data['date'] ?? '', false),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
          )
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, bool highlight) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          color: highlight ? Colors.red[200] : Colors.transparent, // Highlight if exceeding limit
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: highlight ? Colors.red[900] : Colors.black, // Change text color if exceeded
            ),
          ),
        ),
      ),
    );
  }

}