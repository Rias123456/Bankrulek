import 'package:flutter/material.dart';

import '../widgets/primary_button.dart';

/// หน้าหลักของระบบ / Main entry screen for the portal
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ศูนย์รวมติวเตอร์ / Tutor Hub'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'เลือกการทำงานที่ต้องการ / Please choose an action',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              label: 'ล็อกอินติวเตอร์ / Tutor Login',
              onPressed: () => Navigator.pushNamed(context, '/tutor-login'),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'สมัครติวเตอร์ / Register Tutor',
              onPressed: () => Navigator.pushNamed(context, '/register-tutor'),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'ล็อกอินแอดมิน / Admin Login',
              onPressed: () => Navigator.pushNamed(context, '/admin-login'),
            ),
          ],
        ),
      ),
    );
  }
}
