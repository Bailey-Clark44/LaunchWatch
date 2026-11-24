/// Installing LaunchWatch from the browser. On phones and desktop builds there
/// is nothing to install, so [InstallSupport.mode] is [InstallMode.none].
library;

export 'install_stub.dart' if (dart.library.js_interop) 'install_web.dart';
