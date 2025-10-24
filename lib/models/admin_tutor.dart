import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

class AdminTutor {
  static const String defaultStatus = 'เป็นครูอยู่';
  static const List<String> statuses = <String>[defaultStatus, 'พักการสอน'];

  const AdminTutor({
    required this.id,
    required this.fullName,
    required this.nickname,
    required this.phoneNumber,
    required this.lineId,
    required this.email,
    required this.password,
    required this.currentStatus,
    required this.travelTime,
    required this.subjects,
    required this.schedule,
    this.photoUrl,
    this.profileImageBase64,
  });

  final String id;
  final String fullName;
  final String nickname;
  final String phoneNumber;
  final String lineId;
  final String email;
  final String password;
  final String currentStatus;
  final String travelTime;
  final List<String> subjects;
  final List<Map<String, dynamic>> schedule;
  final String? photoUrl;
  final String? profileImageBase64;

  String get status => currentStatus.isEmpty ? defaultStatus : currentStatus;

  String get travelDuration => travelTime;

  String? get teachingSchedule {
    if (schedule.isEmpty) {
      return '';
    }
    return jsonEncode(schedule);
  }

  AdminTutor copyWith({
    String? fullName,
    String? nickname,
    String? phoneNumber,
    String? lineId,
    String? email,
    String? password,
    String? currentStatus,
    String? travelTime,
    List<String>? subjects,
    List<Map<String, dynamic>>? schedule,
    String? photoUrl,
    String? profileImageBase64,
  }) {
    return AdminTutor(
      id: id,
      fullName: fullName ?? this.fullName,
      nickname: nickname ?? this.nickname,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      lineId: lineId ?? this.lineId,
      email: email ?? this.email,
      password: password ?? this.password,
      currentStatus: currentStatus ?? this.currentStatus,
      travelTime: travelTime ?? this.travelTime,
      subjects: subjects ?? List<String>.from(this.subjects),
      schedule: schedule ?? List<Map<String, dynamic>>.from(this.schedule),
      photoUrl: photoUrl ?? this.photoUrl,
      profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
    );
  }

  factory AdminTutor.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final Map<String, dynamic>? data = snapshot.data();
    final List<String> subjects =
        ((data?['subjects'] as List<dynamic>?) ?? <dynamic>[])
            .map((dynamic value) => value?.toString() ?? '')
            .where((String value) => value.isNotEmpty)
            .toList();
    final List<Map<String, dynamic>> schedule =
        ((data?['schedule'] as List<dynamic>?) ?? <dynamic>[])
            .map(
              (dynamic entry) => entry is Map<String, dynamic>
                  ? Map<String, dynamic>.from(entry)
                  : entry is Map
                  ? Map<String, dynamic>.from(entry.cast<String, dynamic>())
                  : <String, dynamic>{},
            )
            .where((Map<String, dynamic> entry) => entry.isNotEmpty)
            .toList();

    return AdminTutor(
      id: snapshot.id,
      fullName: data?['fullName'] as String? ?? '',
      nickname: data?['nickname'] as String? ?? '',
      phoneNumber: data?['phone'] as String? ?? '',
      lineId: data?['lineId'] as String? ?? '',
      email: data?['email'] as String? ?? '',
      password: data?['password'] as String? ?? '',
      currentStatus: data?['currentStatus'] as String? ?? defaultStatus,
      travelTime: data?['travelTime'] as String? ?? '',
      subjects: subjects,
      schedule: schedule,
      photoUrl: data?['photoUrl'] as String?,
      profileImageBase64: null,
    );
  }
}
