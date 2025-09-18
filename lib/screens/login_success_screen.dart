import 'package:flutter/material.dart';

import '../widgets/primary_button.dart';

/// ค่าพารามิเตอร์สำหรับหน้าสำเร็จการล็อกอิน / Arguments for the login success screen
class LoginSuccessArgs {
  /// หัวข้อแสดงผล / Title to display
  final String title;

  /// ข้อความอธิบาย / Description message
  final String message;

  /// ป้ายปุ่มหลัก / Label for the primary action button
  final String? actionLabel;

  /// เส้นทางเมื่อกดปุ่มหลัก / Route to navigate for the primary action
  final String? actionRoute;

  const LoginSuccessArgs({
    this.title = 'ล็อกอินสำเร็จ / Login Successful',
    this.message = 'คุณเข้าสู่ระบบเรียบร้อยแล้ว / You have signed in successfully.',
    this.actionLabel,
    this.actionRoute,
  });
}

/// หน้าแสดงผลเมื่อการล็อกอินเสร็จสมบูรณ์ / Screen displayed after successful login
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(args.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
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
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            if (hasPrimaryAction)
              PrimaryButton(
                label: args.actionLabel!,
                onPressed: () => _navigateTo(context, args.actionRoute!),
              ),
            if (hasPrimaryAction)
              const SizedBox(height: 16),
            if (hasPrimaryAction)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _navigateTo(context, '/'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  child: const Text('กลับหน้าหลัก / Back to home'),
                ),
              ),
            if (!hasPrimaryAction)
              PrimaryButton(
                label: 'กลับหน้าหลัก / Back to home',
                onPressed: () => _navigateTo(context, '/'),
              ),
          ],
        ),
      ),
    );
  }
}
