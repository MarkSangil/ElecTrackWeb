import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_flutter_web_app/ChatBotScreen.dart';
import 'package:my_flutter_web_app/app_theme.dart';
import 'package:my_flutter_web_app/consumption_alert_service.dart';
import 'package:my_flutter_web_app/dashboard_service.dart';
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
  double? _billAmount;

  DateTime? _selectedDate;
  Duration? _selectedDuration;
  double _wattsLimit = 0.0;
  bool _isLoading = true;

  List<TierData> _tiersList = [];
  bool _tiersLoading = true;

  final ScrollController _tableScrollController = ScrollController();
  String _selectedFilter = 'Day';

  @override
  void initState() {
    super.initState();
    _fetchWattsLimit();
    _fetchTiersOnce();
  }

  @override
  void dispose() {
    _applianceController.dispose();
    _wattsController.dispose();
    _tableScrollController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '$hours hr ${minutes.toString().padLeft(2, '0')} min';
  }

  Future<void> _fetchWattsLimit() async {
    final limit = await _dashboardService.fetchWattsLimit();
    setState(() {
      _wattsLimit = limit;
      _isLoading = false;
    });
    _consumptionAlertService.checkConsumptionAndAlert();
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

  Future<void> _fetchTiersOnce() async {
    setState(() => _tiersLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('admin')
          .doc('JiLwbnNdP0FwBKGmDSiD')
          .collection('conversion')
          .doc('currentRates')
          .collection('tiers')
          .orderBy('tierNumber')
          .get();

      final loadedTiers = <TierData>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        loadedTiers.add(TierData(
          tierNumber: data['tierNumber'] ?? 0,
          minKwh: data['minKwh'] ?? 0,
          maxKwh: data['maxKwh'] ?? 0,
          rate: (data['rate'] ?? 0.0).toDouble(),
        ));
      }
      setState(() {
        _tiersList = loadedTiers;
        _tiersLoading = false;
      });
    } catch (e) {
      setState(() => _tiersLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching tiers: $e')),
      );
    }
  }

  // SINGLE-BRACKET LOGIC:
  // If consumption is between minKwh and maxKwh, multiply entire consumption by that tier’s rate.
  // If consumption is above the last tier, multiply entire consumption by that last tier's rate.
  double _computeBill(double consumptionKwh, List<TierData> tiers) {
    if (tiers.isEmpty) return 0.0;

    // Sort by minKwh or tierNumber just to be safe
    final sortedTiers = [...tiers]..sort((a, b) => a.minKwh.compareTo(b.minKwh));

    for (final tier in sortedTiers) {
      if (consumptionKwh >= tier.minKwh && consumptionKwh <= tier.maxKwh) {
        return consumptionKwh * tier.rate;
      }
    }
    // If consumption is above all tiers, charge at the last tier's rate
    final lastTier = sortedTiers.last;
    return consumptionKwh * lastTier.rate;
  }

  Future<void> _calculateBill() async {
    try {
      if (_tiersLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tier data still loading...')),
        );
        return;
      }
      final cost = _computeBill(_totalConsumption, _tiersList);
      setState(() {
        _billAmount = cost;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error computing bill: $e')),
      );
    }
  }

  Future<void> _saveApplianceData() async {
    final watts = double.tryParse(_wattsController.text) ?? 0;
    final hoursUsed = _selectedDuration != null
        ? _selectedDuration!.inHours + (_selectedDuration!.inMinutes.remainder(60) / 60.0)
        : 0.0;

    final consumption = (watts / 1000.0) * hoursUsed;

    final formattedTime = _selectedDuration != null
        ? "${_selectedDuration!.inHours.toString().padLeft(2, '0')}:"
        "${(_selectedDuration!.inMinutes.remainder(60)).toString().padLeft(2, '0')}"
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
                      title: const Text('Select Usage Duration'),
                      subtitle: Text(
                        _selectedDuration != null
                            ? _formatDuration(_selectedDuration!)
                            : 'No duration chosen',
                      ),
                      onTap: () async {
                        final pickedDuration = await showCustomDurationPicker(context);
                        if (pickedDuration != null) {
                          setDialogState(() {
                            _selectedDuration = pickedDuration;
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

  void _showCompactChatbotModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.8,
            child: ChatbotContent(),
          ),
        );
      },
    );
  }

  Future<Duration?> showCustomDurationPicker(BuildContext context) async {
    int hours = 0;
    int minutes = 0;

    return showDialog<Duration>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter Usage Duration'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Hours'),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  hours = int.tryParse(value) ?? 0;
                },
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Minutes'),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  minutes = int.tryParse(value) ?? 0;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(
                  Duration(hours: hours, minutes: minutes),
                );
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
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
      List<QueryDocumentSnapshot> docs,
      String filterType,
      ) {
    final now = DateTime.now();
    double newTotalConsumption = 0.0;

    // 1. Filter the docs
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
        // last 30 days
          final thirtyDaysAgo = now.subtract(const Duration(days: 30));
          isValid = docDate.isAfter(thirtyDaysAgo) &&
              docDate.isBefore(now.add(const Duration(days: 1)));
          break;
      }

      if (isValid) {
        newTotalConsumption += (data['consumption'] as num? ?? 0).toDouble();
      }

      return isValid;
    }).toList();

    // 2. Sort the filtered docs by date ASCENDING
    filteredDocs.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;
      final dateStrA = dataA['date'] ?? '';
      final dateStrB = dataB['date'] ?? '';

      final partsA = dateStrA.split('-');
      final partsB = dateStrB.split('-');
      if (partsA.length != 3 || partsB.length != 3) {
        // If either doc doesn't have a valid date, leave them in place
        return 0;
      }

      final yearA = int.tryParse(partsA[0]) ?? 0;
      final monthA = int.tryParse(partsA[1]) ?? 0;
      final dayA = int.tryParse(partsA[2]) ?? 0;
      final docDateA = DateTime(yearA, monthA, dayA);

      final yearB = int.tryParse(partsB[0]) ?? 0;
      final monthB = int.tryParse(partsB[1]) ?? 0;
      final dayB = int.tryParse(partsB[2]) ?? 0;
      final docDateB = DateTime(yearB, monthB, dayB);

      // For ascending order (oldest first):
      return docDateA.compareTo(docDateB);

      // If you want newest first, do:
      // return docDateB.compareTo(docDateA);
    });

    // 3. Update _totalConsumption
    if (newTotalConsumption != _totalConsumption) {
      Future.microtask(() {
        if (mounted) {
          setState(() {
            _totalConsumption = newTotalConsumption;
          });
        }
      });
    }

    // 4. Return sorted, filtered docs
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
                        return const Center(child: Text('Something went wrong'));
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
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        );
                      }
                      final allDocs = snapshot.data!.docs;
                      final filteredDocs = _filterDocs(allDocs, _selectedFilter);
                      if (filteredDocs.isEmpty) {
                        return const Center(child: Text('No data for this filter.'));
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
                              headingRowColor:
                              MaterialStateProperty.all(AppTheme.lightGreen),
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
                                DataColumn(label: Text('Cost')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: filteredDocs.map((doc) {
                                final docId = doc.id;
                                final data = doc.data() as Map<String, dynamic>;
                                final consumption =
                                (data['consumption'] as num? ?? 0).toDouble();

                                return DataRow(
                                  cells: [
                                    DataCell(Text(data['appliance'] ?? '')),
                                    DataCell(Text((data['watts'] ?? 0).toString())),
                                    DataCell(Text(data['time'] ?? '')),
                                    DataCell(Text(consumption.toStringAsFixed(2))),
                                    DataCell(Text(data['date'] ?? '')),
                                    if (_tiersLoading)
                                      const DataCell(Text('Loading...'))
                                    else
                                      DataCell(
                                        Text(
                                          '₱${_computeBill(consumption, _tiersList).toStringAsFixed(2)}',
                                        ),
                                      ),
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
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isWide = screenWidth > 800;

    return WillPopScope(
      onWillPop: () async {
        await FirebaseAuth.instance.signOut();
        Navigator.of(context).pop();
        return false;
      },
      child: Scaffold(
        appBar: isWide
            ? null
            : AppBar(
          title: const Text('ElecTrack', style: TextStyle(color: Colors.white)),
          elevation: 5,
        ),
        drawer: isWide ? null : Drawer(child: _buildSidebar(context)),
        body: isWide
            ? Row(
          children: [
            _buildSidebar(context),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildMainContent(context),
              ),
            ),
          ],
        )
            : _buildMainContent(context),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showCompactChatbotModal(context),
          backgroundColor: isWide ? AppTheme.lightGreen : Colors.green,
          child: const Icon(Icons.chat),
        ),
      ),
    );
  }
}

class TierData {
  final int tierNumber;
  final int minKwh;
  final int maxKwh;
  final double rate;

  TierData({
    required this.tierNumber,
    required this.minKwh,
    required this.maxKwh,
    required this.rate,
  });
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
