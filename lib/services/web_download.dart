import 'dart:typed_data';

import 'web_download_stub.dart'
    if (dart.library.js_interop) 'web_download_web.dart' as platform;

void triggerWebDownload(Uint8List bytes, String filename) {
  platform.downloadFileWeb(bytes, filename);
}
