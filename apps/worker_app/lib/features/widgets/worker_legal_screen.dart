import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WorkerLegalScreen extends StatelessWidget {
  const WorkerLegalScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Terms & Privacy')),
    body: ListView(
      children: [
        for (final entry in const {
          'Terms of service': String.fromEnvironment('WORKER_TERMS_URL'),
          'Privacy policy': String.fromEnvironment('WORKER_PRIVACY_URL'),
        }.entries)
          ListTile(
            title: Text(entry.key),
            subtitle: entry.value.isEmpty
                ? const Text('Document is not configured. Contact support.')
                : null,
            trailing: entry.value.isEmpty
                ? null
                : const Icon(Icons.open_in_new),
            onTap: entry.value.isEmpty
                ? null
                : () async {
                    final url = Uri.tryParse(entry.value);
                    try {
                      if (url == null ||
                          url.scheme != 'https' ||
                          !url.hasAuthority ||
                          url.userInfo.isNotEmpty ||
                          !await launchUrl(
                            url,
                            mode: LaunchMode.externalApplication,
                          )) {
                        throw StateError('Unavailable policy');
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Unable to open document. Please retry.',
                            ),
                          ),
                        );
}
                    }
                  },
          ),
      ],
    ),
  );
}
