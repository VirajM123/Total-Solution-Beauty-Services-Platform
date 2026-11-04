import 'package:flutter/material.dart';

/// Presentation of the server-provided code; its length is never assumed.
class ServiceStartCode extends StatelessWidget {
  const ServiceStartCode({super.key, required this.code});
  final String code;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Service start code $code',
    child: ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < code.length; i++) ...[
            if (i != 0) const SizedBox(width: 6),
            Flexible(
              child: Container(
                constraints: const BoxConstraints(minHeight: 48, maxWidth: 56),
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF3DAE3)),
                ),
                child: Text(
                  code[i],
                  style: TextStyle(
                    color: const Color(0xFFA5003D),
                    fontSize: code.length > 4 ? 20 : 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
