import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ConsumptionCalculatorModal extends StatefulWidget {
  const ConsumptionCalculatorModal({Key? key}) : super(key: key);

  @override
  _ConsumptionCalculatorModalState createState() => _ConsumptionCalculatorModalState();
}

class _ConsumptionCalculatorModalState extends State<ConsumptionCalculatorModal> {
  // -- Tab 1: Consumption --
  final TextEditingController _wattageController = TextEditingController();
  final TextEditingController _hoursController = TextEditingController();
  double _totalConsumption = 0.0; // in kWh

  // -- Tab 2: Bill --
  final TextEditingController _kwhController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  double _estimatedBill = 0.0; // in Pesos

  // Calculates consumption (Tab 1)
  void _calculateConsumption() {
    final double wattage = double.tryParse(_wattageController.text) ?? 0;
    final double hours   = double.tryParse(_hoursController.text) ?? 0;
    setState(() {
      _totalConsumption = (wattage / 1000.0) * hours;
    });
  }

  // Calculates bill (Tab 2)
  void _calculateBill() {
    final double kwh  = double.tryParse(_kwhController.text) ?? 0;
    final double rate = double.tryParse(_rateController.text) ?? 0; // Pesos/kWh
    setState(() {
      _estimatedBill = kwh * rate;
    });
  }

  void _openMeralcoRates() async {
    const String url = "https://company.meralco.com.ph/news-and-advisories/rates-archives";
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open the link")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Electricity Calculators"),

      // 1) Reduce the default padding around content and buttons
      contentPadding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 8),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 8),

      content: DefaultTabController(
        length: 2,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TabBar(
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(text: "Consumption"),
                Tab(text: "Bill"),
              ],
            ),

            SizedBox(
              height: 240,
              width: 400,
              child: TabBarView(
                children: [
                  // ========== TAB #1: Consumption Calculator ==========
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          TextField(
                            controller: _wattageController,
                            decoration: const InputDecoration(
                              labelText: "Appliance Wattage (W)",
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _hoursController,
                            decoration: const InputDecoration(
                              labelText: "Usage Time (hours)",
                            ),
                            keyboardType: TextInputType.number,
                          ),

                          // 3) Reduce or remove extra spacing
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _calculateConsumption,
                            child: const Text("Calculate kWh"),
                          ),
                          const SizedBox(height: 12),

                          Text(
                            "Total Consumption: ${_totalConsumption.toStringAsFixed(2)} kWh",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ========== TAB #2: Bill Calculator ==========
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          TextField(
                            controller: _kwhController,
                            decoration: const InputDecoration(
                              labelText: "kWh Used",
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _rateController,
                            decoration: const InputDecoration(
                              labelText: "Meralco Rate (₱/kWh)",
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _calculateBill,
                            child: const Text("Calculate Bill"),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Estimated Cost: ₱${_estimatedBill.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _openMeralcoRates,
          child: const Text("Check Meralco Rates"),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Close"),
        ),
      ],
    );
  }
}
