import 'package:flutter/material.dart';
import 'package:adaptive_scroller/adaptive_scroller.dart';
import 'dart:math';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Adaptive Scroller Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const int _itemCount = 10000;

  late final AdaptiveScrollMetricsController _metricsController;
  late final AdaptiveScrollController _scrollController;
  final TextEditingController _textController = TextEditingController();
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _metricsController = AdaptiveScrollMetricsController(itemCount: _itemCount);
    _scrollController =
        AdaptiveScrollController(metricsController: _metricsController);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _jumpTo() {
    final index = int.tryParse(_textController.text);
    if (index != null && index >= 0 && index < _itemCount) {
      _scrollController.scrollToIndex(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adaptive Scroller Example'),
      ),
      body: Column(
        children: [
          // --- UI for controlling the scroll ---
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      labelText: 'Jump to index (0-9999)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _jumpTo,
                  child: const Text('Jump'),
                ),
              ],
            ),
          ),
          // --- The ListView using the adaptive scroller ---
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _itemCount,
              itemBuilder: (context, index) {
                // Use SizeReportingWidget to measure each item
                return SizeReportingWidget(
                  // The 'onSizeChange' parameter is required
                  onSizeChange: (size) =>
                      _metricsController.updateItemHeight(index, size.height),
                  child: Card(
                    color: Colors
                        .primaries[index % Colors.primaries.length].shade100,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      // Create items with variable height
                      child: Text(
                        'Item $index\n' * (_random.nextInt(3) + 1),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
