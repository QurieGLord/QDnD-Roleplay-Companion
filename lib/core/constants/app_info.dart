/// The app's name and version as the launch and settings show them.
///
/// Release builds may pass `--dart-define=QDND_VERSION=x.y.z`; the Cycle
/// build is labelled by `QDND_VETERAN_CYCLE`.
abstract final class AppInfo {
  static const String name = 'Roleplay Companion';
  static const String version =
      String.fromEnvironment('QDND_VERSION', defaultValue: '0.13.0');
  static const bool cycle = bool.fromEnvironment('QDND_VETERAN_CYCLE');

  /// The release channel next to the version.
  static const String channel = cycle ? 'Cycle' : 'Beta';

  /// Major and minor only: «0.13».
  static String get short => version.split('.').take(2).join('.');

  /// «0.13 · Beta».
  static String get line => '$short · $channel';
}
