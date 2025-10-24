import 'package:cloud_firestore/cloud_firestore.dart';

class Tutor {
  final String id;
  final String nickname;
  final String phoneNumber;
  final String lineId;
  final String email;
  final String password;
  final String status;
  final String travelDuration;
  final String? profileImageBase64;
  final List<String> subjects;
  final String? teachingSchedule;
  final String firstName;
  final String lastName;
  final String currentActivity;

  const Tutor({
    required this.id,
    required this.nickname,
    required this.phoneNumber,
    required this.lineId,
    required this.email,
    required this.password,
    this.status = 'Active',
    required this.travelDuration,
    this.profileImageBase64,
    this.subjects = const [],
    this.teachingSchedule,
    this.firstName = '',
    this.lastName = '',
    this.currentActivity = '',
  });

  Tutor copyWith({
    String? id,
    String? nickname,
    String? phoneNumber,
    String? lineId,
    String? email,
    String? password,
    String? status,
    String? travelDuration,
    String? profileImageBase64,
    List<String>? subjects,
    String? teachingSchedule,
    String? firstName,
    String? lastName,
    String? currentActivity,
  }) {
    return Tutor(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      lineId: lineId ?? this.lineId,
      email: email ?? this.email,
      password: password ?? this.password,
      status: status ?? this.status,
      travelDuration: travelDuration ?? this.travelDuration,
      profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
      subjects: subjects ?? this.subjects,
      teachingSchedule: teachingSchedule ?? this.teachingSchedule,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      currentActivity: currentActivity ?? this.currentActivity,
    );
  }

  /// ✅ ดึงจาก Firestore → สร้าง Tutor model
  factory Tutor.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Tutor(
      id: doc.id,
      nickname: data['nickname'] ?? '',
      phoneNumber: data['phone'] ?? '',
      lineId: data['lineId'] ?? '',
      email: data['email'] ?? '',
      password: data['password'] ?? '',
      status: data['currentStatus'] ?? 'Active',
      travelDuration: data['travelTime'] ?? '',
      profileImageBase64: data['profileImageBase64'],
      subjects: List<String>.from(data['subjects'] ?? []),
      teachingSchedule: data['teachingSchedule'],
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      currentActivity: data['currentActivity'] ?? '',
    );
  }

  /// ✅ สำหรับ dropdown etc.
  static const List<String> statuses = [
    'Active',
    'Inactive',
    'Busy',
    'Available'
  ];
}
