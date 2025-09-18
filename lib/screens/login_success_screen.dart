import 'package:flutter/material.dart';
import '../widgets/primary_button.dart';

/// ค่าพารามิเตอร์สำหรับหน้าสำเร็จการล็อกอิน / Arguments for the login success screen
class LoginSuccessArgs {
  final String title;
  final String message;
  final String? actionLabel;
  final String? actionRoute;

  const LoginSuccessArgs({
    this.title = 'ล็อกอินสำเร็จ / Login Successful',
    this.message =
        'คุณเข้าสู่ระบบเรียบร้อยแล้ว / You have signed in successfully.',
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
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // โลโก้
                  Image.asset(
                    'assets/images/logo.png',
                    height: 100,
                  ),
                  const SizedBox(height: 24),

                  // ไอคอนเช็ค
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 96,
                  ),
                  const SizedBox(height: 24),

                  // หัวข้อ
                  Text(
                    args.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ข้อความ
                  Text(
                    args.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ปุ่ม
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
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('กลับหน้าหลัก / Back to home'),
                      ),
                    ),
                  ] else
                    PrimaryButton(
                      label: 'กลับหน้าหลัก / Back to home',
                      onPressed: () => _navigateTo(context, '/'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
