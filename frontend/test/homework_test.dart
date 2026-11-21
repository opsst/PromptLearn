import 'dart:typed_data';
import 'dart:ui' show PointerDeviceKind;

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

  testWidgets('Fingers zoom and pan while stylus ink follows the paper', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final notebook = HomeworkNotebook();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StudentHomeworkView(
              notebook: notebook,
              checker: _UnusedChecker(),
              onBack: () {},
            ),
          ),
        ),
      ),
    );

    final paper = tester.getRect(find.byKey(const ValueKey('homework-paper')));
    final center = paper.center;
    final left = await tester.startGesture(
      center.translate(-40, 0),
      pointer: 1,
    );
    final right = await tester.startGesture(
      center.translate(40, 0),
      pointer: 2,
    );
    await left.moveBy(const Offset(-40, 0));
    await right.moveBy(const Offset(40, 0));
    await left.up();
    await right.up();
    await tester.pump();

    final pan = await tester.startGesture(center, pointer: 3);
    await pan.moveBy(Offset(paper.width * 0.10, 0));
    await pan.up();
    await tester.pump();
    expect(notebook.draft.content.strokes, isEmpty);

    final pen = await tester.startGesture(
      center + Offset(paper.width * 0.25, paper.height * 0.10),
      pointer: 4,
      kind: PointerDeviceKind.stylus,
    );
    final palm = await tester.startGesture(center, pointer: 5);
    await palm.moveBy(const Offset(30, 20));
    await pen.moveBy(const Offset(12, 6));
    await palm.up();
    await pen.up();
    await tester.pump();

    final stroke = notebook.draft.content.strokes.single;
    expect(stroke.points.first.dx, closeTo(0.575, 0.001));
    expect(stroke.points.first.dy, closeTo(0.55, 0.001));
    expect(
      stroke.points.last.dx - stroke.points.first.dx,
      closeTo(12 / (paper.width * 2), 0.001),
    );

    final pinchLeft = await tester.startGesture(
      center.translate(-80, 0),
      pointer: 6,
    );
    final pinchRight = await tester.startGesture(
      center.translate(80, 0),
      pointer: 7,
    );
    await pinchLeft.moveBy(const Offset(40, 0));
    await pinchRight.moveBy(const Offset(-40, 0));
    await pinchLeft.up();
    await pinchRight.up();
    await tester.pump();

    final penAfterZoomOut = await tester.startGesture(
      center,
      pointer: 8,
      kind: PointerDeviceKind.stylus,
    );
    await penAfterZoomOut.up();
    await tester.pump();
    expect(
      notebook.draft.content.strokes.last.points.first.dx,
      closeTo(0.5, 0.001),
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
    final gesture = await tester.startGesture(
      tester.getCenter(paper),
      kind: PointerDeviceKind.stylus,
    );
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
