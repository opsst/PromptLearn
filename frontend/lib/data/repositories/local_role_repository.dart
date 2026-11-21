import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/user_role.dart';
import '../../domain/repositories/role_repository.dart';

class LocalRoleRepository implements RoleRepository {
  LocalRoleRepository(this._preferences);

  static const _roleKey = 'promptlearn.login_role';
  final SharedPreferencesAsync _preferences;

  @override
  Future<UserRole?> load() async {
    final name = await _preferences.getString(_roleKey);
    return UserRole.values.asNameMap()[name];
  }

  @override
  Future<void> save(UserRole role) {
    return _preferences.setString(_roleKey, role.name);
  }

  @override
  Future<void> clear() {
    return _preferences.remove(_roleKey);
  }
}
