import '../domain/vault_item.dart';

class VaultDuplicateMatch {
  const VaultDuplicateMatch({required this.item, required this.reason});

  final VaultItem item;
  final String reason;
}

class VaultDuplicateDetector {
  const VaultDuplicateDetector();

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
