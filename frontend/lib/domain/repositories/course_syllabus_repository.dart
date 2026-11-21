import '../models/course_syllabus.dart';

abstract interface class CourseSyllabusRepository {
  Future<List<CurriculumRow>> loadCurriculum(int grade, {bool english = false});
  Future<CourseSyllabusDraft> generate(CourseSyllabusSelection selection);
  Future<String> save(CourseSyllabusDraft draft);
  Future<SyllabusEditResult> previewEdit(Map<String, Object> edit);
  Future<SyllabusEditResult> saveEdit(Map<String, Object> edit, {String? id});
  Future<SyllabusEditResult> publish(String id);
}
