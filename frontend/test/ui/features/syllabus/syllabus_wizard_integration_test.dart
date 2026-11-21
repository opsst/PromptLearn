import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:promptlearn/app/prompt_learn_app.dart';
import 'package:promptlearn/data/repositories/api_course_syllabus_repository.dart';
import 'package:promptlearn/domain/models/user_role.dart';
import 'package:promptlearn/domain/repositories/role_repository.dart';
import 'package:promptlearn/ui/features/syllabus/views/syllabus_editor_view.dart';

void main() {
  setUpAll(() async {
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'));
    await inter.load();
  });

  testWidgets('The teacher wizard submits and publishes the edited syllabus', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const export = MethodChannel('promptlearn/syllabus_export');
    final messenger = tester.binding.defaultBinaryMessenger;
    final exports = <MethodCall>[];
    messenger.setMockMethodCallHandler(export, (call) async {
      exports.add(call);
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(export, null));
    const rational = 'core/1/1.1/1';
    const construction = 'core/1/2.2/1';
    const geometry = 'core/1/2.2/2';
    final requests = <String>[];
    final edits = <Map<String, dynamic>>[];
    http.Response response(Object body, int status) =>
        http.Response.bytes(utf8.encode(jsonEncode(body)), status);
    Map<String, Object> row(String id, String title, List<String> codes) => {
      'id': id,
      'title': title,
      'outcomes': [
        for (final code in codes) {'code': code, 'text': title},
      ],
    };
    final client = MockClient((request) async {
      final path = request.url.path;
      requests.add('${request.method} $path');
      if (path == '/v1/curriculum/math') {
        expect(request.url.queryParameters, {
          'grade': '1',
          'course_type': 'core',
          'language': 'en',
        });
        return response({
          'groups': [
            {
              'rows': [
                row(rational, 'Rational numbers', [
                  'ค 1.1 ม.1/1',
                  'ค 1.1 ม.1/2',
                ]),
                row(construction, 'Geometric construction', ['ค 2.2 ม.1/1']),
                row(geometry, 'Dimensional relationships', ['ค 2.2 ม.1/2']),
              ],
            },
          ],
        }, 200);
      }
      const syllabus = {'document_html': '<h1>Grade 7 Mathematics</h1>'};
      if (path == '/v1/syllabi/draft') {
        final input = jsonDecode(request.body) as Map<String, dynamic>;
        expect(input['total_sessions'], 54);
        expect(input['reference_ids'], [rational, construction, geometry]);
        expect(input['assessment_weights'], isEmpty);
        return response({
          ...syllabus,
          'description': 'Study the selected standards across one semester.',
          'units': [
            {
              'title': 'Core Mathematics',
              'reference_ids': [rational, construction, geometry],
              'sessions': [
                for (var period = 1; period <= 54; period++)
                  {'number': period, 'title': 'Practice period $period'},
              ],
              'assessments': [],
            },
          ],
        }, 200);
      }
      if (path.endsWith('/publish')) {
        expect(request.body, isEmpty);
        return response({
          'id': 'wizard-id',
          'status': 'published',
          'syllabus': syllabus,
        }, 200);
      }
      edits.add(jsonDecode(request.body) as Map<String, dynamic>);
      if (path.endsWith('/preview')) {
        return response({'syllabus': syllabus}, 200);
      }
      return response({
        'id': 'wizard-id',
        'status': 'draft',
        'syllabus': syllabus,
      }, request.method == 'PUT' ? 200 : 201);
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      PromptLearnApp(
        roleRepository: const _TeacherRole(),
        syllabusRepository: ApiCourseSyllabusRepository(
          Uri.parse('http://127.0.0.1:8080'),
          client,
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> tap(String text, {bool ensureVisible = true}) async {
      final control = find.text(text).hitTestable();
      if (ensureVisible && control.evaluate().isEmpty) {
        await tester.ensureVisible(find.text(text));
      }
      await tester.tap(control);
      await tester.pumpAndSettle();
    }

    await tap('Create syllabus');
    final editor = tester.widget<SyllabusEditorView>(
      find.byType(SyllabusEditorView),
    );
    await tester.enterText(
      find.byType(TextFormField).first,
      'Grade 7 Mathematics',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    for (var step = 0; step < 4; step++) {
      await tap('Continue');
    }
    expect(find.text('Teaching schedule'), findsOneWidget);
    // The separate schedule widget test covers drag gestures. Use the same
    // view-model operation here to check the actual HTTP request after a move.
    editor.draft.moveSchedulePeriod(0, 0, 2);
    await tester.pumpAndSettle();
    await tap('Continue');
    expect(find.text('Review & publish'), findsWidgets);
    await tap('Download HTML');
    expect(exports.single.method, 'saveHtml');
    expect(
      exports.single.arguments['fileName'],
      'PromptLearn-M1-Semester-1.html',
    );
    expect(
      utf8.decode(exports.single.arguments['contents'] as Uint8List),
      '<h1>Grade 7 Mathematics</h1>',
    );
    await tap('Save as draft');
    expect(find.text('Saved to backend · wizard-id'), findsOneWidget);

    editor.draft.setTeachingNotes('Bring graph paper.');
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Publish').hitTestable(),
    );
    await tester.pumpAndSettle();
    expect(find.text('Syllabus published to 3 classes.'), findsOneWidget);
    expect(find.text('Published'), findsOneWidget);
    expect(requests, [
      'GET /v1/curriculum/math',
      'POST /v1/syllabi/preview',
      'POST /v1/syllabi',
      'PUT /v1/syllabi/wizard-id',
      'POST /v1/syllabi/wizard-id/publish',
    ]);

    final edit = edits.last;
    final course = edit['course'] as Map<String, dynamic>;
    expect(course['course_name'], 'Grade 7 Mathematics');
    expect(course['course_code'], 'ค21101');
    expect(course['academic_year'], 2026);
    expect(course['credits'], 1.5);
    expect(course['reference_ids'], [rational, construction, geometry]);
    expect(course['total_sessions'], 54);
    final units = edit['plan']['units'] as List;
    expect(units.map((unit) => unit['title']), [
      'Integers',
      'Geometric construction',
      'Exponents',
      'Decimals & fractions',
      '2D & 3D figures',
    ]);
    expect(units[2]['reference_ids'], [rational]);
    expect(units.first['session_titles'].first, 'Orientation');
    expect(units.last['session_titles'].last, 'Buffer');
    final assessments = units.expand((unit) => unit['assessments'] as List);
    expect(
      assessments.fold(0, (sum, row) => sum + (row['points'] as int)),
      100,
    );
    expect(
      assessments.singleWhere(
        (row) => row['category'] == 'Final exam',
      )['session'],
      0,
    );
    final timetable = edit['timetable'];
    expect(timetable['start_date'], '2026-05-18');
    expect(timetable['end_date'], '2026-09-25');
    expect(timetable['excluded_dates'], contains('2026-06-03'));
    expect(timetable['classes'].length, 3);
    expect(timetable['classes'][0]['student_count'], 32);
    expect(timetable['classes'][0]['slots'][0], {
      'weekday': 1,
      'period_number': 2,
      'start_time': '09:00',
    });
    expect((timetable['classes'][0]['session_order'] as List).take(3), [
      2,
      3,
      1,
    ]);
    expect((timetable['classes'][1]['session_order'] as List).take(3), [
      1,
      2,
      3,
    ]);
    final settings = edit['settings'];
    expect(settings['textbook']['title'], 'Math M.1 Book 1');
    expect(settings['teaching_approaches'], ['inquiry']);
    expect(settings['student_details'], [
      'topics',
      'assessmentDates',
      'scores',
    ]);
    expect(settings['teaching_notes'], 'Bring graph paper.');
    expect(settings['calendar_events'][0], {
      'date': '2026-06-03',
      'name': 'Queen’s Birthday',
    });
    expect(settings['lesson_groups'][0][0], {
      'title': 'Positive and negative integers',
      'periods': 2,
    });

    for (var step = 0; step < 3; step++) {
      await tap('Back');
    }
    await tap('Generate syllabus draft');
    await tap('Generate draft');
    expect(requests.last, 'POST /v1/syllabi/draft');
    expect(editor.draft.units.single.title, 'Core Mathematics');
    expect(editor.draft.units.single.references, hasLength(3));
    expect(editor.draft.units.single.lessons, hasLength(54));
  });
}

class _TeacherRole implements RoleRepository {
  const _TeacherRole();

  @override
  Future<UserRole?> load() async => UserRole.teacher;
  @override
  Future<void> clear() async {}
  @override
  Future<void> save(UserRole role) async {}
}
