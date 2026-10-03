import 'package:flutter/material.dart';

class TvFocusable extends StatefulWidget {
  const TvFocusable({
    required this.child,
    required this.onActivate,
    this.autofocus = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    super.key,
  });

  final Widget child;
  final VoidCallback onActivate;
  final bool autofocus;
  final BorderRadius borderRadius;

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (value) {
        if (mounted) setState(() => _focused = value);
      },
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onActivate();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          border: Border.all(
            width: _focused ? 3 : 0,
            color: _focused
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}
