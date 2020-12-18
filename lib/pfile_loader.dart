import 'package:logging/logging.dart';
import 'package:pfile/pfile_api.dart';

import 'pfile_platform.dart'
    if (dart.library.io) 'native/pfile_native.dart'
    if (dart.library.js) 'web/pfile_web.dart';

final _log = Logger("pfile");

/// Knows how to recognize different types of data representations into a PFile
/// using a series of strategies
class PFileLoader {
  static final log = Logger("pfileLoader");
  final List<FileOf> _strategies;
  var initialized = false;

  Future initialize() async {
    if (initialized) {
      return;
    }
    initialized = true;
    var l = await loaders();
    if (l?.isNotEmpty == true) {
      l.forEach((loader) => this + loader);
    }
  }

  PFileLoader operator +(FileOf strategy) {
    if (!_strategies.contains(strategy)) {
      _strategies.add(strategy);
    }
    return this;
  }

  PFile fileOf(dynamic file, {String name, int size}) {
    assert(initialized,
        "Must be initialized first by calling PFile.initialize() somewhere in your init code");

    if (file == null) return null;
    for (var strategy in _strategies) {
      var res = strategy(file, name: name, size: size);
      if (res != null) {
        return res;
      }
    }
    throw "No strategy could extract file of type ${file.runtimeType}";
  }

  PFileLoader.defaults() : _strategies = [];
}
