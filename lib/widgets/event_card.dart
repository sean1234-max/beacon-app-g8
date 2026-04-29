// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_model.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EventCard extends StatefulWidget {
  final Event event;
  final VoidCallback onTap;
  final String userRole;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const EventCard({
    super.key,
    required this.event,
    required this.onTap,
    required this.userRole,
    this.onDelete,
    this.onEdit,
  });

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  String? _posterBase64;
  bool _posterLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPoster();
  }

  Future<void> _loadPoster() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.event.id)
          .collection('media')
          .doc('poster')
          .get();
      if (mounted && doc.exists) {
        setState(() => _posterBase64 = doc.data()?['base64'] as String?);
      }
    } catch (_) {
      // No poster available
    } finally {
      if (mounted) setState(() => _posterLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentUserId =
        FirebaseAuth.instance.currentUser?.uid ?? '';
    final bool canManage = (widget.userRole == 'admin') ||
        (widget.userRole == 'leader' &&
            widget.event.creatorId == currentUserId);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Poster image area ──
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: _buildPosterImage(),
                ),
                // Manage menu
                if (canManage)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.black87),
                        tooltip: "Manage Event",
                        onSelected: (value) {
                          switch (value) {
                            case 'participants':
                              _showParticipantsDialog(
                                  context, widget.event.participants);
                              break;
                            case 'edit':
                              if (widget.onEdit != null) widget.onEdit!();
                              break;
                            case 'delete':
                              if (widget.onDelete != null) widget.onDelete!();
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'participants',
                            child: ListTile(
                              leading:
                                  const Icon(Icons.people_outline, size: 20),
                              title: Text(
                                  'Participants (${widget.event.participants.length})'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              leading: Icon(Icons.edit, size: 20),
                              title: Text('Edit Details'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(Icons.delete,
                                  color: Colors.red, size: 20),
                              title: Text('Delete Event',
                                  style: TextStyle(color: Colors.red)),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // ── Event info ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.event.title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd MMM yyyy, hh:mm a')
                            .format(widget.event.dateTime),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.event.location,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPosterImage() {
    if (_posterLoading) {
      return Container(
        height: 160,
        width: double.infinity,
        color: Colors.blueGrey[100],
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_posterBase64 != null) {
      try {
        return Image.memory(
          base64Decode(_posterBase64!),
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      } catch (_) {}
    }

    // Gradient placeholder
    return Container(
      height: 160,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF003366), Color(0xFF6C63FF)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_rounded, size: 40, color: Colors.white38),
            const SizedBox(height: 6),
            Text(
              widget.event.title.isNotEmpty
                  ? widget.event.title[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showParticipantsDialog(
      BuildContext context, List<String> participants) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Event Participants"),
        content: participants.isEmpty
            ? const Text("No students have joined this event yet.")
            : Text(
                "There are ${participants.length} students registered for this event."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }
}
