import 'package:flutter/material.dart';

/// ปุ่มหลักที่ใช้ซ้ำได้ทั่วทั้งแอป / Reusable primary button component
class PrimaryButton extends StatelessWidget {
  /// ข้อความบนปุ่ม / Text displayed on the button
  final String label;

  /// ฟังก์ชันเมื่อถูกกด / Callback when the button is pressed
  final VoidCallback? onPressed;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        child: Text(label),
      ),
    );
  }
}
