import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages JWT token storage and retrieval.
class TokenStorage {
  static const _tokenKey = 'jwt_token';
  static const _roleKey = 'user_role';
  static const _actorIdKey = 'actor_id';
  static const _roleIdKey = 'role_specific_id';
  static const _usernameKey = 'username';

  static const _storage = FlutterSecureStorage();

  Future<void> saveSession({
    required String token,
    required String role,
    required int actorId,
    required int roleSpecificId,
    required String username,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _roleKey, value: role);
    await _storage.write(key: _actorIdKey, value: actorId.toString());
    await _storage.write(key: _roleIdKey, value: roleSpecificId.toString());
    await _storage.write(key: _usernameKey, value: username);
  }

  Future<String?> getToken() => _storage.read(key: _tokenKey);
  Future<String?> getRole() => _storage.read(key: _roleKey);
  Future<int?> getActorId() async {
    final v = await _storage.read(key: _actorIdKey);
    return v != null ? int.tryParse(v) : null;
  }

  Future<int?> getRoleSpecificId() async {
    final v = await _storage.read(key: _roleIdKey);
    return v != null ? int.tryParse(v) : null;
  }

  Future<String?> getUsername() => _storage.read(key: _usernameKey);

  Future<void> clear() => _storage.deleteAll();
}
