import 'package:assignment/models/event_model.dart';
import 'package:assignment/services/database_service.dart';
import 'package:assignment/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CheckedInParticipantsScreen extends StatefulWidget {
  final Event event;
  const CheckedInParticipantsScreen({super.key, required this.event});

  @override
  State<CheckedInParticipantsScreen> createState() =>
      _CheckedInParticipantsScreenState();
}

class _CheckedInParticipantsScreenState
    extends State<CheckedInParticipantsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _sorted(List<Map<String, dynamic>> raw) {
    final list = List<Map<String, dynamic>>.from(raw);
    list.sort((a, b) {
      final ta = a['checkedInAt'];
      final tb = b['checkedInAt'];
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      final da = (ta as Timestamp).toDate();
      final db = (tb as Timestamp).toDate();
      return db.compareTo(da);
    });
    return list;
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> sorted) {
    if (_query.isEmpty) return sorted;
    final q = _query.toLowerCase();
    return sorted.where((p) {
      final name = (p['userName'] ?? '').toString().toLowerCase();
      final id = (p['studentId'] ?? '').toString().toLowerCase();
      return name.contains(q) || id.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();
    final registered = widget.event.participants.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryBlue,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CHECKED-IN',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            Text(
              widget.event.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryBlue,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.getCheckedInParticipants(widget.event.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue),
            );
          }

          final raw = snapshot.data ?? [];
          final sorted = _sorted(raw);
          final checkedIn = sorted.length;
          final pct = registered > 0 ? checkedIn / registered : 0.0;
          final filtered = _filtered(sorted);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CountHeader(
                checkedIn: checkedIn,
                registered: registered,
                pct: pct,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _SearchField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                      onClear: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
                    const SizedBox(height: 14),
                    _RosterLabel(
                      isSearching: _query.isNotEmpty,
                      resultCount: filtered.length,
                    ),
                    const SizedBox(height: 8),
                    if (filtered.isEmpty && checkedIn > 0)
                      const _NoSearchResults()
                    else if (filtered.isEmpty)
                      const _EmptyState()
                    else
                      _RosterCard(participants: filtered),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Count header ─────────────────────────────────────────────────────────────

class _CountHeader extends StatelessWidget {
  const _CountHeader({
    required this.checkedIn,
    required this.registered,
    required this.pct,
  });
  final int checkedIn;
  final int registered;
  final double pct;

  @override
  Widget build(BuildContext context) {
    final pctInt = (pct * 100).round();

    return Container(
      color: const Color(0xFF0A1628),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '$checkedIn',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'checked in',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    Text(
                      'of $registered registered',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3DDC84).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$pctInt%',
                  style: const TextStyle(
                    color: Color(0xFF3DDC84),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: Colors.white.withOpacity(0.12),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF3DDC84)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Search field ─────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search name or TP number',
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded,
              color: Colors.grey, size: 20),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.grey, size: 18),
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

// ── Roster label ──────────────────────────────────────────────────────────────

class _RosterLabel extends StatelessWidget {
  const _RosterLabel({required this.isSearching, required this.resultCount});
  final bool isSearching;
  final int resultCount;

  @override
  Widget build(BuildContext context) {
    final label =
        isSearching ? '$resultCount results' : 'Roster · latest first';
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: Colors.grey,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
      ),
    );
  }
}

// ── Roster card ───────────────────────────────────────────────────────────────

class _RosterCard extends StatelessWidget {
  const _RosterCard({required this.participants});
  final List<Map<String, dynamic>> participants;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < participants.length; i++) ...[
            _ParticipantRow(participant: participants[i]),
            if (i < participants.length - 1)
              const Divider(height: 1, thickness: 1, indent: 68),
          ],
        ],
      ),
    );
  }
}

// ── Participant row ───────────────────────────────────────────────────────────

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({required this.participant});
  final Map<String, dynamic> participant;

  static const _avatarColors = [
    Color(0xFF1A56DB),
    Color(0xFF7E3AF2),
    Color(0xFF057A55),
    Color(0xFFB43403),
    Color(0xFF0694A2),
    Color(0xFF6B7280),
  ];

  Color _avatarColor(String name) {
    if (name.isEmpty) return _avatarColors.last;
    return _avatarColors[name.codeUnitAt(0) % _avatarColors.length];
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String _formatTime(dynamic ts) {
    if (ts == null) return '—';
    final dt = ts is Timestamp ? ts.toDate() : ts as DateTime;
    return DateFormat.jm().format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final name = participant['userName'] ?? 'Unknown';
    final studentId = participant['studentId'] ?? '';
    final timeStr = _formatTime(participant['checkedInAt']);
    final color = _avatarColor(name);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color,
                child: Text(
                  _initials(name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3DDC84),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 9,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1A1F2C),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  studentId,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F4EC),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.access_time_rounded,
                    size: 11, color: Color(0xFF057A55)),
                const SizedBox(width: 3),
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF057A55),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty states ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.groups_rounded,
              size: 36,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No one checked in yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1F2C),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Attendees appear here in real time as you scan their QR codes.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 32),
      child: Column(
        children: const [
          Icon(Icons.search_off_rounded, size: 40, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'No matches found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1F2C),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Try a different name or TP number.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
