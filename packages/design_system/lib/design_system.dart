import 'package:flutter/material.dart';

abstract final class BeautyColors {
  static const pink = Color(0xFFE91E63);
  static const deepPink = Color(0xFFC9004C);
  static const blush = Color(0xFFFFF0F4);
  static const pale = Color(0xFFFFF8FA);
  static const ink = Color(0xFF17182C);
  static const muted = Color(0xFF656575);
  static const border = Color(0xFFF1DDE4);
  static const error = Color(0xFFB3261E);
}

abstract final class BeautySpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class BeautyRadius {
  static const card = 20.0;
  static const control = 10.0;
}

abstract final class BeautyTheme {
  static ThemeData get data => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.white,
    colorScheme: ColorScheme.fromSeed(seedColor: BeautyColors.pink, primary: BeautyColors.pink, error: BeautyColors.error),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, height: 1.12, color: BeautyColors.ink),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: BeautyColors.ink),
      bodyMedium: TextStyle(fontSize: 14, height: 1.4, color: BeautyColors.ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(BeautyRadius.control)),
      enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: BeautyColors.border), borderRadius: BorderRadius.circular(BeautyRadius.control)),
    ),
  );
}

class BeautyButton extends StatelessWidget {
  const BeautyButton({super.key, required this.label, required this.onPressed, this.loading = false});
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 48,
    child: DecoratedBox(
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [BeautyColors.pink, BeautyColors.deepPink]), borderRadius: BorderRadius.circular(BeautyRadius.control)),
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(backgroundColor: Colors.transparent, disabledBackgroundColor: Colors.transparent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BeautyRadius.control))),
        child: loading ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    ),
  );
}

class BeautyTextField extends StatelessWidget {
  const BeautyTextField({super.key, required this.controller, required this.label, this.errorText, this.keyboardType, this.maxLength, this.prefix, this.onChanged});
  final TextEditingController controller;
  final String label;
  final String? errorText;
  final TextInputType? keyboardType;
  final int? maxLength;
  final Widget? prefix;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) => TextField(controller: controller, keyboardType: keyboardType, maxLength: maxLength, onChanged: onChanged, decoration: InputDecoration(labelText: label, errorText: errorText, prefixIcon: prefix, counterText: ''));
}

class BeautyCard extends StatelessWidget {
  const BeautyCard({super.key, required this.child, this.padding = const EdgeInsets.all(BeautySpace.md)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(padding: padding, decoration: BoxDecoration(color: Colors.white, border: Border.all(color: BeautyColors.border), borderRadius: BorderRadius.circular(BeautyRadius.card)), child: child);
}

class BeautyMessage extends StatelessWidget {
  const BeautyMessage(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Text(message, style: const TextStyle(color: BeautyColors.error, fontSize: 13));
}

class BeautyLoading extends StatelessWidget {
  const BeautyLoading({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator(color: BeautyColors.pink));
}

class BeautyPage extends StatelessWidget {
  const BeautyPage({super.key, required this.child, this.padding = const EdgeInsets.all(BeautySpace.lg)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => SafeArea(child: LayoutBuilder(builder: (context, constraints) => SingleChildScrollView(padding: padding, child: ConstrainedBox(constraints: BoxConstraints(minHeight: constraints.maxHeight - padding.vertical), child: child))));
}
