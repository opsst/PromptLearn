import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:promptlearn/data/repositories/mock_homework_checker.dart';
import 'package:promptlearn/domain/models/homework_check.dart';
import 'package:promptlearn/domain/repositories/homework_checker.dart';
import 'package:promptlearn/ui/features/assessment/views/student_homework_view.dart';
import 'package:promptlearn/ui/features/assessment/widgets/homework_notebook.dart';

void main() {
  test('Work and lasso stay with their question, and undo restores ink', () {
    final notebook = HomeworkNotebook()..activeIndex = 0;
    final draft = notebook.draft;
    draft.applyStroke(PaperTool.pen, const [
      Offset(0.3, 0.3),
      Offset(0.5, 0.5),
    ]);
    draft.applyStroke(PaperTool.lasso, const [
      Offset(0.2, 0.2),
      Offset(0.6, 0.6),
    ]);
    expect(draft.selection?.isValid, isTrue);

    notebook.activeIndex = 1;
    expect(notebook.draft.content.hasWork, isFalse);
    notebook.activeIndex = 0;
    expect(notebook.draft, same(draft));

    draft.undo();
    expect(draft.selection, isNull);
    draft.applyStroke(PaperTool.eraser, const [
      Offset(0.2, 0.3),
      Offset(0.4, 0.3),
    ]);
    expect(draft.content.hasWork, isFalse);
    draft.undo();
    expect(draft.content.hasWork, isTrue);
  });

  test('Mock only marks the known sample near the selected work', () async {
    const checker = MockHomeworkChecker();
    HomeworkCheckRequest request({PaperRegion? region, bool sample = true}) {
      return HomeworkCheckRequest(
        question: HomeworkNotebook.questions[3],
        paperPng: Uint8List(1),
        imageWidth: 100,
        imageHeight: 100,
        selection: region,
        demoSampleVisible: sample,
      );
    }

    expect((await checker.check(request())).region, homeworkDemoIssue);
    expect((await checker.check(request(sample: false))).region, isNull);
    expect(
      (await checker.check(
        request(region: const PaperRegion(0.7, 0.7, 0.2, 0.2)),
      )).region,
      isNull,
    );
  });

  testWidgets('Automatic check waits for the pen to lift and a 2.5 s pause', (
    tester,
  ) async {
    final checker = _UnusedChecker();
    final notebook = HomeworkNotebook();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StudentHomeworkView(
              notebook: notebook,
              checker: checker,
              onBack: () {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(notebook.automatic, isTrue);

    final paper = find.byKey(const ValueKey('homework-paper'));
    final gesture = await tester.startGesture(tester.getCenter(paper));
    await gesture.moveBy(const Offset(12, 3));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Checking…'), findsNothing);

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 2499));
    expect(find.text('Checking…'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Checking…'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(checker.calls, 0);
  });
}

class _UnusedChecker implements HomeworkChecker {
  int calls = 0;

  @override
  Future<HomeworkFeedback> check(HomeworkCheckRequest request) async {
    calls++;
    return const HomeworkFeedback('Test feedback');
  }
}
