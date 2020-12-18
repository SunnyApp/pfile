import 'dart:typed_data';

import 'package:buffer/buffer.dart';
import 'package:chunked_stream/chunked_stream.dart';
import 'package:uuid/uuid.dart';

extension PFileStreamExt<T> on Stream<T> {
  Stream<List<T>> chunked(int chunkSize) => asChunkedStream(chunkSize, this);
}

extension PFileIterExt<T> on Iterable<T> {
  Stream<List<T>> chunkedStream(int chunkSize) {
    return asChunkedStream(chunkSize, Stream.fromIterable(this ?? <T>[]));
  }
}

extension PFileChunkedStreamReaderExt on Stream<List<int>> {
  Future<Uint8List> readFully() async {
    var buffer = BytesBuffer();
    await for (var b in this) {
      buffer.add(b);
    }
    return buffer.toBytes();
  }
}

final _uuid = Uuid();
String puid() {
  return _uuid.v4();
}

final upToLastDot = RegExp('.*\\.');

extension PFileStringExt on String {
  String get extension {
    if (this == null) return null;
    return "$this".replaceAll(upToLastDot, '');
  }
}

T illegalState<T>(String message) {
  throw (message ?? "IllegalState");
}
