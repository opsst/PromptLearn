import '../../domain/models/homework_check.dart';
import '../../domain/repositories/homework_checker.dart';

class MockHomeworkChecker implements HomeworkChecker {
  const MockHomeworkChecker();

  @override
  Future<HomeworkFeedback> check(HomeworkCheckRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (request.question.id == homeworkDemoQuestionId &&
        request.demoSampleVisible) {
      return const HomeworkFeedback(
        'Look at step 2. When multiplying powers with the same base, what should happen to the exponents?',
        region: homeworkDemoIssue,
        isDemo: true,
      );
    }

    return const HomeworkFeedback(
      'Snapshot received. This demo can mark the sample step in question 4.',
      isDemo: true,
    );
  }
}
