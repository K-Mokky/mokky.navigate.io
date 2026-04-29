import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    required this.size,
    this.borderRadius,
    this.showShadow = false,
  });

  final double size;
  final double? borderRadius;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? size * 0.22;
    final logo = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        'assets/branding/navigateIcon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );

    if (!showShadow) return logo;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4ECDC4).withOpacity(0.28),
            blurRadius: size * 0.28,
            spreadRadius: size * 0.04,
          ),
        ],
      ),
      child: logo,
    );
  }
}
