import 'package:flutter/material.dart';

enum VaultCategory {
  work('Work'),
  finance('Finance'),
  personal('Personal'),
  infrastructure('Infrastructure');

  const VaultCategory(this.label);

  final String label;

  static VaultCategory fromName(String value) {
    return VaultCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () => VaultCategory.personal,
    );
  }
}

class VaultItem {
  const VaultItem({
    required this.id,
    required this.title,
    required this.username,
    required this.secret,
    required this.category,
    required this.strengthScore,
    required this.lastUpdatedLabel,
    this.website,
    this.notes,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String username;
  final String secret;
  final VaultCategory category;
  final int strengthScore;
  final String lastUpdatedLabel;
  final String? website;
  final String? notes;
  final DateTime? updatedAt;

  IconData get icon => switch (category) {
    VaultCategory.work => Icons.design_services_rounded,
    VaultCategory.finance => Icons.account_balance_wallet_rounded,
    VaultCategory.personal => Icons.menu_book_rounded,
    VaultCategory.infrastructure => Icons.dns_rounded,
  };

  Color get accentColor => switch (category) {
    VaultCategory.work => const Color(0xFF1C6E8C),
    VaultCategory.finance => const Color(0xFF2D936C),
    VaultCategory.personal => const Color(0xFFF2C14E),
    VaultCategory.infrastructure => const Color(0xFFD1495B),
  };

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'username': username,
      'secret': secret,
      'category': category.name,
      'strengthScore': strengthScore,
      'lastUpdatedLabel': lastUpdatedLabel,
      'website': website,
      'notes': notes,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory VaultItem.fromJson(Map<String, dynamic> json) {
    return VaultItem(
      id: json['id'] as String,
      title: json['title'] as String,
      username: json['username'] as String,
      secret: json['secret'] as String,
      category: VaultCategory.fromName(json['category'] as String),
      strengthScore: json['strengthScore'] as int,
      lastUpdatedLabel: json['lastUpdatedLabel'] as String,
      website: json['website'] as String?,
      notes: json['notes'] as String?,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );
  }

  VaultItem copyWith({
    String? id,
    String? title,
    String? username,
    String? secret,
    VaultCategory? category,
    int? strengthScore,
    String? lastUpdatedLabel,
    String? website,
    String? notes,
    DateTime? updatedAt,
  }) {
    return VaultItem(
      id: id ?? this.id,
      title: title ?? this.title,
      username: username ?? this.username,
      secret: secret ?? this.secret,
      category: category ?? this.category,
      strengthScore: strengthScore ?? this.strengthScore,
      lastUpdatedLabel: lastUpdatedLabel ?? this.lastUpdatedLabel,
      website: website ?? this.website,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

int estimatePasswordStrength(String secret) {
  var score = 0;
  final trimmed = secret.trim();

  if (trimmed.length >= 8) {
    score += 20;
  }
  if (trimmed.length >= 12) {
    score += 20;
  }
  if (RegExp(r'[A-Z]').hasMatch(trimmed)) {
    score += 15;
  }
  if (RegExp(r'[a-z]').hasMatch(trimmed)) {
    score += 15;
  }
  if (RegExp(r'\d').hasMatch(trimmed)) {
    score += 15;
  }
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(trimmed)) {
    score += 15;
  }

  return score.clamp(5, 100);
}

String formatVaultUpdatedLabel(DateTime updatedAt, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final difference = reference.difference(updatedAt);

  if (difference.inMinutes < 1) {
    return 'Updated now';
  }
  if (difference.inHours < 1) {
    return 'Updated ${difference.inMinutes}m ago';
  }
  if (difference.inDays < 1) {
    return 'Updated ${difference.inHours}h ago';
  }
  if (difference.inDays == 1) {
    return 'Updated yesterday';
  }
  return 'Updated ${difference.inDays}d ago';
}
