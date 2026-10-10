import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'info_content.dart';
import 'neon_theme.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key, required this.document});

  final InfoDocument document;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        document.title,
        maxLines: 2,
        style: const TextStyle(fontSize: 18),
      ),
    ),
    body: ScenicBackground(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SelectionArea(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                for (final section in document.sections) ...[
                  NeonPanel(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.title,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          section.text,
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const _ContactLinks(),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ContactLinks extends StatelessWidget {
  const _ContactLinks();

  Future<void> _open(BuildContext context, Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // The copy control remains available when no external app can open.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось открыть приложение. Скопируйте контакт.'),
        ),
      );
    }
  }

  Future<void> _copy(BuildContext context, String contact) async {
    await Clipboard.setData(ClipboardData(text: contact));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Контакт скопирован')));
    }
  }

  @override
  Widget build(BuildContext context) => NeonPanel(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          developerName,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        _contact(
          context,
          developerEmail,
          Uri(scheme: 'mailto', path: developerEmail),
          Icons.mail_outline,
        ),
        _contact(
          context,
          developerTelegram,
          Uri.parse(developerTelegramUrl),
          Icons.send_outlined,
        ),
      ],
    ),
  );

  Widget _contact(BuildContext context, String label, Uri uri, IconData icon) =>
      Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: () => _open(context, uri),
              icon: Icon(icon, size: 22),
              label: Text(label, overflow: TextOverflow.ellipsis),
            ),
          ),
          IconButton(
            tooltip: 'Скопировать $label',
            onPressed: () => _copy(context, label),
            icon: const Icon(Icons.copy_outlined),
          ),
        ],
      );
}
