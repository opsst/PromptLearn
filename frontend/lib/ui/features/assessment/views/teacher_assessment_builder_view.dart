import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/assessment_draft.dart';
import '../../../core/layout/app_page_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../view_models/assessment_draft_controller.dart';
import '../widgets/assessment_question_editor.dart';
import '../widgets/assessment_settings_panel.dart';
import '../widgets/assessment_student_preview.dart';

const _ink = Color(0xFF202438);
const _green = Color(0xFF1E6C50);
const _tint = Color(0xFFE3F1E9);
const _line = Color(0xFFE2E9E5);

enum _QuestionAction { edit, duplicate, moveUp, moveDown, remove }

class TeacherAssessmentBuilderView extends StatefulWidget {
  const TeacherAssessmentBuilderView({
    super.key,
    required this.controller,
    required this.onBack,
  });

  final AssessmentDraftController controller;
  final VoidCallback onBack;

  @override
  State<TeacherAssessmentBuilderView> createState() =>
      _TeacherAssessmentBuilderViewState();
}

class _TeacherAssessmentBuilderViewState
    extends State<TeacherAssessmentBuilderView> {
  AssessmentDraft get _draft => widget.controller.draft;

  Future<void> _editQuestion([int? index]) async {
    final edited = await showAssessmentQuestionEditor(
      context,
      initial: index == null ? null : _draft.questions[index],
    );
    if (edited == null || !mounted) return;
    final questions = [..._draft.questions];
    if (index == null) {
      questions.add(edited);
    } else {
      questions[index] = edited;
    }
    widget.controller.update(_draft.copyWith(questions: questions));
  }

  Future<void> _questionAction(int index, _QuestionAction action) async {
    final questions = [..._draft.questions];
    switch (action) {
      case _QuestionAction.edit:
        return _editQuestion(index);
      case _QuestionAction.duplicate:
        questions.insert(index + 1, questions[index]);
      case _QuestionAction.moveUp:
        questions.insert(index - 1, questions.removeAt(index));
      case _QuestionAction.moveDown:
        questions.insert(index + 1, questions.removeAt(index));
      case _QuestionAction.remove:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Delete question ${index + 1}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete question'),
              ),
            ],
          ),
        );
        if (!mounted || confirmed != true) return;
        questions.removeAt(index);
    }
    widget.controller.update(_draft.copyWith(questions: questions));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(
          bodyColor: _ink,
          displayColor: _ink,
          letterSpacingFactor: 0,
        ),
      ),
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final inset = constraints.maxWidth >= 900 ? 42.0 : 16.0;
            final width = constraints.maxWidth - 2 * inset;
            final wide = width >= 830;
            return AppPageLayout(
              header: _header(context, inset: inset, wide: wide),
              body: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-0.8, -0.65),
                    radius: 0.54,
                    colors: [Color(0xFFCCEFDA), AppColors.canvas],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(inset, 24, inset, 32),
                  child: _body(context, wide: wide),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context, {
    required double inset,
    required bool wide,
  }) {
    final typography = Theme.of(context).textTheme;
    final kind = _draft.kind == AssessmentKind.quiz ? 'Quiz U3' : 'Homework';
    final state = widget.controller.state;
    final saveStatus = switch (state) {
      DraftSaveState.loading => 'Loading draft…',
      DraftSaveState.newDraft => 'Draft',
      DraftSaveState.saving => 'Saving draft…',
      DraftSaveState.saved => 'Draft · auto-saved',
      DraftSaveState.loadFailed => 'Draft unavailable',
      DraftSaveState.saveFailed => 'Draft not saved',
    };
    final title = Row(
      spacing: 8,
      children: [
        IconButton(
          tooltip: 'Back to Teacher Home',
          onPressed: widget.onBack,
          icon: const Icon(Icons.chevron_left, color: _ink),
        ),
        Expanded(
          child: Wrap(
            spacing: 12,
            runSpacing: 5,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Create Assessment', style: typography.titleLarge),
                  Text(
                    '$kind · Exponents',
                    style: typography.titleMedium?.copyWith(
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ),
              _Label(saveStatus),
              if (state == DraftSaveState.saveFailed)
                TextButton(
                  onPressed: () => widget.controller.update(_draft),
                  child: const Text('Retry save'),
                ),
            ],
          ),
        ),
      ],
    );
    final actions = Wrap(
      spacing: 10,
      runSpacing: 4,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _draft.questions.isEmpty
              ? null
              : () => showAssessmentStudentPreview(context, _draft),
          style: OutlinedButton.styleFrom(
            foregroundColor: _ink,
            side: const BorderSide(color: _line),
            minimumSize: const Size(0, 44),
          ),
          icon: const Icon(Icons.visibility_outlined, size: 19),
          label: const Text('Preview as student'),
        ),
        Tooltip(
          message: 'Scoring rubric will be available in the next step',
          child: FilledButton.icon(
            onPressed: null,
            style: FilledButton.styleFrom(
              disabledBackgroundColor: const Color(0xFF273430),
              disabledForegroundColor: Colors.white70,
              minimumSize: const Size(0, 44),
            ),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.chevron_right, size: 18),
            label: const Text('Next: Scoring rubric'),
          ),
        ),
      ],
    );
    return ColoredBox(
      color: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 100),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: inset, vertical: 8),
          child: wide
              ? Row(
                  spacing: 12,
                  children: [
                    Expanded(flex: 56, child: title),
                    Flexible(flex: 44, child: actions),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [title, actions],
                ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, {required bool wide}) {
    final state = widget.controller.state;
    if (state == DraftSaveState.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state == DraftSaveState.loadFailed) {
      return _AssessmentCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Could not load the assessment draft.'),
            TextButton(
              onPressed: widget.controller.load,
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    final count = _draft.questions.length;
    final points = _draft.totalPoints;
    final totals =
        '$count ${count == 1 ? 'question' : 'questions'} · $points ${points == 1 ? 'pt' : 'pts'}';
    final settings = _AssessmentCard(
      child: AssessmentSettingsPanel(
        draft: _draft,
        totals: totals,
        onChanged: widget.controller.update,
      ),
    );
    final questions = _AssessmentCard(child: _questions(context, totals));
    return wide
        ? Row(
            spacing: 22,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 31, child: settings),
              Expanded(flex: 69, child: questions),
            ],
          )
        : Column(
            spacing: 16,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [questions, settings],
          );
  }

  Widget _questions(BuildContext context, String totals) {
    final typography = Theme.of(context).textTheme;
    return Column(
      spacing: 14,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Questions',
              style: typography.titleLarge?.copyWith(fontSize: 20),
            ),
            _Label(totals, background: _tint, foreground: _green),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final actions = [
              _QuestionSource(
                title: 'Write in app',
                description: 'Short answer, show work, choice, true or false',
                icon: Icons.edit_outlined,
                onTap: _editQuestion,
              ),
              const _QuestionSource(
                title: 'Snap a photo',
                description: 'Photo import coming soon',
                icon: Icons.camera_alt_outlined,
              ),
              const _QuestionSource(
                title: 'Generate with AI',
                description: 'AI generation coming soon',
                icon: Icons.auto_awesome_outlined,
                highlighted: true,
              ),
            ];
            return constraints.maxWidth >= 525
                ? IntrinsicHeight(
                    child: Row(
                      spacing: 10,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final action in actions) Expanded(child: action),
                      ],
                    ),
                  )
                : Column(
                    spacing: 10,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: actions,
                  );
          },
        ),
        if (_draft.questions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              'No questions yet. Use Write in app to add your first question.',
              style: typography.bodyMedium?.copyWith(
                color: AppColors.mutedText,
              ),
            ),
          ),
        for (var index = 0; index < _draft.questions.length; index++)
          _QuestionCard(
            question: _draft.questions[index],
            index: index,
            isLast: index == _draft.questions.length - 1,
            onAction: (action) => _questionAction(index, action),
          ),
      ],
    );
  }
}

class _QuestionSource extends StatelessWidget {
  const _QuestionSource({
    required this.title,
    required this.description,
    required this.icon,
    this.onTap,
    this.highlighted = false,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    return Material(
      color: highlighted ? const Color(0xFFF2F9ED) : Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: highlighted ? AppColors.mint : _line),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            spacing: 10,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: highlighted
                    ? AppColors.lime
                    : AppColors.canvas,
                child: Icon(icon, size: 18, color: highlighted ? _green : _ink),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: typography.titleMedium),
                    Text(
                      description,
                      style: typography.bodySmall?.copyWith(
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.index,
    required this.isLast,
    required this.onAction,
  });

  final AssessmentQuestion question;
  final int index;
  final bool isLast;
  final ValueChanged<_QuestionAction> onAction;

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 10, 14),
        child: Column(
          spacing: 8,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              spacing: 8,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Q${index + 1}',
                        style: typography.labelLarge?.copyWith(color: _green),
                      ),
                      _Label(question.kind.label),
                    ],
                  ),
                ),
                Text('${question.points} pt', style: typography.labelSmall),
                PopupMenuButton<_QuestionAction>(
                  tooltip: 'Question ${index + 1} actions',
                  icon: const Icon(
                    Icons.more_horiz,
                    color: AppColors.mutedText,
                  ),
                  onSelected: onAction,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: _QuestionAction.edit,
                      child: Text('Edit'),
                    ),
                    const PopupMenuItem(
                      value: _QuestionAction.duplicate,
                      child: Text('Duplicate'),
                    ),
                    PopupMenuItem(
                      value: _QuestionAction.moveUp,
                      enabled: index > 0,
                      child: const Text('Move up'),
                    ),
                    PopupMenuItem(
                      value: _QuestionAction.moveDown,
                      enabled: !isLast,
                      child: const Text('Move down'),
                    ),
                    const PopupMenuItem(
                      value: _QuestionAction.remove,
                      child: Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
            Text(question.prompt, style: typography.bodyMedium),
            if (question.options.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (var index = 0; index < question.options.length; index++)
                    _Label(
                      '${String.fromCharCode(65 + index)}  ${question.options[index]}',
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(
    this.text, {
    this.background = AppColors.canvas,
    this.foreground = AppColors.mutedText,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      color: background,
      shape: const StadiumBorder(),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: foreground),
      ),
    ),
  );
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
}
