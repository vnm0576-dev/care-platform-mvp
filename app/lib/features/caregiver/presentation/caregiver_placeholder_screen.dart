import 'package:flutter/material.dart';

class CaregiverPlaceholderScreen extends StatelessWidget {
  const CaregiverPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Анкета сиделки')),
      body: const Center(child: Text('Раздел сиделки готов к реализации.')),
    );
  }
}
