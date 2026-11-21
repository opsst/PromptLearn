import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool get canDownloadSyllabusHtml =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

Future<String?> exportSyllabusHtml({
  required int grade,
  required int term,
  required String html,
}) async {
  if (canDownloadSyllabusHtml) {
    const channel = MethodChannel('promptlearn/syllabus_export');
    final saved = await channel.invokeMethod<bool>('saveHtml', {
      'fileName': 'PromptLearn-M$grade-Semester-$term.html',
      'contents': utf8.encode(html),
    });
    return saved == true ? 'Saved HTML to your device.' : null;
  }
  await Clipboard.setData(ClipboardData(text: html));
  return 'Syllabus HTML copied.';
}
