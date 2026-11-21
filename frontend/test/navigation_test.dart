import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promptlearn/app/prompt_learn_app.dart';
import 'package:promptlearn/domain/models/user_role.dart';
import 'package:promptlearn/domain/repositories/role_repository.dart';
import 'package:promptlearn/domain/services/class_recording_service.dart';
import 'package:promptlearn/domain/services/class_replay_service.dart';
import 'package:promptlearn/ui/features/classroom/views/teacher_class_ended_view.dart';
import 'package:promptlearn/ui/features/home/views/student_home_view.dart';
import 'package:promptlearn/ui/features/home/views/teacher_home_view.dart';
import 'package:promptlearn/ui/features/home/widgets/home_header.dart';
import 'package:promptlearn/ui/features/syllabus/views/teacher_syllabus_dialog.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  setUpAll(() async {
    final inter = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'));
    await inter.load();
  });

  testWidgets('The app uses the PromptLearn typography and palette', (
    tester,
  ) async {
    await _openApp(tester, _MemoryRoleRepository(UserRole.teacher));
    final theme = Theme.of(tester.element(find.byType(HomeHeader)));

    expect(theme.textTheme.titleLarge?.fontFamily, 'Inter');
    expect(theme.textTheme.titleLarge?.fontSize, 26);
    expect(theme.textTheme.bodyMedium?.fontSize, 15);
    expect(theme.textTheme.bodySmall?.fontSize, 13);
    expect(theme.colorScheme.primary, const Color(0xFF32A060));
    expect(theme.colorScheme.primaryContainer, const Color(0xFF52C883));
    expect(theme.colorScheme.secondaryContainer, const Color(0xFFAFE6A2));
    expect(theme.colorScheme.tertiaryContainer, const Color(0xFFB8E68C));
    expect(theme.colorScheme.secondary, const Color(0xFF6AC08F));
  });

  for (final size in [
    const Size(1366, 1024),
    const Size(800, 1200),
    const Size(620, 480),
    const Size(360, 640),
    const Size(800, 360),
  ]) {
    testWidgets('Navigation and notifications work at $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _openApp(tester, _MemoryRoleRepository(UserRole.student));
      expect(find.textContaining('Alexander P.'), findsOneWidget);
      expect(find.byTooltip('Switch login role'), findsOneWidget);

      final notifications = find.byTooltip('Notifications');
      expect(tester.getSize(notifications), const Size.square(48));
      if (size.width == 1366) {
        expect(tester.getSize(find.byType(HomeHeader)).height, 100);
      }
      await tester.tap(notifications);
      await tester.pumpAndSettle();
      expect(find.text('Welcome to PromptLearn.'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      for (final destination in ['Courses', 'Learning tools', 'Profile']) {
        await tester.tap(find.byTooltip(destination));
        await tester.pumpAndSettle();
        expect(find.text(destination), findsOneWidget);
      }

      await tester.tap(find.byTooltip('Home'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Alexander P.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [
    const Size(1366, 1024),
    const Size(800, 1200),
    const Size(360, 640),
  ]) {
    testWidgets('Teacher dashboard and lesson plan work at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _openApp(tester, _MemoryRoleRepository(UserRole.teacher));

      final startClass = find.text('Start Class');
      final today = find.text('Today');
      final lessonPlan = find.text('Lesson Plan');
      expect(find.text('Needs your attention'), findsOneWidget);
      expect(find.text('Class pulse'), findsOneWidget);
      expect(find.text('My syllabus'), findsOneWidget);

      if (size.width == 1366) {
        expect(tester.getSize(find.byType(HomeHeader)).height, 100);
        expect(
          tester.getSize(find.byTooltip('Notifications')),
          const Size.square(48),
        );
        expect(tester.widget<Text>(today).style?.fontSize, 16);
        expect(tester.widget<Text>(startClass).style?.fontSize, 14);

        final dashboard = find.descendant(
          of: find.byType(TeacherHomeView),
          matching: find.byType(Scrollable),
        );
        final position = tester.state<ScrollableState>(dashboard).position;
        expect(position.maxScrollExtent, 0);
        expect(find.text('Create syllabus').hitTestable(), findsOneWidget);
        expect(
          tester.getTopLeft(today).dx,
          greaterThan(tester.getTopLeft(startClass).dx),
        );
        expect(
          tester.getTopLeft(today).dy,
          lessThan(tester.getTopLeft(startClass).dy),
        );
      } else {
        expect(
          tester.getTopLeft(today).dy,
          greaterThan(tester.getTopLeft(startClass).dy),
        );
      }

      await tester.ensureVisible(lessonPlan);
      await tester.tap(lessonPlan);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Warm-up'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(1366, 1024), const Size(360, 640)]) {
    testWidgets('Teacher can configure and teach without recording at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _openApp(tester, _MemoryRoleRepository(UserRole.teacher));

      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tap(find.text('Start Class'));

      final title = find.text('M.1/1 · Period 25').hitTestable();
      final position = tester.getTopLeft(title);
      final options = find.text('Before you start');
      final plan = find.text('This period’s plan');
      expect(find.text('Start teaching & recording'), findsOneWidget);
      if (size.width == 1366) {
        expect(tester.getTopLeft(plan).dy, tester.getTopLeft(options).dy);
        expect(
          tester.getTopLeft(plan).dx,
          greaterThan(tester.getTopLeft(options).dx),
        );
      } else {
        expect(
          tester.getTopLeft(plan).dy,
          greaterThan(tester.getTopLeft(options).dy),
        );
      }

      await tap(find.text('Open lesson plan'));
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Warm-up'),
        ),
        findsOneWidget,
      );
      await tap(find.text('Close'));
      await tap(find.text('Whole screen'));
      await tap(find.byType(Switch).first);
      await tap(find.text('Test mic & screen'));
      expect(
        find.textContaining('Selected source: Whole screen'),
        findsOneWidget,
      );
      await tap(find.text('Close'));
      expect(tester.getTopLeft(title), position);

      await tap(find.text('Start teaching'));
      expect(find.text('Teaching · M.1/1'), findsOneWidget);
      expect(find.text('Recording off'), findsOneWidget);
      expect(find.textContaining('slide 1 / 14'), findsOneWidget);
      await tap(find.byTooltip('Next slide'));
      expect(find.textContaining('slide 2 / 14'), findsOneWidget);
      expect(
        find.text('Invite one student to read the expression aloud.'),
        findsOneWidget,
      );
      await tap(find.byTooltip('Previous slide'));
      expect(find.textContaining('slide 1 / 14'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('End this class?'), findsOneWidget);
      await tap(find.text('Keep teaching'));
      await tap(find.text('Stop & end class'));
      expect(find.text('Start Class').hitTestable(), findsOneWidget);
      await tap(find.text('Start Class'));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Start Class').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    debugManualVideoUpload
        ? 'Ending a recording opens the preview and waits for Test video upload'
        : 'Ending a recording opens the preview and starts uploading the saved clip',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final recording = _FakeClassRecordingService();
      final replay = _FakeClassReplayService();
      addTearDown(recording.dispose);
      final originalPlayer = VideoPlayerPlatform.instance;
      final video = _FakeVideoPlayerPlatform();
      VideoPlayerPlatform.instance = video;
      addTearDown(() => VideoPlayerPlatform.instance = originalPlayer);
      await _openApp(
        tester,
        _MemoryRoleRepository(UserRole.teacher),
        recording: recording,
        replay: replay,
      );

      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tap(find.text('Start Class'));
      await tap(find.text('Whole screen'));
      recording.cancelNextStart = true;
      await tap(find.text('Start teaching & recording'));
      expect(find.text('Screen sharing was cancelled.'), findsOneWidget);
      expect(find.text('Start teaching & recording'), findsOneWidget);

      await tap(find.text('Start teaching & recording'));
      expect(recording.source, RecordingSource.screen);
      expect(find.text('Starting recording…'), findsOneWidget);
      expect(find.text('Teaching · M.1/1'), findsNothing);

      recording.emit(
        const RecordingStatus(
          phase: RecordingPhase.recording,
          source: RecordingSource.screen,
          elapsed: Duration(seconds: 3),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('REC  00:00:03'), findsOneWidget);

      await tap(find.byTooltip('Home'));
      expect(find.text('Teaching · M.1/1'), findsOneWidget);

      await tap(find.text('Stop & end class'));
      expect(recording.stopCount, 1);
      expect(find.text('Saving recording…'), findsOneWidget);
      expect(replay.uploadedPaths, isEmpty);

      recording.emit(
        const RecordingStatus(
          phase: RecordingPhase.saved,
          source: RecordingSource.screen,
          clip: RecordingClip(
            path: '/recordings/class.mp4',
            name: 'class.mp4',
            sizeBytes: 1024,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Class ended · M.1/1'), findsOneWidget);
      FilledButton publishButton(String label) => tester.widget<FilledButton>(
        find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((widget) => widget is FilledButton),
        ),
      );
      Finder uploadButton(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((widget) => widget is OutlinedButton),
      );
      expect(publishButton('Publish replay').onPressed, isNull);
      expect(uploadButton('Upload clip'), findsNothing);
      final testUpload = uploadButton('Test video upload');
      if (debugManualVideoUpload) {
        expect(replay.uploadedPaths, isEmpty);
        await tester.tap(testUpload);
        await tester.pump();
        expect(tester.widget<OutlinedButton>(testUpload).onPressed, isNull);
      } else {
        expect(testUpload, findsNothing);
      }
      expect(replay.uploadedPaths, ['/recordings/class.mp4']);

      replay.reportProgress!(45);
      await tester.pump();
      expect(find.textContaining('45%'), findsOneWidget);
      replay.reportProgress!(100);
      await tester.pump();
      expect(find.text('กำลังถอดเสียง'), findsOneWidget);
      expect(publishButton('Publish replay').onPressed, isNull);

      replay.uploadResult.completeError(
        const ClassReplayException('Upload failed.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Upload failed.'), findsOneWidget);
      expect(find.text('Recorded 00:46'), findsOneWidget);
      expect(video.source?.sourceType, DataSourceType.file);
      expect(
        Uri.parse(video.source!.uri!).toFilePath(),
        '/recordings/class.mp4',
      );

      await tap(find.byTooltip('Play clip'));
      expect(video.playCount, 1);
      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged!(15000);
      slider.onChangeEnd!(15000);
      await tester.pumpAndSettle();
      expect(video.position, const Duration(seconds: 15));

      await tester.binding.setSurfaceSize(const Size(360, 640));
      await tester.pumpAndSettle();
      expect(video.createCount, 1);
      expect(find.text('00:15 / 00:46'), findsOneWidget);
      await tap(find.byTooltip('Pause clip'));

      final retryUpload = debugManualVideoUpload
          ? testUpload
          : uploadButton('Retry upload');
      await tester.ensureVisible(retryUpload);
      await tester.pumpAndSettle();
      await tester.tap(retryUpload);
      await tester.pump();
      expect(replay.uploadedPaths, List.filled(2, '/recordings/class.mp4'));
      replay.uploadResult.complete(
        const ClassReplayDraft('class-replay-id', [
          ClassTranscriptCue(Duration(milliseconds: 5250), 'มาลองแก้สมการ'),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Transcript ready'), findsOneWidget);
      expect(find.text('00:05'), findsOneWidget);
      await tap(find.text('มาลองแก้สมการ'));
      expect(video.position, const Duration(milliseconds: 5250));

      await tap(find.text('Publish replay'));
      expect(publishButton('Publishing…').onPressed, isNull);
      replay.publishResult.completeError(
        const ClassReplayException('Publish failed.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Publish failed.'), findsOneWidget);
      await tap(find.text('Publish replay'));
      expect(replay.publishedIds, List.filled(2, 'class-replay-id'));
      expect(replay.uploadedPaths, hasLength(2));
      replay.publishResult.complete();
      await tester.pumpAndSettle();
      expect(publishButton('Published').onPressed, isNull);
      expect(find.text('มาลองแก้สมการ'), findsOneWidget);

      await tap(find.byTooltip('Back to Teacher Home'));
      expect(find.text('Class ended · M.1/1'), findsNothing);
      expect(find.text('Start Class').hitTestable(), findsOneWidget);
      await tap(find.text('Start Class'));
      await tap(find.text('Last recording'));
      expect(find.text('Class ended · M.1/1'), findsOneWidget);
      expect(replay.uploadedPaths, hasLength(2));
      expect(
        debugManualVideoUpload ? testUpload : uploadButton('Upload clip'),
        findsOneWidget,
      );
      expect(video.createCount, 2);
      await tap(find.byTooltip('Back to Teacher Home'));
      expect(find.text('Class ended · M.1/1'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Teacher Home keeps the lesson summary alongside on a tablet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1164, 777));
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 32, bottom: 16);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    await _openApp(tester, _MemoryRoleRepository(UserRole.teacher));

    final startClass = find.text('Start Class');
    final today = find.text('Today');
    final flow = find.text('Lesson flow · 50 min');
    expect(
      tester.getTopLeft(flow).dx,
      greaterThan(tester.getTopLeft(startClass).dx),
    );
    expect(
      tester.getTopLeft(flow).dy,
      lessThan(tester.getTopLeft(startClass).dy),
    );
    expect(
      tester.getTopLeft(today).dx,
      greaterThan(tester.getTopLeft(flow).dx),
    );
    expect(find.text('Needs your attention').hitTestable(), findsOneWidget);

    await tester.ensureVisible(find.text('Create syllabus'));
    await tester.pumpAndSettle();
    expect(find.text('Create syllabus').hitTestable(), findsOneWidget);
    expect(tester.getSize(find.byType(HomeHeader)).height, 100);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(1366, 768), const Size(360, 640)]) {
    testWidgets('Teacher header stays visible when scrolling at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _openApp(tester, _MemoryRoleRepository(UserRole.teacher));

      final header = find.byType(HomeHeader);
      final notifications = find.byTooltip('Notifications');
      final navigation = find.byTooltip('Home');
      final cards = find.descendant(
        of: find.byType(TeacherHomeView),
        matching: find.byType(SingleChildScrollView),
      );
      final today = find.text('Today');
      final headerPosition = tester.getTopLeft(header);
      final navPosition = tester.getCenter(navigation);
      final initialTodayY = tester.getTopLeft(today).dy;

      await tester.drag(cards, const Offset(0, -350));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(today).dy, lessThan(initialTodayY));
      expect(tester.getTopLeft(header), headerPosition);
      expect(tester.getCenter(navigation), navPosition);

      await tester.tap(notifications);
      await tester.pumpAndSettle();
      expect(find.text('Welcome to PromptLearn.'), findsOneWidget);
    });
  }

  for (final size in [const Size(1366, 1024), const Size(360, 640)]) {
    testWidgets('See all opens the syllabus catalog at $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _openApp(tester, _MemoryRoleRepository(UserRole.teacher));

      final seeAll = find.text('See all');
      await tester.ensureVisible(seeAll);
      await tester.tap(seeAll);
      await tester.pumpAndSettle();

      final modal = find.byType(TeacherSyllabusDialog);
      Finder inModal(String label) =>
          find.descendant(of: modal, matching: find.text(label));

      expect(inModal('My Syllabus'), findsOneWidget);
      expect(inModal('Published'), findsNWidgets(3));
      expect(inModal('Draft · step 3 of 6'), findsOneWidget);
      expect(inModal('3 classes · 94 students'), findsOneWidget);
      expect(inModal('Math 102'), findsOneWidget);

      final math101 = tester.getTopLeft(inModal('Math 101'));
      final math201 = tester.getTopLeft(inModal('Math 201'));
      final math301 = tester.getTopLeft(inModal('Math 301'));
      final math102 = tester.getTopLeft(inModal('Math 102'));
      if (size.width == 1366) {
        expect(math201.dy, math101.dy);
        expect(math301.dy, math101.dy);
        expect(math201.dx, greaterThan(math101.dx));
        expect(math301.dx, greaterThan(math201.dx));
        expect(math102.dy, greaterThan(math101.dy));
      } else {
        expect(math201.dx, math101.dx);
        expect(math201.dy, greaterThan(math101.dy));
      }

      final create = inModal('Create syllabus');
      await tester.ensureVisible(create);
      await tester.pumpAndSettle();
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(
        find.text('The syllabus editor is unavailable in this preview.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close syllabus'));
      await tester.pumpAndSettle();
      expect(modal, findsNothing);
      expect(seeAll, findsOneWidget);
    });
  }

  testWidgets('Math homework on Student Home opens the worksheet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _openApp(tester, _MemoryRoleRepository(UserRole.student));

    final assignment = find.text('HW 3.1 · Exponent practice');
    await tester.ensureVisible(assignment);
    await tester.pumpAndSettle();
    await tester.tap(assignment);
    await tester.pumpAndSettle();

    final title = find.text('HW 3.1 · Mathematics');
    expect(title, findsOneWidget);
    expect(find.text('Question 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Next question'));
    await tester.pumpAndSettle();

    await tester.binding.setSurfaceSize(const Size(800, 480));
    await tester.pumpAndSettle();
    final headerOffset = tester.getTopLeft(title);
    final question = find.text('Question 2');
    final questionOffset = tester.getTopLeft(question);
    await tester.drag(question, const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(question).dy, lessThan(questionOffset.dy));
    expect(tester.getTopLeft(title), headerOffset);

    await tester.binding.setSurfaceSize(const Size(1366, 1024));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back to Home'));
    await tester.pumpAndSettle();
    expect(assignment.hitTestable(), findsOneWidget);
    await tester.tap(assignment);
    await tester.pumpAndSettle();
    expect(find.text('Question 2'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(assignment.hitTestable(), findsOneWidget);
  });

  testWidgets('Remembers the login role until the logo is tapped', (
    tester,
  ) async {
    final repository = _MemoryRoleRepository();
    await _openApp(tester, repository);
    expect(find.text('Login as Teacher'), findsOneWidget);
    expect(find.text('Login as Student'), findsOneWidget);

    await tester.tap(find.text('Login as Teacher'));
    await tester.pumpAndSettle();
    expect(find.byType(TeacherHomeView), findsOneWidget);
    expect(find.byType(StudentHomeView), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await _openApp(tester, repository);
    expect(find.byType(TeacherHomeView), findsOneWidget);
    expect(find.byType(StudentHomeView), findsNothing);

    await tester.tap(find.byTooltip('Courses'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch login role'));
    await tester.pumpAndSettle();
    expect(repository.role, isNull);
    expect(find.text('Login as Student'), findsOneWidget);

    await tester.tap(find.text('Login as Student'));
    await tester.pumpAndSettle();
    expect(repository.role, UserRole.student);
    expect(find.byType(StudentHomeView), findsOneWidget);
    expect(find.byType(TeacherHomeView), findsNothing);
    expect(find.textContaining('Alexander P.'), findsOneWidget);
  });
}

Future<void> _openApp(
  WidgetTester tester,
  RoleRepository repository, {
  ClassRecordingService? recording,
  ClassReplayService? replay,
}) async {
  await tester.pumpWidget(
    recording == null
        ? PromptLearnApp(roleRepository: repository)
        : PromptLearnApp(
            roleRepository: repository,
            classRecording: recording,
            classReplay: replay,
          ),
  );
  await tester.pumpAndSettle();
}

class _FakeClassReplayService implements ClassReplayService {
  final uploadedPaths = <String>[];
  final publishedIds = <String>[];
  void Function(int)? reportProgress;
  late Completer<ClassReplayDraft> uploadResult;
  late Completer<void> publishResult;

  @override
  Future<ClassReplayDraft> upload(
    RecordingClip clip,
    void Function(int) onProgress,
  ) {
    uploadedPaths.add(clip.path);
    reportProgress = onProgress;
    uploadResult = Completer<ClassReplayDraft>();
    return uploadResult.future;
  }

  @override
  Future<void> publish(String recordingId) {
    publishedIds.add(recordingId);
    publishResult = Completer<void>();
    return publishResult.future;
  }
}

class _MemoryRoleRepository implements RoleRepository {
  _MemoryRoleRepository([this.role]);

  UserRole? role;

  @override
  Future<UserRole?> load() async => role;

  @override
  Future<void> save(UserRole role) async {
    this.role = role;
  }

  @override
  Future<void> clear() async {
    role = null;
  }
}

class _FakeClassRecordingService implements ClassRecordingService {
  final _updates = StreamController<RecordingStatus>.broadcast();
  RecordingStatus _status = const RecordingStatus();
  RecordingSource? source;
  bool cancelNextStart = false;
  int stopCount = 0;

  @override
  bool get isSupported => true;

  @override
  Stream<RecordingStatus> get updates => _updates.stream;

  void emit(RecordingStatus status) {
    _status = status;
    _updates.add(status);
  }

  @override
  Future<RecordingStatus> status() async => _status;

  @override
  Future<void> start(RecordingSource source) async {
    this.source = source;
    if (cancelNextStart) {
      cancelNextStart = false;
      throw PlatformException(
        code: 'cancelled',
        message: 'Screen sharing was cancelled.',
      );
    }
    emit(RecordingStatus(phase: RecordingPhase.starting, source: source));
  }

  @override
  Future<void> stop() async {
    stopCount++;
    emit(RecordingStatus(phase: RecordingPhase.saving, source: source));
  }

  @override
  Future<List<RecordingClip>> savedClips() async => [?_status.clip];

  Future<void> dispose() => _updates.close();
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final _streams = <int, StreamController<VideoEvent>>{};
  DataSource? source;
  int playCount = 0;
  int createCount = 0;
  Duration position = Duration.zero;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    source = options.dataSource;
    position = Duration.zero;
    return ++createCount;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    final stream = StreamController<VideoEvent>();
    _streams[playerId] = stream;
    stream.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 46),
        size: const Size(1600, 1000),
      ),
    );
    return stream.stream;
  }

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.expand();

  @override
  Future<void> dispose(int playerId) async {
    await _streams.remove(playerId)?.close();
  }

  @override
  Future<void> play(int playerId) async => playCount++;

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<Duration> getPosition(int playerId) async => position;

  @override
  Future<void> seekTo(int playerId, Duration position) async =>
      this.position = position;

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
}
