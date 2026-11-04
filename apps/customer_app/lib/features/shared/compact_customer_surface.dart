import 'customer_refinements.dart';
import 'package:flutter/material.dart';

/// Opt-in presentation for the seven compact customer views.
class CompactCustomerSurface extends StatelessWidget {
  const CompactCustomerSurface({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: CustomerRefinements.theme(base),
      child: DefaultTextStyle.merge(
        style: const TextStyle(
          fontFamily: CustomerRefinements.fontFamily,
          height: 1.25,
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            image: DecorationImage(
              image: AssetImage(
                'assets/images/backgrounds/customer_compact_canvas.png',
              ),
              fit: BoxFit.cover,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
