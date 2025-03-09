import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatbotContent extends StatefulWidget {
  const ChatbotContent({Key? key}) : super(key: key);

  @override
  State<ChatbotContent> createState() => _ChatbotContentState();
}

class _ChatbotContentState extends State<ChatbotContent> {
  final TextEditingController _messageController = TextEditingController();
  String? conversationId;
  String? currentUserEmail;
  int _notHelpfulCount = 0;
  bool _showChat = false;

  final List<Map<String, dynamic>> faqList = [
    {
      'question': 'How to know the computation of bill?',
      'steps': [
        'Step 1: Note your consumption',
        'Step 2: Click "profile" and open consumption calculator',
        'Step 3: Input consumption & hours used',
        'Step 4: Click "check Meralco rates"',
        'Step 5: Then click "summary schedule of rates"',
      ],
      'expanded': false,
    },
    {
      'question': 'How to use Electrack?',
      'steps': [
        'Step 1: Input the appliance name',
        'Step 2: Input the wattage',
        'Step 3: Input time of use and date',
      ],
      'expanded': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      conversationId = user.uid;
      currentUserEmail = user.email;
      _initializeConversation();
    }
  }

  Future<void> _initializeConversation() async {
    if (conversationId == null) return;
    final conversationRef =
    FirebaseFirestore.instance.collection('conversations').doc(conversationId);
    final doc = await conversationRef.get();
    if (!doc.exists) {
      await conversationRef.set({});
      await conversationRef.collection('messages').add({
        'sender': 'admin',
        'text': 'Welcome to our chat! How can I help you today?',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty || conversationId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add({
        'sender': currentUserEmail ?? conversationId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error sending message: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (conversationId == null) {
      return const Center(child: Text("No user found."));
    }

    final messagesStream = FirebaseFirestore.instance
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();

    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.8,
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          // Title row (FAQ heading + close button)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
            child: Row(
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
          ),

          // FAQ List (scrollable if needed)
          Expanded(
            child: SingleChildScrollView(
              child: _buildFaqList(),
            ),
          ),

          // Only show the chat if _showChat is true
          if (_showChat) ...[
            const Divider(),

            // Messages list
            SizedBox(
              height: 300, // or use Expanded if you want dynamic sizing
              child: StreamBuilder<QuerySnapshot>(
                stream: messagesStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final sender = data['sender'] ?? '';
                      final text = data['text'] ?? '';
                      final isAdmin = sender == 'admin';
                      return Container(
                        alignment: isAdmin
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.7,
                          ),
                          decoration: BoxDecoration(
                            color: isAdmin ? Colors.grey[300] : Colors.blue[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(text),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Text input row
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: "Type a message...",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () async {
                      final text = _messageController.text.trim();
                      if (text.isNotEmpty) {
                        await _sendMessage(text);
                        _messageController.clear();
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFaqList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: faqList.map((qItem) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ExpansionTile(
            title: Text(
              qItem['question'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            children: [
              // Steps
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: (qItem['steps'] as List<dynamic>)
                      .map((step) => Text(step))
                      .toList(),
                ),
              ),
              // "Send this question" button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    // Send question to chat
                    await _sendMessage(qItem['question']);
                  },
                  child: const Text("Send this question"),
                ),
              ),
              // Ask if helpful + Yes/No buttons
              Padding(
                padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text("Is this answer helpful?"),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        // Optional: do something if user clicks "Yes"
                        // e.g. reset the counter or just close the tile
                        setState(() {
                          // Example: reset the counter
                          _notHelpfulCount = 0;
                        });
                      },
                      child: const Text("Yes"),
                    ),
                    TextButton(
                      onPressed: () {
                        // Increment not helpful count
                        setState(() {
                          _notHelpfulCount++;
                          if (_notHelpfulCount >= 3) {
                            // Show chat after 3 "No"s
                            _showChat = true;
                          }
                        });
                      },
                      child: const Text("No"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}