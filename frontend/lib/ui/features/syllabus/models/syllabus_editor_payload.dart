import 'package:intl/intl.dart';

import '../../../../domain/models/course_syllabus.dart';
import '../view_models/syllabus_editor_view_model.dart';
import 'syllabus_schedule.dart';
import 'syllabus_sources.dart';

// The setup grid supplies school period numbers. Use the demo bell schedule
// and the same 50-minute period duration as the syllabus API demo.
const _periodStartTimes = [
  '08:00',
  '09:00',
  '10:00',
  '13:00',
  '14:00',
  '15:00',
  '16:00',
  '17:00',
];

extension SyllabusEditorPayload on SyllabusEditorViewModel {
  CourseSyllabusSelection backendSelection({
    required int sessionCount,
    bool includeScores = true,
  }) => CourseSyllabusSelection(
    title: courseName.trim(),
    code: courseCode.trim(),
    grade: grade,
    term: semester,
    credits: double.parse(credits),
    academicYear: academicYear,
    totalSessions: sessionCount,
    references: unitReferences.map(backendReferenceId).toList(),
    customReferences: standardsSource == StandardsSource.custom
        ? customIndicators
        : const [],
    assessmentWeights: {
      if (includeScores)
        for (final category in AssessmentCategory.values)
              category.label: pointsFor(category),
    },
  );

  Map<String, Object> toBackendEdit() {
    final periods = schedulePeriods;
    final sessionNumbers = {
      for (final (index, period) in periods.indexed) period.id: index + 1,
    };
    final dateFormat = DateFormat('yyyy-MM-dd', 'en_US');
    final book = textbook;
    return {
      'course': backendSelection(sessionCount: periods.length).toJson(),
      'plan': {
        'description': description,
        'units': [
          for (var index = 0; index < units.length; index++)
            _unitJson(this, periods, index),
        ],
      },
      'timetable': {
        'start_date': dateFormat.format(firstDay),
        'end_date': dateFormat.format(lastDay),
        'excluded_dates': [
          for (final event in schoolEvents) dateFormat.format(event.date),
        ],
        'classes': [
          for (final (index, room) in classes.indexed)
            {
              'id': room.name,
              'student_count': room.students,
              'slots': [
                for (final slot in weeklyPeriodsFor(index))
                  {
                    'weekday': slot.weekday,
                    'period_number': slot.period,
                    'start_time': _periodStartTimes[slot.period - 1],
                  },
              ],
              'session_order': [
                for (final slot in scheduleFor(index))
                  if (slot.holiday == null)
                    sessionNumbers[slot.lesson?.id] ?? 0,
              ],
            },
        ],
      },
      'settings': {
        if (book != null)
          'textbook': {
            'title': book.title,
            'pages': book.pages,
            'chapters': book.chapters,
          },
        'teaching_approaches': [
          for (final approach in teachingApproaches) approach.name,
        ],
        'student_details': [for (final detail in studentDetails) detail.name],
        'teaching_notes': teachingNotes,
        'calendar_events': [
          for (final event in schoolEvents)
            {'date': dateFormat.format(event.date), 'name': event.name},
        ],
        'lesson_groups': [
          for (final unit in units)
            [
              for (final lesson in unit.lessons)
                {'title': lesson.title, 'periods': lesson.periods},
            ],
        ],
      },
    };
  }
}

Map<String, Object> _unitJson(
  SyllabusEditorViewModel draft,
  List<SchedulePeriod> schedule,
  int index,
) {
  final unit = draft.units[index];
  final periods = schedule
      .where(
        (period) =>
            period.id.startsWith('unit-${unit.id}-') ||
            (index == 0 && period.id == 'orientation') ||
            (index == draft.units.length - 1 && period.id == 'buffer'),
      )
      .toList();
  return {
    'title': unit.title,
    'reference_ids': unit.references.map(draft.backendReferenceId).toList(),
    'session_titles': [for (final period in periods) period.title],
    'assessments': [
      for (final (number, period) in periods.indexed)
        if (period.quizPoints > 0)
          {
            'title': 'Unit ${index + 1} quiz',
            'category': AssessmentCategory.quizzes.label,
            'session': number + 1,
            'points': period.quizPoints,
          },
      if (index == 0)
        for (final category in AssessmentCategory.values)
          if (category != AssessmentCategory.quizzes &&
              draft.pointsFor(category) > 0)
            {
              'title': category.label,
              'category': category.label,
              'session': 0,
              'points': draft.pointsFor(category),
            },
    ],
  };
}
