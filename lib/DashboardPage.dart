import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_flutter_web_app/ChatBotScreen.dart';
import 'package:my_flutter_web_app/dashboard_service.dart';
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
  final DashboardService _dashboardService = DashboardService();

  final TextEditingController _applianceController = TextEditingController();
  final TextEditingController _wattsController = TextEditingController();

  double _totalConsumption = 0.0;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  double _wattsLimit = 0.0;
  bool _isLoading = true;

  final ScrollController _tableScrollController = ScrollController();

  String _selectedFilter = 'Day';

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

  void _showCompactChatbotModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 8),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.8,
            child: SingleChildScrollView(
              child: ChatbotContent(), // now has no top-level Material
            ),
          ),
        );
      },
    );
  }

  Future<void> _fetchWattsLimit() async {
    final limit = await _dashboardService.fetchWattsLimit();
    setState(() {
      _wattsLimit = limit;
      _isLoading = false;
    });
    _consumptionAlertService.checkConsumptionAndAlert();
  }

  Future<void> _saveApplianceData() async {
    final watts = double.tryParse(_wattsController.text) ?? 0;
    final hoursUsed = _selectedTime != null
        ? _selectedTime!.hour + (_selectedTime!.minute / 60)
        : 0;
    final consumption = (watts / 1000) * hoursUsed;

    final formattedTime = _selectedTime != null
        ? "${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}"
        : '';
    final formattedDate = _selectedDate != null
        ? "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}"
        : '';

    await _dashboardService.addAppliance(
      applianceName: _applianceController.text,
      watts: watts,
      time: formattedTime,
      date: formattedDate,
      consumption: consumption,
    );
  }

  Future<void> _deleteAppliance(String docId) async {
    await _dashboardService.deleteAppliance(docId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Appliance deleted.')),
    );
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
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Logout"),
          ),
        ],
      ),
    ) ??
        false;
  }

  void _showAddApplianceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
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
                        final pickedTime = await showTimePicker(
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
                          setDialogState(() => _selectedTime = pickedTime);
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
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) {
                          setDialogState(() => _selectedDate = pickedDate);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: const Text('Save'),
                  onPressed: () {
                    _saveApplianceData();
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

  Widget _buildSidebar(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Container(
        width: 250,
        color: AppTheme.primaryBlue,
        child: const Center(
          child: Text(
            "No user logged in",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final userDocStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots();

    return Container(
      width: 250,
      color: AppTheme.primaryBlue,
      child: Column(
        children: [
          const SizedBox(height: 60),
          StreamBuilder<DocumentSnapshot>(
            stream: userDocStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator(color: Colors.white);
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Text(
                  'No profile data',
                  style: TextStyle(color: Colors.white),
                );
              }
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              if (data == null) {
                return const Text(
                  'No data',
                  style: TextStyle(color: Colors.white),
                );
              }
              final avatarBase64 = data['avatarBase64'] as String?;
              final userName = data['name'] as String? ?? 'Unnamed User';

              Widget avatarWidget;
              if (avatarBase64 != null && avatarBase64.isNotEmpty) {
                final decodedBytes = base64Decode(avatarBase64);
                avatarWidget = CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: ClipOval(
                    child: Image.memory(
                      decodedBytes,
                      fit: BoxFit.cover,
                      width: 80,
                      height: 80,
                    ),
                  ),
                );
              } else {
                avatarWidget = const CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.person,
                    color: Colors.black,
                    size: 40,
                  ),
                );
              }

              return Column(
                children: [
                  const SizedBox(height: 12),
                  avatarWidget,
                  const SizedBox(height: 12),
                  Text(
                    userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.add, color: Colors.white),
            title: const Text('Add Appliance', style: TextStyle(color: Colors.white)),
            onTap: () => _showAddApplianceDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month, color: Colors.white),
            title: const Text('Consumption Calendar', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pushNamed(context, '/Chart');
            },
          ),
          ListTile(
            leading: const Icon(Icons.person, color: Colors.white),
            title: const Text('Profile', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white),
            title: const Text('Logout', style: TextStyle(color: Colors.white)),
            onTap: () async {
              final shouldLogout = await _showLogoutConfirmationDialog(context);
              if (shouldLogout) {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const Text('Filter by: ', style: TextStyle(fontWeight: FontWeight.bold)),
        DropdownButton<String>(
          value: _selectedFilter,
          items: const [
            DropdownMenuItem(child: Text('Day'), value: 'Day'),
            DropdownMenuItem(child: Text('Week'), value: 'Week'),
            DropdownMenuItem(child: Text('Month'), value: 'Month'),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedFilter = value;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildTotalConsumptionDisplay() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        "Total Consumption: ${_totalConsumption.toStringAsFixed(2)} kWh",
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }

  List<QueryDocumentSnapshot> _filterDocs(
      List<QueryDocumentSnapshot> docs, String filterType) {
    final now = DateTime.now();
    double newTotalConsumption = 0.0;

    final filteredDocs = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final dateStr = data['date'] as String? ?? '';
      final parts = dateStr.split('-');
      if (parts.length != 3) return false;
      final year = int.tryParse(parts[0]) ?? 0;
      final month = int.tryParse(parts[1]) ?? 0;
      final day = int.tryParse(parts[2]) ?? 0;
      final docDate = DateTime(year, month, day);

      bool isValid = false;

      switch (filterType) {
        case 'Day':
          isValid = (docDate.year == now.year &&
              docDate.month == now.month &&
              docDate.day == now.day);
          break;
        case 'Week':
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final endOfWeek = startOfWeek.add(const Duration(days: 7));
          isValid = (docDate.isAtSameMomentAs(startOfWeek) ||
              (docDate.isAfter(startOfWeek) && docDate.isBefore(endOfWeek)));
          break;
        case 'Month':
          isValid = (docDate.year == now.year && docDate.month == now.month);
          break;
      }

      if (isValid) {
        newTotalConsumption += (data['consumption'] as num? ?? 0).toDouble();
      }

      return isValid;
    }).toList();

    if (newTotalConsumption != _totalConsumption) {
      Future.microtask(() {
        if (mounted) {
          setState(() {
            _totalConsumption = newTotalConsumption;
          });
        }
      });
    }

    return filteredDocs;
  }

  Widget _buildMainContent(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFilterDropdown(),
        _buildTotalConsumptionDisplay(),
        Expanded(
          child: Center(
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
                        return const Center(child: Text(
                            'Something went wrong'));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        Future.microtask(() {
                          if (mounted && _totalConsumption != 0) {
                            setState(() {
                              _totalConsumption = 0;
                            });
                          }
                        });

                        return const Center(
                          child: Text(
                            "No appliances found",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        );
                      }

                      final allDocs = snapshot.data!.docs;
                      final filteredDocs = _filterDocs(allDocs, _selectedFilter);

                      if (filteredDocs.isEmpty) {
                        return const Center(child: Text(
                            'No data for this filter.'));
                      }

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
                              headingRowColor: MaterialStateProperty.all(
                                  AppTheme.lightGreen),
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
                              rows: filteredDocs.map((doc) {
                                final docId = doc.id;
                                final data = doc.data() as Map<String, dynamic>;
                                return DataRow(
                                  cells: [
                                    DataCell(Text(data['appliance'] ?? '')),
                                    DataCell(
                                        Text((data['watts'] ?? 0).toString())),
                                    DataCell(Text(data['time'] ?? '')),
                                    DataCell(Text((data['consumption'] ?? 0)
                                        .toStringAsFixed(2))),
                                    DataCell(Text(data['date'] ?? '')),
                                    DataCell(
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () =>
                                                _deleteAppliance(docId),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.timer,
                                                color: Colors.blue),
                                            onPressed: () =>
                                                _openTimerPage(docId, data),
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
          ),
        ),
      ],
    );
  }

    @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isWide = screenWidth > 800;

    if (isWide) {
      return WillPopScope(
        onWillPop: () async {
          await FirebaseAuth.instance.signOut();
          Navigator.of(context).pop();
          return false;
        },
        child: Scaffold(
          body: Row(
            children: [
              _buildSidebar(context),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildMainContent(context),
                ),
              ),
            ],
          ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => _showCompactChatbotModal(context),
              backgroundColor: AppTheme.lightGreen,
              child: const Icon(Icons.chat),
            ),
        ),
      );
    } else {
      return WillPopScope(
        onWillPop: () async {
          await FirebaseAuth.instance.signOut();
          Navigator.of(context).pop();
          return false;
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('ElecTrack', style: TextStyle(color: Colors.white)),
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
                  decoration: BoxDecoration(color: AppTheme.primaryBlue),
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
                    Navigator.pop(context);
                    final shouldLogout = await _showLogoutConfirmationDialog(context);
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
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: const AssetImage('assets/ElecTrack.png'),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.white.withOpacity(0.7),
                        BlendMode.lighten,
                      ),
                    ),
                  ),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: _buildMainContent(context),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showCompactChatbotModal(context),
            backgroundColor: Colors.green,
            child: const Icon(Icons.chat),
          ),
        ),
      );
    }
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