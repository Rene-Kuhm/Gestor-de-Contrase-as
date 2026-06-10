import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_contrasenas/core/update/update_service.dart';

void main() {
  group('UpdateService release notes parsing', () {
    test('reads the legacy Vaulta version label', () {
      expect(
        remoteVersionFromChangelogForTest(
          'Vaulta version: 1.0.14+15\nArchivo de instalacion: vaulta.apk',
        ),
        '1.0.14+15',
      );
    });

    test('reads the generic Version label used by recent releases', () {
      expect(
        remoteVersionFromChangelogForTest(
          'Version: 1.0.13+14\nArchivo de instalacion: vaulta.apk',
        ),
        '1.0.13+14',
      );
    });
  });

  group('UpdateService version comparison', () {
    test('does not treat the same installed build as newer', () {
      expect(isRemoteVersionNewerForTest('1.0.14+15', '1.0.14+15'), isFalse);
    });

    test('treats a larger build number as newer', () {
      expect(isRemoteVersionNewerForTest('1.0.14+16', '1.0.14+15'), isTrue);
    });
  });
}
