import 'package:flutter/widgets.dart';

/// Sticky bool with enter/exit hysteresis so resize near a breakpoint
/// does not flip layouts every frame (side rail ↔ bottom nav, etc.).
class BreakpointLatch {
  BreakpointLatch({
    required this.enter,
    required this.exit,
    this.value = false,
  }) : assert(exit <= enter, 'exit must be ≤ enter');

  final double enter;
  final double exit;
  bool value;

  bool update(double measure) {
    if (value) {
      if (measure < exit) value = false;
    } else {
      if (measure >= enter) value = true;
    }
    return value;
  }
}

/// Rebuilds only when the latched wide/narrow flag changes (not every px).
class WideBreakpointBuilder extends StatefulWidget {
  const WideBreakpointBuilder({
    super.key,
    required this.builder,
    this.enter = 900,
    this.exit = 860,
  });

  final double enter;
  final double exit;
  final Widget Function(BuildContext context, bool wide) builder;

  @override
  State<WideBreakpointBuilder> createState() => _WideBreakpointBuilderState();
}

class _WideBreakpointBuilderState extends State<WideBreakpointBuilder> {
  late final BreakpointLatch _latch = BreakpointLatch(
    enter: widget.enter,
    exit: widget.exit,
  );

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final wide = _latch.update(w);
    return widget.builder(context, wide);
  }
}
