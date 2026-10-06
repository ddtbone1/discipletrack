import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Illustrations for empty, waiting, restricted and error states (user
/// decision 2026-10-06), from unDraw (undraw.co, free under the unDraw
/// licence, no attribution required), recoloured to the app's one lime and
/// bundled under `assets/illustrations/` so they work offline.
enum Illustration {
  /// Nothing here yet.
  empty('empty'),

  /// A D Group, its people.
  group('group'),

  /// Joining or being added to something.
  join('join'),

  /// Lessons and reading.
  reading('reading'),

  /// Not available to this person.
  restricted('restricted'),

  /// No connection.
  offline('offline'),

  /// Something failed.
  error('error'),

  /// All done; nothing left to do.
  complete('complete'),

  /// Waiting on someone else.
  waiting('waiting');

  const Illustration(this.file);

  final String file;

  String get asset => 'assets/illustrations/$file.svg';
}

/// One illustration, decorative: hidden from screen readers, since the
/// text beside it says everything.
class IllustrationView extends StatelessWidget {
  const IllustrationView(this.illustration, {this.height = 140, super.key});

  final Illustration illustration;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SvgPicture.asset(
        illustration.asset,
        height: height,
        fit: BoxFit.contain,
      ),
    );
  }
}
