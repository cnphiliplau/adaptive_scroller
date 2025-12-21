## 1.0.4 - 2025-12-21

*   **FEAT**: Added `setEnlargeFactor` to dynamically tune the scroll estimation aggressiveness.
*   **FEAT**: Introduced `resetAllItemState()` to clear the entire measurement cache, essential when the list's underlying data source changes completely.
*   **FEAT**: Added `resetItemState(int index)` for fine-grained control, allowing the state of a single item to be reset for re-measurement.
*   **FIX**: Hardened `SizeReportingWidget` against rare race conditions by adding checks before invoking callbacks.
*   **DOCS**: Significantly improved internal documentation and comments to clarify complex logic, especially the state-re-synchronization behavior in the offset calculation phase.
*   **REFACTOR**: Minor code cleanup and variable name clarifications for better maintainability.

## 1.0.3 - 2025-12-16

### Fixed
- Corrected a bug in the scroll offset calculation that could cause inaccuracies when scrolling large distances.

### Changed
- **Performance:** `SizeReportingWidget` now caches its last reported size to avoid sending redundant update notifications on widget rebuilds.
- **Performance:** The scroll controller now uses a "high-water mark" to avoid re-calculating metrics for already-processed items, improving efficiency on subsequent scrolls.
- **Scrolling Behavior:** Refined the logic to better handle scrolling precisely to the final item in the list.

### Added
- Improved internal documentation and code comments to clarify the logic of `AdaptiveScrollMetricsController`.

## 1.0.2

### Performance
*   **BREAKING**: Reworked `calculateScrollOffset` to use an O(1) estimation algorithm for large jumps. This eliminates UI freezes when scrolling in very long lists.
*   The controller now calculates an estimated total list height to provide a more stable scroll extent when jumping to unmeasured items.

### API & Fixes
*   **BREAKING**: Removed the `defaultItemHeight` property from `AdaptiveScrollMetricsController`. The controller now relies exclusively on its learned `averageItemHeight` for more accurate estimations.
*   The `calculateScrollOffset` method now returns a `ScrollOffsetResult` object containing both the `targetOffset` and the scroll `distance`.
*   Fixed static analysis warnings by adding explicit type annotations to getters.
*   Added logic to better handle scrolling up from the bottom of the list.

### General
*   Significantly improved documentation for all public classes and methods.
*   Refined internal variable names for better code clarity.
*   Removed all internal logging for a clean production release.

## 1.0.1
*   **BREAKING**: Relocated `adaptive_scroller.dart` into `lib/` directory to follow Dart package conventions.
*   Fixed `pubspec.yaml` description length to meet pub.dev validation requirements.
*   Added a complete, runnable example application to demonstrate package usage.

## 1.0.0
*   Initial release of the adaptive_scroller package.
