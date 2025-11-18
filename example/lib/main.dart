
import 'package:flutter/material.dart';
import 'package:super_markdown/super_markdown.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const DemoScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  final controller = TextEditingController(
    text: "# Test Super Markdown\n\nInline math: \\( a^2 + b^2 = c^2 \\)\n\nBlock:\n$$\n\\int_0^1 x^2 dx = 1/3\n$$\n\nChemistry: H\\(_2\\)O, CO\\(_2\\)\n",
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Super Markdown Example")),
      body: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: SuperMarkdown(data: controller.text),
          ),
        ],
      ),
    );
  }
}
