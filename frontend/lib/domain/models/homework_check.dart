import 'dart:typed_data';

class HomeworkQuestion {
  const HomeworkQuestion(this.id, this.prompt);

  final String id;
  final String prompt;
}

/// A box relative to the captured paper, with its origin at the top left.
class PaperRegion {
  const PaperRegion(this.x, this.y, this.width, this.height);

  final double x;
  final double y;
  final double width;
  final double height;

  double get right => x + width;
  double get bottom => y + height;

  bool get isValid =>
      [x, y, width, height].every((value) => value.isFinite) &&
      x >= 0 &&
      y >= 0 &&
      width > 0 &&
      height > 0 &&
      right <= 1.000001 &&
      bottom <= 1.000001;

  bool overlaps(PaperRegion other) =>
      x < other.right &&
      right > other.x &&
      y < other.bottom &&
      bottom > other.y;
}

const homeworkDemoQuestionId = 'hw-3.1-q4';
const homeworkDemoIssue = PaperRegion(0.31, 0.225, 0.21, 0.16);

class HomeworkCheckRequest {
  const HomeworkCheckRequest({
    required this.question,
    required this.paperPng,
    required this.imageWidth,
    required this.imageHeight,
    this.selection,
    this.demoSampleVisible = false,
  });

  final HomeworkQuestion question;
  final Uint8List paperPng;
  final int imageWidth;
  final int imageHeight;
  final PaperRegion? selection;
  final bool demoSampleVisible;
}

class HomeworkFeedback {
  const HomeworkFeedback(this.hint, {this.region, this.isDemo = false});

  final String hint;
  final PaperRegion? region;
  final bool isDemo;
}
