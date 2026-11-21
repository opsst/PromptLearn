import 'package:material_ui/material_ui.dart';

import '../../../domain/models/user_role.dart';
import '../../core/theme/app_theme.dart';

class ReplayView extends StatelessWidget {
  const ReplayView({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.header,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Courses', style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}
