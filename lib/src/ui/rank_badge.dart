/// A self-contained, asset-free gold laurel-wreath medallion that visualises
/// the collector's current ace [AceStanding] on the Sky tab.
///
/// Everything is drawn with a [CustomPainter] (two laurel branches, a dark
/// medallion face with a gilded rim, and one star per earned rank level) so the
/// badge scales crisply at any [size] and needs no bundled images. When no rank
/// has been earned yet the medallion renders in muted greys with a lock emblem.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/medals.dart';

/// A circular laurel-wreath rank medallion for an [AceStanding].
class RankBadge extends StatelessWidget {
  final AceStanding standing;
  final double size;

  const RankBadge({super.key, required this.standing, this.size = 96});

  @override
  Widget build(BuildContext context) {
    final earned = standing.hasRank;
    final emblemColor =
        earned ? const Color(0xFFF4DD93) : const Color(0xFFBDBDBD);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LaurelBadgePainter(
          level: standing.level,
          maxLevel: standing.maxLevel,
          earned: earned,
        ),
        child: Center(
          child: Icon(
            earned ? Icons.flight : Icons.lock_outline,
            size: size * 0.26,
            color: emblemColor,
            semanticLabel: earned ? 'Rank medallion' : 'No rank yet',
          ),
        ),
      ),
    );
  }
}

class _LaurelBadgePainter extends CustomPainter {
  final int level;
  final int maxLevel;
  final bool earned;

  const _LaurelBadgePainter({
    required this.level,
    required this.maxLevel,
    required this.earned,
  });

  static const _goldLight = Color(0xFFFCE9A6);
  static const _gold = Color(0xFFE7C25C);
  static const _goldMid = Color(0xFFC9A227);
  static const _goldDark = Color(0xFF8A6D1B);

  Color get _leafColor => earned ? _gold : const Color(0xFF9E9E9E);
  Color get _leafDark => earned ? _goldDark : const Color(0xFF6E6E6E);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    // Laurel branches sit behind the medallion.
    _drawBranch(canvas, c, r, mirror: false);
    _drawBranch(canvas, c, r, mirror: true);

    // Medallion: dark radial face with a gilded rim.
    final medR = r * 0.64;
    final face = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF2B2F35), Color(0xFF0A0B0D)],
      ).createShader(Rect.fromCircle(center: c, radius: medR));
    canvas.drawCircle(c, medR, face);

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.09
      ..shader = SweepGradient(
        colors: earned
            ? const [_goldDark, _goldLight, _goldMid, _goldLight, _goldDark]
            : const [
                Color(0xFF6E6E6E),
                Color(0xFFCFCFCF),
                Color(0xFF8A8A8A),
                Color(0xFFCFCFCF),
                Color(0xFF6E6E6E),
              ],
      ).createShader(Rect.fromCircle(center: c, radius: medR));
    canvas.drawCircle(c, medR, rim);

    // One star per earned rank level, fanned across the top of the face.
    if (earned && level > 0) {
      _drawStars(canvas, c, medR);
    }
  }

  void _drawBranch(Canvas canvas, Offset c, double r, {required bool mirror}) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    if (mirror) canvas.scale(-1, 1);

    const leafCount = 9;
    final rWreath = r * 0.9;
    const startDeg = 118.0; // just left of the bottom (y-down coords)
    const endDeg = -78.0; // just right of the top
    for (var i = 0; i < leafCount; i++) {
      final t = i / (leafCount - 1);
      final deg = startDeg + (endDeg - startDeg) * t;
      final rad = deg * math.pi / 180;
      final pos = Offset(math.cos(rad) * rWreath, math.sin(rad) * rWreath);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(rad - math.pi / 2); // orient leaf along the wreath
      final scale = 0.78 + 0.42 * math.sin(t * math.pi);
      _drawLeaf(canvas, r * 0.17 * scale, r * 0.08 * scale);
      canvas.restore();
    }
    canvas.restore();
  }

  void _drawLeaf(Canvas canvas, double len, double wid) {
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(len * 0.5, -wid, len, 0)
      ..quadraticBezierTo(len * 0.5, wid, 0, 0)
      ..close();
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_leafColor, _leafDark],
      ).createShader(Rect.fromLTWH(0, -wid, len, wid * 2));
    canvas.drawPath(path, fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = wid * 0.16
        ..color = _leafDark,
    );
  }

  void _drawStars(Canvas canvas, Offset c, double medR) {
    final n = level.clamp(1, maxLevel);
    final starR = medR * 0.17;
    final arcR = medR * 0.64;
    final spanDeg = (n - 1) * 15.0;
    final startDeg = -90 - spanDeg / 2; // centered on top
    final paint = Paint()..color = _goldLight;
    for (var i = 0; i < n; i++) {
      final rad = (startDeg + i * 15.0) * math.pi / 180;
      final pos = c + Offset(math.cos(rad) * arcR, math.sin(rad) * arcR);
      _drawStar(canvas, pos, starR, paint);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final outer = -math.pi / 2 + i * 2 * math.pi / 5;
      final inner = outer + math.pi / 5;
      final o = center + Offset(math.cos(outer) * r, math.sin(outer) * r);
      final ii =
          center + Offset(math.cos(inner) * r * 0.45, math.sin(inner) * r * 0.45);
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
      path.lineTo(ii.dx, ii.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_LaurelBadgePainter old) =>
      old.level != level || old.earned != earned || old.maxLevel != maxLevel;
}
