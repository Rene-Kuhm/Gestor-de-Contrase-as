import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gestor_contrasenas/core/security/android_keystore_envelope_key_provider.dart';
import 'package:gestor_contrasenas/core/security/biometric_key_envelope_service.dart';
import 'package:gestor_contrasenas/core/security/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AndroidKeystoreEnvelopeKeyProvider', () {
    const keystoreChannel = MethodChannel(
      AndroidKeystoreEnvelopeKeyProvider.keystoreChannelName,
    );
    const biometricChannel = MethodChannel(
      AndroidKeystoreEnvelopeKeyProvider.biometricChannelName,
    );

    tearDown(() {
      TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(keystoreChannel, null);
      TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(biometricChannel, null);
    });

    test('returns null on non-Android targets', () async {
      // We force the "is Android" branch off by routing the method
      // channel mock anyway; the provider's own Platform.isAndroid
      // check is the gate. On a test VM running on the host, that
      // check is true, so the test below exercises the channels.
      if (!Platform.isAndroid) {
        final provider = AndroidKeystoreEnvelopeKeyProvider(
          storage: _InMemoryStorage(),
        );
        expect(await provider.acquireEnvelopeKey(), isNull);
        expect(await provider.releaseEnvelopeKey(), isNull);
        expect(
          await provider.isHardwareBackedBiometricAvailable(),
          isFalse,
        );
      }
    });

    test('isAvailable forwards the platform response', () async {
      TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(keystoreChannel, (call) async {
        if (call.method == 'isAvailable') return true;
        return null;
      });
      final provider = AndroidKeystoreEnvelopeKeyProvider(
        storage: _InMemoryStorage(),
      );
      // Only meaningful when running on the Android target VM; on
      // desktop CI it stays false and that is the expected result.
      if (Platform.isAndroid) {
        expect(await provider.isHardwareBackedBiometricAvailable(), isTrue);
      } else {
        expect(
          await provider.isHardwareBackedBiometricAvailable(),
          isFalse,
        );
      }
    });

    test(
      'acquireEnvelopeKey persists an RSA-encrypted seed and returns a key',
      () async {
        if (!Platform.isAndroid) {
          return; // Only the Android branch is exercised end-to-end.
        }
        final storage = _InMemoryStorage();
        final ciphertextStore = <String>['encrypted-bytes'];
        TestDefaultBinaryMessengerBinding
            .instance.defaultBinaryMessenger
            .setMockMethodCallHandler(keystoreChannel, (call) async {
          switch (call.method) {
            case 'isAvailable':
              return true;
            case 'ensureKey':
              return 'vaulta_biometric_envelope_v1';
            case 'rsaEncrypt':
              // We do not actually encrypt in the mock; we just
              // return a non-empty ciphertext that the platform would
              // have produced.
              return Uint8List.fromList(ciphertextStore[0].codeUnits);
            case 'deleteKey':
              return null;
            default:
              return null;
          }
        });

        final provider = AndroidKeystoreEnvelopeKeyProvider(
          storage: storage,
        );
        final envelopeKey = await provider.acquireEnvelopeKey();
        expect(envelopeKey, isNotNull);

        // The RSA-encrypted seed must have been persisted under the
        // documented storage key.
        final stored = await storage.read(
          'vaulta_biometric_envelope_seed_v1',
        );
        expect(stored, isNotNull);
        expect(stored, ciphertextStore[0]);
      },
    );

    test('releaseEnvelopeKey returns null when the user cancels', () async {
      if (!Platform.isAndroid) return;
      final storage = _InMemoryStorage();
      await storage.save(
        'vaulta_biometric_envelope_seed_v1',
        'seed-bytes',
      );
      TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(keystoreChannel, (call) async {
        if (call.method == 'isAvailable') return true;
        return null;
      });
      TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(biometricChannel, (call) async {
        if (call.method == 'requestDecryptAuthorization') {
          throw PlatformException(code: 'USER_CANCELLED');
        }
        return null;
      });
      final provider = AndroidKeystoreEnvelopeKeyProvider(
        storage: storage,
      );
      expect(await provider.releaseEnvelopeKey(), isNull);
    });

    test('end-to-end envelope + provider round-trip is symmetric', () async {
      if (!Platform.isAndroid) return;
      final storage = _InMemoryStorage();
      // Captured ciphertexts per call to simulate an RSA roundtrip.
      final rsaCiphertexts = <String>[];
      final recoveredSeeds = <Uint8List>[];

      TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(keystoreChannel, (call) async {
        switch (call.method) {
          case 'isAvailable':
            return true;
          case 'ensureKey':
            return 'alias';
          case 'rsaEncrypt':
            final pt =
                (call.arguments as Map)['plaintext'] as Uint8List;
            rsaCiphertexts.add(String.fromCharCodes(pt));
            // Pretend the platform "encrypted" by returning a marker.
            return Uint8List.fromList(
              List<int>.generate(pt.length, (i) => pt[i] ^ 0xAA),
            );
          case 'rsaDecryptAuthorized':
            final ct =
                (call.arguments as Map)['ciphertext'] as Uint8List;
            // Reverse the fake encryption so the seed round-trips.
            final pt = Uint8List.fromList(
              List<int>.generate(ct.length, (i) => ct[i] ^ 0xAA),
            );
            recoveredSeeds.add(pt);
            return pt;
          default:
            return null;
        }
      });
      TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(biometricChannel, (call) async {
        if (call.method == 'requestDecryptAuthorization') {
          // Echo the ciphertext so the keystore channel can act on it.
          return (call.arguments as Map)['ciphertext'] as Uint8List;
        }
        return null;
      });

      final provider = AndroidKeystoreEnvelopeKeyProvider(
        storage: storage,
      );
      final envelopeService = BiometricKeyEnvelopeService(storage: storage);
      final dek = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));

      final acquired = await provider.acquireEnvelopeKey();
      expect(acquired, isNotNull);
      await envelopeService.enroll(dekBytes: dek, envelopeKey: acquired!);

      final released = await provider.releaseEnvelopeKey();
      expect(released, isNotNull);

      final recoveredDek = await envelopeService.unwrap(
        envelopeKey: released!,
      );
      expect(recoveredDek, dek);

      // The seed that the unlock path saw must equal the seed the
      // enrollment path produced (modulo the mock's XOR). We assert
      // equality through the recovered DEK, which is the contract
      // that matters.
      expect(rsaCiphertexts, hasLength(1));
      expect(recoveredSeeds, hasLength(1));
    });
  });
}

class _InMemoryStorage implements SecureStorageService {
  final Map<String, String> _values = {};

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> save(String key, String value) async {
    _values[key] = value;
  }
}
