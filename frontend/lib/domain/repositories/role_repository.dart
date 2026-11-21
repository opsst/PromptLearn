import '../models/user_role.dart';

abstract interface class RoleRepository {
  Future<UserRole?> load();
  Future<void> save(UserRole role);
  Future<void> clear();
}
