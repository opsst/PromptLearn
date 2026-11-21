import 'dart:typed_data';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:promptlearn/data/repositories/mock_homework_checker.dart';
import 'package:promptlearn/domain/models/homework_check.dart';
import 'package:promptlearn/domain/repositories/homework_checker.dart';
import 'package:promptlearn/ui/features/assessment/views/student_homework_view.dart';
import 'package:promptlearn/ui/features/assessment/widgets/homework_notebook.dart';
import 'package:promptlearn/ui/features/assessment/widgets/homework_paper.dart';

void main() {
  test('Each draft keeps its own undo and redo history', () {
    final notebook = HomeworkNotebook()..activeIndex = 0;
    final draft = notebook.draft;
    draft.addInk(PaperTool.pen, const [Offset(0.2, 0.5), Offset(0.8, 0.5)]);

    notebook.activeIndex = 1;
    expect(notebook.draft.content.hasWork, isFalse);
    notebook.activeIndex = 0;
    expect(notebook.draft, same(draft));

    draft.commit(
      draft.content.eraseBetween(
        const Offset(0.5, 0.3),
        const Offset(0.5, 0.7),
      ),
    );
    expect(draft.content.hasWork, isFalse);
    draft.undo();
    expect(draft.content.hasWork, isTrue);
    draft.redo();
    expect(draft.content.hasWork, isFalse);
    draft.undo();
    draft.addInk(PaperTool.highlighter, const [Offset(0.3, 0.3)]);
    expect(draft.canRedo, isFalse);
  });

  test('Mock returns a circle only for the visible sample step', () async {
    const checker = MockHomeworkChecker();
    HomeworkCheckRequest request({required bool sample}) {
      return HomeworkCheckRequest(
        question: HomeworkNotebook.questions[3],
        paperPng: Uint8List(1),
        imageWidth: 100,
        imageHeight: 100,
        demoSampleVisible: sample,
      );
    }

    final marked = await checker.check(request(sample: true));
    expect(marked.region, homeworkDemoIssue);
    expect(marked.markStyle, HomeworkMarkStyle.circle);
    expect((await checker.check(request(sample: false))).region, isNull);
  });

  testWidgets(
    'Eraser hides whole strokes while down and undo groups the drag',
    (tester) async {
      final notebook = HomeworkNotebook()..activeIndex = 0;
      final draft = notebook.draft;
      draft.addInk(PaperTool.pen, const [Offset(0.2, 0.4), Offset(0.8, 0.4)]);
      draft.addInk(PaperTool.pen, const [Offset(0.2, 0.6), Offset(0.8, 0.6)]);
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

      final finder = find.byType(HomeworkPaper);
      final paper = tester.getRect(finder);
      final first = Offset(paper.center.dx, paper.top + paper.height * 0.4);
      final second = Offset(paper.center.dx, paper.top + paper.height * 0.6);
      int visibleStrokes() =>
          tester.widget<HomeworkPaper>(finder).visibleContent.strokes.length;

      expect(find.byTooltip('Lasso'), findsNothing);
      await tester.tap(find.byTooltip('Eraser'));
      await tester.pump();

      final cancelled = await tester.startGesture(
        first,
        kind: PointerDeviceKind.stylus,
      );
      await tester.pump();
      expect(visibleStrokes(), 1);
      await cancelled.cancel();
      await tester.pump();
      expect(visibleStrokes(), 2);

      final drag = await tester.startGesture(
        first,
        kind: PointerDeviceKind.stylus,
      );
      await tester.pump();
      expect(visibleStrokes(), 1);
      await drag.moveTo(second);
      await tester.pump();
      expect(visibleStrokes(), 0);
      expect(draft.content.strokes, hasLength(2));
      await drag.up();
      await tester.pump();
      expect(draft.content.strokes, isEmpty);

      await tester.tap(find.byTooltip('Undo'));
      await tester.pump();
      expect(visibleStrokes(), 2);
      await tester.tap(find.byTooltip('Redo'));
      await tester.pump();
      expect(visibleStrokes(), 0);
    },
  );

  testWidgets('A feedback underline uses the bottom of its paper region', (
    tester,
  ) async {
    final draft = HomeworkDraft();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 448,
            child: HomeworkPaper(
              captureKey: GlobalKey(),
              draft: draft,
              visibleContent: draft.content,
              tool: PaperTool.pen,
              activeTrace: const [],
              feedback: const HomeworkFeedback(
                'Recheck this step.',
                region: PaperRegion(0.25, 0.25, 0.5, 0.25),
                markStyle: HomeworkMarkStyle.underline,
              ),
              onDown: (_, _) {},
              onMove: (_, _) {},
              onEnd: (_, {required cancelled}) {},
            ),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(HomeworkPaper));
    expect(
      find.byType(CustomPaint).last,
      paints..line(
        p1: Offset(size.width * 0.25, size.height * 0.5),
        p2: Offset(size.width * 0.75, size.height * 0.5),
      ),
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
