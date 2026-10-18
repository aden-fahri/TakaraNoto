import 'package:flutter/material.dart';

/// Centers its child and keeps it at a readable width on tablets, desktop
/// and web, where a phone layout would otherwise stretch edge to edge.
class MaxWidthBody extends StatelessWidget {
  const MaxWidthBody({super.key, required this.child, this.maxWidth = 600});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
