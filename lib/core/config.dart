abstract final class AppConfig {
  static const environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
  static const webPreview = bool.fromEnvironment(
    'WEB_PREVIEW',
    defaultValue: false,
  );
  static const demo = bool.fromEnvironment('DEMO_MODE', defaultValue: false);
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static bool get configured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  // There is deliberately no live payment adapter, key, or remotely enabled flag.
  static const realMoneyEnabled = false;
  static void validate() {
    if (webPreview && !demo) {
      throw StateError('Browser preview requires fixture mode.');
    }
    if (environment == 'production' && demo) {
      throw StateError('Production cannot run with fixture identities.');
    }
  }
}
