import 'package:flutter/material.dart';

import '../../features/vault/domain/vault_item.dart';

class VaultEntryTile extends StatelessWidget {
  const VaultEntryTile({super.key, required this.item, this.onTap});

  final VaultItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: item.accentColor.withValues(alpha: 0.14),
        child: Icon(item.icon, color: item.accentColor),
      ),
      title: Text(
        item.title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text('${item.username} - ${item.category.label}'),
      trailing: SizedBox(
        width: 96,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _StrengthBadge(score: item.strengthScore),
            const SizedBox(height: 6),
            Text(
              item.lastUpdatedLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.right,
            ),
          ],
        ),
      ),
    );
  }
}

class _StrengthBadge extends StatelessWidget {
  const _StrengthBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (score) {
      >= 90 => Colors.green,
      >= 70 => Colors.orange,
      _ => theme.colorScheme.error,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$score%',
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
