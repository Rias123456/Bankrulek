import 'package:flutter/material.dart';
import '../widgets/primary_button.dart';

/// หน้าหลักของระบบ / Main entry screen for the portal
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('บ้านครูเล็ก'),
        centerTitle: true, // ทำให้ Title อยู่กลาง AppBar
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // จัดให้อยู่กลางแนวตั้ง
            crossAxisAlignment: CrossAxisAlignment.center, // จัดให้อยู่กลางแนวนอน
            children: [
              // โลโก้ตรงกลาง
              Image.asset(
                'assets/images/logo.png',
                height: 120, // ปรับขนาดโลโก้
              ),
              const SizedBox(height: 24),

              const Text(
                'เลือกการทำงานที่ต้องการ / Please choose an action',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // ปุ่มทั้งหมดจัดตรงกลาง
              SizedBox(
                width: 250, // จำกัดความกว้างปุ่มให้ดูบาลานซ์
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PrimaryButton(
                      label: 'ล็อกอินติวเตอร์ / Tutor Login',
                      onPressed: () =>
                          Navigator.pushNamed(context, '/tutor-login'),
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'สมัครติวเตอร์ / Register Tutor',
                      onPressed: () =>
                          Navigator.pushNamed(context, '/register-tutor'),
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'ล็อกอินแอดมิน / Admin Login',
                      onPressed: () =>
                          Navigator.pushNamed(context, '/admin-login'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
