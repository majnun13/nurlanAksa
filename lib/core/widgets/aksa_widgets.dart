import 'package:flutter/material.dart';
import '../../app/theme.dart';

// ─────────────────────────────────────────────────────
//  AksaCard – temel glassmorphic kart
// ─────────────────────────────────────────────────────
class AksaCard extends StatelessWidget {
  const AksaCard({
    super.key,
    required this.child,
    this.gradient,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.borderRadius = 20,
    this.border,
  });

  final Widget child;
  final LinearGradient? gradient;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final double borderRadius;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        gradient: gradient ?? AksaColors.gradCard,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ??
            Border.all(color: const Color(0xFF1E293B), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

// ─────────────────────────────────────────────────────
//  GradientCard – colored accent cards
// ─────────────────────────────────────────────────────
class GradientCard extends StatelessWidget {
  const GradientCard({
    super.key,
    required this.child,
    required this.gradient,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.borderRadius = 20,
  });

  final Widget child;
  final LinearGradient gradient;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

// ─────────────────────────────────────────────────────
//  SectionHeader
// ─────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.action});

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AksaColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AksaColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  AksaChip
// ─────────────────────────────────────────────────────
class AksaChip extends StatelessWidget {
  const AksaChip({super.key, required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AksaColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: c,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  MacroProgressRow
// ─────────────────────────────────────────────────────
class MacroProgressRow extends StatelessWidget {
  const MacroProgressRow({
    super.key,
    required this.label,
    required this.current,
    required this.target,
    required this.unit,
    required this.color,
  });

  final String label;
  final double current;
  final double target;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = (current / target).clamp(0.0, 1.0);
    final status = current < target * 0.8
        ? 'Düşük'
        : current > target * 1.1
            ? 'Yüksek'
            : 'Hedefte';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AksaColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(
                '${current.toStringAsFixed(0)}/${'${target.toStringAsFixed(0)} $unit'}',
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              AksaChip(label: status, color: color),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  StatTile – compact metric tile
// ─────────────────────────────────────────────────────
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    this.iconColor,
    this.sub,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color? iconColor;
  final String? sub;

  Color get _ic => iconColor ?? AksaColors.primary;

  @override
  Widget build(BuildContext context) {
    return AksaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _ic.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _ic, size: 18),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: _ic,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(unit,
                    style: const TextStyle(
                        color: AksaColors.textMuted, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: AksaColors.textSecondary, fontSize: 12)),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub!,
                style: const TextStyle(
                    color: AksaColors.textMuted, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
//  SeverityBadge
// ─────────────────────────────────────────────────────
class SeverityBadge extends StatelessWidget {
  const SeverityBadge(this.severity, {super.key});

  final String severity;

  @override
  Widget build(BuildContext context) {
    final color = severity == 'YÜKSEK'
        ? AksaColors.riskHigh
        : severity == 'ORTA'
            ? AksaColors.riskMedium
            : AksaColors.riskLow;
    return AksaChip(label: severity, color: color);
  }
}

// Legacy aliases kept for backward compatibility
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AksaCard(child: child);
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return SectionHeader(title, subtitle: subtitle);
  }
}
