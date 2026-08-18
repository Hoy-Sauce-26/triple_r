import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the promise the whole app is built on: Triple R makes no network
/// calls, ever.
///
/// A source scan rather than a runtime check on purpose. "Works in airplane
/// mode" is easy to verify once by hand and impossible to keep verified — the
/// regression arrives as a plugin someone adds in a hurry, and it fails on a
/// user's phone on a train, not on a developer's desk with wifi. This fails in
/// CI the moment the capability is introduced, which is the only time the fix
/// is cheap.
void main() {
  /// Packages that can reach the network. `share_plus` and `file_picker` are
  /// absent deliberately: they hand data to the OS, which may then involve
  /// other apps, but the user drives that and this app opens no socket.
  const networkPackages = [
    'package:http/',
    'package:dio/',
    'package:web_socket_channel/',
    'package:grpc/',
    'package:firebase_',
    'package:cloud_firestore/',
    'package:googleapis',
    'package:supabase',
    'package:graphql',
  ];

  /// dart:io networking types. `dart:io` itself is fine — File and Directory
  /// live there too.
  const networkApis = [
    'HttpClient',
    'ServerSocket',
    'RawDatagramSocket',
    'InternetAddress',
    'WebSocket',
  ];

  late List<({String path, String source})> sources;

  setUpAll(() {
    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue, reason: 'run this from the package root');

    sources = [
      for (final entity in lib.listSync(recursive: true))
        if (entity is File &&
            entity.path.endsWith('.dart') &&
            // Generated; drift emits no networking, and it is not ours to fix.
            !entity.path.endsWith('.g.dart'))
          (path: entity.path, source: entity.readAsStringSync()),
    ];
  });

  test('there is source to scan', () {
    // Guards against the scan silently passing because it found nothing.
    expect(sources.length, greaterThan(15));
  });

  test('no networking package is imported', () {
    final offenders = <String>[];
    for (final file in sources) {
      for (final package in networkPackages) {
        if (file.source.contains(package)) {
          offenders.add('${file.path} imports $package');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('no dart:io networking type is used', () {
    final offenders = <String>[];
    for (final file in sources) {
      for (final api in networkApis) {
        // Word boundary, so `WebSocket` does not match inside an identifier
        // that merely contains it.
        if (RegExp('\\b$api\\b').hasMatch(file.source)) {
          offenders.add('${file.path} uses $api');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('no http or https URL is fetched at runtime', () {
    // The exercise trees carry wiki URLs as reference data. They are allowed
    // to exist; what is not allowed is anything that would *load* one.
    final offenders = <String>[];
    for (final file in sources) {
      if (file.path.endsWith('paths.dart')) continue;
      if (RegExp(r'Uri\.parse\(').hasMatch(file.source)) {
        offenders.add('${file.path} parses a URI');
      }
    }
    expect(offenders, isEmpty);
  });

  test('the Android manifest requests no INTERNET permission', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml');
    expect(manifest.existsSync(), isTrue);
    final xml = manifest.readAsStringSync();

    // Flutter's debug manifest adds INTERNET for hot reload, which is why
    // this checks the main one — the shipped app must not ask for it.
    expect(
      xml.contains('android.permission.INTERNET'),
      isFalse,
      reason: 'the release app must not request network access',
    );
  });
}
