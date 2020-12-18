import 'dart:html';
import 'dart:typed_data';
import 'dart:html' as web;
import 'package:logging/logging.dart';

import '../pfile_api.dart';
import '../pfile_ext.dart';
import 'raw_pfile.dart';
export 'raw_pfile.dart';

Future<List<FileOf>> loaders() async {
  return [webFileOf, webFileOfBytes];
}

class WebPFile extends PFile {
  static final log = Logger("webPFile");
  static int chunkSize = 1000 * 5000; // 5 MB

  @override
  final web.File file;

  WebPFile(this.file);

  @override
  Uint8List get bytes => null;

  @override
  String get name => file.name;

  @override
  Stream<List<int>> openStream([int start, int end]) async* {
    final reader = FileReader();

    int start = 0;
    var startTime = DateTime.now();
    while (start < file.size) {
      final end = start + chunkSize > file.size ? file.size : start + chunkSize;
      final blob = file.slice(start, end);
      reader.readAsArrayBuffer(blob);
      await reader.onLoad.first;
      yield reader.result;
      start += chunkSize;
    }
    var duration = DateTime.now().difference(startTime);
    log.fine(
        "Took $duration to load ${file.name} (${file.size ~/ (1024 * 1024)}kb)");
  }

  @override
  String get path => file.relativePath;

  @override
  Future<PFile> get read async => this;

  @override
  int get size => file.size;
}

/// Since web doesn't have access to write files, we need to just keep things in
/// memory...
PFile webFileOfBytes(dynamic file, {String name, int size}) {
  name ??= puid();
  if (file is Uint8List) {
    return RawPFile.ofBytes(name, file);
  } else if (file is List<int>) {
    return RawPFile.ofBytes(name, Uint8List.fromList(file));
  } else if (file is Stream) {
    assert(size != null, "If you provide a stream, you must provide a length");
    Stream<List<int>> _fileStream;

    if (file is Stream<List<int>>) {
      _fileStream = file;
    } else if (file is Stream<int>) {
      _fileStream = file.chunked(PFile.defaultChunkSize);
    } else {
      assert(false, "Only support streams of List<int> or int");
    }

    return RawPFile.ofSingleStream(name, _fileStream, size: size);
  } else {
    return null;
  }
}

/// Since web doesn't have access to write files, we need to just keep things in
/// memory...
PFile webFileOf(dynamic file, {String name, int size}) {
  name ??= puid();
  if (file is web.File) {
    return WebPFile(file);
  } else {
    return null;
  }
}
