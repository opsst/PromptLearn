import 'dart:math' as math;
import 'dart:ui';

import '../../../../domain/models/homework_check.dart';

enum PaperTool { pen, highlighter, lasso, eraser }

class PaperStroke {
  const PaperStroke(this.tool, this.points);

  final PaperTool tool;
  final List<Offset> points;
}

class PaperContent {
  const PaperContent({this.strokes = const [], this.sampleSteps = const {}});

  final List<PaperStroke> strokes;
  final Set<int> sampleSteps;

  bool get hasWork => strokes.isNotEmpty || sampleSteps.isNotEmpty;
}

const sampleText = ['(x²)(x⁵)', '= x²ˣ⁵', '= x¹⁰'];
const sampleRegions = [
  PaperRegion(0.31, 0.06, 0.21, 0.13),
  homeworkDemoIssue,
  PaperRegion(0.31, 0.39, 0.21, 0.13),
];

class HomeworkDraft {
  HomeworkDraft({bool withSample = false})
    : content = PaperContent(
        sampleSteps: withSample ? const {0, 1, 2} : const {},
      );

  PaperContent content;
  PaperRegion? selection;
  final List<PaperContent> _history = [];

  bool get canUndo => _history.isNotEmpty || selection != null;

  void applyStroke(PaperTool tool, List<Offset> points) {
    switch (tool) {
      case PaperTool.pen:
      case PaperTool.highlighter:
        _replace(
          PaperContent(
            strokes: [
              ...content.strokes,
              PaperStroke(tool, List.unmodifiable(points)),
            ],
            sampleSteps: content.sampleSteps,
          ),
        );
      case PaperTool.lasso:
        final xs = points.map((point) => point.dx);
        final ys = points.map((point) => point.dy);
        final left = xs.reduce(math.min);
        final top = ys.reduce(math.min);
        final region = PaperRegion(
          left,
          top,
          xs.reduce(math.max) - left,
          ys.reduce(math.max) - top,
        );
        selection = region.width > 0.012 && region.height > 0.012
            ? region
            : null;
      case PaperTool.eraser:
        final keptStrokes = content.strokes
            .where(
              (stroke) =>
                  !stroke.points.any((point) => _isNearEraser(point, points)),
            )
            .toList();
        final keptSteps = content.sampleSteps.where((index) {
          final region = sampleRegions[index];
          return !points.any(
            (point) => Rect.fromLTWH(
              region.x,
              region.y,
              region.width,
              region.height,
            ).inflate(0.012).contains(point),
          );
        }).toSet();
        if (keptStrokes.length != content.strokes.length ||
            keptSteps.length != content.sampleSteps.length) {
          _replace(PaperContent(strokes: keptStrokes, sampleSteps: keptSteps));
        }
    }
  }

  void undo() {
    if (selection != null) {
      selection = null;
    } else if (_history.isNotEmpty) {
      content = _history.removeLast();
    }
  }

  void _replace(PaperContent next) {
    if (_history.length == 24) _history.removeAt(0);
    _history.add(content);
    content = next;
    selection = null;
  }
}

bool _isNearEraser(Offset point, List<Offset> eraserPath) {
  const radiusSquared = 0.000196;
  var start = eraserPath.first;
  if ((point - start).distanceSquared <= radiusSquared) return true;

  for (final end in eraserPath.skip(1)) {
    final segment = end - start;
    if (segment.distanceSquared > 0) {
      final delta = point - start;
      final position =
          ((delta.dx * segment.dx + delta.dy * segment.dy) /
                  segment.distanceSquared)
              .clamp(0.0, 1.0);
      if ((point - start - segment * position).distanceSquared <=
          radiusSquared) {
        return true;
      }
    }
    start = end;
  }
  return false;
}

class HomeworkNotebook {
  static const questions = [
    HomeworkQuestion('hw-3.1-q1', 'Simplify x² · x³.'),
    HomeworkQuestion('hw-3.1-q2', 'Simplify (a³)².'),
    HomeworkQuestion('hw-3.1-q3', 'Simplify y⁶ ÷ y², where y ≠ 0.'),
    HomeworkQuestion(homeworkDemoQuestionId, 'Simplify (x²)(x⁵).'),
    HomeworkQuestion('hw-3.1-q5', 'Simplify (m²)(m⁴).'),
    HomeworkQuestion('hw-3.1-q6', 'Simplify (2x²)(3x³).'),
    HomeworkQuestion('hw-3.1-q7', 'Simplify (p²)⁴.'),
    HomeworkQuestion('hw-3.1-q8', 'Simplify (x³)² ÷ x⁴, where x ≠ 0.'),
  ];

  int activeIndex = 3;
  bool automatic = false;
  final _drafts = <int, HomeworkDraft>{3: HomeworkDraft(withSample: true)};

  HomeworkDraft get draft =>
      _drafts.putIfAbsent(activeIndex, HomeworkDraft.new);

  bool hasWorkAt(int index) => _drafts[index]?.content.hasWork ?? false;
}
