// ignore_for_file: deprecated_member_use_from_same_package
import 'dart:typed_data';

import 'package:pfile/pfile_loader.dart';

import 'pfile_ext.dart';

typedef FileOf = PFile? Function(dynamic type, {String? name, int? size});

typedef PFileToByteStream = Stream<List<int>> Function(PFile file);

/// A cross-platform representation of a file, provides some ability to read/cache
/// the data internally in a mutable way, so it can be passed around while it's
/// loading
abstract class PFile {
  static int defaultChunkSize = 1024 * 1024;
  static PFileLoader loaders = PFileLoader.defaults();

  static Future initialize() => loaders.initialize();

  const PFile();

  static PFile? of(dynamic raw, {String? name, int? size}) {
    if (raw is PFile) return raw;
    PFile.initialize();
    return loaders.fileOf(raw, name: name, size: size);
  }

  // /// This constructor is more low-level because we can't pull in any file dependencies
  // /// into this code
  // factory PFile.ofFile(
  //   String path,
  //   PFileToByteStream _readStreamFactory,
  //   int _size, {
  //   SafeCompleter completer,
  // }) = RawPFile.ofFile;
  //
  // factory PFile.ofBytes(String name, Uint8List bytes) = RawPFile.ofBytes;
  //
  // factory PFile.ofStream(
  //         String name, PFileToByteStream _readStreamFactory, int _size) =
  //     RawPFile.ofStream;
  //
  // factory PFile.ofSingleStream(String name, Stream<List<int>> data,
  //     {int size}) = RawPFile.ofSingleStream;

  dynamic get file;

  /// The absolute path for a cached copy of this file. It can be used to create a
  /// file instance with a descriptor for the given path.
  /// ```
  /// final File myFile = File(platformFile.path);
  /// ```
  String? get path;

  /// File name including its extension.
  String? get name;

  // /// File content as stream
  // final PFileToByteStream _readStreamFactory;

  Stream<List<int>> openStream([int start, int end]);

  int get size;

  Future<PFile> get read;

  /// File extension for this file.
  String? get extension => name?.split('.').lastWhere((element) => true);

  /// Try not to use this
  @deprecated
  Uint8List? get bytes;
}

extension PlatformFileWriteExt on PFile {
  // Future<File> toFile() async {
  //   final imageData = await this.data;
  //   final tmpDir = await getTemporaryDirectory();
  //   final tmpFile = File("${tmpDir.path}/${uuid()}");
  //
  //   tmpFile.writeAsBytesSync(imageData, flush: true);
  //   return tmpFile;
  // }

  Future<Uint8List> get awaitData async {
    if (bytes != null) {
      return bytes!;
    } else {
      return openStream().readFully();
    }
  }

  String? get extension {
    var np = this.name ?? path;
    return np?.extension;
  }
}
