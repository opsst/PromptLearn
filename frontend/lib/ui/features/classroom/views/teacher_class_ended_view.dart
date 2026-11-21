import 'dart:async';

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../domain/services/class_recording_service.dart';
import '../../../../domain/services/class_replay_service.dart';
import '../../../core/layout/app_page_layout.dart';
import '../../../core/theme/app_theme.dart';
import '../models/teacher_class_preview.dart';
import '../widgets/local_class_clip_player.dart';

const _ink = Color(0xFF202438);
const _green = Color(0xFF1E6C50);
const _tint = Color(0xFFE3F1E9);
const _line = Color(0xFFE2E9E5);

class TeacherClassEndedView extends StatefulWidget {
  const TeacherClassEndedView({
    super.key,
    required this.clip,
    required this.onBack,
    this.notice,
    this.replayService,
    this.uploadOnOpen = false,
  });

  final RecordingClip clip;
  final VoidCallback onBack;
  final String? notice;
  final ClassReplayService? replayService;
  final bool uploadOnOpen;

  @override
  State<TeacherClassEndedView> createState() => _TeacherClassEndedViewState();
}

class _TeacherClassEndedViewState extends State<TeacherClassEndedView> {
  final _playerKey = GlobalKey<LocalClassClipPlayerState>();
  Duration? _duration;
  int? _uploadPercent;
  ClassReplayDraft? _draft;
  String? get _recordingId => _draft?.recordingId;
  String? _replayError;
  bool _publishing = false;
  bool _published = false;

  bool get _clipTooLarge => widget.clip.sizeBytes > maxReplayClipBytes;

  @override
  void initState() {
    super.initState();
    if (widget.uploadOnOpen) unawaited(_upload());
  }

  Future<void> _upload() async {
    final service = widget.replayService;
    if (service == null ||
        _clipTooLarge ||
        _uploadPercent != null ||
        _recordingId != null) {
      return;
    }
    setState(() {
      _uploadPercent = 0;
      _replayError = null;
    });
    try {
      final draft = await service.upload(widget.clip, (percent) {
        if (mounted && percent != _uploadPercent) {
          setState(() => _uploadPercent = percent);
        }
      });
      if (mounted) setState(() => _draft = draft);
    } on ClassReplayException catch (error) {
      if (mounted) setState(() => _replayError = error.message);
    } finally {
      if (mounted) setState(() => _uploadPercent = null);
    }
  }

  Future<void> _publish() async {
    final service = widget.replayService;
    final id = _recordingId;
    if (service == null || id == null || _publishing || _published) return;
    setState(() {
      _publishing = true;
      _replayError = null;
    });
    try {
      await service.publish(id);
      if (mounted) setState(() => _published = true);
    } on ClassReplayException catch (error) {
      if (mounted) setState(() => _replayError = error.message);
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(letterSpacingFactor: 0),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inset = constraints.maxWidth >= 900 ? 48.0 : 16.0;
          final wide = constraints.maxWidth - inset * 2 >= 810;
          final player = _ReplayCard(child: _buildClip(context));
          final details = Column(
            spacing: 18,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ReplayCard(
                child: _ReplayStatus(
                  sizeBytes: widget.clip.sizeBytes,
                  uploadPercent: _uploadPercent,
                  ready: _recordingId != null,
                  error: _replayError,
                  canUpload: widget.replayService != null && !_clipTooLarge,
                  onUpload: _upload,
                ),
              ),
              _ReplayCard(child: _buildSharingOptions(context)),
            ],
          );

          return AppPageLayout(
            header: _buildHeader(context, inset: inset, wide: wide),
            body: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.75, -0.64),
                  radius: 0.48,
                  colors: [Color(0xFFCCEFDA), AppColors.canvas],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(inset, 24, inset, 32),
                child: wide
                    ? Row(
                        spacing: 22,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 61, child: player),
                          Expanded(flex: 39, child: details),
                        ],
                      )
                    : Column(
                        spacing: 18,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [player, details],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required double inset,
    required bool wide,
  }) {
    final title = Row(
      spacing: 6,
      children: [
        IconButton(
          tooltip: 'Back to Teacher Home',
          onPressed: widget.onBack,
          icon: const Icon(Icons.chevron_left, color: _ink),
        ),
        Expanded(
          child: Text(
            'Class ended · ${TeacherClassPreview.classroom}',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: _ink),
          ),
        ),
      ],
    );
    final actions = Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 4,
      children: [
        _StatusPill(
          _duration == null
              ? 'Recorded'
              : 'Recorded ${formatClipTime(_duration!)}',
          background: _tint,
          color: _green,
          icon: Icons.check,
        ),
        FilledButton.icon(
          onPressed: _recordingId == null || _publishing || _published
              ? null
              : _publish,
          style: FilledButton.styleFrom(
            disabledBackgroundColor: const Color(0xFF273430),
            disabledForegroundColor: Colors.white70,
            minimumSize: const Size(0, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          icon: Icon(_published ? Icons.check : Icons.send_outlined, size: 17),
          label: Text(
            _published
                ? 'Published'
                : _publishing
                ? 'Publishing…'
                : 'Publish replay',
          ),
        ),
      ],
    );
    return ColoredBox(
      color: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 100),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: inset,
            vertical: wide ? 10 : 4,
          ),
          child: wide
              ? Row(
                  spacing: 12,
                  children: [
                    Expanded(child: title),
                    actions,
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [title, actions],
                ),
        ),
      ),
    );
  }

  Widget _buildClip(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    final savedAt = widget.clip.savedAt;
    final details = [
      if (savedAt != null)
        DateFormat('EEE d MMM yyyy', 'en_US').format(savedAt),
      'P4',
      TeacherClassPreview.lessonTitle,
    ].join(' · ');
    return Column(
      spacing: 14,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          spacing: 12,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  const _ReplayHeading('Class clip'),
                  Text(
                    details,
                    style: typography.bodySmall?.copyWith(
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ),
            ),
            Tooltip(
              message: 'Clip editing is coming soon',
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.content_cut, size: 17),
                label: const Text('Edit'),
              ),
            ),
          ],
        ),
        if (widget.notice case final notice?)
          Text(
            notice,
            style: typography.bodySmall?.copyWith(color: AppColors.mutedText),
          ),
        LocalClassClipPlayer(
          key: _playerKey,
          path: widget.clip.path,
          onDuration: (duration) => setState(() => _duration = duration),
        ),
        const Divider(height: 1, color: _line),
        const _ReplayHeading('Transcript'),
        if (_draft case final draft? when draft.transcript.isNotEmpty)
          Column(
            children: [
              for (final cue in draft.transcript)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _duration == null
                      ? null
                      : () => unawaited(
                          _playerKey.currentState?.seekTo(cue.start),
                        ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                    child: Row(
                      spacing: 14,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatClipTime(cue.start),
                          style: typography.bodyMedium?.copyWith(color: _green),
                        ),
                        Expanded(child: Text(cue.text)),
                      ],
                    ),
                  ),
                ),
            ],
          )
        else
          Text(
            _draft != null ? 'No transcript was returned for this clip.' : 'The transcript will appear here when transcription is complete.',
            style: typography.bodySmall?.copyWith(color: AppColors.mutedText),
          ),
      ],
    );
  }

  Widget _buildSharingOptions(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    return Column(
      spacing: 10,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _ReplayHeading('What to send students'),
            _StatusPill('M.1/1 · 32 students', icon: Icons.group_outlined),
          ],
        ),
        for (var index = 0; index < _sharingOptions.length; index++)
          CheckboxListTile(
            value: index == 0,
            onChanged: null,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            activeColor: _green,
            checkColor: Colors.white,
            title: Text(
              _sharingOptions[index].$1,
              style: typography.titleMedium?.copyWith(color: _ink),
            ),
            subtitle: _sharingOptions[index].$2.isEmpty
                ? null
                : Text(
                    _sharingOptions[index].$2,
                    style: typography.bodySmall?.copyWith(
                      color: AppColors.mutedText,
                    ),
                  ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF2F9ED),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              spacing: 12,
              children: [
                const CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.lime,
                  child: Icon(Icons.trending_up, color: _green, size: 18),
                ),
                Expanded(
                  child: Column(
                    spacing: 3,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Teaching summary',
                        style: typography.titleMedium?.copyWith(color: _ink),
                      ),
                      Text(
                        'Available after replay processing.',
                        style: typography.bodySmall?.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

const _sharingOptions = [
  ('Clip with transcript', 'Students can jump to a timestamp.'),
  ('Homework HW 3.2 · 8 questions', 'Coming soon'),
  ('Let students ask AI Tutor about the clip', 'Coming soon'),
  ('Also share the clip with parents', 'Coming soon'),
];

class _ReplayStatus extends StatelessWidget {
  const _ReplayStatus({
    required this.sizeBytes,
    required this.uploadPercent,
    required this.ready,
    required this.error,
    required this.canUpload,
    required this.onUpload,
  });

  final int sizeBytes;
  final int? uploadPercent;
  final bool ready;
  final String? error;
  final bool canUpload;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final typography = Theme.of(context).textTheme;
    final size = sizeBytes >= 1000000
        ? '${(sizeBytes / 1000000).toStringAsFixed(1)} MB'
        : '${(sizeBytes / 1000).ceil()} KB';
    final sending = uploadPercent != null && uploadPercent! < 100;
    final transcribing = uploadPercent != null && !sending;
    final fileSent = transcribing || ready;
    final steps = [
      (
        'Upload clip',
        fileSent
            ? 'Sent · $size'
            : sending
            ? '$uploadPercent% · $size'
            : 'Saved on this device · $size',
        fileSent,
        sending,
      ),
      (
        'Transcribe audio',
        ready
            ? 'Transcript ready'
            : transcribing
            ? 'กำลังถอดเสียง'
            : 'Waiting for upload',
        ready,
        transcribing,
      ),
      ('Create chapters', 'Coming soon', false, false),
      ('Link exercises to timestamps', 'Coming soon', false, false),
      ('Auto-edit clip', 'Coming soon', false, false),
    ];
    return Column(
      spacing: 12,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ReplayHeading('Preparing the replay'),
        for (final (label, status, done, active) in steps)
          Row(
            spacing: 12,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: done || active ? _tint : AppColors.canvas,
                child: active
                    ? const SizedBox.square(
                        dimension: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        done ? Icons.check : Icons.schedule,
                        size: 15,
                        color: done ? _green : AppColors.mutedText,
                      ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      label,
                      style: typography.titleMedium?.copyWith(color: _ink),
                    ),
                    Text(
                      status,
                      style: typography.bodySmall?.copyWith(
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        if (sizeBytes > maxReplayClipBytes)
          const Text('Clips must be 50 MB or smaller.')
        else if (!canUpload)
          const Text('Connect to the replay server to upload the clip.'),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (canUpload && !ready && uploadPercent == null)
          OutlinedButton.icon(
            onPressed: onUpload,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: Text(error == null ? 'Upload clip' : 'Retry upload'),
          ),
      ],
    );
  }
}

class _ReplayHeading extends StatelessWidget {
  const _ReplayHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontSize: 18, color: _ink),
  );
}

class _ReplayCard extends StatelessWidget {
  const _ReplayCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(
    this.label, {
    this.background = AppColors.canvas,
    this.color = AppColors.mutedText,
    required this.icon,
  });

  final String label;
  final Color background;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      color: background,
      shape: const StadiumBorder(),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Icon(icon, color: color, size: 14),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    ),
  );
}
