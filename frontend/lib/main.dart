import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/prompt_learn_app.dart';
import 'data/repositories/local_role_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final roleRepository = LocalRoleRepository(SharedPreferencesAsync());
  runApp(PromptLearnApp(roleRepository: roleRepository));
}
