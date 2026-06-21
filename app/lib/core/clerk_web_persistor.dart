import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:shared_preferences/shared_preferences.dart';

/// A web-safe [clerk.Persistor] backed by [SharedPreferences] (localStorage on
/// web). Clerk's default persistor caches to disk via path_provider, which has
/// no web implementation and throws MissingPluginException during init —
/// leaving auth stuck on the loading spinner. This keeps Clerk sessions alive
/// across page reloads on web.
///
/// Clerk persists small string values (tokens, client/session json). Non-string
/// values are stored via their toString(); reads return the stored String.
class ClerkWebPersistor implements clerk.Persistor {
  ClerkWebPersistor._(this._prefs);

  static const _prefix = 'clerk.';
  final SharedPreferences _prefs;

  /// Build and initialise a persistor instance.
  static Future<ClerkWebPersistor> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ClerkWebPersistor._(prefs);
  }

  @override
  Future<void> initialize() async {}

  @override
  void terminate() {}

  @override
  T? read<T>(String key) => _prefs.getString('$_prefix$key') as T?;

  @override
  Future<void> write<T>(String key, T value) =>
      _prefs.setString('$_prefix$key', value.toString());

  @override
  Future<void> delete(String key) => _prefs.remove('$_prefix$key');
}
