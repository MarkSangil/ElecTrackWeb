import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ConsumptionCalendarPage extends StatefulWidget {
  const ConsumptionCalendarPage({Key? key}) : super(key: key);

  @override
  State<ConsumptionCalendarPage> createState() => _ConsumptionCalendarPageState();
}

class _ConsumptionCalendarPageState extends State<ConsumptionCalendarPage> {
  final Map<DateTime, List<Map<String, dynamic>>> _dataByDate = {};
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('appliances')
          .get();

      for (var doc in query.docs) {
        final data = doc.data();
        final appliance = data['appliance'] as String? ?? 'Unknown';
        final consumption = (data['consumption'] as num?)?.toDouble() ?? 0.0;
        final dateString = data['date'] as String? ?? '';

        if (dateString.isEmpty) continue;

        DateTime? date;
        try {
          date = DateTime.parse(dateString);
        } catch (_) {
          continue;
        }

        final dayOnly = DateTime(date.year, date.month, date.day);
        _dataByDate.putIfAbsent(dayOnly, () => []);
        _dataByDate[dayOnly]!.add({
          'appliance': appliance,
          'consumption': consumption,
        });
      }

      setState(() {});
    } catch (e) {
      print('Error fetching consumption data: $e');
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return _dataByDate[d] ?? [];
  }

  void _showDayDataPopup(DateTime day) {
    final data = _getEventsForDay(day);

    if (data.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('No Data'),
          content: const Text('No consumption data for this day.'),
          actions: [
            TextButton(
              onPressed: Navigator.of(context).pop,
              child: const Text('OK'),
            )
          ],
        ),
      );
      return;
    }

    double total = 0;
    for (var e in data) {
      total += e['consumption'] as double;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Energy Consumption on ${DateFormat('dd MMM yyyy').format(day)}'),
        content: SizedBox(
          width: 300,
          height: 200,
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (ctx, i) {
                    final appliance = data[i]['appliance'];
                    final consumption = data[i]['consumption'];
                    return ListTile(
                      title: Text(appliance),
                      trailing: Text('${consumption.toStringAsFixed(2)} kWh'),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Total: ${total.toStringAsFixed(2)} kWh',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('Close'),
          )
        ],
      ),
    );
  }

  void _showMonthYearPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Month and Year'),
          content: SizedBox(
            width: 300,
            height: 300,
            child: YearMonthPicker(
              selectedDate: _focusedDay,
              onChanged: (DateTime dateTime) {
                setState(() {
                  _focusedDay = dateTime;
                });
                Navigator.pop(context);
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Give the whole page a subtle gradient background:
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Color(0xFFE0F2F1)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            _buildAppBar(),
            _buildMonthNavigator(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: TableCalendar(
                  eventLoader: _getEventsForDay,
                  focusedDay: _focusedDay,
                  firstDay: DateTime(1990),
                  lastDay: DateTime(DateTime.now().year, 12, 31),
                  calendarFormat: _calendarFormat,
                  headerVisible: false,
                  startingDayOfWeek: StartingDayOfWeek.sunday,
                  availableCalendarFormats: const {
                    CalendarFormat.month: 'Month',
                  },
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                    _showDayDataPopup(selectedDay);
                  },
                  selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                  onPageChanged: (focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
                    });
                  },
                  daysOfWeekStyle: DaysOfWeekStyle(
                    // Slightly colored background + bottom border
                    decoration: BoxDecoration(
                      color: Colors.blueGrey[50],
                      border: const Border(
                        bottom: BorderSide(color: Colors.grey),
                      ),
                    ),
                    weekdayStyle: const TextStyle(
                      color: Colors.blueGrey,
                      fontWeight: FontWeight.bold,
                    ),
                    weekendStyle: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  calendarStyle: CalendarStyle(
                    // Add some space around each cell
                    cellMargin: const EdgeInsets.all(6.0),

                    // Default day cell
                    defaultDecoration: BoxDecoration(
                      color: Colors.white70,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey),
                    ),
                    defaultTextStyle: const TextStyle(color: Colors.black87),

                    // Weekend day cell
                    weekendDecoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey),
                    ),
                    weekendTextStyle: const TextStyle(color: Colors.blue),

                    // Days from previous/next month
                    outsideDaysVisible: false,
                    outsideDecoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey),
                    ),

                    // Today
                    todayDecoration: BoxDecoration(
                      color: Colors.orangeAccent.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orangeAccent),
                    ),

                    // Selected day
                    selectedDecoration: BoxDecoration(
                      color: Colors.blue[800],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue),
                    ),
                  ),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      if (events.isNotEmpty) {
                        return Positioned(
                          bottom: 4,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.green.shade300,
                            ),
                            width: 6,
                            height: 6,
                          ),
                        );
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text(
        'Energy Consumption',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: Colors.blue[800],
      centerTitle: true,
      elevation: 2,
    );
  }

  Widget _buildMonthNavigator() {
    return GestureDetector(
      onTap: _showMonthYearPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          border: Border(
            bottom: BorderSide(color: Colors.blueGrey.shade200),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.chevron_left, color: Colors.blue[800]),
              onPressed: () {
                setState(() {
                  _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
                });
              },
            ),
            Text(
              DateFormat('MMMM yyyy').format(_focusedDay),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
            IconButton(
              icon: Icon(Icons.chevron_right, color: Colors.blue[800]),
              onPressed: () {
                setState(() {
                  _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

class YearMonthPicker extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onChanged;

  const YearMonthPicker({
    Key? key,
    required this.selectedDate,
    required this.onChanged,
  }) : super(key: key);

  @override
  _YearMonthPickerState createState() => _YearMonthPickerState();
}

class _YearMonthPickerState extends State<YearMonthPicker> {
  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.selectedDate.year;
    _selectedMonth = widget.selectedDate.month;
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Year Selection
        DropdownButton<int>(
          value: _selectedYear,
          hint: const Text('Select Year'),
          items: [
            for (int year = currentYear; year >= 1990; year--)
              DropdownMenuItem(
                value: year,
                child: Text(year.toString()),
              ),
          ],
          onChanged: (year) {
            if (year != null) {
              setState(() {
                _selectedYear = year;
              });
            }
          },
        ),
        // Month Selection
        DropdownButton<int>(
          value: _selectedMonth,
          hint: const Text('Select Month'),
          items: List.generate(
            12,
                (index) => DropdownMenuItem(
              value: index + 1,
              child: Text(
                DateFormat('MMMM').dateSymbols.MONTHS[index],
              ),
            ),
          ),
          onChanged: (month) {
            if (month != null) {
              setState(() {
                _selectedMonth = month;
              });
            }
          },
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[800],
          ),
          onPressed: () {
            widget.onChanged(DateTime(_selectedYear, _selectedMonth));
          },
          child: const Text('Select'),
        ),
      ],
    );
  }
}
