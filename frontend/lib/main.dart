import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app/http_inspector.dart';
import 'app/prompt_learn_app.dart';
import 'data/repositories/api_assessment_rubric_generator.dart';
import 'data/repositories/api_assistant_repository.dart';
import 'data/repositories/api_course_syllabus_repository.dart';
import 'data/repositories/api_homework_checker.dart';
import 'data/repositories/local_role_repository.dart';
import 'data/services/api_class_replay_service.dart';
import 'data/services/api_http_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await Firebase.initializeApp();
  }

  final roleRepository = LocalRoleRepository(SharedPreferencesAsync());
  const apiBase = String.fromEnvironment('PROMPTLEARN_API_BASE_URL');
  if (apiBase.isEmpty) {
    runApp(PromptLearnApp(roleRepository: roleRepository));
  } else {
    final base = Uri.tryParse(apiBase);
    if (base == null ||
        !base.hasAuthority ||
        base.host.isEmpty ||
        (base.scheme != 'http' && base.scheme != 'https')) {
      throw ArgumentError('PROMPTLEARN_API_BASE_URL must be an HTTP(S) URL.');
    }
    final client = http.Client();
    runApp(
      PromptLearnApp(
        roleRepository: roleRepository,
        homeworkChecker: ApiHomeworkChecker(base, client),
        assessmentRubricGenerator: ApiAssessmentRubricGenerator(base, client),
        assistantRepository: ApiAssistantRepository(base, client),
        syllabusRepository: ApiCourseSyllabusRepository(
          base,
          createApiHttpClient(),
        ),
        classReplay: ApiClassReplayService(base, createApiHttpClient()),
      ),
    );
  }
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(HttpInspector.initialize());
  });
}
