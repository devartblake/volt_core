import 'package:flutter/material.dart';

import 'login_palette.dart';

/// Right-hand brand panel shown on wide screens.
class LoginBrandingPanel extends StatelessWidget {
  const LoginBrandingPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary.withValues(alpha: 0.8),
            colors.secondary.withValues(alpha: 0.6),
            colors.tertiary.withValues(alpha: 0.4),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(color: LoginPalette.white(0.05)),
            ),
          ),
          // Scrolls instead of overflowing when the panel is short.
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bolt, size: 120, color: LoginPalette.white(0.9)),
                  const SizedBox(height: 32),
                  Text(
                    'Voltcore',
                    style: loginText(
                      context,
                      text.displayLarge,
                      alpha: 0.95,
                      weight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Inspection Management System',
                    textAlign: TextAlign.center,
                    style: loginText(
                      context,
                      text.titleLarge,
                      alpha: 0.8,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 48),
                  const _FeatureBox(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureBox extends StatelessWidget {
  const _FeatureBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: LoginPalette.white(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LoginPalette.white(0.2)),
      ),
      child: const Column(
        children: [
          _FeaturePill(Icons.checklist_rtl, 'Maintenance Tracking'),
          SizedBox(height: 12),
          _FeaturePill(Icons.description_outlined, 'Digital Reports'),
          SizedBox(height: 12),
          _FeaturePill(Icons.analytics_outlined, 'Real-time Analytics'),
        ],
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: LoginPalette.white(0.9), size: 20),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            label,
            style: loginText(
              context,
              Theme.of(context).textTheme.bodyLarge,
              alpha: 0.9,
              weight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
