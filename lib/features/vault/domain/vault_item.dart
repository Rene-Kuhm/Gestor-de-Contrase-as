import 'package:flutter/material.dart';

enum VaultCategory {
  work('Work'),
  finance('Finance'),
  personal('Personal'),
  infrastructure('Infrastructure');

  const VaultCategory(this.label);

  final String label;
}

class VaultItem {
  const VaultItem({
    required this.title,
    required this.username,
    required this.category,
    required this.strengthScore,
    required this.lastUpdatedLabel,
    required this.icon,
    required this.accentColor,
  });

  final String title;
  final String username;
  final VaultCategory category;
  final int strengthScore;
  final String lastUpdatedLabel;
  final IconData icon;
  final Color accentColor;
}
