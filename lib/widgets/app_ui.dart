import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/motomap_colors.dart';

class MotoMapBrandIcon extends StatelessWidget {
  const MotoMapBrandIcon({super.key, required this.size, this.radius});

  static const lightAsset = 'assets/branding/motomap_icon_light.jpg';
  static const darkAsset = 'assets/branding/motomap_icon_dark.jpg';

  final double size;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    // Use the phone's appearance so branding follows the system even while
    // MotoMap's current interface remains dark-first.
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius ?? size * 0.28),
      child: Image.asset(
        isDark ? darkAsset : lightAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class MotoMapLogo extends StatelessWidget {
  const MotoMapLogo({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MotoMapBrandIcon(size: compact ? 30 : 36, radius: compact ? 10 : 12),
        const SizedBox(width: 10),
        Text(
          'MotoMap',
          style: MotoMapText.title.copyWith(
            fontSize: compact ? 16 : 18,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: color ?? MotoMapColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? MotoMapColors.outlineVariant),
    );

    if (onTap == null) {
      return Container(padding: padding, decoration: decoration, child: child);
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(padding: padding, decoration: decoration, child: child),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.action,
    this.onAction,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: MotoMapText.title),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: MotoMapText.bodyMd.copyWith(
                    color: MotoMapColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: MotoMapColors.primary,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(action!),
          ),
      ],
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.expanded = true,
    this.secondary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      height: 50,
      child: secondary
          ? OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon ?? Icons.arrow_forward_rounded, size: 18),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: MotoMapColors.onSurface,
                side: const BorderSide(color: MotoMapColors.outlineVariant),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            )
          : FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon ?? Icons.arrow_forward_rounded, size: 18),
              label: Text(label),
              style: FilledButton.styleFrom(
                backgroundColor: MotoMapColors.primary,
                foregroundColor: MotoMapColors.onPrimary,
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class AppPill extends StatelessWidget {
  const AppPill({
    required this.label,
    super.key,
    this.icon,
    this.selected = false,
    this.onTap,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 13,
        vertical: compact ? 7 : 9,
      ),
      decoration: BoxDecoration(
        color: selected
            ? MotoMapColors.primary
            : MotoMapColors.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected
              ? MotoMapColors.primary
              : MotoMapColors.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: compact ? 13 : 15,
              color: selected
                  ? MotoMapColors.onPrimary
                  : MotoMapColors.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: selected
                  ? MotoMapColors.onPrimary
                  : MotoMapColors.onSurface,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return GestureDetector(onTap: onTap, child: child);
  }
}

class RiderAvatar extends StatelessWidget {
  const RiderAvatar({
    required this.initials,
    super.key,
    this.size = 44,
    this.color = const Color(0xFF34544A),
    this.verified = false,
  });

  final String initials;
  final double size;
  final Color color;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withValues(alpha: 0.95), color],
              ),
              border: Border.all(
                color: MotoMapColors.outlineVariant,
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: TextStyle(
                fontSize: size * 0.3,
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
          if (verified)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: size * 0.32,
                height: size * 0.32,
                decoration: const BoxDecoration(
                  color: MotoMapColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: size * 0.22,
                  color: MotoMapColors.onPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class TinyStat extends StatelessWidget {
  const TinyStat({
    required this.icon,
    required this.label,
    super.key,
    this.color = MotoMapColors.onSurfaceVariant,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class RouteArtwork extends StatelessWidget {
  const RouteArtwork({
    super.key,
    this.height = 180,
    this.variant = 0,
    this.showMarkers = true,
  });

  final double height;
  final int variant;
  final bool showMarkers;

  @override
  Widget build(BuildContext context) {
    const palettes = [
      [Color(0xFF233B35), Color(0xFF101A18)],
      [Color(0xFF352E29), Color(0xFF151311)],
      [Color(0xFF263245), Color(0xFF10151C)],
      [Color(0xFF3C3320), Color(0xFF17150E)],
    ];
    final colors = palettes[variant % palettes.length];
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: CustomPaint(
          painter: _RoutePainter(
            variant: variant,
            background: colors,
            showMarkers: showMarkers,
          ),
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter({
    required this.variant,
    required this.background,
    required this.showMarkers,
  });

  final int variant;
  final List<Color> background;
  final bool showMarkers;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: background,
        ).createShader(rect),
    );

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    for (double x = -size.height; x < size.width; x += 34) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        gridPaint,
      );
    }
    for (double y = 22; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final sideRoad = Path()
      ..moveTo(-10, size.height * .72)
      ..cubicTo(
        size.width * .24,
        size.height * .5,
        size.width * .5,
        size.height * .92,
        size.width + 10,
        size.height * .65,
      );
    canvas.drawPath(sideRoad, roadPaint);

    final path = Path();
    if (variant.isEven) {
      path
        ..moveTo(size.width * .10, size.height * .78)
        ..cubicTo(
          size.width * .22,
          size.height * .63,
          size.width * .25,
          size.height * .30,
          size.width * .48,
          size.height * .43,
        )
        ..cubicTo(
          size.width * .67,
          size.height * .55,
          size.width * .68,
          size.height * .17,
          size.width * .90,
          size.height * .22,
        );
    } else {
      path
        ..moveTo(size.width * .13, size.height * .25)
        ..cubicTo(
          size.width * .31,
          size.height * .18,
          size.width * .28,
          size.height * .70,
          size.width * .53,
          size.height * .66,
        )
        ..cubicTo(
          size.width * .74,
          size.height * .62,
          size.width * .75,
          size.height * .30,
          size.width * .91,
          size.height * .78,
        );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          colors: [MotoMapColors.primary, Color(0xFFFFB36B)],
        ).createShader(rect)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    if (showMarkers) {
      final start = variant.isEven
          ? Offset(size.width * .10, size.height * .78)
          : Offset(size.width * .13, size.height * .25);
      final end = variant.isEven
          ? Offset(size.width * .90, size.height * .22)
          : Offset(size.width * .91, size.height * .78);
      canvas.drawCircle(start, 7, Paint()..color = MotoMapColors.onSurface);
      canvas.drawCircle(start, 3.5, Paint()..color = MotoMapColors.success);
      canvas.drawCircle(end, 8, Paint()..color = MotoMapColors.primary);
      final flag = Path()
        ..moveTo(end.dx - 2, end.dy - 4)
        ..lineTo(end.dx + 5, end.dy)
        ..lineTo(end.dx - 2, end.dy + 4)
        ..close();
      canvas.drawPath(flag, Paint()..color = MotoMapColors.onPrimary);
    }

    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              MotoMapColors.primary.withValues(alpha: 0.13),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * .72, size.height * .32),
              radius: math.min(size.width, size.height) * .5,
            ),
          );
    canvas.drawRect(rect, glow);
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) =>
      oldDelegate.variant != variant;
}

void showAppMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
