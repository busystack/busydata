import 'dart:math' as math;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:re_editor/re_editor.dart';
import '../../features/workspace/editor/sql_editor.dart';
import 'accessibility_text_geometry.dart';

/// One mounted editor's public upstream layout observations. No document text is
/// copied here. An observation becomes unusable immediately when its owner moves.
class SqlEditorGeometry extends ChangeNotifier {
  SqlEditorGeometry(this.scroll);
  final CodeScrollController scroll;
  GlobalKey verticalViewportKey = GlobalKey();
  GlobalKey horizontalViewportKey = GlobalKey();
  GlobalKey indicatorKey = GlobalKey();
  CodeIndicatorValueNotifier? _paragraphs;
  SqlEditorController? _controller;
  SqlEditorValue? _layoutOwner;
  Rect? _viewport;
  TextDirection _direction = TextDirection.ltr;
  bool _wrap = true, _scheduled = false, _disposed = false;
  bool _valid = false;
  Offset _layoutScroll = Offset.zero;
  Offset? _paragraphScroll;
  List<CodeLineRenderParagraph> _layoutParagraphs = const [];
  Object? _configuration;
  VoidCallback? focusEditor;

  /// Keys belong to the mounted view, whose retained scrollbar subtree may
  /// survive a scroll-controller handoff through the public ScrollBehavior.
  void attachViewportKeys(
    GlobalKey vertical,
    GlobalKey horizontal,
    GlobalKey indicator,
  ) {
    if (identical(verticalViewportKey, vertical) &&
        identical(horizontalViewportKey, horizontal) &&
        identical(indicatorKey, indicator)) {
      return;
    }
    verticalViewportKey = vertical;
    horizontalViewportKey = horizontal;
    indicatorKey = indicator;
    scheduleLayout();
  }

  List<CodeLineRenderParagraph> get paragraphs =>
      current ? _layoutParagraphs : const [];
  bool get current =>
      !_disposed &&
      _valid &&
      _viewport != null &&
      _controller != null &&
      identical(_controller!.value, _layoutOwner) &&
      _layoutScroll == _liveScrollOffset;
  Rect? get viewport => current ? _viewport : null;
  ScrollPosition? _ownedPosition(ScrollController controller, GlobalKey key) {
    final owner = key.currentContext;
    if (owner == null || controller.positions.length > 4) return null;
    final target = owner is Element ? owner.renderObject : null;
    if (target == null || !target.attached) return null;
    ScrollPosition? found;
    for (final position in controller.positions) {
      final context = position.context.notificationContext;
      if (context == null || !position.hasPixels) continue;
      RenderObject? render = context is Element ? context.renderObject : null;
      if (render == null || !render.attached) continue;
      var belongs = false, depth = 0;
      while (render != null && depth++ < 128) {
        if (identical(render, target)) {
          belongs = true;
          break;
        }
        render = render.parent;
      }
      if (!belongs) continue;
      if (found != null) return null;
      found = position;
    }
    return found;
  }

  Offset? get _liveScrollOffset {
    final vertical = _ownedPosition(
      scroll.verticalScroller,
      verticalViewportKey,
    );
    final horizontal = _wrap
        ? null
        : _ownedPosition(scroll.horizontalScroller, horizontalViewportKey);
    if (vertical == null || (!_wrap && horizontal == null)) return null;
    return Offset(horizontal?.pixels ?? 0, vertical.pixels);
  }

  Offset get scrollOffset => _layoutScroll;

  void configure(Object configuration) {
    if (_configuration == configuration) return;
    _configuration = configuration;
    scheduleLayout();
  }

  void bind(
    SqlEditorController controller,
    CodeIndicatorValueNotifier paragraphs,
    TextDirection direction,
    bool wrap,
  ) {
    var changed = _direction != direction || _wrap != wrap;
    if (!identical(_controller, controller)) {
      changed = true;
      _controller?.removeListener(_changed);
      _controller = controller;
      controller.addListener(_changed);
      _layoutOwner = null;
    }
    if (!identical(_paragraphs, paragraphs)) {
      changed = true;
      _paragraphs?.removeListener(_paragraphChanged);
      _paragraphs = paragraphs;
      _paragraphScroll = paragraphs.value == null ? null : _liveScrollOffset;
      paragraphs.addListener(_paragraphChanged);
    }
    _direction = direction;
    _wrap = wrap;
    if (changed) scheduleLayout();
  }

  void _changed() {
    // Readers also compare the immutable owner synchronously, so stale geometry
    // cannot be used while the next layout is still pending.
    scheduleLayout();
  }

  void _paragraphChanged() {
    _paragraphScroll = _liveScrollOffset;
    scheduleLayout();
  }

  static Rect? _bounds(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox ||
        !box.attached ||
        !box.hasSize ||
        box.size.isEmpty) {
      return null;
    }
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void scheduleLayout() {
    _valid = false;
    if (_scheduled || _disposed) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_disposed) return;
      final outer = _bounds(verticalViewportKey);
      final horizontal = !_wrap ? _bounds(horizontalViewportKey) : null;
      final indicator = _bounds(indicatorKey);
      Rect? next;
      if (horizontal != null) {
        next = horizontal;
      } else if (outer != null && indicator != null) {
        // The app supplies no separator/margin/border. The public indicator
        // builder owns the gutter, while its remaining row sibling is text.
        next = _direction == TextDirection.rtl
            ? Rect.fromLTRB(outer.left, outer.top, indicator.left, outer.bottom)
            : Rect.fromLTRB(
                indicator.right,
                outer.top,
                outer.right,
                outer.bottom,
              );
      }
      _viewport = next?.isEmpty == false ? next : null;
      _layoutOwner = _controller?.value;
      final liveScroll = _liveScrollOffset;
      _layoutScroll = liveScroll ?? Offset.zero;
      // The official public notifier publishes viewport-relative positions
      // during layout. A horizontal-only scroll can repaint without publishing
      // another layout. Apply only movement since that actual observation;
      // subtracting the full scroll would move already-normalized positions twice.
      final observedScroll = _paragraphScroll;
      final movement = observedScroll == null
          ? Offset.zero
          : _layoutScroll - observedScroll;
      _layoutParagraphs = [
        for (final paragraph
            in _paragraphs?.value?.paragraphs ??
                const <CodeLineRenderParagraph>[])
          paragraph.copyWith(offset: paragraph.offset - movement),
      ];
      _valid =
          _viewport != null &&
          _layoutOwner != null &&
          liveScroll != null &&
          observedScroll != null;
      notifyListeners();
    });
    // A scroll-owner handoff can invalidate layout while the scheduler is
    // already idle or in a post-frame callback. Registration alone does not
    // request the frame needed to publish the new public observation.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// Exact rendered caret, obtained from upstream's public paragraph API.
  Rect? caret(CodeLinePosition position) {
    final bounds = viewport;
    if (bounds == null) return null;
    for (final line in paragraphs) {
      if (line.index != position.index) continue;
      final offset = line.getOffset(position.textPosition);
      if (offset == null) return null;
      // CodeIndicatorValue publishes viewport-relative paragraph offsets.
      final point = bounds.topLeft + line.offset + offset;
      final rect = Rect.fromLTWH(
        point.dx,
        point.dy,
        1,
        line.preferredLineHeight,
      );
      return rect.overlaps(bounds) ? rect : null;
    }
    return null;
  }

  /// Glyph boxes in the current global logical view, indexed by the native
  /// semantic line's UTF-16 offsets. Only public upstream paragraph geometry is
  /// used; offscreen text has no fabricated bounds.
  Map<String, Object?>? semanticTextGeometry(
    SqlEditorController controller,
    SqlEditorValue expected,
    int lineIndex,
    int length,
  ) {
    final bounds = viewport;
    if (bounds == null ||
        !identical(_controller, controller) ||
        !identical(_layoutOwner, expected) ||
        length < 0 ||
        length > 16384 ||
        lineIndex < 0 ||
        lineIndex >= expected.codeLines.length) {
      return null;
    }
    final source = expected.codeLines[lineIndex].text;
    if (length > source.length) return null;
    final visible = paragraphs.where((line) => line.index == lineIndex);
    if (visible.length != 1) return null;
    final line = visible.single;
    if (length > line.length) return null;
    final boxes = <Map<String, Object?>>[];
    for (var start = 0; start < length;) {
      var end = start + 1;
      final first = source.codeUnitAt(start);
      if (first >= 0xd800 && first <= 0xdbff) {
        if (end >= length) return null;
        final second = source.codeUnitAt(end);
        if (second < 0xdc00 || second > 0xdfff) return null;
        end++;
      } else if (first >= 0xdc00 && first <= 0xdfff) {
        return null;
      }
      for (final local in line.getRangeRects(
        TextRange(start: start, end: end),
      )) {
        final rect = local
            .shift(bounds.topLeft + line.offset)
            .intersect(bounds);
        if (rect.isEmpty) continue;
        if (!rect.isFinite ||
            boxes.length == AccessibilityTextGeometry.maximumBoxes) {
          return null;
        }
        boxes.add({
          'start': start,
          'end': end,
          'rect': [rect.left, rect.top, rect.width, rect.height],
        });
      }
      start = end;
    }
    return {'start': 0, 'end': length, 'boxes': boxes};
  }

  /// Keyboard menus never reveal/scroll the caret as a side effect.
  Offset? contextMenuAnchor(CodeLinePosition position) {
    final bounds = viewport;
    if (bounds == null) return null;
    final rect = caret(position);
    final visible = paragraphs;
    final before = visible.isNotEmpty && position.index < visible.first.index;
    final raw =
        rect?.bottomLeft ??
        Offset(bounds.left, before ? bounds.top : bounds.bottom);
    return Offset(
      raw.dx.clamp(bounds.left, math.max(bounds.left, bounds.right - 1)),
      raw.dy.clamp(bounds.top, math.max(bounds.top, bounds.bottom - 1)),
    );
  }

  /// Page navigation uses the next visible public layout, preserving the
  /// rendered horizontal position instead of assuming fixed-width glyphs.
  void navigatePage(SqlEditorController controller, bool down, bool extend) {
    final bounds = viewport;
    final active = caret(controller.selection.extent);
    if (bounds == null ||
        active == null ||
        !scroll.verticalScroller.hasClients) {
      return;
    }
    final revision = controller.value.revision;
    final base = controller.offsetForPosition(controller.selection.base);
    final relative = active.center - bounds.topLeft;
    final position = scroll.verticalScroller.position;
    final distance = math.max(active.height, bounds.height - active.height);
    final next = (position.pixels + (down ? distance : -distance)).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next == position.pixels) return;
    scroll.verticalScroller.jumpTo(next);
    scheduleLayout();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed ||
          !identical(_controller, controller) ||
          controller.value.revision != revision ||
          !current) {
        return;
      }
      final visible = paragraphs;
      if (visible.isEmpty) return;
      final y = relative.dy.clamp(0.0, math.max(0.0, bounds.height - 1));
      var selected = visible.first;
      for (final line in visible) {
        selected = line;
        if (y < line.bottom) break;
      }
      final point = selected.getPosition(
        Offset(relative.dx, y.toDouble()) - selected.offset,
      );
      final target = controller.offsetForPosition(point);
      controller.selectOffsets(extend ? base : target, target);
    });
  }

  void detach(SqlEditorController controller) {
    if (!identical(_controller, controller)) return;
    _controller?.removeListener(_changed);
    _paragraphs?.removeListener(_paragraphChanged);
    _controller = null;
    _paragraphs = null;
    _layoutOwner = null;
    _layoutParagraphs = const [];
    _viewport = null;
    _valid = false;
    focusEditor = null;
  }

  @override
  void dispose() {
    _disposed = true;
    focusEditor = null;
    _controller?.removeListener(_changed);
    _paragraphs?.removeListener(_paragraphChanged);
    _controller = null;
    _paragraphs = null;
    _layoutParagraphs = const [];
    super.dispose();
  }
}

class SqlEditorScrollController extends CodeScrollController {
  SqlEditorScrollController({
    super.verticalScroller,
    super.horizontalScroller,
  }) {
    geometry = SqlEditorGeometry(this);
    verticalScroller.addListener(geometry.scheduleLayout);
    horizontalScroller.addListener(geometry.scheduleLayout);
  }
  late final SqlEditorGeometry geometry;
  Offset? contextMenuAnchor(CodeLinePosition position) =>
      geometry.contextMenuAnchor(position);
  @override
  void dispose() {
    verticalScroller.removeListener(geometry.scheduleLayout);
    horizontalScroller.removeListener(geometry.scheduleLayout);
    geometry.dispose();
    super.dispose();
  }
}

/// Paint only the visible portions of already validated extra ranges. Layout,
/// bidi ordering, wrapping, font fallback and scaling stay with upstream.
class SqlExtraSelectionPainter extends CustomPainter {
  SqlExtraSelectionPainter({
    required this.geometry,
    required this.controller,
    required this.origin,
    required this.selectionColor,
    required this.caretColor,
    required this.caretWidth,
    required this.focused,
    required this.caretVisible,
  }) : super(repaint: Listenable.merge([geometry, controller, caretVisible]));
  final SqlEditorGeometry geometry;
  final SqlEditorController controller;
  final Offset Function() origin;
  final Color selectionColor, caretColor;
  final double caretWidth;
  final bool Function() focused;
  final ValueListenable<bool> caretVisible;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = geometry.viewport;
    if (bounds == null) return;
    final localOrigin = origin();
    final clip = bounds.shift(-localOrigin).intersect(Offset.zero & size);
    if (clip.isEmpty) return;
    canvas.save();
    canvas.clipRect(clip);
    final selectionPaint = Paint()..color = selectionColor;
    final caretPaint = Paint()..color = caretColor;
    for (final range in controller.value.secondarySelections) {
      for (final line in geometry.paragraphs) {
        if (line.index < range.startIndex || line.index > range.endIndex) {
          continue;
        }
        final start = line.index == range.startIndex ? range.startOffset : 0;
        final end = line.index == range.endIndex
            ? range.endOffset
            : line.length;
        if (start < end) {
          for (final rect in line.getRangeRects(
            TextRange(start: start, end: end),
          )) {
            canvas.drawRect(
              rect.shift(bounds.topLeft + line.offset - localOrigin),
              selectionPaint,
            );
          }
        }
      }
      if (focused()) {
        final caret = geometry.caret(range.extent);
        if (caret != null) {
          canvas.drawRect(
            Rect.fromLTWH(
              caret.left - localOrigin.dx,
              caret.top - localOrigin.dy,
              caretWidth,
              caret.height,
            ),
            caretPaint,
          );
        }
      }
    }
    if (focused() && caretVisible.value && controller.selection.isCollapsed) {
      final primary = geometry.caret(controller.selection.extent);
      if (primary != null) {
        canvas.drawRect(
          Rect.fromLTWH(
            primary.left - localOrigin.dx,
            primary.top - localOrigin.dy,
            caretWidth,
            primary.height,
          ),
          caretPaint,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SqlExtraSelectionPainter old) =>
      old.geometry != geometry ||
      old.controller != controller ||
      old.selectionColor != selectionColor ||
      old.caretColor != caretColor ||
      old.caretWidth != caretWidth ||
      old.caretVisible != caretVisible;
}
