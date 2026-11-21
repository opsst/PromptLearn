import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../classroom/models/teacher_class_preview.dart';
import '../../syllabus/models/syllabus_preview.dart';
import '../../syllabus/views/teacher_syllabus_dialog.dart';
import '../widgets/home_header.dart';

const _paper = Color(0xFFFFFFFF);
const _text = Color(0xFF202438);
const _highlight = Color(0xFFDFFFCC);
const _lavender = Color(0xFFF2F3FF);
const _line = Color(0xFFE6ECE8);
const _upcomingGreen = Color(0xFF4ABE7A);

class TeacherHomeView extends StatelessWidget {
  const TeacherHomeView({
    super.key,
    required this.displayName,
    required this.now,
    required this.onStartClass,
  });

  final String displayName;
  final DateTime now;
  final VoidCallback onStartClass;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF8F8F8),
      child: Column(
        children: [
          HomeHeader(displayName: displayName, now: now, teacherLayout: true),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final inset = constraints.maxWidth >= 900 ? 42.0 : 16.0;
                final padding = EdgeInsets.fromLTRB(inset, 25, inset, 18);
                final width = constraints.maxWidth - padding.horizontal;
                final showTodayAlongside = width >= 950;
                final lessonWidth = showTodayAlongside
                    ? (width - 20) * 791 / 1093
                    : width;
                return SingleChildScrollView(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0.8, -0.2),
                        radius: 0.75,
                        colors: [Color(0xFFDFF8D5), Color(0xFFF8F8F8)],
                      ),
                    ),
                    child: Stack(
                      children: [
                        const Positioned(
                          top: -40,
                          left: -48,
                          width: 460,
                          height: 500,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment(0, -0.3),
                                colors: [Color(0x3B6FF9A8), Color(0x006FF9A8)],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: padding,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight:
                                  (constraints.maxHeight - padding.vertical)
                                      .clamp(0.0, double.infinity),
                            ),
                            child: IntrinsicHeight(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                spacing: 20,
                                children: [
                                  _DashboardRow(
                                    horizontal: showTodayAlongside,
                                    flexes: const [791, 302],
                                    children: [
                                      _NextClass(
                                        width: lessonWidth,
                                        onStartClass: onStartClass,
                                      ),
                                      const _Today(),
                                    ],
                                  ),
                                  Expanded(
                                    child: _DashboardRow(
                                      horizontal: width >= 900,
                                      flexes: const [387, 387, 300],
                                      children: const [
                                        _Attention(),
                                        _ClassPulse(),
                                        _Syllabi(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardRow extends StatelessWidget {
  const _DashboardRow({
    required this.horizontal,
    required this.flexes,
    required this.children,
  });

  final bool horizontal;
  final List<int> flexes;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (!horizontal) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 20,
        children: children,
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 20,
        children: [
          for (var index = 0; index < children.length; index++)
            Expanded(flex: flexes[index], child: children[index]),
        ],
      ),
    );
  }
}

Widget _card(Widget child, {double padding = 20}) {
  return Container(
    padding: EdgeInsets.all(padding),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: _paper,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1A65776C),
          blurRadius: 40,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );
}

TextStyle _style(
  BuildContext context,
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = _text,
}) {
  return Theme.of(context).textTheme.bodyMedium!.copyWith(
    fontSize: size,
    fontWeight: weight,
    fontVariations: [FontVariation('wght', weight.value.toDouble())],
    height: 1.35,
    color: color,
  );
}

Widget _heading(BuildContext context, String title, Widget trailing) {
  return Row(
    children: [
      Expanded(
        child: Text(title, style: _style(context, 18, weight: FontWeight.w700)),
      ),
      const SizedBox(width: 8),
      trailing,
    ],
  );
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, {this.color = _highlight, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 5,
          children: [
            if (icon != null) Icon(icon, size: 14, color: _text),
            Flexible(
              child: Text(
                label,
                style: _style(context, 12, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showDetails(BuildContext context, String title, Widget content) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _NextClass extends StatelessWidget {
  const _NextClass({required this.width, required this.onStartClass});

  final double width;
  final VoidCallback onStartClass;

  @override
  Widget build(BuildContext context) {
    final split = width >= 680;
    final overview = _LessonOverview(
      onStartClass: onStartClass,
      horizontalActions: (split ? width - 280 : width) >= 417,
    );
    const flow = _LessonFlow();

    return _card(
      split
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: overview),
                  const SizedBox(width: 280, child: flow),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [overview, flow],
            ),
      padding: 0,
    );
  }
}

class _LessonOverview extends StatelessWidget {
  const _LessonOverview({
    required this.horizontalActions,
    required this.onStartClass,
  });

  final bool horizontalActions;
  final VoidCallback onStartClass;

  @override
  Widget build(BuildContext context) {
    final buttons = [
      _LessonButton(
        label: 'Start Class',
        iconAsset: 'assets/home/iconmind_art-class-outline-thin.svg',
        primary: true,
        onPressed: onStartClass,
      ),
      _LessonButton(
        label: 'Lesson Plan',
        iconAsset: 'assets/home/akar-icons_book-close.svg',
        onPressed: () => _showDetails(
          context,
          TeacherClassPreview.lessonTitle,
          const _LessonFlow(),
        ),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: 15,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              const Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Pill('Next · in 15 min', icon: Icons.schedule),
                  Text('P4 · 10:20–11:10 · Room 204'),
                ],
              ),
              Text(
                TeacherClassPreview.lessonTitle,
                style: _style(context, 26, weight: FontWeight.w700),
              ),
              Row(
                spacing: 8,
                children: [
                  const Icon(
                    Icons.group_outlined,
                    size: 18,
                    color: AppColors.mutedText,
                  ),
                  Flexible(
                    child: Text(
                      'M.1/1 · 32 students · 2 on leave',
                      style: _style(context, 13, color: AppColors.mutedText),
                    ),
                  ),
                ],
              ),
              const Wrap(
                spacing: 7,
                runSpacing: 6,
                children: [
                  _Pill('IBL plan ready', icon: Icons.check),
                  _Pill(
                    '14 slides',
                    icon: Icons.slideshow_outlined,
                    color: _lavender,
                  ),
                  _Pill(
                    '2 exercises need review',
                    icon: Icons.error_outline,
                    color: Color(0xFFFFF1D6),
                  ),
                ],
              ),
            ],
          ),
          horizontalActions
              ? Row(
                  spacing: 16,
                  children: [
                    for (final button in buttons) Expanded(child: button),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: buttons,
                ),
        ],
      ),
    );
  }
}

class _LessonButton extends StatelessWidget {
  const _LessonButton({
    required this.label,
    required this.iconAsset,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final String iconAsset;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: primary ? const Color(0xFF000000) : _lavender,
        foregroundColor: primary ? _paper : _text,
        minimumSize: const Size(0, 57),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      icon: SvgPicture.asset(
        iconAsset,
        width: 24,
        height: 24,
        excludeFromSemantics: true,
      ),
      label: Text(label),
    );
  }
}

class _LessonFlow extends StatelessWidget {
  const _LessonFlow();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 357),
      color: const Color(0xFFF0FFE8),
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Text(
            'Lesson flow · 50 min',
            style: _style(
              context,
              13,
              weight: FontWeight.w600,
              color: _upcomingGreen,
            ),
          ),
          for (final step in TeacherClassPreview.steps)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                Text(
                  '${step.startMinute}′',
                  style: _style(
                    context,
                    12,
                    weight: FontWeight.w700,
                    color: const Color(0xFF286140),
                  ),
                ),
                Expanded(
                  child: _EntryText(step.title, step.summary, titleSize: 13),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EntryText extends StatelessWidget {
  const _EntryText(this.title, this.description, {this.titleSize = 14});

  final String title;
  final String description;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Text(title, style: _style(context, titleSize, weight: FontWeight.w600)),
        if (description.isNotEmpty)
          Text(
            description,
            style: _style(context, 12, color: AppColors.mutedText),
          ),
      ],
    );
  }
}

class _Today extends StatelessWidget {
  const _Today();

  static const _periods = [
    ('08:30', '3.2 Multiplying powers', 'M.1/2'),
    ('10:20', '3.2 Multiplying powers', 'M.1/1'),
    ('12:00', 'Lunch break', ''),
    ('13:00', '3.1 What an exponent means', 'M.1/3'),
    ('14:00', 'Math 201 · 4.3 Factoring', 'M.2/1'),
  ];

  @override
  Widget build(BuildContext context) {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          _heading(
            context,
            'Today',
            Text(
              '4 periods',
              style: _style(context, 13, color: AppColors.mutedText),
            ),
          ),
          for (final (time, title, room) in _periods)
            Container(
              decoration: BoxDecoration(
                color: time == '10:20' ? _highlight : null,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                spacing: 10,
                children: [
                  Text(
                    time,
                    style: _style(context, 13, weight: FontWeight.w600),
                  ),
                  Expanded(child: _EntryText(title, room, titleSize: 13)),
                  if (time == '10:20')
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        color: _upcomingGreen,
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        child: Text(
                          'Upcoming',
                          style: _style(
                            context,
                            10,
                            weight: FontWeight.w600,
                            color: _paper,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Attention extends StatelessWidget {
  const _Attention();

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        Icons.error_outline,
        Color(0xFFFFF1D6),
        'Review 4 quiz papers',
        'AI wasn’t sure how to score these answers.',
      ),
      (
        Icons.auto_awesome_outlined,
        _lavender,
        'Approve 7 practice sets',
        'Made from each student’s mistakes.',
      ),
    ];
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          _heading(context, 'Needs your attention', const _Pill('2')),
          for (final (icon, color, title, description) in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                spacing: 12,
                children: [
                  _TileIcon(icon, color: color),
                  Expanded(child: _EntryText(title, description)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ClassPulse extends StatelessWidget {
  const _ClassPulse();

  static const _classes = [
    ('M.1/1', 94, 78, 'On track'),
    ('M.1/2', 97, 86, 'On track'),
    ('M.1/3', 88, 61, '1 behind'),
  ];

  @override
  Widget build(BuildContext context) {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          _heading(
            context,
            'Class pulse',
            Text(
              'This week',
              style: _style(context, 13, color: AppColors.mutedText),
            ),
          ),
          for (final (room, attendance, homework, status) in _classes)
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: _line, width: 2),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 6,
                children: [
                  Row(
                    spacing: 8,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              room,
                              style: _style(
                                context,
                                15,
                                weight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Math 101',
                              style: _style(
                                context,
                                12,
                                color: AppColors.mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _Pill(
                        status,
                        color: status == 'On track'
                            ? _highlight
                            : const Color(0xFFFFF1D6),
                      ),
                    ],
                  ),
                  _Metric('Attendance', attendance, AppColors.primary),
                  _Metric('Homework done', homework, AppColors.sage),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.percent, this.color);

  final String label;
  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 8,
      children: [
        Flexible(
          flex: 3,
          child: Text(
            label,
            style: _style(context, 12, color: AppColors.mutedText),
          ),
        ),
        Expanded(
          flex: 2,
          child: LinearProgressIndicator(
            value: percent / 100,
            color: color,
            backgroundColor: _line,
            minHeight: 6,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        Text('$percent%', style: _style(context, 12, weight: FontWeight.w600)),
      ],
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon(this.icon, {required this.color, this.size = 40});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: _text, size: 20),
    );
  }
}

class _Syllabi extends StatelessWidget {
  const _Syllabi();

  void _showCreateSyllabus(BuildContext context) {
    _showDetails(
      context,
      'Create syllabus',
      const Text('The syllabus editor is unavailable in this preview.'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          _heading(
            context,
            'My syllabus',
            TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                barrierColor: const Color(0x87101010),
                builder: (context) => TeacherSyllabusDialog(
                  syllabi: teacherSyllabusPreviews,
                  onCreateSyllabus: () => _showCreateSyllabus(context),
                ),
              ),
              child: const Text('See all'),
            ),
          ),
          _courseList(),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _text,
              minimumSize: const Size(0, 48),
              side: const BorderSide(color: Color(0xFFC9D3CD), width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => _showCreateSyllabus(context),
            icon: const Icon(Icons.add),
            label: const Text('Create syllabus'),
          ),
        ],
      ),
    );
  }

  Widget _courseList() {
    return Column(
      spacing: 12,
      children: [
        for (final syllabus in teacherSyllabusPreviews.take(3))
          Row(
            spacing: 12,
            children: [
              _TileIcon(
                Icons.menu_book_outlined,
                color: syllabus.coverColor,
                size: 52,
              ),
              Expanded(child: _EntryText(syllabus.title, syllabus.homeSummary)),
              if (syllabus.isDraft) const _Pill('Draft', color: _lavender),
            ],
          ),
      ],
    );
  }
}
