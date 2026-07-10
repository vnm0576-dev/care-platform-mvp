import 'package:flutter/material.dart';

class ClientPlaceholderScreen extends StatelessWidget {
  const ClientPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Поиск сиделки')),
      body: const Center(child: Text('Раздел клиента готов к реализации.')),
    );
  }
}
