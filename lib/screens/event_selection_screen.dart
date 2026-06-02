// get current user id from firebase
//show each event in a ListTitle inside StreamBuilder
import 'package:assignment/models/event_model.dart';
import 'package:assignment/screens/scan_qr_screen.dart';
import 'package:assignment/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EventSelectionScreen extends StatelessWidget {
  const EventSelectionScreen({super.key});

  @override
  Widget build(BuildContext) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final db = DatabaseService();

    return Scaffold(
        appBar: AppBar(title: const Text('Select Event to Scan')),
        body: StreamBuilder<List<Event>>(
            stream: db.getUpcomingEvetnsByCreator(uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final events = snapshot.data ?? [];
              if (events.isEmpty) {
                return const Center(child: Text('No upcoming events found'));
              }
              return ListView.builder(
                  itemCount: events.length,
                  itemBuilder: (context, i) {
                    final event = events[i];
                    return ListTile(
                        title: Text(event.title),
                        subtitle: Text(event.date),
                        onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ScanQrScreen(event: event),
                              ),
                            ));
                  });
            }));
  }
}
