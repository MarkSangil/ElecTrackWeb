import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ConsumptionCalculatorModal extends StatefulWidget {
  @override
  _ConsumptionCalculatorModalState createState() => _ConsumptionCalculatorModalState();
}

class _ConsumptionCalculatorModalState extends State<ConsumptionCalculatorModal> {
  final TextEditingController _wattageController = TextEditingController();
  final TextEditingController _hoursController = TextEditingController();

  double _totalConsumption = 0.0; // Holds the calculated consumption

  void _calculateConsumption() {
    final double wattage = double.tryParse(_wattageController.text) ?? 0;
    final double hours = double.tryParse(_hoursController.text) ?? 0;

    setState(() {
      _totalConsumption = (wattage / 1000) * hours; // Convert to kWh
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
      title: const Text("Electricity Consumption Calculator"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _wattageController,
            decoration: const InputDecoration(labelText: "Appliance Wattage (W)"),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _hoursController,
            decoration: const InputDecoration(labelText: "Usage Time (hours)"),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _calculateConsumption,
            child: const Text("Calculate"),
          ),
          const SizedBox(height: 12),
          Text(
            "Total Consumption: ${_totalConsumption.toStringAsFixed(2)} kWh",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
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
