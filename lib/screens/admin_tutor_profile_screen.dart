import 'dart:convert';

import 'package:flutter/material.dart';

import '../providers/auth_provider.dart';

class AdminTutorProfileScreen extends StatelessWidget {
  const AdminTutorProfileScreen({super.key, required this.tutor});

  final Tutor tutor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color backgroundColor = const Color(0xFFFFE5EC);
    final String fullName = _buildFullName();
    final String nickname = tutor.nickname.isNotEmpty ? tutor.nickname : '-';
    final String lineId = tutor.lineId.isNotEmpty ? tutor.lineId : '-';
    final String phoneNumber = tutor.phoneNumber.isNotEmpty ? tutor.phoneNumber : '-';
    final String currentActivity = tutor.currentActivity.isNotEmpty ? tutor.currentActivity : 'ยังไม่ได้ระบุ';
    final String travelDuration = tutor.travelDuration.isNotEmpty ? tutor.travelDuration : 'ยังไม่ได้ระบุ';

    ImageProvider<Object>? avatarImage;
    if (tutor.profileImageBase64 != null && tutor.profileImageBase64!.isNotEmpty) {
      try {
        avatarImage = MemoryImage(base64Decode(tutor.profileImageBase64!));
      } catch (_) {
        avatarImage = null;
      }
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        title: const Text('โปรไฟล์ครู'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 48,
                backgroundImage: avatarImage,
                backgroundColor: theme.colorScheme.onSurface.withOpacity(0.08),
                child: avatarImage == null
                    ? Text(
                        nickname.characters.isNotEmpty ? nickname.characters.first : '?',
                        style: theme.textTheme.headlineMedium,
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                'ครู$nickname',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              _InfoCard(
                children: [
                  _ReadOnlyField(
                    icon: Icons.badge_outlined,
                    label: 'ชื่อจริง นามสกุล',
                    value: fullName.isNotEmpty ? fullName : 'ยังไม่ได้ระบุ',
                  ),
                  const SizedBox(height: 12),
                  _ReadOnlyField(
                    icon: Icons.person_outline,
                    label: 'ชื่อเล่น',
                    value: nickname,
                  ),
                  const SizedBox(height: 12),
                  _ReadOnlyField(
                    icon: Icons.perm_identity,
                    label: 'ID Line',
                    value: lineId,
                  ),
                  const SizedBox(height: 12),
                  _ReadOnlyField(
                    icon: Icons.phone_outlined,
                    label: 'เบอร์โทรศัพท์',
                    value: phoneNumber,
                  ),
                  const SizedBox(height: 12),
                  _ReadOnlyField(
                    icon: Icons.event_note_outlined,
                    label: 'สิ่งที่กำลังทำในปัจจุบัน',
                    value: currentActivity,
                  ),
                  const SizedBox(height: 12),
                  _ReadOnlyField(
                    icon: Icons.directions_walk_outlined,
                    label: 'ระยะเวลาเดินทาง',
                    value: travelDuration,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _InfoCard(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'วิชาที่สอน',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (tutor.subjects.isEmpty)
                    Text(
                      'ยังไม่ได้เลือกวิชา',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tutor.subjects
                          .map(
                            (String subject) => Chip(
                              label: Text(subject),
                              backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                              labelStyle: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildFullName() {
    final List<String> parts = <String>[tutor.firstName, tutor.lastName]
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList();
    return parts.join(' ');
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x19000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return TextFormField(
      readOnly: true,
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: theme.colorScheme.surface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.primary),
        ),
      ),
      style: theme.textTheme.bodyMedium,
    );
  }
}
