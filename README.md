A smart Flutter scroll controller designed to efficiently manage long lists with variable-height items. This package was developed by Chun Ngok Lau (Philip) in close collaboration with Google's Gemini AI assistant.

The `AdaptiveScrollController` provides methods to jump or scroll to any index in a list, even if the items have not been rendered yet. It achieves this by maintaining a running average of item heights and calculating an estimated scroll position for large jumps.

## The "Adaptive" Feature

The key feature of this package is its ability to **adapt**. When you first jump to a distant, un-rendered item, the scroll position is an estimate. It might not be perfectly accurate because the controller doesn't know the real height of every item in between.

However, as the user scrolls and more items are rendered on screen, the `AdaptiveScrollController` uses the `SizeReportingWidget` to learn their actual heights. It continuously updates its internal cache and refines its running average. Each subsequent scroll or jump becomes more accurate. This "learning" process ensures a smooth and increasingly precise user experience without the performance cost of pre-rendering the entire list. For perfect accuracy, the user would simply have to scroll the entire list once.

## Features

*   **Efficient Long List Handling:** Built specifically for `ListView.builder` with thousands of variable-height items.
*   **Smart Estimations:** Uses a running average of item heights to intelligently estimate scroll offsets for un-rendered parts of the list.
*   **Immediate Jumps (`jumpToIndex`):** Instantly jumps to a calculated or estimated position without animation. Ideal for "Go to First/Last" functionality or large, non-sequential moves.
*   **Contextual Scrolling (`scrollToIndex`):** Animates to a nearby index, automatically converting to a jump for larger distances to ensure a smooth user experience.
*   **Progressive Caching:** As items are rendered, their real heights and scroll offsets are cached. This makes the controller "smarter" and more accurate over time.
*   **Configurable Defaults:** Allows you to set a `defaultItemHeight` to provide a better starting point for estimations.
*   **Simple API:** Initializes with an `itemCount` and is used just like a standard `ScrollController`, making it easy to integrate into existing projects.
*   **Lightweight and Focused:** Contains a small, focused set of classes (`AdaptiveScrollController`, `AdaptiveScrollMetricsController`, `SizeReportingWidget`) that work together to solve this specific problem without adding bloat.

## Usage

To use this package, add `adaptive_scroller` as a dependency in your `pubspec.yaml` file.

yaml dependencies: adaptive_scroller: ^1.0.0

Then, import the package and use it in your widget.

**1. Create the Controllers**

In your `StatefulWidget`'s state, create an `AdaptiveScrollMetricsController` and an `AdaptiveScrollController`.

dart
// Your code here
  late final AdaptiveScrollMetricsController _metricsController;
  
  late final AdaptiveScrollController _scrollController;
  
  final int _itemCount = 10000;
  
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
    super.dispose();
  }

**2. Build the ListView**

Wrap each item in your `ListView.builder` with a `SizeReportingWidget`.

dart
// Your code here
  ListView.builder(
    controller: _scrollController,
    itemCount: _itemCount,
    itemBuilder: (context, index) {
      return SizeReportingWidget( metricsController: _metricsController,
        index: index,
        child: Card(
          // Your list item widget
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            // Example of a variable height item
            child: Text('Item $index\n' * (index % 5 + 1)),
          ),
        ),
      );
    },
  )


**3. Scroll to an Index**
Now you can programmatically scroll to any item.

dart
  _scrollController.scrollToIndex(5000);
