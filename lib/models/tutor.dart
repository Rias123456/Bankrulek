import 'package:cloud_firestore/cloud_firestore.dart';

class TutorScheduleEntry {
  const TutorScheduleEntry({
    required this.day,
    required this.start,
    required this.end,
    this.studentName,
    this.dayIndex,
  });

  factory TutorScheduleEntry.fromMap(Map<String, dynamic> map) {
    return TutorScheduleEntry(
      day: (map['day'] as String?)?.trim() ?? '',
      start: (map['start'] as String?)?.trim() ?? '',
      end: (map['end'] as String?)?.trim() ?? '',
      studentName: (map['studentName'] as String?)?.trim(),
      dayIndex: map['dayIndex'] is int ? map['dayIndex'] as int : null,
    );
  }

  final String day;
  final String start;
  final String end;
  final String? studentName;
  final int? dayIndex;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'day': day,
      if (dayIndex != null) 'dayIndex': dayIndex,
      'start': start,
      'end': end,
      if (studentName != null && studentName!.trim().isNotEmpty)
        'studentName': studentName!.trim(),
    };
  }
}

class Tutor {
  const Tutor({
    required this.id,
    this.firstName = '',
    this.lastName = '',
    this.currentActivity = '',
    required this.nickname,
    required this.phoneNumber,
    required this.lineId,
    required this.email,
    required this.password,
    this.status = defaultStatus,
    this.travelDuration = defaultTravelDuration,
    this.profileImageBase64,
    this.photoUrl,
    this.subjects = const <String>[],
    this.teachingSchedule,
    this.schedule = const <TutorScheduleEntry>[],
    this.createdAt,
    this.updatedAt,
  });

  factory Tutor.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final Map<String, dynamic>? raw = snapshot.data();
    if (raw == null) {
      throw StateError('Document ${snapshot.id} does not contain data');
    }
    return Tutor.fromMap(snapshot.id, raw);
  }

  factory Tutor.fromMap(String id, Map<String, dynamic> map) {
    final String? fullName = (map['fullName'] as String?)?.trim();
    String resolvedFirstName = (map['firstName'] as String?)?.trim() ?? '';
    String resolvedLastName = (map['lastName'] as String?)?.trim() ?? '';
    if (fullName != null && fullName.isNotEmpty) {
      final List<String> parts = fullName
          .split(RegExp(r'\s+'))
          .where((String part) => part.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) {
        resolvedFirstName = parts.first;
        resolvedLastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      }
    }
    final List<dynamic>? rawSubjects = map['subjects'] as List<dynamic>?;
    final List<TutorScheduleEntry> schedule = (map['schedule'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(TutorScheduleEntry.fromMap)
        .toList();
    return Tutor(
      id: id,
      firstName: resolvedFirstName,
      lastName: resolvedLastName,
      currentActivity: (map['currentActivity'] as String?)?.trim() ?? '',
      nickname: (map['nickname'] as String?)?.trim() ?? '',
      phoneNumber: (map['phone'] as String?)?.trim() ?? (map['phoneNumber'] as String?)?.trim() ?? '',
      lineId: (map['lineId'] as String?)?.trim() ?? (map['line'] as String?)?.trim() ?? '',
      email: (map['email'] as String?)?.trim() ?? '',
      password: (map['password'] as String?)?.trim() ?? '',
      status:
          (map['currentStatus'] as String?)?.trim() ?? (map['status'] as String?)?.trim() ?? defaultStatus,
      travelDuration: (map['travelTime'] as String?)?.trim() ??
          (map['travelDuration'] as String?)?.trim() ??
          defaultTravelDuration,
      profileImageBase64:
          (map['photoBase64'] as String?)?.trim() ?? (map['profileImageBase64'] as String?)?.trim(),
      photoUrl: (map['photoUrl'] as String?)?.trim(),
      subjects: rawSubjects == null
          ? const <String>[]
          : rawSubjects
              .whereType<String>()
              .map((String subject) => subject.trim())
              .where((String subject) => subject.isNotEmpty)
              .toList(),
      teachingSchedule:
          (map['scheduleSerialized'] as String?)?.trim() ?? (map['teachingSchedule'] as String?)?.trim(),
      schedule: schedule,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  static const String defaultStatus = 'เป็นครูอยู่';
  static const String defaultTravelDuration = '';
  static const List<String> statuses = <String>[
    defaultStatus,
    'พักการสอน',
  ];

  final String id;
  final String firstName;
  final String lastName;
  final String currentActivity;
  final String nickname;
  final String phoneNumber;
  final String lineId;
  final String email;
  final String password;
  final String status;
  final String travelDuration;
  final String? profileImageBase64;
  final String? photoUrl;
  final List<String> subjects;
  final String? teachingSchedule;
  final List<TutorScheduleEntry> schedule;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get fullName {
    final List<String> parts = <String>[firstName, lastName]
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList();
    return parts.join(' ');
  }

  Tutor copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? currentActivity,
    String? nickname,
    String? phoneNumber,
    String? lineId,
    String? email,
    String? password,
    String? status,
    String? travelDuration,
    String? profileImageBase64,
    String? photoUrl,
    List<String>? subjects,
    String? teachingSchedule,
    List<TutorScheduleEntry>? schedule,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Tutor(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      currentActivity: currentActivity ?? this.currentActivity,
      nickname: nickname ?? this.nickname,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      lineId: lineId ?? this.lineId,
      email: email ?? this.email,
      password: password ?? this.password,
      status: status ?? this.status,
      travelDuration: travelDuration ?? this.travelDuration,
      profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
      photoUrl: photoUrl ?? this.photoUrl,
      subjects: subjects ?? this.subjects,
      teachingSchedule: teachingSchedule ?? this.teachingSchedule,
      schedule: schedule ?? this.schedule,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toFirestoreMap({bool includeTimestamps = false}) {
    final Map<String, dynamic> data = <String, dynamic>{
      'fullName': fullName,
      'firstName': firstName,
      'lastName': lastName,
      'currentActivity': currentActivity,
      'nickname': nickname,
      'phone': phoneNumber,
      'lineId': lineId,
      'email': email,
      'password': password,
      'currentStatus': status,
      'travelTime': travelDuration,
      if (profileImageBase64 != null && profileImageBase64!.isNotEmpty)
        'photoBase64': profileImageBase64,
      if (photoUrl != null && photoUrl!.isNotEmpty) 'photoUrl': photoUrl,
      'subjects': subjects,
      if (teachingSchedule != null) 'scheduleSerialized': teachingSchedule,
      'schedule': schedule.map((TutorScheduleEntry entry) => entry.toMap()).toList(),
    };
    if (includeTimestamps) {
      data['updatedAt'] = FieldValue.serverTimestamp();
    }
    return data;
  }
}
