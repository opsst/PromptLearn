import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/user_role.dart';
import '../../../core/theme/app_theme.dart';

class RoleSelectionView extends StatelessWidget {
  const RoleSelectionView({
    super.key,
    required this.onSelect,
    required this.isSaving,
  });

  final ValueChanged<UserRole> onSelect;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                margin: EdgeInsets.zero,
                color: AppColors.canvas,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Image.asset(
                            'assets/navigation/mark.png',
                            width: 48,
                            height: 48,
                            excludeFromSemantics: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'PromptLearn',
                        textAlign: TextAlign.center,
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(height: 24),
                      for (final role in UserRole.values)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 48),
                            ),
                            onPressed: isSaving ? null : () => onSelect(role),
                            icon: Icon(switch (role) {
                              UserRole.teacher => Icons.school_outlined,
                              UserRole.student => Icons.person_outline,
                            }),
                            label: Text('Login as ${role.label}'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
