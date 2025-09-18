import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

/// หน้าควบคุมสำหรับแอดมิน / Administrative dashboard screen
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('แดชบอร์ดแอดมิน / Admin Dashboard'),
        actions: [
          IconButton(
            tooltip: 'ออกจากระบบ / Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (BuildContext context, AuthProvider authProvider, _) {
          if (authProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          if (!authProvider.isAdminLoggedIn) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'กรุณาล็อกอินก่อน / Please login as admin first',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pushReplacementNamed(
                      context,
                      '/admin-login',
                    ),
                    child: const Text('ไปหน้าแอดมิน / Go to admin login'),
                  ),
                ],
              ),
            );
          }
          final List<Tutor> tutors = authProvider.tutors;
          if (tutors.isEmpty) {
            return const Center(
              child: Text('ยังไม่มีติวเตอร์ในระบบ / No tutors registered yet'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: tutors.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (BuildContext context, int index) {
              final Tutor tutor = tutors[index];
              return Card(
                elevation: 2,
                child: ListTile(
                  title: Text(tutor.name),
                  subtitle: Text(tutor.email),
                  leading: CircleAvatar(
                    child: Text(
                      tutor.name.isNotEmpty ? tutor.name.characters.first : '?',
                    ),
                  ),
                  trailing: const Icon(Icons.verified_user),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
