import 'package:flutter/material.dart';

class AuthPlaceholderScreen extends StatelessWidget {
  const AuthPlaceholderScreen({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Экран будет реализован на следующем этапе.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
