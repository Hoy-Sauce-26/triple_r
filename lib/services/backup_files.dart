import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Moving a backup file in and out of the app.
///
/// An interface because both sides are platform channels — a share sheet and
/// a document picker — neither of which exists in a test VM.
abstract class BackupFiles {
  /// Writes [contents] to a temporary file and hands it to the OS share
  /// sheet. Returns false if the user dismissed without choosing anything.
  Future<bool> share(String fileName, String contents);

  /// Opens a document picker. Returns the file's contents, or null if the
  /// user backed out.
  Future<String?> pickAndRead();
}

class PlatformBackupFiles implements BackupFiles {
  const PlatformBackupFiles();

  @override
  Future<bool> share(String fileName, String contents) async {
    // Written to the temp directory rather than anywhere permanent: once the
    // share sheet has handed it off, the copy the user chose is the real one
    // and ours is litter.
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(contents);

    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        fileNameOverrides: [fileName],
      ),
    );
    return result.status == ShareResultStatus.success;
  }

  @override
  Future<String?> pickAndRead() async {
    final picked = await FilePicker.pickFile(dialogTitle: 'Choose a backup');
    if (picked == null) return null;

    // readAsBytes rather than opening the path: on Android a picked document
    // is a content:// URI that dart:io File() cannot open at all.
    return utf8.decode(await picked.readAsBytes());
  }
}

/// Captures what would have been shared, and returns a canned file to import.
@visibleForTesting
class FakeBackupFiles implements BackupFiles {
  String? sharedFileName;
  String? sharedContents;

  /// What [pickAndRead] returns. Null simulates the user cancelling.
  String? fileToPick;

  @override
  Future<bool> share(String fileName, String contents) async {
    sharedFileName = fileName;
    sharedContents = contents;
    return true;
  }

  @override
  Future<String?> pickAndRead() async => fileToPick;
}
