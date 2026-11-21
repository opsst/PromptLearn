import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/notifications_button.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.displayName, required this.now});

  final String displayName;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final greeting = switch (now.hour) {
      < 12 => 'Good Morning!',
      < 18 => 'Good Afternoon!',
      _ => 'Good Evening!',
    };
    final date = DateFormat(
      'EEEE d MMMM yyyy',
      'en_US',
    ).format(now).toUpperCase();

    return ColoredBox(
      color: AppColors.header,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          return ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 100),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: wide ? 42 : 16,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SvgPicture.asset(
                              'assets/navigation/clock.svg',
                              width: 15,
                              height: 15,
                              excludeFromSemantics: true,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                date,
                                style: textTheme.labelSmall?.copyWith(
                                  color: AppColors.mutedText,
                                  height: 17 / 13,
                                  letterSpacing: 0.78,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$greeting $displayName',
                          style: textTheme.titleLarge?.copyWith(
                            color: AppColors.ink,
                            height: 1.16,
                            letterSpacing: -0.165,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  const NotificationsButton(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
