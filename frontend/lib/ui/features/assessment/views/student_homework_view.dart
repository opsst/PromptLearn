import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/homework_check.dart';
import '../../../../domain/repositories/homework_checker.dart';
import '../../../core/layout/app_page_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/notifications_button.dart';
import '../widgets/homework_notebook.dart';
import '../widgets/homework_paper.dart';

class StudentHomeworkView extends StatefulWidget {
  const StudentHomeworkView({
    super.key,
    required this.notebook,
    required this.checker,
    required this.onBack,
  });

  final HomeworkNotebook notebook;
  final HomeworkChecker checker;
  final VoidCallback onBack;

  @override
  State<StudentHomeworkView> createState() => _StudentHomeworkViewState();
}

class _StudentHomeworkViewState extends State<StudentHomeworkView> {
  static const _pause = Duration(milliseconds: 2500);
  final _captureKey = GlobalKey();

  PaperTool _tool = PaperTool.pen;
  List<Offset> _trace = const [];
  PaperContent? _erasePreview;
  int? _pointer;
  int _revision = 0;
  Timer? _timer;
  bool _checkQueued = false;
  bool _checking = false;
  bool _checkFailed = false;
  HomeworkFeedback? _feedback;

  HomeworkNotebook get _notebook => widget.notebook;
  HomeworkDraft get _draft => _notebook.draft;

  void _stopTimer() {
    _timer?.cancel();
    _checkQueued = false;
  }

  void _workChanged() {
    _stopTimer();
    _revision++;
    _feedback = null;
    _checkFailed = false;
  }

  void _scheduleCheck() {
    if (!_notebook.automatic || !_draft.content.hasWork) return;

    _timer = Timer(_pause, () {
      if (_checking) {
        _checkQueued = true;
      } else {
        unawaited(_check());
      }
    });
  }

  void _startStroke(int pointer, Offset point) {
    if (_pointer != null) return;
    setState(() {
      _workChanged();
      _pointer = pointer;
      _trace = [point];
      if (_tool == PaperTool.eraser) {
        _erasePreview = _draft.content.eraseBetween(point, point);
      }
    });
  }

  void _extendStroke(int pointer, Offset point) {
    if (_pointer != pointer ||
        (_trace.last - point).distanceSquared < 0.000001) {
      return;
    }
    setState(() {
      final preview = _erasePreview;
      if (preview == null) {
        _trace.add(point);
      } else {
        _erasePreview = preview.eraseBetween(_trace.last, point);
        _trace = [point];
      }
    });
  }

  void _finishStroke(int pointer, {required bool cancelled}) {
    if (_pointer != pointer) return;

    final before = _draft.content;
    setState(() {
      if (!cancelled) {
        final preview = _erasePreview;
        if (preview != null) {
          _draft.commit(preview);
        } else {
          _draft.addInk(_tool, _trace);
        }
      }
      _resetStroke();
    });
    if (_draft.content != before) _scheduleCheck();
  }

  void _resetStroke() {
    _pointer = null;
    _trace = const [];
    _erasePreview = null;
  }

  void _selectQuestion(int index) {
    if (_notebook.activeIndex == index) return;
    setState(() {
      _workChanged();
      _resetStroke();
      _notebook.activeIndex = index;
    });
  }

  void _editHistory(VoidCallback edit) {
    setState(() {
      _workChanged();
      edit();
    });
    _scheduleCheck();
  }

  void _submitHomework() {
    if (_pointer != null || !_notebook.canSubmit) return;
    setState(_notebook.submit);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Homework submitted for this session.')),
    );
  }

  Future<void> _check() async {
    if (_checking || _pointer != null || !_draft.content.hasWork) return;
    _stopTimer();
    final revision = _revision;
    final question = HomeworkNotebook.questions[_notebook.activeIndex];

    setState(() {
      _checking = true;
      _checkFailed = false;
    });
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || revision != _revision) return;
      final boundary =
          _captureKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final longestEdge = boundary.size.longestSide;
      final image = await boundary.toImage(
        pixelRatio: math.min(2, 1600 / longestEdge),
      );
      final HomeworkCheckRequest request;
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) {
          throw StateError('Paper snapshot could not be encoded.');
        }
        request = HomeworkCheckRequest(
          question: question,
          paperPng: bytes.buffer.asUint8List(
            bytes.offsetInBytes,
            bytes.lengthInBytes,
          ),
          imageWidth: image.width,
          imageHeight: image.height,
        );
      } finally {
        image.dispose();
      }

      if (!mounted || revision != _revision) return;
      final feedback = await widget.checker
          .check(request)
          .timeout(const Duration(seconds: 20));
      if (mounted && revision == _revision) {
        setState(() => _feedback = feedback);
      }
    } catch (_) {
      if (mounted && revision == _revision) {
        setState(() => _checkFailed = true);
      }
    } finally {
      if (mounted) {
        setState(() => _checking = false);
        if (_checkQueued && _notebook.automatic) {
          unawaited(_check());
        }
      }
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final question = HomeworkNotebook.questions[_notebook.activeIndex];
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = constraints.maxWidth >= 760 ? 32.0 : 12.0;
        return AppPageLayout(
          header: _HomeworkHeader(inset: inset, onBack: widget.onBack),
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE3F4EA),
                  AppColors.canvas,
                  Color(0xFFF0F7E7),
                  AppColors.canvas,
                ],
                stops: [0, 0.30, 0.55, 0.85],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(inset, 16, inset, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProgressCard(
                    notebook: _notebook,
                    onSelect: _selectQuestion,
                    onSubmit: _pointer == null && _notebook.canSubmit
                        ? _submitHomework
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _HomeworkCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Question ${_notebook.activeIndex + 1}',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: _greenInk),
                            ),
                            const _Pill('1 pt'),
                            const _Pill('Show your work'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          question.prompt,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _HomeworkCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _toolbar(),
                        const SizedBox(height: 8),
                        _paper(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _paper() {
    final feedback = _feedback;
    final paper = HomeworkPaper(
      key: const ValueKey('homework-paper'),
      captureKey: _captureKey,
      draft: _draft,
      visibleContent: _erasePreview ?? _draft.content,
      tool: _tool,
      activeTrace: _trace,
      feedback: feedback,
      onDown: _startStroke,
      onMove: _extendStroke,
      onEnd: _finishStroke,
    );
    final Widget? message;
    if (_checkFailed) {
      message = const _FeedbackMessage(
        title: 'Check failed',
        message: 'Tap Snap paper work to try again.',
      );
    } else if (feedback != null) {
      message = _FeedbackMessage(
        title: feedback.isDemo ? 'Demo feedback' : 'Hint',
        message: feedback.hint,
      );
    } else {
      message = null;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              paper,
              if (message != null) ...[const SizedBox(height: 10), message],
            ],
          );
        }

        final region = feedback?.region;
        final showOnRight = region == null || region.right <= 0.62;
        return Stack(
          children: [
            paper,
            if (message != null)
              Positioned(
                top: 12,
                left: showOnRight ? null : 12,
                right: showOnRight ? 12 : null,
                width: math.min(340, constraints.maxWidth * 0.34),
                child: IgnorePointer(child: message),
              ),
          ],
        );
      },
    );
  }

  Widget _toolbar() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 4,
      children: [
        Wrap(
          spacing: 3,
          children: [
            _toolButton('Pen', 'pen.svg', PaperTool.pen),
            _toolButton('Highlighter', 'hl.svg', PaperTool.highlighter),
            _toolButton('Eraser', 'eraser.svg', PaperTool.eraser),
            _historyButton('Undo', _draft.canUndo, _draft.undo),
            _historyButton('Redo', _draft.canRedo, _draft.redo, flipped: true),
          ],
        ),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Flexible(
                  child: Text(
                    'Automatic Checker',
                    style: TextStyle(color: _greenInk),
                  ),
                ),
                const SizedBox(width: 6),
                Semantics(
                  label: 'Automatic Checker',
                  child: Switch(
                    value: _notebook.automatic,
                    onChanged: (enabled) {
                      _stopTimer();
                      setState(() => _notebook.automatic = enabled);
                    },
                  ),
                ),
              ],
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: _greenInk),
              onPressed:
                  !_checking && _draft.content.hasWork && _pointer == null
                  ? _check
                  : null,
              icon: _checking
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.camera_alt_outlined, size: 18),
              label: Text(_checking ? 'Checking…' : 'Snap paper work'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _toolButton(String label, String asset, PaperTool tool) {
    final selected = _tool == tool;
    return Semantics(
      selected: selected,
      child: IconButton(
        tooltip: label,
        isSelected: selected,
        style: IconButton.styleFrom(
          backgroundColor: selected
              ? const Color(0xFFE3F1E8)
              : Colors.transparent,
        ),
        onPressed: _pointer == null ? () => setState(() => _tool = tool) : null,
        icon: SvgPicture.asset(
          'assets/assessment/$asset',
          width: 18,
          height: 18,
          colorFilter: ColorFilter.mode(
            selected ? _greenInk : Colors.black,
            BlendMode.srcIn,
          ),
          excludeFromSemantics: true,
        ),
      ),
    );
  }

  Widget _historyButton(
    String label,
    bool enabled,
    VoidCallback action, {
    bool flipped = false,
  }) {
    final icon = SvgPicture.asset(
      'assets/assessment/undo.svg',
      width: 18,
      height: 18,
      excludeFromSemantics: true,
    );
    return IconButton(
      tooltip: label,
      onPressed: enabled && _pointer == null
          ? () => _editHistory(action)
          : null,
      icon: flipped ? Transform.flip(flipX: true, child: icon) : icon,
    );
  }
}

const _greenInk = Color(0xFF206D50);

class _HomeworkHeader extends StatelessWidget {
  const _HomeworkHeader({required this.inset, required this.onBack});

  final double inset;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ColoredBox(
      color: AppColors.header,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 100),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: inset, vertical: 12),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back to Home',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 24),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Math 101 · Mathematics',
                      style: text.labelSmall?.copyWith(
                        color: AppColors.mutedText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text('HW 3.1 · Mathematics', style: text.titleLarge),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const NotificationsButton(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.notebook,
    required this.onSelect,
    required this.onSubmit,
  });

  final HomeworkNotebook notebook;
  final ValueChanged<int> onSelect;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final activeIndex = notebook.activeIndex;
    final questions = Wrap(
      spacing: 3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'HW 3.1',
          style: text.labelSmall?.copyWith(color: AppColors.mutedText),
        ),
        for (var index = 0; index < HomeworkNotebook.questions.length; index++)
          IconButton(
            tooltip: 'Question ${index + 1}',
            isSelected: index == activeIndex,
            style: IconButton.styleFrom(
              backgroundColor: index == activeIndex
                  ? _greenInk
                  : notebook.hasWorkAt(index)
                  ? const Color(0xFFE3F1E8)
                  : AppColors.canvas,
              minimumSize: const Size.square(36),
              padding: EdgeInsets.zero,
            ),
            onPressed: () => onSelect(index),
            icon: Text(
              '${index + 1}',
              style: text.labelSmall?.copyWith(
                color: index == activeIndex
                    ? Colors.white
                    : AppColors.mutedText,
              ),
            ),
          ),
      ],
    );
    final actions = Wrap(
      spacing: 4,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton(
          tooltip: 'Previous question',
          onPressed: activeIndex > 0 ? () => onSelect(activeIndex - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        IconButton(
          tooltip: 'Next question',
          onPressed: activeIndex < HomeworkNotebook.questions.length - 1
              ? () => onSelect(activeIndex + 1)
              : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        FilledButton(
          onPressed: onSubmit,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          child: Text(notebook.submitted ? 'Submitted' : 'Submit'),
        ),
      ],
    );

    return _HomeworkCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 660) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [questions, actions],
            );
          }
          return Row(
            children: [
              Expanded(child: questions),
              const SizedBox(width: 12),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _HomeworkCard extends StatelessWidget {
  const _HomeworkCard({required this.padding, required this.child});

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1565776C),
            blurRadius: 32,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: AppColors.mutedText),
        ),
      ),
    );
  }
}

class _FeedbackMessage extends StatelessWidget {
  const _FeedbackMessage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5EB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$title  ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _greenInk,
                  ),
                ),
                TextSpan(text: message),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
