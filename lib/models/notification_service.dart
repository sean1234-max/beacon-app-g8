import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- EXISTING INITIALIZATION CODE ---
  Future<void> initializeNotificationSystem(BuildContext context) async {
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notification permissions.');
      String? token = await _fcm.getToken();
      if (token != null) {
        await _saveTokenToDatabase(token);
      }
      _fcm.onTokenRefresh.listen(_saveTokenToDatabase);
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.notification!.title ?? 'New Notification',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (message.notification!.body != null)
                  Text(message.notification!.body!),
              ],
            ),
          ),
        );
      }
    });
  }

  Future<void> _saveTokenToDatabase(String token) async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await _db.collection('users').doc(uid).set({
          'fcmToken': token,
          'lastTokenUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint("Error saving FCM token: $e");
      }
    }
  }

  // --- 🔴 FIXED STATIC METHOD FOR PROJECT COMPLIANCE ---
  /// Saves a notification document inside the targeted user's notification collection.
  static Future<void> sendNotification({
    required String userId,
    required String title,
    String? message, // Kept for backwards compatibility 
    String? body,    // 🟢 ADDED: Matches your UI parameter passing screens!
    required String type,
  }) async {
    try {
      // Fallback mechanism: use body if message is null, or vice versa
      final String finalContent = body ?? message ?? '';

      // Matches the security rules path: /users/{userId}/notifications/{notificationId}
      await _db
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': title,
        'message': finalContent,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      debugPrint("Notification successfully recorded in Firestore for user: $userId");
    } catch (e) {
      debugPrint("Failed to log notification in Firestore: $e");
    }
  }
}