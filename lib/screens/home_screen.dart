// ignore_for_file: library_private_types_in_public_api, no_leading_underscores_for_local_identifiers

import 'package:assignment/screens/edit_event_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:assignment/screens/club_list_screen.dart';
import 'package:assignment/screens/add_event_screen.dart';
import 'package:assignment/screens/event_details_screen.dart';
import 'package:assignment/services/database_service.dart';
import 'package:assignment/services/auth_service.dart';
import 'package:assignment/models/event_model.dart';
import 'package:assignment/widgets/event_card.dart';
import 'package:assignment/theme/app_theme.dart';
import 'package:assignment/screens/profile_screen.dart';
import 'package:assignment/screens/notifications_screen.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:assignment/screens/login_screen.dart';
// lib/screens/home_screen.dart

class MainNavigationScreen extends StatefulWidget {
  static final GlobalKey<_MainNavigationScreenState> navKey =
      GlobalKey<_MainNavigationScreenState>();

  MainNavigationScreen() : super(key: navKey);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  String _searchQuery = "";
  String _userRole = 'student'; // Logic: only 'admin' or 'leader' see the FAB

  void handleExternalSearch(String query, int targetTab) {
    setState(() {
      _selectedIndex = targetTab; // Usually your Events tab index
      _searchQuery = query;
      _controller.text = query;
    });
  }

  final TextEditingController _controller = TextEditingController();
  @override
  void dispose() {
    _controller
        .dispose(); // Always clean up controllers when the screen is closed
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
    checkAndNotifyExpiredEvents();
  }

  void _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (mounted && doc.exists) {
        setState(() {
          // Fallback to 'student' if role field is missing
          _userRole = doc.data()?['role'] ?? 'student';
        });
      }
    }
  }

  Future<void> checkAndNotifyExpiredEvents() async {
    final now = DateTime.now();

    try {
      // Simplified Query: Just get events that have passed
      final expiredQuery = await FirebaseFirestore.instance
          .collection('events')
          .where('dateTime', isLessThan: now)
          .get();

      for (var doc in expiredQuery.docs) {
        final data = doc.data();

        // Safety Check: If we already notified for this event, skip it
        // This works even if the field is missing (null != true)
        if (data['isExpiredNotified'] == true) continue;

        final String eventId = doc.id;
        final String eventTitle = data['title'] ?? "Untitled Event";
        final String creatorId = data['creatorId'] ?? "";
        final List<dynamic> participants = data['participants'] ?? [];

        // Notify Creator
        if (creatorId.isNotEmpty) {
          await _sendNotification(
            userId: creatorId,
            title: "Event Completed",
            body: "Your event '$eventTitle' has ended. Thank you for hosting!",
          );
        }

        // Notify Participants
        for (String uid in participants) {
          await _sendNotification(
            userId: uid,
            title: "Event Ended",
            body: "We hope you enjoyed '$eventTitle'!",
          );
        }

        // Mark as notified in the database
        await FirebaseFirestore.instance
            .collection('events')
            .doc(eventId)
            .update({
          'isExpiredNotified': true,
        });
      }
    } catch (e) {
      debugPrint("Notification Error: $e");
      // This catch prevents the "Yellow Highlight" crash in VS Code
    }
  }

  Future<void> _sendNotification({
    required String userId,
    required String title,
    required String body,
    String type = 'info', // Added a default type
  }) async {
    // Guard clause: Don't try to send a notification to a non-existent ID
    if (userId.isEmpty) {
      debugPrint("Notification Error: userId is empty.");
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': type, // Helpful for UI styling later
      });
    } catch (e) {
      debugPrint("Failed to send notification: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    // Screens list
    final List<Widget> _screens = [
      EventListView(searchQuery: _searchQuery, userRole: _userRole),
      const ClubsScreen(),
      const ProfileScreen(),
      const NotificationsScreen(),
    ];

    // A reusable StreamBuilder for the notification count
    Widget _buildNotificationBadge(Widget child) {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('notifications')
            .where('isRead', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshot) {
          int unreadCount = snapshot.data?.docs.length ?? 0;
          return Badge(
            isLabelVisible: unreadCount > 0,
            label: Text('$unreadCount'),
            child: child,
          );
        },
      );
    }

    return Scaffold(
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: AppTheme.primaryBlue),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child:
                    Icon(Icons.person, size: 40, color: AppTheme.primaryBlue),
              ),
              accountName: Text(
                "${FirebaseAuth.instance.currentUser?.displayName ?? "Student"} (${_userRole.toUpperCase()})",
              ),
              accountEmail:
                  Text(FirebaseAuth.instance.currentUser?.email ?? ""),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text("Home"),
              onTap: () => setState(() => _selectedIndex = 0),
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Logout"),
              onTap: () async {
                await AuthService().signOut();

                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil (
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              }
            ),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
        title: _buildSearchField(),
        actions: [
          IconButton(
            // --- Dynamic Badge in AppBar ---
            icon: _buildNotificationBadge(
                const Icon(Icons.notifications, color: Colors.white)),
            onPressed: () => setState(() => _selectedIndex = 3),
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      floatingActionButton: _shouldShowFab()
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AddEventScreen()),
                );
              },
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              label: const Text("Create Event"),
              icon: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            if (index != 0) _searchQuery = "";
          });
        },
        selectedItemColor: AppTheme.primaryBlue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed, // Better for 4+ items
        items: [
          const BottomNavigationBarItem(
              icon: Icon(Icons.event), label: "Events"),
          const BottomNavigationBarItem(
              icon: Icon(Icons.groups), label: "Clubs"),
          const BottomNavigationBarItem(
              icon: Icon(Icons.person), label: "Profile"),
          BottomNavigationBarItem(
            // --- Dynamic Badge in Bottom Nav ---
            icon: _buildNotificationBadge(const Icon(Icons.notifications)),
            label: "Alerts",
          ),
        ],
      ),
    );
  }

  // Helper function to keep the build method clean
  bool _shouldShowFab() {
    return _selectedIndex == 0 &&
        (_userRole == 'admin' || _userRole == 'leader');
  }

  Widget _buildSearchField() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _controller,
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
        style: const TextStyle(color: Colors.white),
        // REMOVE 'const' from the line below
        decoration: const InputDecoration(
          hintText: 'Search events...',
          hintStyle: TextStyle(color: Colors.white60),
          prefixIcon: Icon(Icons.search, color: Colors.white60, size: 20),
          border: InputBorder.none, // Use this for no border
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

class EventListView extends StatelessWidget {
  final String searchQuery;
  final String userRole;
  const EventListView({
    super.key,
    required this.searchQuery,
    required this.userRole,
  });

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    String userRole = 'student';

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- SECTION: STUDENT DASHBOARD (Upcoming Schedule) ---
              // StreamBuilder wraps everything now so we can completely hide the schedule section if empty
              StreamBuilder<List<Event>>(
                stream: DatabaseService().getUserRegisteredEvents(userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final registeredEvents = snapshot.data ?? [];

                  // If there are no joined events, completely remove this UI section
                  if (registeredEvents.isEmpty) {
                    return const SizedBox.shrink(); 
                  }

                  // If there are events, render the schedule layout normally
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Your Upcoming Schedule",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      
                      // --- THE SINGLE CORRECT CALENDAR ---
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TableCalendar(
                          firstDay: DateTime.utc(2024, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: DateTime.now(),
                          calendarFormat: CalendarFormat.week,
                          startingDayOfWeek: StartingDayOfWeek.monday,
                          eventLoader: (day) {
                            return registeredEvents.where((event) {
                              return _isSameDay(event.dateTime, day);
                            }).toList();
                          },
                          calendarBuilders: CalendarBuilders(
                            markerBuilder: (context, day, events) {
                              if (events.isNotEmpty) {
                                return Container(
                                  margin: const EdgeInsets.all(6.0),
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primaryBlue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${day.day}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              }
                              return null;
                            },
                          ),
                          calendarStyle: CalendarStyle(
                            markersMaxCount: 0,
                            todayDecoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            todayTextStyle: const TextStyle(
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.bold,
                            ),
                            markerSize: 7.0,
                            markersAlignment: Alignment.bottomCenter,
                          ),
                          headerStyle: const HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                            titleTextStyle: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                      ),

                      // --- 2. THE HORIZONTAL TICKETS ---
                      SizedBox(
                        height: 130,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: registeredEvents.length,
                          itemBuilder: (context, index) {
                            final event = registeredEvents[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EventDetailsScreen(event: event),
                                  ),
                                );
                              },
                              child: Container(
                                width: 220,
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue,
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      event.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Spacer(),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Icon(Icons.qr_code_2, color: Colors.white70, size: 32),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            const Text("Entry Pass", style: TextStyle(color: Colors.white70, fontSize: 10)),
                                            Text(event.date, style: const TextStyle(color: Colors.white, fontSize: 12)),
                                          ],
                                        )
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24), // Extra spacer before the "Discover Events" section begins
                    ],
                  );
                },
              ),

              // --- SECTION: DISCOVER EVENTS ---
              // Your existing Discover Events UI implementation continues down here...

              // --- SECTION: DISCOVER EVENTS ---
              const Text(
                "Discover Events",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              StreamBuilder<List<Event>>(
                stream: DatabaseService().getEvents(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    print("DEBUG EVENT ERROR: ${snapshot.error}"); 
                    
                    return const Center(child: Text("Error loading events"));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // --- SEARCH FILTER LOGIC START ---
                  // --- SEARCH & EXPIRED FILTER LOGIC ---
                  final allEvents = snapshot.data ?? [];
                  final now = DateTime.now(); // Current time

                  final filteredEvents = allEvents.where((event) {
                    // 1. Check if the event date is in the future
                    final isNotExpired = event.dateTime.isAfter(now);

                    // 2. Your existing Search Logic
                    final titleMatch = event.title
                        .toLowerCase()
                        .contains(searchQuery.toLowerCase());
                    final locationMatch = event.location
                        .toLowerCase()
                        .contains(searchQuery.toLowerCase());

                    // Return true ONLY if it matches the search AND is not expired
                    return isNotExpired && (titleMatch || locationMatch);
                  }).toList();
                  // --- SEARCH FILTER LOGIC END ---

                  if (filteredEvents.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text("No events found matching your search."),
                      ),
                    );
                  }

                  return StreamBuilder<DocumentSnapshot>(
                    // Fetch the current user's profile to get their role
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser?.uid)
                        .snapshots(),
                    builder: (context, userSnapshot) {
                      // Default to 'student' if data isn't loaded yet or field is missing
                      String role = 'student';
                      if (userSnapshot.hasData && userSnapshot.data!.exists) {
                        final data =
                            userSnapshot.data!.data() as Map<String, dynamic>;
                        role = data['role'] ?? 'student';
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredEvents.length,
                        itemBuilder: (context, index) {
                          final currentEvent = filteredEvents[index];

                          return EventCard(
                            event: currentEvent,
                            userRole:
                                role, // Provided role ('admin', 'leader', or 'student')
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      EventDetailsScreen(event: currentEvent),
                                ),
                              );
                            },

                            // 1. Implementation of the Edit Logic
                            onEdit: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      EditEventScreen(event: currentEvent),
                                ),
                              );
                            },

                            // 2. Implementation of the Delete Logic with Confirmation
                            onDelete: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text("Delete Event?"),
                                  content: const Text(
                                      "Are you sure? This action cannot be undone."),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text("Cancel"),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        Navigator.pop(context); // Close dialog
                                        await FirebaseFirestore.instance
                                            .collection('events')
                                            .doc(currentEvent.id)
                                            .delete();

                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    "Event deleted successfully")),
                                          );
                                        }
                                      },
                                      child: const Text("Delete",
                                          style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ), // This returns 'nothing' if the user is a student
    );
  }
}
