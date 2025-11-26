// filename:     adaptive_scroller.dart
// copyright:    Copyright (C) 2025 Thinkwider CO., LTD.. All Rights Reserved.
// author:       Philip Lau
//               in collaboration with Google's AI Assistant
// history:      13 nov, 2025 - Initial skeleton creation

library adaptive_scroller;

// import 'dart:math';
import 'package:flutter/material.dart';

//----------------------------------------------------------------------------
// Enums and Constants
//----------------------------------------------------------------------------

const double _kDefaultItemHeight = 60.0;
const int _kScrollOffsetStartIndex = 1;

/// The state of an item's metrics within the controller.
enum _AdaptiveItemState {
  /// The item has not been measured yet. Its height is an estimate.
  initial,
  /// The item has been measured, but its offset has not been cached yet.
  changed,
  /// The item has been measured and its offset is cached and stable.
  calculated,
}

//----------------------------------------------------------------------------
// Data Models
//----------------------------------------------------------------------------

/// Holds the layout metrics for a single item in a list.
/// This is the core data model managed by the [AdaptiveScrollMetricsController].
class _AdaptiveItemMetrics {
  /// The measured height of the item in logical pixels.
  double measuredHeight;

  /// The cached starting offset of this item from the top of the list.
  double cachedOffset;

  /// The state of this item's metrics.
  _AdaptiveItemState state;

  _AdaptiveItemMetrics({
    this.measuredHeight = -1.0, // -1 indicates "not measured"
    this.cachedOffset = 0.0,
    this.state = _AdaptiveItemState.initial,
  });
}

//----------------------------------------------------------------------------
// Manages all the layout metric calculations.
//----------------------------------------------------------------------------
/// Manages the measurement and offset calculations for a list of items.
///
/// This controller is the "engine" of the adaptive scroller. It maintains a
/// list of metrics for each item and uses a running average to estimate the
//  offsets of unmeasured items.
class AdaptiveScrollMetricsController {
  late List<_AdaptiveItemMetrics> _metrics;
  late double _defaultItemHeight;
  late int _scrollOffsetStartIndex;
  double _averageItemHeight;
  int _metricsMeasuredCount = 0;
  final int itemCount;
  late int _lastMeasured = 0;

  /// The running average height of all measured items.
  get averageItemHeight => _averageItemHeight;

  /// The item measured count.
  get metricsMeasuredCount => _metricsMeasuredCount;

  AdaptiveScrollMetricsController({
    required this.itemCount,
    double defaultItemHeight = _kDefaultItemHeight,
    int defaultVisibleItem = _kScrollOffsetStartIndex,
  })  : _defaultItemHeight = defaultItemHeight,
        _scrollOffsetStartIndex = defaultVisibleItem,
        _averageItemHeight = defaultItemHeight {
    // Initialize the metrics list for all items.
    _metrics = List.generate(
      itemCount,
          (index) => _AdaptiveItemMetrics(),
      growable: false,
    );
  }

  /// Updates the height for a specific item, usually from a [SizeReportingWidget].
  void updateItemHeight(int index, double measuredHeight) {
    if (index >= _metrics.length || _metrics[index].state != _AdaptiveItemState.initial) {
      return; // Already measured, no need to update again.
    }

    // Mark that the item's size has changed and needs its offset recalculated.
    _metrics[index].measuredHeight = measuredHeight;
    _metrics[index].state = _AdaptiveItemState.changed;

    // Update the running average. This is the core of the estimation.
    // A simple but effective running average calculation.
    _averageItemHeight =
        ((_averageItemHeight * _metricsMeasuredCount) + measuredHeight) /
            (_metricsMeasuredCount + 1);

    ++_metricsMeasuredCount;
  }

  /// Calculates the scroll offset required to bring a target index into view.
  /// This is the "engine" of the library.
  double calculateScrollOffset(int targetIndex) {
    if (targetIndex < 0 || targetIndex >= itemCount) {
      return 0.0;
    }

    // Optimization: If we already calculated this offset, return it.
    if (_lastMeasured >= targetIndex) {
      return _metrics[targetIndex].cachedOffset;
    }

    // Find the last known offset to start from.
    double offset = _metrics[_lastMeasured].cachedOffset;
    double lastMeasuredHeight = _metrics[_lastMeasured].measuredHeight > 0
        ? _metrics[_lastMeasured].measuredHeight
        : _averageItemHeight;

    // If the last measured item was past the start index, its height was already included.
    if (_lastMeasured > _scrollOffsetStartIndex) {
      offset += lastMeasuredHeight;
    }

    // Loop from the last known point to the target.
    for (int i = _lastMeasured + 1; i < targetIndex; ++i) {
      double itemHeight;

      if (_metrics[i].state == _AdaptiveItemState.initial) {
        // For unmeasured items, use the running average.
        itemHeight = _averageItemHeight;
      } else {
        // For measured items, use their actual height.
        itemHeight = _metrics[i].measuredHeight;
      }

      // Cache the offset for the current item 'i'.
      _metrics[i].cachedOffset = offset;
      _metrics[i].state = _AdaptiveItemState.calculated;

      // The key logic: Only add the height to the running offset if we are
      // past the initial visible items.
      if (i >= _scrollOffsetStartIndex) {
        offset += itemHeight;
      }
    }

    // Update our high-water mark.
    _lastMeasured = targetIndex - 1;

    // The final offset for the targetIndex is the last calculated offset.
    return offset;
  }

  /// Resets the default item height used for estimations.
  void setDefaultItemHeight(double height) {
    _defaultItemHeight = height;
    // If no items have been measured yet, update the average to match.
    if (_metricsMeasuredCount == 0) {
      _averageItemHeight = height;
    }
  }
}

//----------------------------------------------------------------------------
// A custom ScrollController
//----------------------------------------------------------------------------
/// A custom [ScrollController] that enables efficient scrolling to any item
/// in a [ListView] with items of variable height.
///
/// This controller works in conjunction with an [AdaptiveScrollMetricsController]
/// and [SizeReportingWidget] to measure item heights as they are built,
/// allowing it to accurately calculate scroll offsets for items that have not
/// yet been rendered.
class AdaptiveScrollController extends ScrollController {
  late AdaptiveScrollMetricsController metricsController;
  final double largeScrollThresholdInItems;

  AdaptiveScrollController({
    required this.metricsController,
    this.largeScrollThresholdInItems = 50.0,
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
  });

  // Jumps directly to an estimated or calculated position without animation.
  // Ideal for large jumps, like a "Go to Last" button.
  Future<void> jumpToIndex(int index) {
    final targetOffset = () {
      final calOffset = metricsController.calculateScrollOffset(index);

      // Ensure the target offset does not exceed the maximum scroll extent.
      // This check is only possible if the scroll view has been laid out.
      if (position.hasPixels) {
        if (calOffset > position.maxScrollExtent) {
          return position.maxScrollExtent;
        }
      }
      return calOffset;
    }();

    jumpTo(targetOffset);
    return Future.value();
  }

  /// Scrolls to an index, automatically deciding whether to animate or jump.
  Future<void> scrollToIndex(int index,
      {Duration duration = const Duration(milliseconds: 300),
        Curve curve = Curves.easeInOut}) {

    // This check is crucial. We can't get scroll metrics until the view is built.
    if (!position.hasPixels) {
      return Future.value();
    }

    // Determine the current index based on scroll position
    // This is an estimation but good enough for this logic.
    final currentAverageHeight = metricsController.averageItemHeight > 0
        ? metricsController.averageItemHeight
        : _kDefaultItemHeight;
    final currentIndex = (offset / currentAverageHeight).round();

    final distance = (index - currentIndex).abs();

    final targetOffset = () {
      final calOffset = metricsController.calculateScrollOffset(index);

      final endOfContentThreshold = position.maxScrollExtent - position.viewportDimension;

      // Ensure the target offset does not exceed the maximum scroll extent.
      // This check is only possible if the scroll view has been laid out.
      if (calOffset > endOfContentThreshold) {
        return position.maxScrollExtent;
      }
      return calOffset;
    }();

    // If the scroll distance is too large, just jump. Otherwise, animate.
    if (distance > largeScrollThresholdInItems) {
      jumpTo(targetOffset);
    } else {
      animateTo(
        targetOffset,
        duration: duration,
        curve: curve,
      );
    }
    return Future.value();
  }
}

//----------------------------------------------------------------------------
// A helper widget to report its size for an item.
//----------------------------------------------------------------------------
/// A wrapper widget that reports its size after it has been laid out.
///
/// Wrap this widget around each item in your [ListView] to enable the
/// [AdaptiveScrollMetricsController] to measure its height.
class SizeReportingWidget extends StatefulWidget {
  final Widget child;
  final ValueChanged<Size> onSizeChange;

  const SizeReportingWidget({
    super.key,
    required this.child,
    required this.onSizeChange,
  });

  @override
  State<SizeReportingWidget> createState() => _SizeReportingWidgetState();
}

class _SizeReportingWidgetState extends State<SizeReportingWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportSize());
  }

  void _reportSize() {
    if (mounted) {
      final context = this.context;
      if (context.size != null) {
        widget.onSizeChange(context.size!);
      }
    }

  }

  // Also report size on update, in case layout changes.
  @override
  void didUpdateWidget(covariant SizeReportingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportSize());
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

