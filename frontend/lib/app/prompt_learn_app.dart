import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../data/repositories/mock_homework_checker.dart';
import '../data/services/android_class_recording_service.dart';
import '../domain/models/user_role.dart';
import '../domain/repositories/homework_checker.dart';
import '../domain/repositories/role_repository.dart';
import '../domain/services/class_recording_service.dart';
import '../ui/core/layout/app_navigation.dart';
import '../ui/core/layout/app_page_layout.dart';
import '../ui/core/theme/app_theme.dart';
import '../ui/features/assessment/views/student_homework_view.dart';
import '../ui/features/assessment/widgets/homework_notebook.dart';
import '../ui/features/auth/views/role_selection_view.dart';
import '../ui/features/classroom/views/teacher_class_setup_view.dart';
import '../ui/features/home/views/student_home_view.dart';
import '../ui/features/home/views/teacher_home_view.dart';
import '../ui/features/replay/replay_view_stub.dart'
    if (dart.library.js_interop) '../ui/features/replay/replay_view_web.dart';
import 'http_inspector.dart';

class PromptLearnApp extends StatelessWidget {
  const PromptLearnApp({
    super.key,
    required this.roleRepository,
    this.homeworkChecker = const MockHomeworkChecker(),
    this.classRecording = const AndroidClassRecordingService(),
  });

  final RoleRepository roleRepository;
  final HomeworkChecker homeworkChecker;
  final ClassRecordingService classRecording;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PromptLearn',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      navigatorKey: HttpInspector.navigatorKey,
      navigatorObservers: HttpInspector.navigatorObservers,
      localizationsDelegates: HttpInspector.localizationsDelegates,
      home: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: _RoleGate(
          repository: roleRepository,
          homeworkChecker: homeworkChecker,
          classRecording: classRecording,
        ),
      ),
    );
  }
}

class _RoleGate extends StatefulWidget {
  const _RoleGate({
    required this.repository,
    required this.homeworkChecker,
    required this.classRecording,
  });

  final RoleRepository repository;
  final HomeworkChecker homeworkChecker;
  final ClassRecordingService classRecording;

  @override
  State<_RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<_RoleGate> {
  UserRole? _role;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _restoreRole();
  }

  Future<void> _restoreRole() async {
    UserRole? role;
    try {
      role = await widget.repository.load();
    } on PlatformException {
      // Open the login screen when the saved role cannot be read.
    }
    if (!mounted) return;
    setState(() {
      _role = role;
      _loading = false;
    });
  }

  Future<void> _changeRole(UserRole? role) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (role == null) {
        await widget.repository.clear();
      } else {
        await widget.repository.save(role);
      }
      if (mounted) setState(() => _role = role);
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not change roles. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.ink,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    final role = _role;
    if (role == null) {
      return RoleSelectionView(onSelect: _changeRole, isSaving: _saving);
    }

    return _PromptLearnShell(
      role: role,
      homeworkChecker: widget.homeworkChecker,
      classRecording: widget.classRecording,
      onSwitchRole: () => _changeRole(null),
    );
  }
}

class _PromptLearnShell extends StatefulWidget {
  const _PromptLearnShell({
    required this.role,
    required this.homeworkChecker,
    required this.onSwitchRole,
    required this.classRecording,
  });

  final UserRole role;
  final HomeworkChecker homeworkChecker;
  final ClassRecordingService classRecording;
  final VoidCallback onSwitchRole;

  @override
  State<_PromptLearnShell> createState() => _PromptLearnShellState();
}

class _PromptLearnShellState extends State<_PromptLearnShell> {
  var _destination = AppDestination.home;
  bool _homeDetailOpen = false;
  bool _classLocked = false;
  final _pageKey = GlobalKey();
  late final _homeworkNotebook = HomeworkNotebook();

  @override
  void initState() {
    super.initState();
    if (widget.role == UserRole.teacher && widget.classRecording.isSupported) {
      _restoreActiveClass();
    }
  }

  Future<void> _restoreActiveClass() async {
    try {
      final recording = await widget.classRecording.status();
      if (!mounted || !recording.inProgress) return;
      setState(() {
        _destination = AppDestination.home;
        _homeDetailOpen = true;
      });
    } on PlatformException {
      // Stay on Home when the recording service is unavailable.
    } on MissingPluginException {
      // Leave Home usable on platforms that do not register Android capture.
    }
  }

  bool _canLeaveClass() {
    if (!_classLocked) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('End the class before leaving this page.')),
    );
    return false;
  }

  void _switchRole() {
    if (_canLeaveClass()) widget.onSwitchRole();
  }

  void _selectDestination(AppDestination destination) {
    if (!_canLeaveClass()) return;
    setState(() {
      _destination = destination;
      _homeDetailOpen = false;
    });
  }

  void _openHomeDetail() => setState(() => _homeDetailOpen = true);

  void _closeHomeDetail() => _selectDestination(AppDestination.home);

  Widget _buildHome() {
    const displayName = 'Alexander P.';
    final now = DateTime.now();

    return switch (widget.role) {
      UserRole.teacher => TeacherHomeView(
        displayName: displayName,
        now: now,
        onStartClass: _openHomeDetail,
      ),
      UserRole.student => StudentHomeView(
        displayName: displayName,
        now: now,
        onOpenHomework: _openHomeDetail,
      ),
    };
  }

  Widget _buildPage(BuildContext context, {required bool wide}) {
    if (_destination == AppDestination.home) {
      final home = _buildHome();

      return PopScope(
        canPop: !_homeDetailOpen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _homeDetailOpen && !_classLocked) _closeHomeDetail();
        },
        child: IndexedStack(
          index: _homeDetailOpen ? 1 : 0,
          sizing: StackFit.expand,
          children: [
            ExcludeFocus(excluding: _homeDetailOpen, child: home),
            if (_homeDetailOpen)
              switch (widget.role) {
                UserRole.teacher => TeacherClassSetupView(
                  onBack: _closeHomeDetail,
                  recordingService: widget.classRecording,
                  onNavigationLockChanged: (locked) => _classLocked = locked,
                ),
                UserRole.student => StudentHomeworkView(
                  notebook: _homeworkNotebook,
                  checker: widget.homeworkChecker,
                  onBack: _closeHomeDetail,
                ),
              },
          ],
        ),
      );
    }

    if (kIsWeb && _destination == AppDestination.courses) {
      return SingleChildScrollView(child: ReplayView(role: widget.role));
    }

    return AppPageLayout(
      header: ColoredBox(
        color: AppColors.header,
        child: Padding(
          padding: EdgeInsets.all(wide ? 42 : 20),
          child: Text(
            _destination.label,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final useSidebar =
                constraints.maxWidth >= 600 && constraints.maxHeight >= 480;
            final wide = constraints.maxWidth >= 1000;
            final navigation = AppNavigation(
              destination: _homeDetailOpen && widget.role == UserRole.teacher
                  ? AppDestination.courses
                  : _destination,
              vertical: useSidebar,
              onSwitchRole: _switchRole,
              onSelected: _selectDestination,
            );
            final double inset = wide ? 25 : 12;
            final corners = BorderRadius.circular(wide ? 40 : 24);
            final panel = Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                useSidebar ? 0 : inset,
                inset,
                inset,
                useSidebar ? inset : 0,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: corners,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2465776C),
                      blurRadius: 120,
                      spreadRadius: -25,
                      offset: Offset(0, -3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: corners,
                  child: ColoredBox(
                    color: AppColors.canvas,
                    child: SizedBox.expand(
                      key: _pageKey,
                      child: _buildPage(context, wide: wide),
                    ),
                  ),
                ),
              ),
            );

            if (useSidebar) {
              return Row(
                children: [
                  SizedBox(width: 100, child: navigation),
                  Expanded(child: panel),
                ],
              );
            }
            return Column(
              children: [
                Expanded(child: panel),
                navigation,
              ],
            );
          },
        ),
      ),
    );
  }
}
