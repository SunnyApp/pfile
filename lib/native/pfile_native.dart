import 'dart:io' as io;
import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

import '../pfile.dart';
import '../web/safe_completer.dart';

Directory? _tmpDir;
final _log = Logger("pfileNative");

Future<List<FileOf>> loaders() async {
  try {
    _tmpDir = await getTemporaryDirectory();
  } catch (e) {
    _log.info("Not using tmpFile for PFile loaders: $e");
  }
  return [loadFromFile, if (_tmpDir != null) loadIntoTempFile];
}

class NativePFile extends PFile {
  final io.File file;

  NativePFile(this.file);

  @override
  Uint8List get bytes => file.readAsBytesSync();

  @override
  String get name => file.fileName;

  @override
  Stream<List<int>> openStream([int? start, int? end]) {
    return file.openRead(start, end);
  }

  @override
  String get path => file.absolute.path;

  @override
  Future<PFile> get read async => this;

  @override
  int get size => file.lengthSync();

  io.File get wrapped => file;
}

/// For memory efficiency, we write to a temp file as soon as we can.
PFile? loadIntoTempFile(dynamic file, {String? name, int? size}) {
  assert(_tmpDir != null);
  name ??= puid();

  var tmpFile = name.contains("/") ? File(name) : _tmpDir!.file(name);
  var ready = SafeCompleter();
  if (!tmpFile.existsSync()) {
    if (file == null) return null;
    if (file is Uint8List || file is List<int>) {
      var uints =
          file is Uint8List ? file : Uint8List.fromList(file as List<int>);

      /// Only write if it doesn't exists.
      final buffer = uints.buffer;
      tmpFile.writeAsBytesSync(
          buffer.asUint8List(uints.offsetInBytes, uints.lengthInBytes),
          flush: true);
      ready.complete();
    } else if (file is Stream) {
      assert(
          size != null, "If you provide a stream, you must provide a length");
      assert(file is Stream<List<int>> || file is Stream<int>);
      var _fileStream = file is Stream<List<int>>
          ? file
          : (file as Stream<int>).chunked(PFile.defaultChunkSize);

      _fileStream.toList().then((bytes) {
        tmpFile.writeAsBytesSync(bytes.expand((_) => _).toList(), flush: true);
        ready.complete();
      });
    } else {
      return null;
    }
  } else {
    ready.complete();
  }
  return NativePFile(tmpFile);
}

PFile? loadFromFile(dynamic file, {String? name, int? size}) {
  if (file is File) {
    return NativePFile(file);
  }
  return null;
}

extension DirectoryExt on Directory {
  bool hasChild(String name) {
    return file(name).existsSync();
  }

  File file(String name) {
    return File(this + name);
  }

  Directory dir(String name) {
    return Directory(this + name);
  }

  String operator +(String name) {
    return "${this.path}/$name";
  }
}

extension FileExt on File {}

extension FileSystemEntityExt on FileSystemEntity {
  File variant(String variant) {
    return parent.file("$baseName$variant.$extension");
  }

  String get pathFromAssets => path.replaceAll(RegExp(".*\/assets\/"), "");

  File renamed(String name) {
    return parent.file(name);
  }

  String get extension {
    return nameParts[1];
  }

  List<String> get nameParts {
    final fileName = this.fileName;
    final ll = fileName.lastIndexOf("\.");
    if (ll == -1) {
      return [fileName, ''];
    } else {
      final baseName = fileName.substring(0, ll);
      final extension = fileName.substring(ll + 1, fileName.length);
      return [baseName, extension];
    }
  }

  String get baseName => nameParts[0];

  String get baseNameNoVariant {
    final fileName = this.fileName.replaceAll(RegExp("\@.x"), "");
    print("No variant: $fileName");
    if (!fileName.contains("\.")) {
      return "";
    }

    return fileName.split("\.").first;
  }

  String get fileName => path.split("/").last;
}
