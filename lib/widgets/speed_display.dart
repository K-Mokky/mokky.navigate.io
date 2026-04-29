import 'package:flutter/material.dart';
import '../providers/settings_provider.dart';

class SpeedDisplay extends StatelessWidget {
  const SpeedDisplay({
    super.key,
    required this.speedKmh,
    required this.speedUnit,
  });

  final double speedKmh;
  final SpeedUnit speedUnit;

  @override
  Widget build(BuildContext context) {
    final displaySpeed = speedUnit.fromKmh(speedKmh);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1A2332).withOpacity(0.92),
        border: Border.all(color: _color.withOpacity(0.65), width: 2),
        boxShadow: [
          BoxShadow(
            color: _color.withOpacity(0.18),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${displaySpeed.round()}',
            style: TextStyle(
              color: _color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            speedUnit.label,
            style: TextStyle(
              color: _color.withOpacity(0.65),
              fontSize: 9,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color get _color {
    if (speedKmh >= 100) return const Color(0xFFFF6B6B);
    if (speedKmh >= 60) return const Color(0xFFFFE66D);
    if (speedKmh >= 20) return const Color(0xFF4ECDC4);
    return Colors.white60;
  }
}
