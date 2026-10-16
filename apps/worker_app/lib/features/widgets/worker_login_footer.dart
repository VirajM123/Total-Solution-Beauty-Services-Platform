import 'package:flutter/material.dart';

const _plum = Color(0xFF460621);
const _berry = Color(0xFFB20A50);
const _muted = Color(0xFF624352);
const _line = Color(0xFFE8C9CE);

/// UI-only footer. Social sign-in, policies and applications are placeholders
/// until real backend flows and published policy pages are available.
class WorkerLoginFooter extends StatelessWidget {
  const WorkerLoginFooter({
    super.key,
    required this.onGoogle,
    required this.onApple,
    required this.onRegister,
    required this.onTerms,
    required this.onPrivacy,
  });

  final VoidCallback onGoogle;
  final VoidCallback onApple;
  final VoidCallback onRegister;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Row(
          children: [
            Expanded(child: Divider(color: _line)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or continue with',
                style: TextStyle(
                  color: _muted,
                  fontFamily: 'Georgia',
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(child: Divider(color: _line)),
          ],
        ),
        const SizedBox(height: 10),
        _SocialButton(
          label: 'Continue with Google',
          icon: const Text(
            'G',
            style: TextStyle(
              color: Color(0xFF4285F4),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          onPressed: onGoogle,
        ),
        const SizedBox(height: 9),
        _SocialButton(
          label: 'Continue with Apple',
          icon: const Icon(Icons.apple, color: _plum, size: 24),
          onPressed: onApple,
        ),
        const SizedBox(height: 13),
        const Text(
        'By continuing, you agree to our',
textAlign: TextAlign.center,
style: TextStyle(
  color: _muted,
  fontSize: 12,
  fontWeight: FontWeight.w500,
),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 2,
          children: [
            TextButton(
              onPressed: onTerms,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                foregroundColor: _plum,
              ),
              child: const Text('Terms', style: TextStyle(
                fontSize: 11, decoration: TextDecoration.underline)),
            ),
            const Text('&', style: TextStyle(color: _muted, fontSize: 11)),
            TextButton(
              onPressed: onPrivacy,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                foregroundColor: _plum,
              ),
              child: const Text('Privacy Policy', style: TextStyle(
                fontSize: 11, decoration: TextDecoration.underline)),
            ),
          ],
        ),
        const Divider(color: _line),

TextButton(
  onPressed: onRegister,
  style: TextButton.styleFrom(
    foregroundColor: _berry,
    minimumSize: const Size(0, 48),
    padding: const EdgeInsets.symmetric(
      horizontal: 8,
      vertical: 10,
    ),
  ),
  child: Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 5,
    children: const [
      Text(
        'New professional?',
        style: TextStyle(
          color: _muted,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      Text(
        'Apply to join',
        style: TextStyle(
          color: _berry,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      Icon(
        Icons.arrow_forward_rounded,
        color: _berry,
        size: 19,
      ),
    ],
  ),
),

      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final Widget icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.9),
          foregroundColor: _plum,
          side: const BorderSide(color: _line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 15,
                  color: _plum,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
