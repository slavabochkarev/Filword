import 'package:flutter/material.dart';

import 'neon_theme.dart';

class ThemePage extends StatefulWidget {
  const ThemePage({super.key, required this.light, required this.onChanged});
  final bool light;
  final ValueChanged<bool> onChanged;
  @override
  State<ThemePage> createState() => _ThemePageState();
}

class _ThemePageState extends State<ThemePage> {
  late bool light = widget.light;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Тема')),
    body: ScenicBackground(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          NeonPanel(
            child: ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: const Text('Тёмная'),
              trailing: !light ? const Icon(Icons.check) : null,
              onTap: () {
                setState(() => light = false);
                widget.onChanged(false);
              },
            ),
          ),
          const SizedBox(height: 12),
          NeonPanel(
            child: ListTile(
              leading: const Icon(Icons.light_mode_outlined),
              title: const Text('Светлая'),
              trailing: light ? const Icon(Icons.check) : null,
              onTap: () {
                setState(() => light = true);
                widget.onChanged(true);
              },
            ),
          ),
        ],
      ),
    ),
  );
}
