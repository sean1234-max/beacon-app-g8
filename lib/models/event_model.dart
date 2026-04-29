import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class Event {
  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime dateTime;
  final DateTime? registrationDeadline;
  final List<String> participants;
  final String creatorId;
  final String paymentType; // 'free' or 'paid'
  final double eventFee;
  final String picName;
  final String picPhone;
  final String bankName;
  final String bankAccountNumber;
  final String bankReceiverName;
  final String status;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.dateTime,
    this.registrationDeadline,
    required this.participants,
    required this.creatorId,
    this.paymentType = 'free',
    this.eventFee = 0,
    this.picName = '',
    this.picPhone = '',
    this.bankName = '',
    this.bankAccountNumber = '',
    this.bankReceiverName = '',
    this.status = 'pending',
  });

  String get date => DateFormat('dd MMM').format(dateTime);

  bool get isPaid => paymentType == 'paid';

  factory Event.fromFirestore(DocumentSnapshot doc) {
    final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Event(
      id: doc.id,
      title: data['title'] ?? 'No Title',
      description: data['description'] ?? '',
      location: data['location'] ?? 'No Location',
      dateTime: data['dateTime'] != null
          ? (data['dateTime'] as Timestamp).toDate()
          : DateTime.now(),
      registrationDeadline: data['registrationDeadline'] != null
          ? (data['registrationDeadline'] as Timestamp).toDate()
          : null,
      participants: data['participants'] != null
          ? List<String>.from(data['participants'])
          : [],
      creatorId: data['creatorId'] ?? '',
      paymentType: data['paymentType'] ?? 'free',
      eventFee: (data['eventFee'] as num?)?.toDouble() ?? 0,
      picName: data['picName'] ?? '',
      picPhone: data['picPhone'] ?? '',
      bankName: data['bankName'] ?? '',
      bankAccountNumber: data['bankAccountNumber'] ?? '',
      bankReceiverName: data['bankReceiverName'] ?? '',
      status: data['status'] ?? 'pending',
    );
  }
}
