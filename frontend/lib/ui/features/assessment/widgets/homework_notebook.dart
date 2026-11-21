import 'dart:ui';

import '../../../../domain/models/homework_check.dart';

enum PaperTool { pen, highlighter, eraser }

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

  /// Removes entire strokes touched by this segment of the eraser gesture.
  PaperContent eraseBetween(Offset start, Offset end) {
    final keptStrokes = strokes.where((stroke) {
      var previous = stroke.points.first;
      for (final point in stroke.points) {
        if (_eraserHitsSegment(start, end, previous, point)) return false;
        previous = point;
      }
      return true;
    }).toList();
    final keptSteps = sampleSteps.where((index) {
      final region = sampleRegions[index];
      final box = Rect.fromLTWH(
        region.x,
        region.y,
        region.width,
        region.height,
      );
      final edges = [
        box.topLeft,
        box.topRight,
        box.bottomRight,
        box.bottomLeft,
        box.topLeft,
      ];
      if (box.contains(start) || box.contains(end)) return false;
      for (var edge = 1; edge < edges.length; edge++) {
        if (_eraserHitsSegment(start, end, edges[edge - 1], edges[edge])) {
          return false;
        }
      }
      return true;
    }).toSet();
    if (keptStrokes.length == strokes.length &&
        keptSteps.length == sampleSteps.length) {
      return this;
    }
    return PaperContent(strokes: keptStrokes, sampleSteps: keptSteps);
  }
}

const paperEraserRadius = 0.014;
const sampleText = ['(x²)(x⁵)', '= x²ˣ⁵', '= x¹⁰'];
const sampleRegions = [
  PaperRegion(0.31, 0.06, 0.21, 0.13),
  homeworkDemoIssue,
  PaperRegion(0.31, 0.39, 0.21, 0.13),
];

class HomeworkDraft {
  HomeworkDraft({bool withSample = false})
    : _content = PaperContent(
        sampleSteps: withSample ? const {0, 1, 2} : const {},
      );

  PaperContent _content;
  final List<PaperContent> _undoHistory = [];
  final List<PaperContent> _redoHistory = [];

  PaperContent get content => _content;
  bool get canUndo => _undoHistory.isNotEmpty;
  bool get canRedo => _redoHistory.isNotEmpty;

  void addInk(PaperTool tool, List<Offset> points) {
    assert(tool != PaperTool.eraser);
    if (points.isEmpty) return;
    commit(
      PaperContent(
        strokes: [
          ...content.strokes,
          PaperStroke(tool, List.unmodifiable(points)),
        ],
        sampleSteps: content.sampleSteps,
      ),
    );
  }

  void commit(PaperContent next) {
    if (identical(next, _content)) return;
    _rememberForUndo();
    _redoHistory.clear();
    _content = next;
  }

  void undo() {
    if (!canUndo) return;
    _redoHistory.add(_content);
    _content = _undoHistory.removeLast();
  }

  void redo() {
    if (!canRedo) return;
    _rememberForUndo();
    _content = _redoHistory.removeLast();
  }

  void _rememberForUndo() {
    if (_undoHistory.length == 24) _undoHistory.removeAt(0);
    _undoHistory.add(_content);
  }
}

bool _eraserHitsSegment(Offset a, Offset b, Offset c, Offset d) {
  const limit = paperEraserRadius * paperEraserRadius;
  if (_distanceToSegmentSquared(c, a, b) <= limit ||
      _distanceToSegmentSquared(d, a, b) <= limit ||
      _distanceToSegmentSquared(a, c, d) <= limit ||
      _distanceToSegmentSquared(b, c, d) <= limit) {
    return true;
  }

  double side(Offset start, Offset end, Offset point) {
    final axis = end - start;
    final relative = point - start;
    return axis.dx * relative.dy - axis.dy * relative.dx;
  }

  return side(a, b, c) * side(a, b, d) < 0 && side(c, d, a) * side(c, d, b) < 0;
}

double _distanceToSegmentSquared(Offset point, Offset start, Offset end) {
  final segment = end - start;
  final lengthSquared = segment.distanceSquared;
  final delta = point - start;
  if (lengthSquared == 0) return delta.distanceSquared;
  final fraction =
      ((delta.dx * segment.dx + delta.dy * segment.dy) / lengthSquared).clamp(
        0.0,
        1.0,
      );
  return (delta - segment * fraction).distanceSquared;
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
