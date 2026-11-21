import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/homework_check.dart';
import '../../../core/theme/app_theme.dart';
import 'homework_notebook.dart';

class HomeworkPaper extends StatelessWidget {
  const HomeworkPaper({
    super.key,
    required this.captureKey,
    required this.draft,
    required this.tool,
    required this.activeTrace,
    required this.feedbackRegion,
    required this.onDown,
    required this.onMove,
    required this.onEnd,
  });

  final GlobalKey captureKey;
  final HomeworkDraft draft;
  final PaperTool tool;
  final List<Offset> activeTrace;
  final PaperRegion? feedbackRegion;
  final void Function(int pointer, Offset point) onDown;
  final void Function(int pointer, Offset point) onMove;
  final void Function(int pointer, {required bool cancelled}) onEnd;

  @override
  Widget build(BuildContext context) {
    final drawsInk = tool == PaperTool.pen || tool == PaperTool.highlighter;
    return AspectRatio(
      aspectRatio: 2.24,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE1E8E3), width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              Offset normalize(Offset point) => Offset(
                (point.dx / constraints.maxWidth).clamp(0.0, 1.0),
                (point.dy / constraints.maxHeight).clamp(0.0, 1.0),
              );

              return RawGestureDetector(
                gestures: {
                  EagerGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        EagerGestureRecognizer
                      >(EagerGestureRecognizer.new, (_) {}),
                },
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) =>
                      onDown(event.pointer, normalize(event.localPosition)),
                  onPointerMove: (event) =>
                      onMove(event.pointer, normalize(event.localPosition)),
                  onPointerUp: (event) =>
                      onEnd(event.pointer, cancelled: false),
                  onPointerCancel: (event) =>
                      onEnd(event.pointer, cancelled: true),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RepaintBoundary(
                        key: captureKey,
                        child: CustomPaint(
                          painter: _InkPainter(
                            draft.content,
                            drawsInk ? PaperStroke(tool, activeTrace) : null,
                          ),
                        ),
                      ),
                      IgnorePointer(
                        child: CustomPaint(
                          painter: _MarkPainter(
                            selection: draft.selection,
                            feedback: feedbackRegion,
                            tool: tool,
                            trace: drawsInk ? const [] : activeTrace,
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
      ),
    );
  }
}

const _inkColor = Color(0xFF293681);

Offset _project(Offset point, Size size) =>
    Offset(point.dx * size.width, point.dy * size.height);

Rect _area(PaperRegion region, Size size) => Rect.fromLTWH(
  region.x * size.width,
  region.y * size.height,
  region.width * size.width,
  region.height * size.height,
);

Path _tracePath(List<Offset> points, Size size) {
  final first = _project(points.first, size);
  final path = Path()..moveTo(first.dx, first.dy);
  for (final point in points.skip(1)) {
    final projected = _project(point, size);
    path.lineTo(projected.dx, projected.dy);
  }
  return path;
}

class _InkPainter extends CustomPainter {
  const _InkPainter(this.content, this.activeStroke);

  final PaperContent content;
  final PaperStroke? activeStroke;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFFFEFEFE), BlendMode.src);
    final dotPaint = Paint()..color = const Color(0xFFDCE6E0);
    for (var y = 16.0; y < size.height; y += 24) {
      for (var x = 16.0; x < size.width; x += 24) {
        canvas.drawCircle(Offset(x, y), 0.9, dotPaint);
      }
    }

    for (final index in content.sampleSteps) {
      final area = _area(sampleRegions[index], size);
      final fontSize = (size.width * 0.032).clamp(13.0, 36.0);
      final text = TextPainter(
        text: TextSpan(
          text: sampleText[index],
          style: TextStyle(
            color: _inkColor,
            fontSize: fontSize,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        area.centerLeft.translate(area.width * 0.08, -text.height / 2),
      );
      text.dispose();
    }

    for (final stroke in content.strokes) {
      _drawStroke(canvas, size, stroke);
    }
    final active = activeStroke;
    if (active != null) _drawStroke(canvas, size, active);
  }

  void _drawStroke(Canvas canvas, Size size, PaperStroke stroke) {
    if (stroke.points.isEmpty) return;
    final highlighted = stroke.tool == PaperTool.highlighter;
    final paint = Paint()
      ..color = highlighted ? const Color(0x70B8E68C) : _inkColor
      ..strokeWidth = highlighted ? 12 : 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (stroke.points.length == 1) {
      canvas.drawCircle(
        _project(stroke.points.first, size),
        paint.strokeWidth / 2,
        paint,
      );
    } else {
      canvas.drawPath(
        _tracePath(stroke.points, size),
        paint..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _InkPainter old) =>
      old.content != content || old.activeStroke != activeStroke;
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({
    required this.selection,
    required this.feedback,
    required this.tool,
    required this.trace,
  });

  final PaperRegion? selection;
  final PaperRegion? feedback;
  final PaperTool tool;
  final List<Offset> trace;

  @override
  void paint(Canvas canvas, Size size) {
    final feedbackRegion = feedback;
    final selectionRegion = selection;
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    if (selectionRegion != null) {
      final path = Path()..addOval(_area(selectionRegion, size));
      for (final metric in path.computeMetrics()) {
        for (var distance = 0.0; distance < metric.length; distance += 12) {
          canvas.drawPath(metric.extractPath(distance, distance + 7), paint);
        }
      }
    }

    if (feedbackRegion != null && feedbackRegion.isValid) {
      canvas.drawOval(_area(feedbackRegion, size), paint..strokeWidth = 3);
    }

    if (trace.isEmpty) return;
    if (tool == PaperTool.lasso) {
      canvas.drawPath(_tracePath(trace, size), paint);
    } else if (tool == PaperTool.eraser) {
      canvas.drawCircle(_project(trace.last, size), 9, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MarkPainter old) => true;
}
