import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/services/class_recording_service.dart';
import '../../domain/services/class_replay_service.dart';

class ApiClassReplayService implements ClassReplayService {
  const ApiClassReplayService(this.baseUrl, this.client);

  final Uri baseUrl;
  final http.Client client;

  @override
  Future<ClassReplayDraft> upload(
    RecordingClip clip,
    void Function(int) onProgress,
  ) async {
    final file = File(clip.path);
    try {
      final length = await file.length();
      if (length > maxReplayClipBytes) {
        throw const ClassReplayException('Clips must be 50 MB or smaller.');
      }
      if (length == 0) {
        throw const ClassReplayException('The saved clip is empty.');
      }

      final abort = Completer<void>();
      var bytesSent = 0;
      final stream = file.openRead().map((chunk) {
        bytesSent += chunk.length;
        onProgress(bytesSent * 100 ~/ length);
        return chunk;
      });
      final request =
          http.AbortableMultipartRequest(
              'POST',
              baseUrl.resolve('/api/demo/recordings'),
              abortTrigger: abort.future,
            )
            ..files.add(
              http.MultipartFile('video', stream, length, filename: clip.name),
            );
      final response = await _send(
        request,
        abort,
        const Duration(minutes: 4, seconds: 10),
      );
      final body = _readResponse(response, 201);
      final recordingId = body?['recordingId'];
      if (recordingId is! String || recordingId.isEmpty) {
        throw const ClassReplayException(
          'The server did not return a recording ID.',
        );
      }
      final transcript = body?['transcript'];
      return ClassReplayDraft(recordingId, [
        if (transcript is List)
          for (final cue in transcript)
            if (cue
                case {'startMs': final int startMs, 'text': final String text}
                when startMs >= 0 && text.isNotEmpty)
              ClassTranscriptCue(Duration(milliseconds: startMs), text),
      ]);
    } on FileSystemException {
      throw const ClassReplayException('Could not read the saved clip.');
    }
  }

  @override
  Future<void> publish(String recordingId) async {
    final abort = Completer<void>();
    final request =
        http.AbortableRequest(
            'PUT',
            baseUrl.resolve('/api/demo/publication'),
            abortTrigger: abort.future,
          )
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode({'recordingId': recordingId});
    final response = await _send(request, abort, const Duration(seconds: 30));
    _readResponse(response, 200);
  }

  Future<http.Response> _send(
    http.BaseRequest request,
    Completer<void> abort,
    Duration timeout,
  ) async {
    request.headers['X-Demo-Role'] = 'teacher';
    try {
      return await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(
            timeout,
            onTimeout: () {
              abort.complete();
              throw const ClassReplayException(
                'The server took too long. Try again.',
              );
            },
          );
    } on http.ClientException {
      throw const ClassReplayException(
        'Could not reach the replay server. Try again.',
      );
    }
  }

  Map<String, dynamic>? _readResponse(
    http.Response response,
    int expectedStatus,
  ) {
    Map<String, dynamic>? body;
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is Map<String, dynamic>) body = json;
    } on FormatException {
      // Go's default 404 response is plain text when the replay routes are off.
    }
    if (response.statusCode != expectedStatus) {
      final message = body?['message'];
      throw ClassReplayException(
        message is String && message.isNotEmpty
            ? message
            : 'Replay request failed (HTTP ${response.statusCode}).',
      );
    }
    return body;
  }
}
