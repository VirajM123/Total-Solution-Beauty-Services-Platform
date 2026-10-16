
import 'package:flutter/material.dart';

class SlidePageRoute<T> extends PageRouteBuilder<T> {
  SlidePageRoute({required Widget page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (
            context,
            animation,
            secondaryAnimation,
            child,
          ) {
            final offsetAnimation = Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).chain(
              CurveTween(curve: Curves.easeInOutCubic),
            );

            return SlideTransition(
              position: animation.drive(offsetAnimation),
              child: child,
            );
          },
        );
}
