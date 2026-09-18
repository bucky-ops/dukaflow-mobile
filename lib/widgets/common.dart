import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/utils.dart';

/// Shared UI atoms — KPI cards, badges, section headers, empty states.

class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = DukaColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: DukaColors.ink,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: DukaColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;

  const StatusChip(this.label, this.color, {super.key, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color : color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: filled ? DukaColors.white : color,
        ),
      ),
    );
  }
}

class TierBadge extends StatelessWidget {
  final String tier;

  const TierBadge(this.tier, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = switch (tier.toLowerCase()) {
      'gold' || 'platinum' => const Color(0xFFB8860B),
      'silver' => const Color(0xFF6B778C),
      _ => DukaColors.primary,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.stars, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          '$tier ${tier.toLowerCase() == 'gold' ? '★' : ''}'.trim(),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: DukaColors.ink,
            ),
          ),
          const Spacer(),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                action!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: DukaColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: DukaColors.inkMuted.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, color: DukaColors.ink),
            ),
            const SizedBox(height: 4),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: DukaColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  final String name;
  final double size;

  const Avatar(this.name, {super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: DukaColors.primary.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: Text(
        initialsOf(name),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: DukaColors.primary,
        ),
      ),
    );
  }
}

class OfflineBanner extends StatelessWidget {
  final VoidCallback? onTap;

  const OfflineBanner({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DukaColors.warning,
      child: InkWell(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.cloud_off, size: 15, color: DukaColors.ink),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Offline — sales save locally and sync automatically',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
