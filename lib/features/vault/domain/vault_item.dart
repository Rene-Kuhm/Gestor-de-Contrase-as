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
  });

  final String id;
  final String title;
  final String username;
  final String secret;
  final VaultCategory category;
  final int strengthScore;
  final String lastUpdatedLabel;

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
    );
  }
}
