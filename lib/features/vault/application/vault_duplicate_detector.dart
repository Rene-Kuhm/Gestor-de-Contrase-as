import '../domain/vault_item.dart';

/// A match between a candidate [VaultItem] and an entry already in
/// the vault. Returned by [VaultDuplicateDetector.findDuplicate].
/// A match between a candidate [VaultItem] and an entry already in
/// the vault. Returned by [VaultDuplicateDetector.findDuplicate].
class VaultDuplicateMatch {
  /// Builds a duplicate match. [item] is the conflicting existing
  /// entry and [reason] is the Spanish explanation surfaced in the
  /// import preview UI.
  const VaultDuplicateMatch({required this.item, required this.reason});

  /// The existing entry that conflicts with the candidate.
  final VaultItem item;

  /// Spanish explanation of why the candidate is considered a
  /// duplicate. Surfaced in the import preview UI.
  final String reason;
}

/// Detects whether a [VaultItem] being imported is already present
/// in the vault, using two heuristics:
/// 1. Same normalized title + username + website ("same entry").
/// 2. Same secret + at least one of (username, website, title)
///    matching ("same credential").
/// Detects whether a [VaultItem] being imported is already present
/// in the vault, using two heuristics:
/// 1. Same normalized title + username + website ("same entry").
/// 2. Same secret + at least one of (username, website, title)
///    matching ("same credential").
class VaultDuplicateDetector {
  /// Creates a stateless detector. The class is `const` because it
  /// carries no state; instances are interchangeable.
  const VaultDuplicateDetector();

  /// Scans [existingItems] in order and returns the first conflict
  /// with [candidate], or `null` if no conflict is found.
  VaultDuplicateMatch? findDuplicate(
    VaultItem candidate,
    Iterable<VaultItem> existingItems,
  ) {
    for (final existing in existingItems) {
      if (_sameEntryIdentity(candidate, existing)) {
        return VaultDuplicateMatch(
          item: existing,
          reason: 'Ya existe una entrada con el mismo titulo, usuario y sitio.',
        );
      }
      if (_sameCredential(candidate, existing)) {
        return VaultDuplicateMatch(
          item: existing,
          reason:
              'Ya existe una credencial con el mismo usuario, sitio y password.',
        );
      }
    }
    return null;
  }

  bool _sameEntryIdentity(VaultItem left, VaultItem right) {
    return _normalize(left.title) == _normalize(right.title) &&
        _normalize(left.username) == _normalize(right.username) &&
        _normalize(left.website ?? '') == _normalize(right.website ?? '');
  }

  bool _sameCredential(VaultItem left, VaultItem right) {
    final leftSecret = left.secret.trim();
    final rightSecret = right.secret.trim();
    if (leftSecret.isEmpty ||
        rightSecret.isEmpty ||
        leftSecret != rightSecret) {
      return false;
    }

    final sameUsername =
        _normalize(left.username).isNotEmpty &&
        _normalize(left.username) == _normalize(right.username);
    final sameWebsite =
        _normalize(left.website ?? '').isNotEmpty &&
        _normalize(left.website ?? '') == _normalize(right.website ?? '');
    final sameTitle =
        _normalize(left.title).isNotEmpty &&
        _normalize(left.title) == _normalize(right.title);

    return sameUsername || sameWebsite || sameTitle;
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
