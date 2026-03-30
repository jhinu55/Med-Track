import 'package:flutter/foundation.dart';
import 'token_storage.dart';

/// Holds the current user session and notifies listeners on changes.
class AuthProvider extends ChangeNotifier {
  final TokenStorage _storage = TokenStorage();

  String? _token;
  String? _role;
  int? _actorId;
  int? _roleSpecificId;
  String? _username;

  bool get isLoggedIn => _token != null;
  String? get token => _token;
  String? get role => _role;
  int? get actorId => _actorId;
  int? get roleSpecificId => _roleSpecificId;
  String? get username => _username;

  Future<void> load() async {
    _token = await _storage.getToken();
    _role = await _storage.getRole();
    _actorId = await _storage.getActorId();
    _roleSpecificId = await _storage.getRoleSpecificId();
    _username = await _storage.getUsername();
    notifyListeners();
  }

  Future<void> login({
    required String token,
    required String role,
    required int actorId,
    required int roleSpecificId,
    required String username,
  }) async {
    await _storage.saveSession(
      token: token,
      role: role,
      actorId: actorId,
      roleSpecificId: roleSpecificId,
      username: username,
    );
    _token = token;
    _role = role;
    _actorId = actorId;
    _roleSpecificId = roleSpecificId;
    _username = username;
    notifyListeners();
  }

  Future<void> logout() async {
    await _storage.clear();
    _token = null;
    _role = null;
    _actorId = null;
    _roleSpecificId = null;
    _username = null;
    notifyListeners();
  }
}
