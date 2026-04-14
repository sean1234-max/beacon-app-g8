import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Import your AppTheme if you use it for colors

class ClubChatScreen extends StatefulWidget {
  final DocumentSnapshot club;

  const ClubChatScreen({super.key, required this.club});

  @override
  State<ClubChatScreen> createState() => _ClubChatScreenState();
}

class _ClubChatScreenState extends State<ClubChatScreen> {
  final TextEditingController msgController = TextEditingController();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
  final String _currentUserName = FirebaseAuth.instance.currentUser?.displayName ?? "Member";

  @override
  void dispose() {
    msgController.dispose(); // Important for memory management
    super.dispose();
  }

  void sendMessage() async {
    final text = msgController.text.trim();
    if (text.isEmpty) return;

    await FirebaseFirestore.instance.collection('messages').add({
      'clubId': widget.club.id,
      'senderId': _currentUserId,
      'senderName': _currentUserName,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
    msgController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.club['name']),
        backgroundColor: Colors.white, // Or your theme color
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('messages')
                  .where('clubId', isEqualTo: widget.club.id)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final messages = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final bool isMe = msg['senderId'] == _currentUserId;
                    
                    final DateTime timestamp = (msg['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

                    return _buildChatBubble(msg, isMe, timestamp);
                  },
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  // Move your existing bubble UI here
  Widget _buildChatBubble(DocumentSnapshot msg, bool isMe, DateTime timestamp) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Text(msg['senderName'] ?? "Member", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: isMe ? Colors.blue : Colors.grey[200], // Adjust colors
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(msg['text'], style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
          ),
          Text("${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}", style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: msgController,
              decoration: InputDecoration(hintText: "Type a message...", filled: true, fillColor: Colors.grey[100]),
            ),
          ),
          IconButton(icon: const Icon(Icons.send), onPressed: sendMessage),
        ],
      ),
    );
  }
}