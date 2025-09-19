import 'package:flutter/material.dart';

import '../widgets/primary_button.dart';

/// ค่าพารามิเตอร์สำหรับหน้าสำเร็จการล็อกอิน
class LoginSuccessArgs {
  /// หัวข้อแสดงผล
  final String title;

  /// ข้อความอธิบาย
  final String message;

  /// ป้ายปุ่มหลัก
  final String? actionLabel;

  /// เส้นทางเมื่อกดปุ่มหลัก
  final String? actionRoute;

  const LoginSuccessArgs({
    this.title = 'ล็อกอินสำเร็จ',
    this.message = 'คุณเข้าสู่ระบบเรียบร้อยแล้ว',
    this.actionLabel,
    this.actionRoute,
  });
}

/// หน้าแสดงผลเมื่อการล็อกอินเสร็จสมบูรณ์
class LoginSuccessScreen extends StatelessWidget {
  const LoginSuccessScreen({super.key});

  void _navigateTo(BuildContext context, String route) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      route,
      (Route<dynamic> _) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Object? rawArgs = ModalRoute.of(context)?.settings.arguments;
    final LoginSuccessArgs args =
        rawArgs is LoginSuccessArgs ? rawArgs : const LoginSuccessArgs();

    final bool hasPrimaryAction = args.actionLabel != null &&
        args.actionRoute != null &&
        args.actionLabel!.isNotEmpty &&
        args.actionRoute!.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E1), // พื้นหลังชมพูอ่อน
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(args.title),
        backgroundColor: const Color(0xFFFFE4E1),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green.shade600,
              size: 96,
            ),
            const SizedBox(height: 24),
            Text(
              args.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              args.message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 32),

            // ถ้ามีปุ่ม Action พิเศษ -> แสดงทั้งปุ่ม Action และปุ่มกลับหน้าหลัก
            if (hasPrimaryAction) ...[
              PrimaryButton(
                label: args.actionLabel!,
                onPressed: () => _navigateTo(context, args.actionRoute!),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _navigateTo(context, '/'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  child: const Text('กลับหน้าหลัก'),
                ),
              ),
            ],

            // ถ้าไม่มี -> แสดงปุ่มกลับหน้าหลักปุ่มเดียว
            if (!hasPrimaryAction)
              PrimaryButton(
                label: 'กลับหน้าหลัก',
                onPressed: () => _navigateTo(context, '/'),
              ),
          ],
        ),
      ),
    );
  }
}
