import 'package:flutter/material.dart';
import '../widgets/primary_button.dart';

/// หน้าหลักของระบบ / Main entry screen for the portal
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(

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
                height: 150, // ปรับขนาดโลโก้
              ),
              const SizedBox(height: 20),



              // ปุ่มทั้งหมดจัดตรงกลาง
              SizedBox(
                width: 250, // จำกัดความกว้างปุ่มให้ดูบาลานซ์
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PrimaryButton(
                      label: 'เข้าสู่ระบบติวเตอร์',
                      onPressed: () =>
                          Navigator.pushNamed(context, '/tutor-login'),
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'ลงทะเบียนติวเตอร์',
                      onPressed: () =>
                          Navigator.pushNamed(context, '/register-tutor'),
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Admin Login',
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
