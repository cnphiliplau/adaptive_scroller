import 'dart:async';
import 'package:flutter/widgets.dart';

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

  _AdaptiveItemMetrics()
      : measuredHeight = -1.0, // -1 indicates "not measured"
        cachedOffset = 0.0,
        state = _AdaptiveItemState.initial;
}

/// A data class returned by `calculateScrollOffset` containing the results
/// of the scroll calculation.
class ScrollOffsetResult {
  /// The calculated or estimated target scroll offset in pixels.
  final double targetOffset;

  /// The distance in item count between the previous and current target index.
  final int distance;

  ScrollOffsetResult({required this.targetOffset, required this.distance});
}

//----------------------------------------------------------------------------
// Manages all the layout metric calculations.
//----------------------------------------------------------------------------
/// Manages the measurement and offset calculations for a list of items.
///
/// This controller is the "engine" of the adaptive scroller. It maintains a
/// list of metrics for each item and uses a running average to estimate the
/// offsets of unmeasured items. It is responsible for calculating the pixel
/// offset required to scroll to any given index.
class AdaptiveScrollMetricsController {
  late List<_AdaptiveItemMetrics> _metrics;
  final int _scrollOffsetStartIndex;
  double _averageItemHeight;
  int _metricsMeasuredCount = 0;
  final int itemCount;

  /// The index of the last item in a contiguous block starting from index 0
  /// that has had its size measured and its offset calculated.
  int _lastMeasured = 0;
  int _previousIndex = 0;

  /// Tracks the last known bottom-most index to handle scrolling up from the end.
  int _bottomIndex = 0;

  /// The running average height of all items that have been measured so far.
  double get averageItemHeight => _averageItemHeight;

  /// The total number of items that have had their height measured.
  int get metricsMeasuredCount => _metricsMeasuredCount;

  AdaptiveScrollMetricsController({
    required this.itemCount,
    double defaultItemHeight = _kDefaultItemHeight,
    int defaultVisibleItem = _kScrollOffsetStartIndex,
  })  : _scrollOffsetStartIndex = defaultVisibleItem,
        _averageItemHeight = defaultItemHeight {
    // Initialize the metrics list for all items.
    _metrics = List.generate(
      itemCount,
          (index) => _AdaptiveItemMetrics(),
      growable: false,
    );
  }

  /// Updates the height for a specific item, usually from a [SizeReportingWidget].
  /// This is the primary input for the controller's learning process.
  bool updateItemHeight(int index, double measuredHeight) {
    if (index >= _metrics.length ||
        _metrics[index].state != _AdaptiveItemState.initial) {
      return false; // Already measured, no need to update again.
    }

    // Mark that the item's size has changed and needs its offset recalculated.
    _metrics[index].measuredHeight = measuredHeight;
    _metrics[index].state = _AdaptiveItemState.changed;

    // Update the running average. This is the core of the estimation.
    _averageItemHeight =
        ((_averageItemHeight * _metricsMeasuredCount) + measuredHeight) /
            (_metricsMeasuredCount + 1);

    ++_metricsMeasuredCount;
    return true;
  }

  /// Calculates the scroll offset required to bring a target index into view.
  ///
  /// This is the most critical method in the library. It performs two key tasks:
  /// 1. It iterates through all items that have been measured but not yet
  ///    processed, calculating their precise `cachedOffset`. This advances the
  ///    `_lastMeasured` high-water mark.
  /// 2. If the `targetIndex` is beyond the `_lastMeasured` mark, it uses an O(1)
  ///    calculation to estimate the total scroll height of the list, providing a
  ///    target for the `ScrollController` to jump to.
  ScrollOffsetResult calculateScrollOffset(
      int targetIndex, ScrollPosition position) {
    if (targetIndex < 0 || targetIndex >= itemCount) {
      return ScrollOffsetResult(targetOffset: 0.0, distance: 0);
    }

    final distance = (targetIndex - _previousIndex).abs();
    _previousIndex = targetIndex;

    // Fast path: If the target's offset is already accurately known, return it.
    if (_lastMeasured >= targetIndex) {
      return ScrollOffsetResult(
          targetOffset: _metrics[targetIndex].cachedOffset, distance: distance);
    }

    // --- Phase 1: Calculate precise offsets for all newly measured items ---
    // This loop advances the `_lastMeasured` index by processing any items
    // marked as `changed` in a contiguous block from the start.
    double preciseOffset = 0.0;
    double prevItemHeight = 0.0;

    for (int i = _lastMeasured; (i < itemCount); ++i) {
      if (_metrics[i].state == _AdaptiveItemState.changed) {
        _metrics[i].state = _AdaptiveItemState.calculated;
        _metrics[i].cachedOffset = preciseOffset + prevItemHeight;

        if (i > _scrollOffsetStartIndex) {
          preciseOffset += _metrics[i].measuredHeight;
        }
      } else if (_metrics[i].state == _AdaptiveItemState.calculated) {
        preciseOffset = _metrics[i].cachedOffset;
        if (i > _scrollOffsetStartIndex) {
          prevItemHeight = _metrics[i].measuredHeight;
        }
      } else {
        // Stop when we hit the first unmeasured item.
        break;
      }

      if (i > _lastMeasured) {
        _lastMeasured = i;
      }
    }

    // --- Phase 2: Estimate offset for targets in the unmeasured zone ---
    // This uses an O(1) calculation to estimate the total height of the list.
    final remainingItemCount = (itemCount - 1 - _lastMeasured);
    final estimatedRemainingHeight = remainingItemCount * _averageItemHeight;

    // The total estimated height is the sum of the precisely known part and
    // the estimated remaining part.
    final totalEstimatedHeight = preciseOffset + (estimatedRemainingHeight);

    // --- Phase 3: Handle specific scrolling scenarios ---

    // Scenario: Scrolling to the very last item.
    if (targetIndex == (itemCount - 1)) {
      _bottomIndex = targetIndex;

      // If our estimated total height is greater than what Flutter currently
      // knows, we must provide our larger estimate to force it to scroll further.
      if (totalEstimatedHeight > position.maxScrollExtent) {
        _metrics[targetIndex].cachedOffset = totalEstimatedHeight;
        return ScrollOffsetResult(
            targetOffset: totalEstimatedHeight, distance: distance);
      }

      // Otherwise, trust Flutter's current maximum extent.
      _metrics[targetIndex].cachedOffset = position.maxScrollExtent;
      return ScrollOffsetResult(
          targetOffset: position.maxScrollExtent, distance: distance);
    }

    // Scenario: Scrolling up from the bottom of the list.
    if (targetIndex == (_bottomIndex - 1)) {
      _bottomIndex = targetIndex;
      final gap = itemCount - _bottomIndex - 1;
      final targetOffset = position.maxScrollExtent - (gap * _averageItemHeight);

      return ScrollOffsetResult(targetOffset: targetOffset, distance: distance);
    }

    // Default scenario: Return the total estimated height. This is the most
    // common path for jumps into the unmeasured part of the list.
    return ScrollOffsetResult(
        targetOffset: totalEstimatedHeight, distance: distance);
  }
}

//----------------------------------------------------------------------------
// A custom ScrollController
//----------------------------------------------------------------------------
/// A custom [ScrollController] that enables efficient scrolling to any item
/// in a [ListView] with items of variable height.
///
/// This controller works in conjunction with an [AdaptiveScrollMetricsController]
/// and a `SizeReportingWidget` to measure item heights as they are built,
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

  /// Jumps directly to an estimated or calculated position without animation.
  /// Ideal for large jumps, like a "Go to Last" button.
  Future<void> jumpToIndex(int index) {
    if (!position.hasPixels) {
      return Future.value();
    }

    final scrollResult =
    metricsController.calculateScrollOffset(index, position);
    jumpTo(scrollResult.targetOffset);
    return Future.value();
  }

  /// Scrolls to an index, automatically deciding whether to animate or jump
  /// based on the distance of the scroll.
  Future<void> scrollToIndex(int index,
      {Duration duration = const Duration(milliseconds: 300),
        Curve curve = Curves.easeInOut}) {
    // This check is crucial. We can't get scroll metrics until the view is built.
    if (!position.hasPixels) {
      return Future.value();
    }

    final scrollResult =
    metricsController.calculateScrollOffset(index, position);
    final targetOffset = scrollResult.targetOffset;
    final distance = scrollResult.distance;

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
// A helper widget to report its size.
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
