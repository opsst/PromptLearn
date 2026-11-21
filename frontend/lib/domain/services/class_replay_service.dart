import 'class_recording_service.dart';

const maxReplayClipBytes = 50000000;

abstract interface class ClassReplayService {
  Future<ClassReplayDraft> upload(
    RecordingClip clip,
    void Function(int) onProgress,
  );
  Future<void> publish(String recordingId);
}

class ClassReplayDraft {
  const ClassReplayDraft(this.recordingId, this.transcript);

  final String recordingId;
  final List<ClassTranscriptCue> transcript;
}

class ClassTranscriptCue {
  const ClassTranscriptCue(this.start, this.text);

  final Duration start;
  final String text;
}

class ClassReplayException implements Exception {
  const ClassReplayException(this.message);

  final String message;
}
