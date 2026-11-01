import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../busydata_design.dart';
import '../busydata_surface_colors.dart';
import 'linux_header_style.dart';
import 'linux_window_host.dart';
import '../../l10n/workbench_strings.dart';

/// The canonical Linux page composition.
///
/// The sidebar header and body are a single full-height child of one clipped
/// allocation, so their visible edge is physically identical at every frame.
class LinuxPageFrame extends StatefulWidget {
  const LinuxPageFrame({
    super.key,
    required this.header,
    required this.body,
    this.sidebarHeader,
    this.sidebarBody,
    this.sidebarAvailable = false,
    this.sidebarExpanded = false,
    this.sidebarOverlay = false,
    this.sidebarTransitionGeneration = 0,
    this.sidebarWidth = BusyDataSizes.sidebarWidth,
    this.onSidebarResize,
  });

  final Widget header;
  final Widget body;
  final Widget? sidebarHeader;
  final Widget? sidebarBody;
  final bool sidebarAvailable;
  final bool sidebarExpanded;
  final bool sidebarOverlay;
  final int sidebarTransitionGeneration;
  final double sidebarWidth;
  final ValueChanged<double>? onSidebarResize;

  @override
  State<LinuxPageFrame> createState() => _LinuxPageFrameState();
}

class _LinuxPageFrameState extends State<LinuxPageFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
    value: _targetVisible ? 1 : 0,
  );
  final _headerKey = GlobalKey();
  final _bodyKey = GlobalKey();
  final _sidebarKey = GlobalKey();
  late int _generation;
  bool _disableAnimations = false;

  bool get _hasSidebar =>
      widget.sidebarHeader != null && widget.sidebarBody != null;
  bool get _targetVisible =>
      _hasSidebar && widget.sidebarAvailable && widget.sidebarExpanded;

  @override
  void initState() {
    super.initState();
    _generation = widget.sidebarTransitionGeneration;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (disabled != _disableAnimations) {
      _disableAnimations = disabled;
      if (disabled && _controller.isAnimating) {
        _controller.value = _targetVisible ? 1 : 0;
      }
    }
  }

  @override
  void didUpdateWidget(covariant LinuxPageFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = _targetVisible ? 1.0 : 0.0;
    if (widget.sidebarTransitionGeneration == _generation) {
      final oldTarget =
          oldWidget.sidebarHeader != null &&
          oldWidget.sidebarBody != null &&
          oldWidget.sidebarAvailable &&
          oldWidget.sidebarExpanded;
      if (oldTarget != _targetVisible) {
        _controller
          ..stop()
          ..value = target;
      }
      return;
    }
    _generation = widget.sidebarTransitionGeneration;
    if (_disableAnimations) {
      _controller.value = target;
      return;
    }
    final distance = (target - _controller.value).abs();
    if (distance == 0) {
      _controller
        ..stop()
        ..value = target;
      return;
    }
    _controller.animateTo(
      target,
      duration: BusyDataMotion.sidebar * distance,
      curve: BusyDataMotion.presentationCurve,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = BusyDataSurfaceColors.of(context);
    final metrics = LinuxWindowMetricsScope.of(context);
    final textDirection = Directionality.of(context);
    final sidebarAtLeft = textDirection == TextDirection.ltr;
    final sidebarControlInset = sidebarAtLeft
        ? metrics.leftControlInset
        : metrics.rightControlInset;
    final oppositeControlInset = sidebarAtLeft
        ? metrics.rightControlInset
        : metrics.leftControlInset;
    final retainedSidebar = KeyedSubtree(
      key: _sidebarKey,
      child: widget.sidebarBody ?? const SizedBox.shrink(),
    );
    final sidebar = _hasSidebar
        ? SizedBox(
            width: widget.sidebarWidth,
            child: ColoredBox(
              color: colors.sidebar,
              child: Column(
                children: [
                  SizedBox(
                    height: BusyDataLinuxWindowMetrics.headerHeight,
                    child: Padding(
                      padding: sidebarAtLeft
                          ? EdgeInsets.only(left: sidebarControlInset)
                          : EdgeInsets.only(right: sidebarControlInset),
                      child: widget.sidebarHeader!,
                    ),
                  ),
                  Expanded(child: retainedSidebar),
                ],
              ),
            ),
          )
        : null;
    final main = _LinuxFrameMain(
      header: KeyedSubtree(
        key: _headerKey,
        child: ColoredBox(color: colors.headerbarFlat, child: widget.header),
      ),
      body: KeyedSubtree(key: _bodyKey, child: widget.body),
    );
    return AnimatedBuilder(
      animation: _controller,
      child: main,
      builder: (context, mainChild) {
        final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
        final rawWidth = widget.sidebarWidth * _controller.value;
        final presentedWidth =
            (rawWidth * devicePixelRatio).round() / devicePixelRatio;
        final widthFactor = presentedWidth / widget.sidebarWidth;
        final sidebarSideOverlap = (sidebarControlInset - presentedWidth)
            .clamp(0.0, double.infinity)
            .toDouble();
        final leftObstruction = sidebarAtLeft
            ? sidebarSideOverlap
            : oppositeControlInset;
        final rightObstruction = sidebarAtLeft
            ? oppositeControlInset
            : sidebarSideOverlap;
        final sidebarInteractive = _targetVisible && _controller.value == 1;
        if (widget.sidebarOverlay) {
          return Stack(
            children: [
              Positioned.fill(
                child: Column(
                  children: [
                    SizedBox(
                      height: BusyDataLinuxWindowMetrics.headerHeight,
                      child: LinuxPageHeaderInsetsScope(
                        leftObstruction: metrics.leftControlInset,
                        rightObstruction: metrics.rightControlInset,
                        child: (mainChild! as _LinuxFrameMain).header,
                      ),
                    ),
                    Expanded(child: (mainChild as _LinuxFrameMain).body),
                  ],
                ),
              ),
              if (_hasSidebar)
                PositionedDirectional(
                  start: 0,
                  top: BusyDataLinuxWindowMetrics.headerHeight,
                  bottom: 0,
                  width: widget.sidebarWidth,
                  child: Offstage(
                    offstage: !_targetVisible,
                    child: ExcludeFocus(
                      excluding: !_targetVisible,
                      child: ColoredBox(
                        color: colors.sidebar,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: BorderDirectional(
                              end: BorderSide(color: colors.sidebarBorder),
                            ),
                          ),
                          child: retainedSidebar,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        }
        return Row(
          children: [
            if (sidebar != null)
              Stack(
                children: [
                  DecoratedBox(
                    key: const ValueKey('linux-sidebar-viewport'),
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      border: BorderDirectional(
                        end: BorderSide(
                          color: colors.sidebarBorder.withValues(
                            alpha: presentedWidth == 0
                                ? 0
                                : colors.sidebarBorder.a,
                          ),
                        ),
                      ),
                    ),
                    child: IgnorePointer(
                      ignoring: !sidebarInteractive,
                      child: ExcludeFocus(
                        excluding: !_targetVisible,
                        child: ExcludeSemantics(
                          excluding: !sidebarInteractive,
                          child: TickerMode(
                            enabled:
                                sidebarInteractive || _controller.value > 0,
                            child: ClipRect(
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                widthFactor: widthFactor,
                                child: sidebar,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (sidebarInteractive && widget.onSidebarResize != null)
                    PositionedDirectional(
                      top: 0,
                      bottom: 0,
                      end: 0,
                      child: _SidebarResizeGrip(
                        width: widget.sidebarWidth,
                        atLeft: sidebarAtLeft,
                        resize: widget.onSidebarResize!,
                      ),
                    ),
                ],
              ),
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    height: BusyDataLinuxWindowMetrics.headerHeight,
                    child: LinuxPageHeaderInsetsScope(
                      leftObstruction: leftObstruction,
                      rightObstruction: rightObstruction,
                      child: (mainChild! as _LinuxFrameMain).header,
                    ),
                  ),
                  Expanded(child: (mainChild as _LinuxFrameMain).body),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SidebarResizeGrip extends StatefulWidget {
  const _SidebarResizeGrip({
    required this.width,
    required this.atLeft,
    required this.resize,
  });
  final double width;
  final bool atLeft;
  final ValueChanged<double> resize;
  @override
  State<_SidebarResizeGrip> createState() => _SidebarResizeGripState();
}

class _SidebarResizeGripState extends State<_SidebarResizeGrip> {
  bool focused = false;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    enabled: true,
    label: strings(context).explorerWidthDivider,
    value: strings(context).explorerExtent('${widget.width.round()}'),
    increasedValue: strings(context).widerExplorer,
    decreasedValue: strings(context).narrowerExplorer,
    onIncrease: () => widget.resize(widget.width + 16),
    onDecrease: () => widget.resize(widget.width - 16),
    child: Focus(
      onFocusChange: (value) => setState(() => focused = value),
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent ||
            ![
              LogicalKeyboardKey.arrowLeft,
              LogicalKeyboardKey.arrowRight,
            ].contains(event.logicalKey)) {
          return KeyEventResult.ignored;
        }
        final direction =
            (event.logicalKey == LogicalKeyboardKey.arrowRight ? 1 : -1) *
            (widget.atLeft ? 1 : -1);
        widget.resize(widget.width + 16 * direction);
        return KeyEventResult.handled;
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) => widget.resize(
            widget.width + details.delta.dx * (widget.atLeft ? 1 : -1),
          ),
          child: Container(
            width: 4,
            height: double.infinity,
            color: focused
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
          ),
        ),
      ),
    ),
  );
}

class _LinuxFrameMain extends StatelessWidget {
  const _LinuxFrameMain({required this.header, required this.body});

  final Widget header;
  final Widget body;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class BusyDataLinuxBrandHeader extends StatelessWidget {
  const BusyDataLinuxBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return LinuxTitlebarGestureRegion(
      child: Center(
        child: Text(
          'BusyData',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: busyDataLinuxHeaderBrandStyle(context),
        ),
      ),
    );
  }
}
