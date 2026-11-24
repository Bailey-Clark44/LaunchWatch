import 'install_mode.dart';

export 'install_mode.dart';

class InstallSupport {
  static InstallMode get mode => InstallMode.none;
  static Stream<void> get changes => const Stream.empty();

  /// Returns 'accepted', 'dismissed' or 'unavailable'.
  static Future<String> ask() async => 'unavailable';
}
