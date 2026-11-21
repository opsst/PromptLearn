import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/course_syllabus.dart';
import '../../domain/repositories/course_syllabus_repository.dart';

class ApiCourseSyllabusRepository implements CourseSyllabusRepository {
  const ApiCourseSyllabusRepository(this.baseUrl, this.client);

  final Uri baseUrl;
  final http.Client client;
  static const _timeout = Duration(seconds: 70);
  static const _json = {'Content-Type': 'application/json'};

  @override
  Future<List<CurriculumRow>> loadCurriculum(
    int grade, {
    bool english = false,
  }) async {
    final uri = baseUrl
        .resolve('/v1/curriculum/math')
        .replace(
          queryParameters: {
            'grade': '$grade',
            'course_type': 'core',
            if (english) 'language': 'en',
          },
        );
    final catalog = _read(await client.get(uri).timeout(_timeout), 200);
    return [
      for (final group in catalog['groups'] as List)
        for (final row in group['rows'] as List)
          CurriculumRow.fromJson(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<CourseSyllabusDraft> generate(
    CourseSyllabusSelection selection,
  ) async {
    final response = await _post('/v1/syllabi/draft', selection.toJson());
    return CourseSyllabusDraft.fromJson(selection, _read(response, 200));
  }

  @override
  Future<String> save(CourseSyllabusDraft draft) async {
    final response = await _post('/v1/syllabi', draft.toEditJson());
    final id = _read(response, 201)['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('The saved syllabus has no draft ID.');
    }
    return id;
  }

  @override
  Future<SyllabusEditResult> previewEdit(Map<String, Object> edit) async =>
      SyllabusEditResult.fromJson(
        _read(await _post('/v1/syllabi/preview', edit), 200),
      );

  @override
  Future<SyllabusEditResult> saveEdit(
    Map<String, Object> edit, {
    String? id,
  }) async {
    final response = id == null
        ? await _post('/v1/syllabi', edit)
        : await client
              .put(
                baseUrl.resolve('/v1/syllabi/${Uri.encodeComponent(id)}'),
                headers: _json,
                body: jsonEncode(edit),
              )
              .timeout(_timeout);
    final result = SyllabusEditResult.fromJson(
      _read(response, id == null ? 201 : 200),
    );
    if (result.id == null || result.id!.isEmpty) {
      throw const FormatException('The saved syllabus has no draft ID.');
    }
    return result;
  }

  @override
  Future<SyllabusEditResult> publish(String id) async {
    final response = await client
        .post(baseUrl.resolve('/v1/syllabi/${Uri.encodeComponent(id)}/publish'))
        .timeout(_timeout);
    return SyllabusEditResult.fromJson(_read(response, 200));
  }

  Future<http.Response> _post(String path, Map<String, Object> body) {
    return client
        .post(baseUrl.resolve(path), headers: _json, body: jsonEncode(body))
        .timeout(_timeout);
  }

  Map<String, dynamic> _read(http.Response response, int expectedStatus) {
    if (response.statusCode != expectedStatus) {
      try {
        final detail = jsonDecode(utf8.decode(response.bodyBytes));
        if (detail case {'message': final String message}) {
          throw SyllabusRequestException(message);
        }
      } on FormatException {
        // Some endpoints send plain text errors.
      }
      throw SyllabusRequestException(
        'Syllabus API returned ${response.statusCode}.',
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }
}
