import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/assessment_draft.dart';
import '../../../core/theme/app_theme.dart';

const _green = Color(0xFF1E6C50);

class AssessmentSettingsPanel extends StatelessWidget {
  const AssessmentSettingsPanel({
    super.key,
    required this.draft,
    required this.totals,
    required this.onChanged,
  });

  final AssessmentDraft draft;
  final String totals;
  final ValueChanged<AssessmentDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    final homework = draft.kind == AssessmentKind.homework;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Text('Settings', style: typography.titleLarge?.copyWith(fontSize: 20)),
        Text(
          'Assessment type',
          style: typography.labelLarge?.copyWith(color: AppColors.mutedText),
        ),
        SegmentedButton<AssessmentKind>(
          segments: const [
            ButtonSegment(value: AssessmentKind.quiz, label: Text('Quiz')),
            ButtonSegment(
              value: AssessmentKind.homework,
              label: Text('Homework'),
            ),
          ],
          selected: {draft.kind},
          onSelectionChanged: (selection) =>
              onChanged(draft.copyWith(kind: selection.single)),
        ),
        _SettingRow(
          icon: Icons.groups_outlined,
          label: 'Classes',
          value: Text(
            'M.1/1 · M.1/2 · M.1/3',
            textAlign: TextAlign.end,
            style: typography.labelSmall,
          ),
        ),
        _SettingRow(
          icon: Icons.calendar_today_outlined,
          label: 'When',
          value: Text(
            'Not scheduled',
            textAlign: TextAlign.end,
            style: typography.labelSmall,
          ),
        ),
        _SettingRow(
          icon: Icons.schedule,
          label: 'Time limit',
          value: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: draft.timeLimitMinutes,
                isDense: true,
                items: [
                  for (final minutes in {
                    0,
                    15,
                    30,
                    45,
                    60,
                    draft.timeLimitMinutes,
                  })
                    DropdownMenuItem(
                      value: minutes,
                      child: Text(minutes == 0 ? 'No limit' : '$minutes min'),
                    ),
                ],
                onChanged: (minutes) {
                  if (minutes != null) {
                    onChanged(draft.copyWith(timeLimitMinutes: minutes));
                  }
                },
                style: typography.labelSmall,
              ),
            ),
          ),
        ),
        _SettingRow(
          icon: Icons.star_border,
          label: 'Points',
          value: Text(
            totals,
            textAlign: TextAlign.end,
            style: typography.labelSmall,
          ),
        ),
        const Divider(color: Color(0xFFE2E9E5), height: 1),
        _AssessmentSwitch(
          title: 'Require shown work',
          description: 'Ask students to show their solution steps.',
          value: draft.requireShownWork,
          onChanged: (enabled) =>
              onChanged(draft.copyWith(requireShownWork: enabled)),
        ),
        _AssessmentSwitch(
          title: 'Accept photos of paper work',
          description: 'Accept a photo of handwritten work.',
          value: draft.acceptPhotos,
          onChanged: (enabled) =>
              onChanged(draft.copyWith(acceptPhotos: enabled)),
        ),
        _AssessmentSwitch(
          title: 'AI Tutor hints',
          description: 'Available for homework.',
          value: homework && draft.homeworkHints,
          onChanged: homework
              ? (enabled) => onChanged(draft.copyWith(homeworkHints: enabled))
              : null,
        ),
        _AssessmentSwitch(
          title: 'Shuffle question order',
          value: draft.shuffleQuestions,
          onChanged: (enabled) =>
              onChanged(draft.copyWith(shuffleQuestions: enabled)),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 8,
    children: [
      Icon(icon, size: 19, color: AppColors.mutedText),
      Flexible(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.mutedText),
        ),
      ),
      Expanded(child: value),
    ],
  );
}

class _AssessmentSwitch extends StatelessWidget {
  const _AssessmentSwitch({
    required this.title,
    this.description,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? description;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    return SwitchListTile(
      title: Text(title, style: typography.titleMedium),
      subtitle: description == null
          ? null
          : Text(
              description!,
              style: typography.bodySmall?.copyWith(color: AppColors.mutedText),
            ),
      contentPadding: EdgeInsets.zero,
      activeTrackColor: _green,
      value: value,
      onChanged: onChanged,
    );
  }
}
