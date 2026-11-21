import 'package:flutter/widgets.dart';

import '../widgets/home_header.dart';

class StudentHomeView extends StatelessWidget {
  const StudentHomeView({
    super.key,
    required this.displayName,
    required this.now,
  });

  final String displayName;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return HomeHeader(displayName: displayName, now: now);
  }
}
