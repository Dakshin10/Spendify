import 'package:flutter/material.dart';
import '../utils/formatters.dart';

// Global Curve Constants
class AppAnimationCurves {
  static const Curve easeInOutCubic = Curves.easeInOutCubic;
  static const Curve easeOutBack = Curves.easeOutBack;
  static const Curve easeOutExpo = Curves.easeOutExpo;
  static const Curve easeOutCubic = Curves.easeOutCubic;
  static const Curve easeInOutSine = Curves.easeInOutSine;
}

// 1. Staggered Entrance Animation Widget (Fades and slides up)
class FadeUpEntrance extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offset;

  const FadeUpEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 400),
    this.offset = 16.0,
  });

  @override
  State<FadeUpEntrance> createState() => _FadeUpEntranceState();
}

class _FadeUpEntranceState extends State<FadeUpEntrance> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, widget.offset / 100.0), // Normalise offset to fraction
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

// 2. Spring Scale Button (Scale to 0.97 on press)
class SpringScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Duration duration;
  final double scaleDownFactor;

  const SpringScaleButton({
    super.key,
    required this.child,
    required this.onTap,
    this.duration = const Duration(milliseconds: 120),
    this.scaleDownFactor = 0.97,
  });

  @override
  State<SpringScaleButton> createState() => _SpringScaleButtonState();
}

class _SpringScaleButtonState extends State<SpringScaleButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      lowerBound: widget.scaleDownFactor,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        _controller.animateTo(widget.scaleDownFactor, curve: Curves.easeOut);
      },
      onTapUp: (_) {
        _controller.animateTo(1.0, curve: Curves.easeOutBack);
        widget.onTap();
      },
      onTapCancel: () {
        _controller.animateTo(1.0, curve: Curves.easeOutBack);
      },
      child: ScaleTransition(
        scale: _controller,
        child: widget.child,
      ),
    );
  }
}

// 3. Screen Parallax Transitions Builder (push/pop)
class AppPageTransitions {
  static Route<T> buildParallaxRoute<T>(Widget screen) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Primary slide-in from right
        final slideIn = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: AppAnimationCurves.easeInOutCubic,
        ));

        // Secondary slide-out to left at 60% speed
        final slideOut = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.4, 0.0),
        ).animate(CurvedAnimation(
          parent: secondaryAnimation,
          curve: AppAnimationCurves.easeInOutCubic,
        ));

        return SlideTransition(
          position: slideOut,
          child: SlideTransition(
            position: slideIn,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 280),
    );
  }

  static Route<T> buildBottomSheetRoute<T>(Widget sheet) {
    return PageRouteBuilder<T>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      pageBuilder: (context, animation, secondaryAnimation) => sheet,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Slide up with slight overshoot
        final slideUp = Tween<Offset>(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: AppAnimationCurves.easeOutBack,
        ));

        return SlideTransition(
          position: slideUp,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 320),
    );
  }
}

// 4. Horizontal Shake Animation Widget (triggered on validation error)
class ShakeWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double offset;

  const ShakeWidget({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 350),
    this.offset = 8.0,
  });

  @override
  State<ShakeWidget> createState() => ShakeWidgetState();
}

class ShakeWidgetState extends State<ShakeWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void shake() {
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> offsetAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: widget.offset), weight: 10),
      TweenSequenceItem(tween: Tween<double>(begin: widget.offset, end: -widget.offset), weight: 20),
      TweenSequenceItem(tween: Tween<double>(begin: -widget.offset, end: widget.offset), weight: 20),
      TweenSequenceItem(tween: Tween<double>(begin: widget.offset, end: -widget.offset), weight: 20),
      TweenSequenceItem(tween: Tween<double>(begin: -widget.offset, end: widget.offset), weight: 20),
      TweenSequenceItem(tween: Tween<double>(begin: widget.offset, end: 0.0), weight: 10),
    ]).animate(_controller);

    return AnimatedBuilder(
      animation: offsetAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(offsetAnimation.value, 0),
          child: widget.child,
        );
      },
      child: widget.child,
    );
  }
}

// Count-up number animation widget
class CountUpText extends StatefulWidget {
  final double value;
  final TextStyle style;
  final String prefix;
  final Duration duration;

  const CountUpText({
    super.key,
    required this.value,
    required this.style,
    this.prefix = "₹",
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  State<CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<CountUpText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 0.0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(CountUpText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(begin: _animation.value, end: widget.value).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo),
      );
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        String formattedVal;
        if (widget.prefix == "₹" || widget.prefix.isEmpty) {
          formattedVal = formatIndianRupees(_animation.value);
        } else {
          formattedVal = _animation.value.toStringAsFixed(2);
        }
        return Text(
          "${widget.prefix}$formattedVal",
          style: widget.style,
        );
      },
    );
  }
}

