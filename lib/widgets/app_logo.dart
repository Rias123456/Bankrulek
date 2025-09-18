import 'package:flutter/material.dart';

/// แสดงไอคอนโลโก้ของแอป / Display the application logo icon
class AppLogo extends StatelessWidget {
  /// ความสูงของรูปโลโก้ / Desired height for the logo
  final double height;

  /// ความกว้างของรูปโลโก้ / Desired width for the logo
  final double width;

  const AppLogo({
    super.key,
    this.height = 40,
    this.width = 40,
  });

  @override
  Widget build(BuildContext context) {
    final double size = (height + width) / 2;
    return Icon(
      Icons.school_outlined,
      size: size,
      color: Theme.of(context).colorScheme.primary,
    );
  }
}
