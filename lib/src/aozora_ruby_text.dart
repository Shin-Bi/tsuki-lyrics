import 'package:flutter/material.dart';

class AozoraRubyText extends StatelessWidget {
  const AozoraRubyText(
    this.source, {
    super.key,
    this.showRuby = true,
    this.baseStyle,
    this.rubyStyle,
  });

  final String source;
  final bool showRuby;
  final TextStyle? baseStyle;
  final TextStyle? rubyStyle;

  static final _rubyPattern = RegExp(r'｜([^《]+)《([^》]+)》');

  @override
  Widget build(BuildContext context) {
    final effectiveBase =
        baseStyle ??
        Theme.of(context).textTheme.headlineSmall!.copyWith(
          fontWeight: FontWeight.w600,
          height: 1.25,
        );
    final effectiveRuby =
        rubyStyle ??
        Theme.of(context).textTheme.labelSmall!.copyWith(
          color: const Color(0xFF7C6640),
          height: 1.05,
          fontWeight: FontWeight.w600,
        );

    if (!showRuby) {
      return Text(
        source.replaceAllMapped(_rubyPattern, (match) => match.group(1)!),
        style: effectiveBase,
      );
    }

    final segments = <_RubySegment>[];
    var cursor = 0;
    for (final match in _rubyPattern.allMatches(source)) {
      if (match.start > cursor) {
        segments.add(_RubySegment(source.substring(cursor, match.start), ''));
      }
      segments.add(_RubySegment(match.group(1)!, match.group(2)!));
      cursor = match.end;
    }
    if (cursor < source.length) {
      segments.add(_RubySegment(source.substring(cursor), ''));
    }

    return Wrap(
      spacing: 0,
      runSpacing: 5,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: segments
          .map((segment) {
            return Semantics(
              label: segment.reading.isEmpty
                  ? segment.base
                  : '${segment.base}, ${segment.reading}',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 16,
                    child: Text(
                      segment.reading,
                      textAlign: TextAlign.center,
                      style: effectiveRuby,
                    ),
                  ),
                  Text(segment.base, style: effectiveBase),
                ],
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _RubySegment {
  const _RubySegment(this.base, this.reading);

  final String base;
  final String reading;
}
