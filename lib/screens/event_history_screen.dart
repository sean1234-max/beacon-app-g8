// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/event_model.dart';
import '../theme/app_theme.dart';

class EventHistoryScreen extends StatefulWidget {
  const EventHistoryScreen({super.key});

  @override
  State<EventHistoryScreen> createState() => _EventHistoryScreenState();
}

class _EventHistoryScreenState extends State<EventHistoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterType = 'all'; // 'all', 'free', 'paid'

  static const Color _navy = Color(0xFF0A1628);
  static const Color _bg = Color(0xFFF2F4F8);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<List<Event>> _historyStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('events')
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snap) {
      final now = DateTime.now();
      final events = snap.docs
          .map((d) => Event.fromFirestore(d))
          .where((e) => e.dateTime.isBefore(now))
          .toList()
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      return events;
    });
  }

  List<Event> _applyFilters(List<Event> events) {
    return events.where((e) {
      final matchesSearch = _searchQuery.isEmpty ||
          e.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          e.location.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesType = _filterType == 'all' ||
          (_filterType == 'free' && !e.isPaid) ||
          (_filterType == 'paid' && e.isPaid);
      return matchesSearch && matchesType;
    }).toList();
  }

  Map<String, List<Event>> _groupByMonth(List<Event> events) {
    final Map<String, List<Event>> grouped = {};
    for (final e in events) {
      final key = DateFormat('MMMM yyyy').format(e.dateTime).toUpperCase();
      grouped.putIfAbsent(key, () => []).add(e);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Event History',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppTheme.primaryBlue,
          ),
        ),
      ),
      body: StreamBuilder<List<Event>>(
        stream: _historyStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red)),
            );
          }

          final allEvents = snapshot.data ?? [];
          final filtered = _applyFilters(allEvents);
          final grouped = _groupByMonth(filtered);

          final totalAttended = allEvents.length;
          final totalPaid = allEvents.where((e) => e.isPaid).length;
          return ListView(
            children: [
              _buildHero(totalAttended, totalPaid),
              _buildFilterChips(),
              if (filtered.isEmpty)
                _buildEmptyState()
              else
                ..._buildGroupedList(grouped),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  // ─── HERO ───────────────────────────────────────────────────────────────────

  Widget _buildHero(int attended, int paid) {
    return Container(
      color: _navy,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUR ACTIVITY',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$attended event${attended == 1 ? '' : 's'} attended',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ─── FILTER CHIPS ────────────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: ['all', 'free', 'paid'].map((type) {
          final selected = _filterType == type;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filterType = type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primaryBlue : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        selected ? AppTheme.primaryBlue : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  type[0].toUpperCase() + type.substring(1),
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.grey[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── GROUPED LIST ────────────────────────────────────────────────────────────

  List<Widget> _buildGroupedList(Map<String, List<Event>> grouped) {
    final widgets = <Widget>[];
    for (final entry in grouped.entries) {
      widgets.add(_buildMonthHeader(entry.key));
      for (final event in entry.value) {
        widgets.add(_buildEventCard(event));
      }
    }
    return widgets;
  }

  Widget _buildMonthHeader(String month) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(
        month,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildEventCard(Event event) {
    final dayOfWeek = DateFormat('EEE').format(event.dateTime).toUpperCase();
    final dayNum = DateFormat('d').format(event.dateTime);
    final shortMonth = DateFormat('MMM').format(event.dateTime).toUpperCase();
    final timeStr = DateFormat('h:mm a').format(event.dateTime);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: GestureDetector(
        onTap: () => _showDetailSheet(context, event),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color.fromARGB(8, 255, 0, 0),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              // Date pill
              Container(
                width: 54,
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: const BoxDecoration(
                        color: AppTheme.secondaryRed,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(9)),
                      ),
                      child: Text(
                        dayOfWeek,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          Text(
                            dayNum,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              height: 1,
                            ),
                          ),
                          Text(
                            shortMonth,
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(timeStr,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600])),
                          const SizedBox(width: 12),
                          Icon(Icons.location_on_rounded,
                              size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.location,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildFeePill(event),
                          const SizedBox(width: 8),
                          _buildAttendedBadge(),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeePill(Event event) {
    if (!event.isPaid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE6F4EC),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'FREE',
          style: TextStyle(
            color: Color(0xFF1E8A4F),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0DC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'RM${event.eventFee.toStringAsFixed(2)}',
        style: const TextStyle(
          color: Color(0xFFC2410C),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildAttendedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F4EC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF1E8A4F)),
          SizedBox(width: 4),
          Text(
            'ATTENDED',
            style: TextStyle(
              color: Color(0xFF1E8A4F),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ─── EMPTY STATE ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.history_rounded, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 14),
          Text(
            _searchQuery.isNotEmpty || _filterType != 'all'
                ? 'No events match your filters'
                : 'No past events yet',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_searchQuery.isNotEmpty || _filterType != 'all') ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() {
                _searchQuery = '';
                _searchController.clear();
                _filterType = 'all';
              }),
              child: const Text('Clear filters'),
            ),
          ],
        ],
      ),
    );
  }

  // ─── DETAIL SHEET ────────────────────────────────────────────────────────────

  void _showDetailSheet(BuildContext context, Event event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventDetailSheet(event: event),
    );
  }
}

// ─── DETAIL BOTTOM SHEET ─────────────────────────────────────────────────────

class _EventDetailSheet extends StatelessWidget {
  const _EventDetailSheet({required this.event});
  final Event event;

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('h:mm a').format(event.dateTime);
    final fullDate = DateFormat('EEE, d MMM yyyy').format(event.dateTime);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF2F4F8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Grabber
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 4),

              // Close button row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBanner(),
                      const SizedBox(height: 16),
                      _buildDetailsCard(fullDate, timeStr),
                      const SizedBox(height: 12),
                      if (event.isPaid) ...[
                        _buildPaymentCard(),
                        const SizedBox(height: 12),
                      ],
                      _buildAboutCard(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryBlue, Color(0xFF0A1628)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildFeePillWhite(),
              const SizedBox(width: 8),
              _buildAttendedBadgeWhite(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeePillWhite() {
    if (!event.isPaid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: const Text(
          'FREE',
          style: TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Text(
        'RM${event.eventFee.toStringAsFixed(2)}',
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildAttendedBadgeWhite() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E8A4F),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 12, color: Colors.white),
          SizedBox(width: 4),
          Text(
            'ATTENDED',
            style: TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(String fullDate, String timeStr) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        children: [
          _buildDetailRow(Icons.calendar_today_rounded, 'Date', fullDate),
          const Divider(height: 1, indent: 56),
          _buildDetailRow(Icons.access_time_rounded, 'Time', timeStr),
          const Divider(height: 1, indent: 56),
          _buildDetailRow(Icons.location_on_rounded, 'Venue', event.location),
          const Divider(height: 1, indent: 56),
          _buildDetailRow(Icons.people_rounded, 'Attendees',
              '${event.participants.length} people'),
          const Divider(height: 1, indent: 56),
          _buildDetailRow(
            Icons.confirmation_num_rounded,
            'Entry fee',
            event.isPaid
                ? 'RM${event.eventFee.toStringAsFixed(2)} per person'
                : 'Free event',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppTheme.primaryBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard() {
    final txnId = 'TXN-${event.id.substring(0, 8).toUpperCase()}';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE6F4EC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E8A4F)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  color: Color(0xFF1E8A4F), size: 18),
              SizedBox(width: 8),
              Text(
                'Payment successful',
                style: TextStyle(
                  color: Color(0xFF1E8A4F),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPaymentRow(
              'Method', '${event.bankName} — ${event.bankAccountNumber}'),
          const SizedBox(height: 6),
          _buildPaymentRow('Amount', 'RM${event.eventFee.toStringAsFixed(2)}'),
          const SizedBox(height: 6),
          _buildPaymentRow('Transaction ID', txnId),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.download_rounded,
                  size: 16, color: Color(0xFF1E8A4F)),
              label: const Text(
                'Download receipt',
                style: TextStyle(
                    color: Color(0xFF1E8A4F), fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1E8A4F)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
                color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildAboutCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About this event',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 10),
          Text(
            event.description.isNotEmpty
                ? event.description
                : 'No description provided.',
            style: const TextStyle(
                fontSize: 14, color: Colors.black87, height: 1.5),
          ),
        ],
      ),
    );
  }
}
