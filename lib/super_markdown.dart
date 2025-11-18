
/// super_markdown plugin
library super_markdown;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

class SuperMarkdown extends StatelessWidget {
  final String data;
  final EdgeInsetsGeometry padding;
  final MarkdownStyleSheet? styleSheet;
  final ScrollController? controller;
  final bool selectable;

  const SuperMarkdown({
    super.key,
    required this.data,
    this.padding = const EdgeInsets.all(8),
    this.styleSheet,
    this.controller,
    this.selectable = false,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyleSheet = styleSheet ??
        MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          code: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontFamily: 'monospace'),
        );

    return Padding(
      padding: padding,
      child: MarkdownBody(
        data: data,
        styleSheet: baseStyleSheet,
        selectable: selectable,
        controller: controller,
        extensionSet: md.ExtensionSet.gitHubFlavored,
        inlineSyntaxes: [
          InlineChemSyntax(),
          InlineMathSyntax(),
        ],
        blockSyntaxes: [
          const BlockMathSyntax(),
          ...md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        ],
        builders: {
          'math': MathElementBuilder(),
          'chem': ChemElementBuilder(),
        },
      ),
    );
  }
}

class InlineMathSyntax extends md.InlineSyntax {
  InlineMathSyntax() : super(r'\\\((.+?)\\\)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final tex = match.group(1)?.trim() ?? '';
    parser.addNode(
      md.Element('math', [md.Text(tex)])
        ..attributes['block'] = 'false',
    );
    return true;
  }
}

class BlockMathSyntax extends md.BlockSyntax {
  const BlockMathSyntax();

  @override
  RegExp get pattern => RegExp(r'^\${2}\s*$');

  @override
  bool canEndBlock(md.BlockParser parser) => false;

  @override
  md.Node parse(md.BlockParser parser) {
    parser.advance();
    final buffer = StringBuffer();

    while (!parser.isDone) {
      final line = parser.current;
      if (line.trim() == r'$$') break;
      buffer.writeln(line);
      parser.advance();
    }

    if (!parser.isDone && parser.current.trim() == r'$$') {
      parser.advance();
    }

    final tex = buffer.toString().trim();

    return md.Element('math', [md.Text(tex)])..attributes['block'] = 'true';
  }
}

class InlineChemSyntax extends md.InlineSyntax {
  InlineChemSyntax() : super(r'([A-Z][a-z]?)\\\(_(\d+)\\\)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final symbol = match.group(1) ?? '';
    final sub = match.group(2) ?? '';
    final tex = '$symbol\_$sub';
    parser.addNode(md.Element('chem', [md.Text(tex)]));
    return true;
  }
}

class MathElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final tex = element.textContent.trim();
    final isBlock = element.attributes['block'] == 'true';

    final mathWidget = Math.tex(tex, textStyle: preferredStyle);

    if (isBlock) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(child: mathWidget),
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [mathWidget],
    );
  }
}

class ChemElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final tex = element.textContent.trim();
    return Math.tex(tex, textStyle: preferredStyle);
  }
}
