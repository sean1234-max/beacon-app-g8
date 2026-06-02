//show each participants in a ListTile with name, student ID, and checkin time

import 'package:assignment/models/event_model.dart';
import 'package:assignment/services/database_service.dart';
import 'package:flutter/material.dart';

class CheckedInParticipantsScreen extends StatelessWidget {
  final Event event;
  const CheckedInParticipantsScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();
    return Scaffold(
      appBar: AppBar(
        title: Text('Checked-In: ${event.title}'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        // listens CONTINUOUSLY. Every time Firestore data changes, the UI rebuilds automatically.
        stream: db.getCheckedInParticipants(event.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final participants = snapshot.data ?? [];
          if (participants.isEmpty) {
            return const Center(child: Text('No one checked in yet.'));
          }
          return ListView.builder(
            itemCount: participants.length,
            itemBuilder: (context, i) {
              final p = participants[i];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(p['userName'] ?? 'Unknown'),
                subtitle: Text(p['studentId'] ?? ''),
              );
            },
          );
        },
      ),
    );
  }
}
