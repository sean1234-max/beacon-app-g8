import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/notification_service.dart';
import '../theme/app_theme.dart';
import 'add_event_screen.dart';

class ClubManagementScreen extends StatefulWidget {
  const ClubManagementScreen({super.key});

  @override
  State<ClubManagementScreen> createState() => _ClubManagementScreenState();
}

class _ClubManagementScreenState extends State<ClubManagementScreen> {
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  // ─── Shared card decoration ──────────────────────────────────

  static const BoxDecoration _cardDeco = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.all(Radius.circular(14)),
    boxShadow: [
      BoxShadow(
        color: Color(0x0A000000),
        blurRadius: 2,
        offset: Offset(0, 1),
      ),
    ],
  );

  // ─── Helpers ─────────────────────────────────────────────────

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'technology':
        return Icons.computer_rounded;
      case 'sports':
        return Icons.sports_rounded;
      case 'arts':
        return Icons.palette_rounded;
      case 'music':
        return Icons.music_note_rounded;
      case 'academic':
        return Icons.school_rounded;
      case 'cultural':
        return Icons.diversity_3_rounded;
      case 'environment':
        return Icons.eco_rounded;
      default:
        return Icons.groups_rounded;
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Color _avatarColor(String name) {
    const colors = [
      Color(0xFF5C6BC0),
      Color(0xFF26A69A),
      Color(0xFFEF5350),
      Color(0xFFAB47BC),
      Color(0xFF42A5F5),
      Color(0xFF66BB6A),
      Color(0xFFFF7043),
      Color(0xFF8D6E63),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  // ─── Grabber + title used by every bottom sheet ──────────────

  Widget _sheetHeader(BuildContext ctx, String title) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
          child: Row(
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Section header with optional count badge ─────────────────

  Widget _sectionHeader(String title, int? count) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                  color: AppTheme.primaryBlue,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryBlue,
        elevation: 0,
        title: const Text('Club Management',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clubs')
            .where('leaderId', isEqualTo: _currentUserId)
            .where('status', isEqualTo: 'approved')
            .limit(1)
            .snapshots(),
        builder: (context, clubSnap) {
          if (clubSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!clubSnap.hasData || clubSnap.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final clubDoc = clubSnap.data!.docs.first;
          final clubData = clubDoc.data() as Map<String, dynamic>;
          final String clubId = clubDoc.id;

          return ListView(
            children: [
              _buildHeroCard(clubId, clubData),
              const SizedBox(height: 16),
              _buildQuickActions(clubId, clubData),
              const SizedBox(height: 20),
              _buildMembersSection(clubId, clubData),
              const SizedBox(height: 20),
              _buildUpcomingEventsSection(clubId),
              const SizedBox(height: 20),
              _buildFooter(clubData),
              const SizedBox(height: 36),
            ],
          );
        },
      ),
    );
  }

  // ─── Empty state ──────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.groups_rounded,
                size: 56, color: AppTheme.primaryBlue),
          ),
          const SizedBox(height: 20),
          const Text("You don't lead any clubs yet",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Apply to create a club from the Clubs tab',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  1. HERO CARD
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHeroCard(String clubId, Map<String, dynamic> club) {
    final String category = club['category'] ?? '';
    final String name = club['name'] ?? '';
    final String description = club['description'] ?? '';
    final int maxMembers = (club['maxMembers'] as num?)?.toInt() ?? 200;
    final List members = club['members'] ?? [];

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .where('clubId', isEqualTo: clubId)
          .snapshots(),
      builder: (context, evSnap) {
        final now = DateTime.now();
        final upcomingCount = evSnap.hasData
            ? evSnap.data!.docs.where((d) {
                final dt = (d.data() as Map<String, dynamic>)['dateTime'];
                if (dt == null) return false;
                return (dt as Timestamp).toDate().isAfter(now);
              }).length
            : 0;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0A1628), Color(0xFF122140)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 64 px rounded square club icon
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(_categoryIcon(category),
                          color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // LEADER + category pills
                          Row(
                            children: [
                              _heroPill(
                                'LEADER',
                                const Color(0xFFF5B400),
                                const Color(0x26F5B400),
                              ),
                              if (category.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                _heroPill(
                                  category.toUpperCase(),
                                  Colors.white70,
                                  Colors.white.withValues(alpha: 0.12),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.65),
                                    fontSize: 12,
                                    height: 1.4)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // stat strip
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: _heroStat(
                            'MEMBERS', '${members.length} / $maxMembers'),
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      Expanded(
                        child: _heroStat('UPCOMING', '$upcomingCount'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _heroPill(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              color: textColor, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _heroStat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  2. QUICK ACTIONS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildQuickActions(String clubId, Map<String, dynamic> club) {
    final actions = [
      {
        'icon': Icons.campaign_rounded,
        'title': 'Post Event',
        'sub': 'Create a new event',
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => AddEventScreen(clubId: clubId)),
          );
        },
      },
      {
        'icon': Icons.notifications_active_rounded,
        'title': 'Announcement',
        'sub': 'Broadcast to members',
        'onTap': () {
          _showAnnouncementSheet(clubId, club);
        },
      },
      {
        'icon': Icons.swap_horiz_rounded,
        'title': 'Transfers Leadership',
        'sub': 'Pass your role',
        'onTap': () {
          _showTransferLeadershipSheet(clubId, club);
        },
      },
      {
        'icon': Icons.edit_rounded,
        'title': 'Edit Club',
        'sub': 'Update details',
        'onTap': () {
          _showEditClubSheet(clubId, club);
        },
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Quick Actions', null),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.65,
            children: actions.map((a) {
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: a['onTap'] as VoidCallback,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(a['icon'] as IconData,
                              color: AppTheme.primaryBlue, size: 20),
                        ),
                        const SizedBox(height: 8),
                        Text(a['title'] as String,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(a['sub'] as String,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  3. MEMBERS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildMembersSection(String clubId, Map<String, dynamic> club) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('registrations')
            .where('clubId', isEqualTo: clubId)
            .snapshots(),
        builder: (context, snap) {
          final docs = snap.hasData ? snap.data!.docs : <DocumentSnapshot>[];
          final sortedDocs = [...docs]..sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aIsLeader = aData['userId'] == club['leaderId'];
              final bIsLeader = bData['userId'] == club['leaderId'];
              if (aIsLeader) return -1;
              if (bIsLeader) return 1;
              return 0;
            });
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(
                  'Members', snap.hasData ? sortedDocs.length : null),
              const SizedBox(height: 10),
              if (!snap.hasData)
                const Center(child: CircularProgressIndicator())
              else if (sortedDocs.isEmpty)
                Container(
                  decoration: _cardDeco,
                  padding: const EdgeInsets.all(20),
                  child: const Center(
                    child: Text('No members yet',
                        style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                Container(
                  decoration: _cardDeco,
                  child: Column(
                    children: sortedDocs.asMap().entries.map((entry) {
                      final i = entry.key;
                      final member = entry.value.data() as Map<String, dynamic>;
                      final isLeader = member['userId'] == club['leaderId'];
                      return Column(
                        children: [
                          _buildMemberTile(member, isLeader, clubId),
                          if (i < sortedDocs.length - 1)
                            const Divider(height: 1, indent: 70),
                        ],
                      );
                    }).toList(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMemberTile(
      Map<String, dynamic> member, bool isLeader, String clubId) {
    final String name = member['name'] ?? 'Unknown';
    final Color color = _avatarColor(name);
    final Timestamp? joinedAt = member['joinedAt'] as Timestamp?;
    final String joined = joinedAt != null
        ? DateFormat('MMM yyyy').format(joinedAt.toDate())
        : 'Unknown';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: color,
        radius: 22,
        child: Text(_initials(name),
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(name,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          if (isLeader)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0x26F5B400),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium_rounded,
                      size: 10, color: Color(0xFFF5B400)),
                  SizedBox(width: 3),
                  Text('LEADER',
                      style: TextStyle(
                          color: Color(0xFFF5B400),
                          fontSize: 9,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
      subtitle: Text('Joined $joined',
          style: const TextStyle(fontSize: 12, color: Colors.grey)),
      onTap: () => _showMemberSheet(member, isLeader, clubId),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  4. UPCOMING EVENTS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildUpcomingEventsSection(String clubId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('events')
            .where('clubId', isEqualTo: clubId)
            .snapshots(),
        builder: (context, snap) {
          // Show error if query fails
          if (snap.hasError) {
            return Center(
                child: Text('Error: ${snap.error}',
                    style: const TextStyle(color: Colors.red)));
          }

          // Show loading spinner while waiting
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final now = DateTime.now();

          // Filter only future events, then sort by date ascending
          final upcoming = snap.data!.docs.where((d) {
            final dt = (d.data() as Map<String, dynamic>)['dateTime'];
            if (dt == null) return false;
            return (dt as Timestamp).toDate().isAfter(now);
          }).toList()
            ..sort((a, b) {
              final aTime =
                  ((a.data() as Map<String, dynamic>)['dateTime'] as Timestamp)
                      .toDate();
              final bTime =
                  ((b.data() as Map<String, dynamic>)['dateTime'] as Timestamp)
                      .toDate();
              return aTime.compareTo(bTime); // earliest first
            });

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader('Upcoming Events', upcoming.length),
              const SizedBox(height: 10),
              if (upcoming.isEmpty)
                Container(
                  decoration: _cardDeco,
                  padding: const EdgeInsets.all(20),
                  child: const Center(
                    child: Text('No upcoming events',
                        style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                Column(
                  children: upcoming.map((doc) {
                    final event = doc.data() as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildEventCard(doc.id, event, clubId),
                    );
                  }).toList(),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEventCard(
      String eventId, Map<String, dynamic> event, String clubId) {
    final DateTime dt = (event['dateTime'] as Timestamp).toDate();
    final List participants = List.from(event['participants'] ?? []);
    final int maxP = (event['maxParticipants'] as num?)?.toInt() ?? 100;
    final double progress =
        maxP > 0 ? (participants.length / maxP).clamp(0.0, 1.0) : 0;
    final bool atCapacity = participants.length >= maxP;

    return Container(
      decoration: _cardDeco,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // date pill
            Container(
              width: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
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
                          BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Text(
                      DateFormat('EEE').format(dt).toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        Text(DateFormat('d').format(dt),
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        Text(DateFormat('MMM').format(dt),
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event['title'] ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 3),
                      Text(DateFormat('hh:mm a').format(dt),
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 11)),
                      if ((event['location'] ?? '').isNotEmpty) ...[
                        const Text(' · ', style: TextStyle(color: Colors.grey)),
                        const Icon(Icons.location_on_rounded,
                            size: 12, color: Colors.grey),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(event['location'] as String,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 11)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  // attendance progress
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation(
                                atCapacity ? Colors.amber : Colors.green),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${participants.length}/$maxP',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // pill buttons
                  Row(
                    children: [
                      _actionPill('View', Icons.visibility_rounded,
                          AppTheme.primaryBlue, () {}),
                      const SizedBox(width: 6),
                      _actionPill('Edit', Icons.edit_rounded, Colors.orange,
                          () => _showEditEventSheet(eventId, event)),
                      const SizedBox(width: 6),
                      _actionPill(
                          'Remind',
                          Icons.notifications_rounded,
                          Colors.purple,
                          () => _sendEventReminder(eventId, event)),
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

  Widget _actionPill(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  5. FOOTER
  // ═══════════════════════════════════════════════════════════════

  Widget _buildFooter(Map<String, dynamic> club) {
    final Timestamp? createdAt = club['createdAt'] as Timestamp?;
    final String founded = createdAt != null
        ? DateFormat('MMMM yyyy').format(createdAt.toDate())
        : 'Unknown';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        'Founded $founded · Reviewed by APU Student Affairs',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.grey, fontSize: 11),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  BOTTOM SHEETS
  // ═══════════════════════════════════════════════════════════════
  // ── Announcement ─────────────────────────────────────────────

  void _showAnnouncementSheet(String clubId, Map<String, dynamic> club) {
    final titleCtrl = TextEditingController();
    final msgCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHeader(ctx, 'Announcement'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                children: [
                  TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Announcement Title')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: msgCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                          labelText: 'Message', alignLabelWithHint: true)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (titleCtrl.text.trim().isEmpty ||
                            msgCtrl.text.trim().isEmpty) return;
                        try {
                          final mSnap = await FirebaseFirestore.instance
                              .collection('registrations')
                              .where('clubId', isEqualTo: clubId)
                              .get();
                          for (final m in mSnap.docs) {
                            final uid = (m.data())['userId'] as String?;
                            if (uid != null) {
                              await NotificationService.sendNotification(
                                userId: uid,
                                title: '📢 ${titleCtrl.text.trim()}',
                                message: msgCtrl.text.trim(),
                                type: 'broadcast',
                              );
                            }
                          }
                          if (mounted) Navigator.pop(ctx);
                          _showSnackBar('Announcement sent to all members!',
                              Colors.green);
                        } catch (e) {
                          _showSnackBar('Error: $e', Colors.red);
                        }
                      },
                      child: const Text('Send to All Members'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Edit Club ────────────────────────────────────────────────

  void _showEditClubSheet(String clubId, Map<String, dynamic> club) {
    final nameCtrl = TextEditingController(text: club['name'] ?? '');
    final catCtrl = TextEditingController(text: club['category'] ?? '');
    final descCtrl = TextEditingController(text: club['description'] ?? '');
    final maxCtrl = TextEditingController(
        text: '${(club['maxMembers'] as num?)?.toInt() ?? 200}');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHeader(ctx, 'Edit Club'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                children: [
                  TextField(
                      controller: nameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Club Name')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: catCtrl,
                      decoration: const InputDecoration(labelText: 'Category')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          labelText: 'Description', alignLabelWithHint: true)),
                  const SizedBox(height: 12),
                  TextField(
                      controller: maxCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Max Members')),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await FirebaseFirestore.instance
                              .collection('clubs')
                              .doc(clubId)
                              .update({
                            'name': nameCtrl.text.trim(),
                            'category': catCtrl.text.trim(),
                            'description': descCtrl.text.trim(),
                            'maxMembers':
                                int.tryParse(maxCtrl.text.trim()) ?? 200,
                          });
                          if (mounted) Navigator.pop(ctx);
                          _showSnackBar('Club updated!', Colors.green);
                        } catch (e) {
                          _showSnackBar('Error: $e', Colors.red);
                        }
                      },
                      child: const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Edit Event ───────────────────────────────────────────────

  void _showEditEventSheet(String eventId, Map<String, dynamic> event) {
    final titleCtrl = TextEditingController(text: event['title'] ?? '');
    final locationCtrl = TextEditingController(text: event['location'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHeader(ctx, 'Edit Event'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                children: [
                  TextField(
                      controller: titleCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Event Title')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: locationCtrl,
                      decoration: const InputDecoration(labelText: 'Location')),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await FirebaseFirestore.instance
                              .collection('events')
                              .doc(eventId)
                              .update({
                            'title': titleCtrl.text.trim(),
                            'location': locationCtrl.text.trim(),
                          });
                          if (mounted) Navigator.pop(ctx);
                          _showSnackBar('Event updated!', Colors.green);
                        } catch (e) {
                          _showSnackBar('Error: $e', Colors.red);
                        }
                      },
                      child: const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Member detail sheet ──────────────────────────────────────

  void _showMemberSheet(
      Map<String, dynamic> member, bool isLeader, String clubId) {
    final String name = member['name'] ?? 'Unknown';
    final String userId = member['userId'] ?? '';
    final Color color = _avatarColor(name);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            CircleAvatar(
              backgroundColor: color,
              radius: 36,
              child: Text(_initials(name),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22)),
            ),
            const SizedBox(height: 12),
            Text(name,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 4),
            if (isLeader) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x26F5B400),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('LEADER',
                    style: TextStyle(
                        color: Color(0xFFF5B400),
                        fontWeight: FontWeight.bold,
                        fontSize: 11)),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_rounded, color: Colors.amber, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "You're the Leader. Use Transfer "
                        "Leadership to pass the role first.",
                        style: TextStyle(color: Colors.amber, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.message_rounded,
                    color: AppTheme.primaryBlue),
                title: const Text('Send Message'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSnackBar('Messaging coming soon!', Colors.blue);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.person_remove_rounded, color: Colors.red),
                title: const Text('Remove from Club',
                    style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _removeMember(userId, name, clubId);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Transfer Leadership ──────────────────────────────────────

  void _showTransferLeadershipSheet(
      String clubId, Map<String, dynamic> club) async {
    final mSnap = await FirebaseFirestore.instance
        .collection('registrations')
        .where('clubId', isEqualTo: clubId)
        .get();

    final eligible = mSnap.docs
        .where((d) => (d.data())['userId'] != _currentUserId)
        .toList();

    if (!mounted) return;

    String? selUid;
    String? selName;
    bool showConfirm = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSS) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollCtrl) => Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
                child: Row(
                  children: [
                    Text(
                      showConfirm ? 'Confirm Transfer' : 'Transfer Leadership',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: showConfirm
                    ? _buildTransferConfirm(
                        sheetCtx,
                        selUid!,
                        selName!,
                        clubId,
                        club,
                        eligible,
                        onBack: () => setSS(() => showConfirm = false),
                      )
                    : _buildTransferPickList(
                        scrollCtrl,
                        eligible,
                        selUid,
                        onSelect: (uid, name) => setSS(() {
                          selUid = uid;
                          selName = name;
                        }),
                        onContinue: selUid != null
                            ? () => setSS(() => showConfirm = true)
                            : null,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransferPickList(
    ScrollController ctrl,
    List<QueryDocumentSnapshot> eligible,
    String? selUid, {
    required void Function(String uid, String name) onSelect,
    required VoidCallback? onContinue,
  }) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_rounded, color: Colors.amber, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "The selected member becomes the new Leader. "
                  "You'll become a regular member of the club.",
                  style: TextStyle(color: Colors.amber, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        if (eligible.isEmpty)
          const Expanded(
            child: Center(
              child: Text('No other members to transfer to.',
                  style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              itemCount: eligible.length,
              itemBuilder: (_, i) {
                final m = eligible[i].data() as Map<String, dynamic>;
                final uid = m['userId'] as String? ?? '';
                final name = m['name'] as String? ?? 'Unknown';
                final picked = uid == selUid;
                return ListTile(
                  onTap: () => onSelect(uid, name),
                  tileColor: picked
                      ? AppTheme.primaryBlue.withValues(alpha: 0.06)
                      : null,
                  leading: CircleAvatar(
                    backgroundColor: _avatarColor(name),
                    child: Text(_initials(name),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: picked
                      ? const Icon(Icons.check_circle_rounded,
                          color: AppTheme.primaryBlue)
                      : const Icon(Icons.radio_button_unchecked_rounded,
                          color: Colors.grey),
                );
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: onContinue != null
                    ? AppTheme.primaryBlue
                    : Colors.grey.shade300,
                foregroundColor: Colors.white,
              ),
              child: const Text('Continue'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransferConfirm(
    BuildContext sheetCtx,
    String newUid,
    String newName,
    String clubId,
    Map<String, dynamic> club,
    List<QueryDocumentSnapshot> allMembers, {
    required VoidCallback onBack,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.swap_horiz_rounded,
                color: Colors.amber, size: 36),
          ),
          const SizedBox(height: 20),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
              children: [
                const TextSpan(text: 'Make '),
                TextSpan(
                    text: newName, style: const TextStyle(color: Colors.amber)),
                const TextSpan(text: ' the new Leader?'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "You'll lose your leader privileges and become a "
            "regular member of ${club['name']}.",
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _avatarColor(newName),
                  child: Text(_initials(newName),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(newName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Text('Incoming Leader',
                        style: TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onBack,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    side: const BorderSide(color: Colors.grey),
                    foregroundColor: Colors.grey,
                  ),
                  child: const Text('No, go back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    try {
                      await FirebaseFirestore.instance
                          .collection('clubs')
                          .doc(clubId)
                          .update({'leaderId': newUid});

                      await NotificationService.sendNotification(
                        userId: newUid,
                        title: "You're now the Leader of "
                            "${club['name']}! 👑",
                        message: 'Congratulations! Leadership has '
                            'been transferred to you.',
                        type: 'approval',
                      );

                      for (final m in allMembers) {
                        final uid = (m.data() as Map<String, dynamic>)['userId']
                            as String?;
                        if (uid != null) {
                          await NotificationService.sendNotification(
                            userId: uid,
                            title: '🔄 Leadership Update',
                            message: '$newName is now the new Leader '
                                'of ${club['name']}.',
                            type: 'broadcast',
                          );
                        }
                      }

                      if (!mounted) return;
                      Navigator.pop(sheetCtx);
                      Navigator.of(context).popUntil((route) => route.isFirst);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Leadership transferred to $newName. '
                            "You're no longer a club leader."),
                        backgroundColor: Colors.green,
                      ));
                    } catch (e) {
                      _showSnackBar('Error: $e', Colors.red);
                    }
                  },
                  child: const Text('Yes, transfer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  FIRESTORE ACTIONS
  // ═══════════════════════════════════════════════════════════════

  Future<void> _removeMember(String userId, String name, String clubId) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('registrations')
          .where('clubId', isEqualTo: clubId)
          .where('userId', isEqualTo: userId)
          .get();
      for (final doc in query.docs) {
        await doc.reference.delete();
      }
      await FirebaseFirestore.instance.collection('clubs').doc(clubId).update({
        'members': FieldValue.arrayRemove([userId]),
      });
      _showSnackBar('$name removed from club.', Colors.orange);
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  Future<void> _sendEventReminder(
      String eventId, Map<String, dynamic> event) async {
    try {
      final participants = List<String>.from(event['participants'] ?? []);
      for (final uid in participants) {
        await NotificationService.sendNotification(
          userId: uid,
          title: '⏰ Reminder: ${event['title']}',
          message: "Don't forget! The event is coming up. See you there!",
          type: 'event',
        );
      }
      _showSnackBar(
          'Reminder sent to ${participants.length} attendees!', Colors.green);
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }
}
