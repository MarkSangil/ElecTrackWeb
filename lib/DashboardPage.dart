import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
                          ? "${_selectedTime!.hour.toString().padLeft(
                          2, '0')}:${_selectedTime!.minute.toString().padLeft(
                          2, '0')}"
                          : 'No time chosen'),
                      onTap: () async {
                        TimeOfDay? pickedTime = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime ??
                              const TimeOfDay(hour: 0, minute: 0),
                          builder: (BuildContext context, Widget? child) {
                            return MediaQuery(
                              data: MediaQuery.of(context).copyWith(
                                  alwaysUse24HourFormat: true),
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
                          ? "${_selectedDate!.year}-${_selectedDate!.month
                          .toString().padLeft(2, '0')}-${_selectedDate!.day
                          .toString().padLeft(2, '0')}"
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
      double hoursUsed = 0.0;

      if (_selectedTime != null) {
        hoursUsed = _selectedTime!.hour + (_selectedTime!.minute / 60.0);
      }

      double consumption = (watts * hoursUsed) / 1000; // kWh calculation

      print("Watts: $watts");  // Debugging
      print("Hours Used: $hoursUsed");  // Debugging
      print("Calculated Consumption: $consumption kWh/day");  // Debugging

      String formattedTime = _selectedTime != null
          ? "${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}"
          : '';
      String formattedDate = _selectedDate != null
          ? "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}"
          : '';

      Map<String, dynamic> applianceData = {
        'appliance': _applianceController.text.trim(),
        'watts': watts.toString(),
        'time': formattedTime,
        'date': formattedDate,
        'consumption': consumption.toStringAsFixed(4) // Ensure precision for debugging
      };

      FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('appliances')
          .add(applianceData)
          .then((docRef) {
        print("Appliance added: ${docRef.id}");
      }).catchError((error) {
        print("Error adding appliance: $error");
      });

      // Clear input fields after saving
      _applianceController.clear();
      _wattsController.clear();
      _selectedDate = null;
      _selectedTime = null;
    } else {
      print("No user logged in.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        bool shouldLogout = await _showLogoutConfirmationDialog(context);
        if (shouldLogout) {
          FirebaseAuth.instance.signOut();
          Navigator.of(context).pop();
        }
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'ElecTrack',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.black,
          elevation: 5,
          leading: IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: () async {
              bool shouldLogout = await _showLogoutConfirmationDialog(context);
              if (shouldLogout) {
                FirebaseAuth.instance.signOut();
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
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
              Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(FirebaseAuth.instance.currentUser?.uid)
                              .collection('appliances')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return const Text('Something went wrong');
                            }
                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                              return Container(
                                color: Colors.white,
                                alignment: Alignment.center,
                                child: const Text(
                                  "No appliances found",
                                  style: TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              );
                            }
                            return Column(
                              children: [
                                Table(
                                  columnWidths: const {
                                    0: FlexColumnWidth(1.5),
                                    1: FlexColumnWidth(),
                                    2: FlexColumnWidth(),
                                    3: FlexColumnWidth(),
                                    4: FlexColumnWidth(1.5),
                                  },
                                  border: TableBorder.all(
                                      color: Colors.grey, width: 1),
                                  children: [
                                    TableRow(
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                      ),
                                      children: [
                                        TableCell(
                                            child: Padding(
                                                padding: const EdgeInsets.all(8),
                                                child: Text('Appliance',
                                                    style: TextStyle(
                                                        fontWeight:
                                                        FontWeight.bold)))),
                                        TableCell(
                                            child: Padding(
                                                padding: const EdgeInsets.all(8),
                                                child: Text('Watts',
                                                    style: TextStyle(
                                                        fontWeight:
                                                        FontWeight.bold)))),
                                        TableCell(
                                            child: Padding(
                                                padding: const EdgeInsets.all(8),
                                                child: Text('Time',
                                                    style: TextStyle(
                                                        fontWeight:
                                                        FontWeight.bold)))),
                                        TableCell(
                                            child: Padding(
                                                padding: const EdgeInsets.all(8),
                                                child: Text('Consumption',
                                                    style: TextStyle(
                                                        fontWeight:
                                                        FontWeight.bold)))),
                                        TableCell(
                                            child: Padding(
                                                padding: const EdgeInsets.all(8),
                                                child: Text('Date',
                                                    style: TextStyle(
                                                        fontWeight:
                                                        FontWeight.bold)))),
                                      ],
                                    ),
                                    ...snapshot.data!.docs.map(
                                            (DocumentSnapshot document) {
                                          Map<String, dynamic> data =
                                          document.data() as Map<String, dynamic>;
                                          return TableRow(children: [
                                            TableCell(
                                              child: Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: Text(data['appliance'],
                                                    style: const TextStyle(
                                                        fontWeight: FontWeight.bold)),
                                              ),
                                            ),
                                            TableCell(
                                              child: Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: Text(data['watts'],
                                                    style: const TextStyle(
                                                        fontWeight: FontWeight.bold)),
                                              ),
                                            ),
                                            TableCell(
                                              child: Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: Text(data['time'],
                                                    style: const TextStyle(
                                                        fontWeight: FontWeight.bold)),
                                              ),
                                            ),
                                            TableCell(
                                              child: Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: Text(data['consumption'],
                                                    style: const TextStyle(
                                                        fontWeight: FontWeight.bold)),
                                              ),
                                            ),
                                            TableCell(
                                              child: Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: Text(data['date'],
                                                    style: const TextStyle(
                                                        fontWeight: FontWeight.bold)),
                                              ),
                                            ),
                                          ]);
                                        }).toList(),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            _showAddApplianceDialog(context);
          },
          backgroundColor: Colors.black,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      )
      ,
    );
  }

  Future<bool> _showLogoutConfirmationDialog(BuildContext context) async {
    return await showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
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
    ) ?? false; // Default to false if dismissed
  }
}