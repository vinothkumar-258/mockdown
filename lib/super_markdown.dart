library kashcool_markdown;

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

const Key kKashcoolMarkdownDirectionalityKey =
    ValueKey('kashcool_markdown_directionality');
final RegExp _lineBreakPattern = RegExp(r'\s*\n');
final RegExp _mathBlockPattern = RegExp(r'\$\$');
final RegExp _chemicalMacroPattern = RegExp(r'\\ce\{([^}]*)\}');
final RegExp _chemicalArrowPattern = RegExp(r'->\[(.*?)\]');
final RegExp _chemicalDigitPattern = RegExp(r'([A-Za-z])(\d+)');

/// KashcoolMarkdown
/// Markdown + LaTeX Math + Chemistry support on top of flutter_markdown.
class KashcoolMarkdown extends StatelessWidget {
  final String data;
  final MarkdownStyleSheet? styleSheet;
  final MarkdownStyleSheetBaseTheme? styleSheetTheme;
  final TextDirection? textDirection;
  final TextStyle? style;

  const KashcoolMarkdown({
    super.key,
    required this.data,
    this.styleSheet,
    this.styleSheetTheme,
    this.textDirection,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = _normalizeLineBreaks(data);
    if (_hasUnmatchedMathBlocks(normalized)) {
      return _buildErrorFallback();
    }
    final direction = textDirection ?? Directionality.of(context);
    final parentStyle = style ?? DefaultTextStyle.of(context).style;
    final themeStyleSheet = MarkdownStyleSheet.fromTheme(Theme.of(context));
    final inheritedStyleSheet = MarkdownStyleSheet(
      p: parentStyle,
      h1: parentStyle,
      h2: parentStyle,
      h3: parentStyle,
      h4: parentStyle,
      h5: parentStyle,
      h6: parentStyle,
      em: parentStyle,
      strong: parentStyle,
      del: parentStyle,
      blockquote: parentStyle,
      img: parentStyle,
      checkbox: parentStyle,
      listBullet: parentStyle,
      tableHead: parentStyle,
      tableBody: parentStyle,
    );
    final baseStyleSheet = themeStyleSheet.merge(inheritedStyleSheet);
    final resolvedStyleSheet =
        styleSheet != null ? baseStyleSheet.merge(styleSheet!) : baseStyleSheet;

    return Directionality(
      key: kKashcoolMarkdownDirectionalityKey,
      textDirection: direction,
      child: MarkdownBody(
        data: _appendFlush(normalized),
        extensionSet: md.ExtensionSet.gitHubFlavored,
        inlineSyntaxes: [
          InlineMathSyntax(),
          InlineChemSyntax(),
        ],
        blockSyntaxes: [
          BlockMathSyntax(),
          ...md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        ],
        builders: {
          "math-inline": MathInlineBuilder(),
          "math-block": MathBlockBuilder(),
          "chem-inline": ChemInlineBuilder(),
        },
        styleSheet: resolvedStyleSheet,
        styleSheetTheme: styleSheetTheme,
      ),
    );
  }
}

/// Inline math syntax: \( a^2 + b^2 = c^2 \)
class InlineMathSyntax extends md.InlineSyntax {
  InlineMathSyntax() : super(r'(?:\\\(|\\\\\()(.+?)(?:\\\)|\\\\\))|\$(.+?)\$');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final rawTex = match.group(1) ?? match.group(2) ?? "";
    parser.addNode(md.Element("math-inline", [md.Text(_prepareMath(rawTex))]));
    return true;
  }
}

/// Block math syntax:
/// $$
///  a^2 + b^2 = c^2
/// $$
class BlockMathSyntax extends md.BlockSyntax {
  BlockMathSyntax();

  @override
  RegExp get pattern => RegExp(r'^\$\$\s*$');

  @override
  md.Node parse(md.BlockParser parser) {
    // skip opening $$
    parser.advance();
    final buf = StringBuffer();

    while (!parser.isDone) {
      final line = parser.current.content;
      if (line.trim() == r"$$") break;
      buf.writeln(line);
      parser.advance();
    }

    // skip closing $$
    if (!parser.isDone) {
      parser.advance();
      while (!parser.isDone &&
          parser.current.content.trim().isEmpty &&
          parser.current.content != r"$$") {
        parser.advance();
      }
    }

    final tex = _normalizeEscapedBackslashes(buf.toString());
    return md.Element("math-block", [md.Text(tex)]);
  }
}

/// Chemistry inline syntax: H\(_2\)O, CO\(_2\)
class InlineChemSyntax extends md.InlineSyntax {
  InlineChemSyntax()
      : super(r'([A-Za-z]+)(?:\\\(|\\\\\()_(\d+)(?:\\\)|\\\\\))');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final atom = match.group(1) ?? "";
    final sub = match.group(2) ?? "";
    parser.addNode(md.Element("chem-inline", [md.Text("${atom}_$sub")]));
    return true;
  }
}

/// Builder for inline math nodes.
class MathInlineBuilder extends MarkdownElementBuilder {
  MathInlineBuilder();

  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final tex = _prepareMath(element.textContent);
    return Directionality(
        textDirection: TextDirection.ltr,
        child: _buildMathWidget(tex, preferredStyle));
  }
}

/// Builder for block math nodes.
class MathBlockBuilder extends MarkdownElementBuilder {
  MathBlockBuilder();

  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final tex = _prepareMath(element.textContent);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: _buildMathWidget(tex, preferredStyle),
        ),
      ),
    );
  }

  @override
  bool isBlockElement() => true;
}

/// Builder for inline chemistry nodes.
class ChemInlineBuilder extends MarkdownElementBuilder {
  ChemInlineBuilder();

  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final tex = _prepareMath(element.textContent);
    return Directionality(
        textDirection: TextDirection.ltr,
        child: _buildMathWidget(tex, preferredStyle));
  }
}

final _escapedMathFollow = RegExp(r'[A-Za-z0-9_{}\[\]\(\)\\\^\$]');

bool _shouldCollapseEscapedSlash(String next) {
  return _escapedMathFollow.hasMatch(next);
}

String _normalizeEscapedBackslashes(String input) {
  final buffer = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    if (char == '\\' &&
        i + 1 < input.length &&
        input[i + 1] == '\\' &&
        i + 2 < input.length &&
        _shouldCollapseEscapedSlash(input[i + 2])) {
      buffer.write('\\');
      i++;
      continue;
    }
    buffer.write(char);
  }
  return buffer.toString();
}

String _prepareMath(String raw) {
  final escaped = _normalizeEscapedBackslashes(raw.trim());
  final normalizedChemical = _normalizeChemicalExpressions(escaped);
  return normalizedChemical;
}

String _normalizeChemicalExpressions(String input) {
  return input.replaceAllMapped(_chemicalMacroPattern, (match) {
    var content = match.group(1)!;
    content = content.replaceAllMapped(_chemicalArrowPattern, (arrowMatch) {
      return r'\xrightarrow{' + arrowMatch.group(1)! + '}';
    });
    content = content.replaceAll('->', r'\rightarrow');
    content = content.replaceAllMapped(_chemicalDigitPattern, (digitMatch) {
      return '${digitMatch.group(1)}_{${digitMatch.group(2)}}';
    });
    return content;
  });
}

String _appendFlush(String value) {
  if (value.isEmpty) {
    return value;
  }
  const flushMarker = '\u200B';
  final trimmed = value.trimRight();
  if (trimmed.endsWith(flushMarker)) {
    return trimmed;
  }
  return '$trimmed\n$flushMarker';
}

String _normalizeLineBreaks(String input) {
  return input.replaceAllMapped(_lineBreakPattern, (_) => '\n\n');
}

bool _hasUnmatchedMathBlocks(String input) {
  final count = _mathBlockPattern.allMatches(input).length;
  return count.isOdd;
}

Widget _buildErrorFallback() {
  return const Padding(
    padding: EdgeInsets.all(24),
    child: Center(
      child: Text(
        'Unable to parse the math/chemistry section.',
        textAlign: TextAlign.center,
      ),
    ),
  );
}

Widget _buildMathWidget(String tex, TextStyle? style) {
  final matrix = _buildMatrixWidget(tex, style);
  if (matrix != null) {
    return matrix;
  }
  try {
    return Math.tex(tex, textStyle: style);
  } catch (error, stack) {
    // ignore: avoid_print
    print('Math parsing failed: $error\n$stack');
    return Text('Parser Error: ${error.runtimeType}', style: style);
  }
}

Widget? _buildMatrixWidget(String tex, TextStyle? style) {
  return SelectableMath.tex(tex);
}
