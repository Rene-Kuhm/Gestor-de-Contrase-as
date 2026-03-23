import 'package:flutter/material.dart';

import '../../../app/design_system/app_panel.dart';
import '../../../app/theme/app_spacing.dart';
import '../domain/vault_item.dart';

class VaultEntryEditorScreen extends StatefulWidget {
  const VaultEntryEditorScreen({super.key, this.initialItem});

  final VaultItem? initialItem;

  bool get isEditing => initialItem != null;

  @override
  State<VaultEntryEditorScreen> createState() => _VaultEntryEditorScreenState();
}

class _VaultEntryEditorScreenState extends State<VaultEntryEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _usernameController;
  late final TextEditingController _secretController;
  late final TextEditingController _websiteController;
  late final TextEditingController _notesController;

  late VaultCategory _category;
  bool _obscureSecret = true;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _titleController = TextEditingController(text: item?.title ?? '');
    _usernameController = TextEditingController(text: item?.username ?? '');
    _secretController = TextEditingController(text: item?.secret ?? '');
    _websiteController = TextEditingController(text: item?.website ?? '');
    _notesController = TextEditingController(text: item?.notes ?? '');
    _category = item?.category ?? VaultCategory.personal;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _secretController.dispose();
    _websiteController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit entry' : 'New entry'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Identity',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _titleController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          hintText: 'GitHub, banking, Wi-Fi...',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Give this entry a clear title.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _usernameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Username or email',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Add the account identifier.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<VaultCategory>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items: VaultCategory.values
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(category.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _category = value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Secret',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Vaulta recalculates strength locally before re-encrypting the entry.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _secretController,
                        obscureText: _obscureSecret,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Password or secret',
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() => _obscureSecret = !_obscureSecret);
                            },
                            icon: Icon(
                              _obscureSecret
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Store a real secret, not an empty field.';
                          }
                          if (value.trim().length < 8) {
                            return 'Use at least 8 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _websiteController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Website or app',
                          hintText: 'https://example.com',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _notesController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          hintText: 'Recovery codes, context, reminders...',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.lock_rounded),
                    label: Text(
                      widget.isEditing ? 'Save changes' : 'Create entry',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final baseItem = widget.initialItem;
    final now = DateTime.now();
    final secret = _secretController.text.trim();
    final item = VaultItem(
      id: baseItem?.id ?? 'entry-${now.microsecondsSinceEpoch}',
      title: _titleController.text.trim(),
      username: _usernameController.text.trim(),
      secret: secret,
      category: _category,
      strengthScore: estimatePasswordStrength(secret),
      lastUpdatedLabel: formatVaultUpdatedLabel(now, now: now),
      website: _normalizeOptional(_websiteController.text),
      notes: _normalizeOptional(_notesController.text),
      updatedAt: now,
    );

    Navigator.of(context).pop(item);
  }

  String? _normalizeOptional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
