import 'class_recording_service.dart';

const maxReplayClipBytes = 50000000;

abstract interface class ClassReplayService {
  Future<String> upload(RecordingClip clip, void Function(int) onProgress);
  Future<void> publish(String recordingId);
}

class ClassReplayException implements Exception {
  const ClassReplayException(this.message);

  final String message;
}
