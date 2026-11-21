import '../models/homework_check.dart';

abstract interface class HomeworkChecker {
  Future<HomeworkFeedback> check(HomeworkCheckRequest request);
}
