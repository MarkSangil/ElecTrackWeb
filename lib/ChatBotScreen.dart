import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatbotContent extends StatefulWidget {
  const ChatbotContent({Key? key}) : super(key: key);

  @override
  State<ChatbotContent> createState() => _ChatbotContentState();
}

class _ChatbotContentState extends State<ChatbotContent> {
  String? currentUserEmail;
  final List<Map<String, dynamic>> faqList = [
    {
      'question': 'How to know the computation of bill?',
      'steps': [
        'Step 1: Take down note the consumption you used',
        'Step 2: Click "profile" and click open consumption calculator',
        'Step 3: Input the note of your consumption and how many hours used',
        'Step 4: Click "check Meralco rates"',
        'Step 5: Then click "summary schedule of rates"',
      ],
      'expanded': false,
    },
    {
      'question': 'How to use Elecktrack?',
      'steps': [
        'Step 1: Input the appliance name',
        'Step 2: Input the wattage of the appliance you want to track',
        'Step 3: Input time of use and date',
      ],
      'expanded': false,
    },
  ];

  final TextEditingController _questionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      currentUserEmail = user?.email;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1) "Close" or "Back" button row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Chatbot FAQ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2) Your existing FAQ Cards
          ...faqList.asMap().entries.map((entry) {
            final index = entry.key;
            final qItem = entry.value;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      qItem['question'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: Icon(
                      qItem['expanded']
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                    ),
                    onTap: () {
                      setState(() {
                        faqList[index]['expanded'] =
                        !faqList[index]['expanded'];
                      });
                    },
                  ),
                  if (qItem['expanded'])
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List<Widget>.generate(
                          qItem['steps'].length,
                              (stepIndex) => Text(qItem['steps'][stepIndex]),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),

          const SizedBox(height: 24),
          // 3) “Other Questions?” prompt, text field, etc.
          const Text(
            'Other Questions?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _questionController,
            decoration: const InputDecoration(
              labelText: 'Type your question here',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 8),

          ElevatedButton.icon(
            icon: const Icon(Icons.send),
            label: const Text('Send to Admin'),
            onPressed: _sendQuestionToAdmin,
          ),
        ],
      ),
    );
  }

  Future<void> _sendQuestionToAdmin() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) return;

    try {
      final emailToUse = currentUserEmail ?? 'unknown@domain.com';

      await FirebaseFirestore.instance
          .collection('admin')
          .doc('JiLwbnNdP0FwBKGmDSiD')
          .collection('messages')
          .add({
        'message': question,
        'date': DateTime.now().toIso8601String(),
        'userEmail': emailToUse,
      });

      _questionController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your question was sent to admin.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending question: $e')),
      );
    }
  }
}