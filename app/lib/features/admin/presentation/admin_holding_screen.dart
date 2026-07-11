import 'package:flutter/material.dart';

class AdminHoldingScreen extends StatelessWidget {
  const AdminHoldingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Администрирование')),
      body: const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Раздел модерации готовится',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
