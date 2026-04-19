import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    required String type, // 'approval', 'rejection', 'event', 'broadcast'
  }) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
      'title': title,
      'message': message,
      'type': type,
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}