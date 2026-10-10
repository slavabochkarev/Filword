import 'package:flutter/material.dart';

import 'neon_theme.dart';

class InfoPage extends StatelessWidget {
  const InfoPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Инфо')),
    body: ScenicBackground(
      child: ListView(
        padding: EdgeInsets.all(20),
        children: [
          Text(
            'ПоискСлов',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Text(
            '',
          ),
          SizedBox(height: 12),
          Text(
            'Проводите пальцем или мышью по соседним буквам либо нажимайте на них по очереди. Диагонали и повороты разрешены. Возврат на предыдущую клетку отменяет последний шаг. Слово засчитывается автоматически.',
          ),
          SizedBox(height: 12),
          Text('Прогресс хранится только на этом устройстве.'),
        ],
      ),
    ),
  );
}
