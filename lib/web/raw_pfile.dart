import 'dart:typed_data';

import 'package:buffer/buffer.dart';
import 'package:logging/logging.dart';

import '../pfile_api.dart';
import '../pfile_ext.dart';
import 'safe_completer.dart';

/// Web cannot write files, so this acts as an in-memory representation
class RawPFile extends PFile {
  static int defaultChunkSize = 1024 * 1024;
  static final log = Logger("rawPFile");
  final SafeCompleter<PFile> _read;

  /// This constructor is more low-level because we can't pull in any file dependencies
  /// into this code
  RawPFile.ofFile(
    this.path,
    this._readStreamFactory,
    this._size, {
    SafeCompleter completer,
  })  : assert(_size != null),
        assert(path != null),
        _read = SafeCompleter.stopped(),
        name = path.split("/").last {
    if (completer != null) {
      _read.start();
      completer.future.whenComplete(() {
        _read.complete(this);
      });
    }
  }

  RawPFile.ofBytes(String name, Uint8List bytes)
      : assert(bytes != null),
        _isRead = true,
        path = null,
        _bytes = bytes,
        name = name ?? puid(),
        _read = SafeCompleter.stopped(),
        _readStreamFactory =
            ((_) => Stream.fromIterable((_ as RawPFile)._bytes).chunked(1024)),
        _size = bytes.length;

  RawPFile.ofStream(String name, this._readStreamFactory, this._size)
      : name = name ?? puid(),
        path = null,
        _isRead = false,
        _read = _size == null ? SafeCompleter() : SafeCompleter.stopped();

  factory RawPFile.ofSingleStream(String name, Stream<List<int>> data,
      {int size}) {
    /// The read stream getter will read the stream the first time,
    /// copy it into memory and serve it from there the next time.
    Stream<List<int>> getReadStream(PFile file) async* {
      final pfile = file as RawPFile;
      pfile._read.start();
      if (!pfile._isRead) {
        log.warning("Full read of $name.  SLOW!!");
        var start = DateTime.now();
        var buffer = BytesBuffer();
        await for (var b in data) {
          buffer.add(b);
          yield b;
        }
        log.warning(
            "Full read of $name in ${DateTime.now().difference(start)}");
        pfile.markRead(buffer.toBytes());
        return;
      } else {
        yield* pfile._bytes.chunkedStream(PFile.defaultChunkSize);
      }
    }

    return RawPFile.ofStream(name, getReadStream, size);
  }

  @override
  dynamic get file {}

  /// The absolute path for a cached copy of this file. It can be used to create a
  /// file instance with a descriptor for the given path.
  /// ```
  /// final File myFile = File(platformFile.path);
  /// ```
  @override
  final String path;

  /// File name including its extension.
  @override
  final String name;

  /// Byte data for this file. Particurlarly useful if you want to manipulate its data
  /// or easily upload to somewhere else.
  Uint8List _bytes;

  bool _isRead;

  bool get hasBeenRead {
    return _isRead == true && _bytes != null;
  }

  /// File content as stream
  final PFileToByteStream _readStreamFactory;

  /// The file size in KB.
  int _size;

  int get size =>
      _size ?? illegalState("No file size yet - wait until read is complete");

  Future<PFile> get read async {
    if (_read.isStarted) {
      return await _read.future;
    } else {
      return this;
    }
  }

  /// File extension for this file.
  String get extension => name?.split('.')?.last;

  Uint8List get bytes {
    return _bytes ?? illegalState("No bytes available");
  }

  void markRead(Uint8List data) {
    _isRead = true;
    _bytes = data;
    _read.complete(this);
  }

  @override
  Stream<List<int>> openStream([int start, int end]) {
    return _readStreamFactory(this).skip(start);
  }
}

extension RawPFileWriteExt on RawPFile {
  // Future<File> toFile() async {
  //   final imageData = await this.data;
  //   final tmpDir = await getTemporaryDirectory();
  //   final tmpFile = File("${tmpDir.path}/${uuid()}");
  //
  //   tmpFile.writeAsBytesSync(imageData, flush: true);
  //   return tmpFile;
  // }

  Future<Uint8List> get awaitData async {
    if (_isRead) {
      return _bytes;
    } else {
      return _readStreamFactory(this).readFully();
    }
  }

  String get extension {
    String np = this.name ?? path;
    return np?.extension;
  }

  Stream<List<int>> get dataStream {
    return _readStreamFactory(this);
  }
}
