class CurriculumRow {
  const CurriculumRow(
    this.id,
    this.title,
    this.outcomes, {
    this.codes = const [],
  });

  factory CurriculumRow.fromJson(Map<String, dynamic> json) {
    final source = _objects(json['outcomes']);
    return CurriculumRow(
      json['id'] as String,
      json['title'] as String,
      [
        for (final outcome in source)
          [
            if (outcome['code'] case final String code) code,
            (outcome['text'] as String).replaceAll('\n', ' '),
          ].join(' · '),
      ],
      codes: [
        for (final outcome in source)
          if (outcome['code'] case final String code) code,
      ],
    );
  }

  final String id;
  final String title;
  final List<String> outcomes;
  final List<String> codes;
}

class CourseSyllabusSelection {
  const CourseSyllabusSelection({
    required this.grade,
    required this.term,
    required this.references,
    this.title,
    this.code,
    this.credits,
    this.academicYear,
    this.totalSessions = periods,
    this.sessionMinutes = minutes,
    this.assessmentWeights = weights,
    this.customReferences = const [],
  });

  static const periods = 54;
  static const minutes = 50;
  static const weights = {
    'Classwork': 40,
    'Unit Quizzes': 30,
    'Final Exam': 30,
  };

  final int grade;
  final int term;
  final List<String> references;
  final String? title;
  final String? code;
  final double? credits;
  final int? academicYear;
  final int totalSessions;
  final int sessionMinutes;
  final Map<String, int> assessmentWeights;
  final List<String> customReferences;

  String get courseName => title ?? 'Mathematics (Mathayom $grade)';

  Map<String, Object> toJson() => {
    'course_name': courseName,
    'course_code': ?code,
    'credits': ?credits,
    'academic_year': ?academicYear,
    'grade': grade,
    'course_type': 'core',
    'term': term,
    'total_sessions': totalSessions,
    'minutes_per_session': sessionMinutes,
    'reference_ids': references,
    if (customReferences.isNotEmpty) 'custom_references': customReferences,
    'assessment_weights': [
      for (final weight in assessmentWeights.entries)
        {'category': weight.key, 'points': weight.value},
    ],
  };
}

class SyllabusEditResult {
  const SyllabusEditResult({required this.documentHtml, this.id, this.status});

  factory SyllabusEditResult.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final status = json['status'];
    if (json case {'syllabus': {'document_html': final String html}}) {
      return SyllabusEditResult(
        id: id is String ? id : null,
        status: status is String ? status : null,
        documentHtml: html,
      );
    }
    throw const FormatException(
      'The syllabus response did not include its document.',
    );
  }

  final String? id;
  final String? status;
  final String documentHtml;
}

class SyllabusRequestException implements Exception {
  const SyllabusRequestException(this.message);

  final String message;
}

typedef SyllabusPeriod = ({int number, String title});
typedef SyllabusAssessment = ({
  String title,
  String category,
  int period,
  int points,
});

class CourseSyllabusUnit {
  const CourseSyllabusUnit({
    required this.title,
    required this.referenceIds,
    required this.periods,
    required this.assessments,
  });

  factory CourseSyllabusUnit.fromJson(Map<String, dynamic> json) {
    return CourseSyllabusUnit(
      title: json['title'] as String,
      referenceIds: (json['reference_ids'] as List).cast<String>(),
      periods: [
        for (final period in _objects(json['sessions']))
          (number: period['number'] as int, title: period['title'] as String),
      ],
      assessments: [
        for (final assessment in _objects(json['assessments']))
          (
            title: assessment['title'] as String,
            category: assessment['category'] as String,
            period: assessment['session'] as int,
            points: assessment['points'] as int,
          ),
      ],
    );
  }

  final String title;
  final List<String> referenceIds;
  final List<SyllabusPeriod> periods;
  final List<SyllabusAssessment> assessments;

  Map<String, Object> toEditedPlanJson() => {
    'title': title,
    'reference_ids': referenceIds,
    'session_titles': [for (final period in periods) period.title],
    'assessments': [
      for (final assessment in assessments)
        {
          'title': assessment.title,
          'category': assessment.category,
          // Draft responses number periods across the semester. Save expects
          // the assessment's period number within its unit.
          'session': assessment.period - periods.first.number + 1,
          'points': assessment.points,
        },
    ],
  };
}

class CourseSyllabusDraft {
  const CourseSyllabusDraft({
    required this.selection,
    required this.description,
    required this.references,
    required this.units,
    required this.documentHtml,
  });

  factory CourseSyllabusDraft.fromJson(
    CourseSyllabusSelection selection,
    Map<String, dynamic> json,
  ) {
    return CourseSyllabusDraft(
      selection: selection,
      description: json['description'] as String,
      references: [
        for (final reference in _objects(json['references']))
          CurriculumRow.fromJson(reference['row'] as Map<String, dynamic>),
      ],
      units: [
        for (final unit in _objects(json['units']))
          CourseSyllabusUnit.fromJson(unit),
      ],
      documentHtml: json['document_html'] as String,
    );
  }

  final CourseSyllabusSelection selection;
  final String description;
  final List<CurriculumRow> references;
  final List<CourseSyllabusUnit> units;
  final String documentHtml;

  Map<String, Object> toEditJson() => {
    'course': selection.toJson(),
    'plan': {
      'description': description,
      'units': [for (final unit in units) unit.toEditedPlanJson()],
    },
  };
}

List<Map<String, dynamic>> _objects(Object? json) =>
    (json as List? ?? const []).cast<Map<String, dynamic>>();
