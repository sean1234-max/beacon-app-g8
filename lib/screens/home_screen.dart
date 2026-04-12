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
// lib/screens/home_screen.dart

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    // We add the NotificationsScreen as the 4th item (index 3)
    final List<Widget> _screens = [
      EventListView(searchQuery: _searchQuery),
      const ClubsScreen(),
      const ProfileScreen(),
      const NotificationsScreen(),
    ];

    return Scaffold(
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: AppTheme.primaryBlue),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage: FirebaseAuth.instance.currentUser?.photoURL !=
                        null
                    ? NetworkImage(FirebaseAuth.instance.currentUser!.photoURL!)
                    : null,
                child: FirebaseAuth.instance.currentUser?.photoURL == null
                    ? const Icon(Icons.person,
                        size: 40, color: AppTheme.primaryBlue)
                    : null,
              ),
              accountName: Text(
                  FirebaseAuth.instance.currentUser?.displayName ??
                      "APU Student"),
              accountEmail:
                  Text(FirebaseAuth.instance.currentUser?.email ?? ""),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text("Settings"),
              onTap: () {},
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Logout"),
              onTap: () => AuthService().signOut(),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Container(
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Search events...',
              hintStyle: TextStyle(color: Colors.white60),
              prefixIcon: Icon(Icons.search, color: Colors.white60, size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        actions: [
          IconButton(
            // Using a Badge to make the notification icon stand out
            icon: const Badge(
              label: Text('2'),
              child: Icon(Icons.notifications, color: Colors.white),
            ),
            onPressed: () {
              setState(() {
                _selectedIndex = 3; // Navigate to NotificationsScreen
              });
            },
          ),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        // If _selectedIndex is 3 (Notifications), we show 0 (Home) as active
        // or you can handle it to show no active item.
        currentIndex: _selectedIndex > 2 ? 0 : _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: AppTheme.primaryBlue,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Clubs'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class EventListView extends StatelessWidget {
  final String searchQuery;
  const EventListView({super.key, required this.searchQuery});

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- SECTION: STUDENT DASHBOARD (Upcoming Schedule) ---
              const Text(
                "Your Upcoming Schedule",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // We put the StreamBuilder here so the Calendar and the Tickets
              // both update at the same time using the same data!
              StreamBuilder<List<Event>>(
                stream: DatabaseService().getUserRegisteredEvents(userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final registeredEvents = snapshot.data ?? [];

                  return Column(
                    children: [
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
                                    color: AppTheme.primaryBlue, // Solid background
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${day.day}',
                                    style: const TextStyle(
                                      color: Colors.white, // White text so it's readable
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
                            // CHANGED THIS LINE:
                            // Setting max count to 0 hides the default dots
                            markersMaxCount: 0,

                            todayDecoration: BoxDecoration(
                              color:
                                  AppTheme.primaryBlue.withValues(alpha: 0.15),
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
                                color: AppTheme.primaryBlue),
                          ),
                        ),
                      ),

                      // --- 2. THE HORIZONTAL TICKETS ---
                      SizedBox(
                        height: 130,
                        child: registeredEvents.isEmpty
                            ? Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                    child: Text("No events joined yet")),
                              )
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: registeredEvents.length,
                                itemBuilder: (context, index) {
                                  final event = registeredEvents[index];
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              EventDetailsScreen(event: event),
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
                                            color: Colors.black
                                                .withValues(alpha: 0.1),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          )
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Icon(Icons.qr_code_2,
                                                  color: Colors.white70,
                                                  size: 32),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  const Text("Entry Pass",
                                                      style: TextStyle(
                                                          color: Colors.white70,
                                                          fontSize: 10)),
                                                  Text(event.date,
                                                      style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12)),
                                                ],
                                              )
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }, // End of itemBuilder
                              ), // End of ListView.builder
                      ), // End of SizedBox
                    ], // End of Column (that holds Calendar + Tickets)
                  ); // End of StreamBuilder return
                }, // End of StreamBuilder builder
              ), // End of StreamBuilder

              const SizedBox(height: 24),

              // --- SECTION: DISCOVER EVENTS ---
              const Text(
                "Discover Events",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // We use a ListView.builder here, but since it's inside a SingleChildScrollView Column,
              // we set shrinkWrap to true and physics to never scroll.
              StreamBuilder<List<Event>>(
                stream: DatabaseService().getEvents(),
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return const Center(child: Text("Error loading events"));
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // --- SEARCH FILTER LOGIC START ---
                  final allEvents = snapshot.data ?? [];

                  // This filters the events based on what you type in the search bar
                  final filteredEvents = allEvents.where((event) {
                    final titleMatch = event.title
                        .toLowerCase()
                        .contains(searchQuery.toLowerCase());
                    final locationMatch = event.location
                        .toLowerCase()
                        .contains(searchQuery.toLowerCase());
                    return titleMatch || locationMatch;
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

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredEvents.length,
                    itemBuilder: (context, index) {
                      return EventCard(
                        event: filteredEvents[index],
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EventDetailsScreen(
                                  event: filteredEvents[index]),
                            ),
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddEventScreen()),
          );
        },
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        label: const Text("Create Event"),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
