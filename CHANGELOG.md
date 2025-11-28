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
