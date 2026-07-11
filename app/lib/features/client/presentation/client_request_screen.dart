import 'package:care_platform_app/features/client/domain/client_request.dart';
import 'package:care_platform_app/features/client/domain/client_request_gateway.dart';
import 'package:flutter/material.dart';

class ClientRequestScreen extends StatefulWidget {
  const ClientRequestScreen({required this.gateway, super.key});

  final ClientRequestGateway gateway;

  @override
  State<ClientRequestScreen> createState() => _ClientRequestScreenState();
}

class _ClientRequestScreenState extends State<ClientRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cityController = TextEditingController();
  final _careTypeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isSaving = false;
  bool _needsLiveIn = false;
  bool _needsNightShifts = false;
  bool _dementiaCase = false;
  bool _bedriddenCase = false;
  bool _strokeCase = false;
  bool _heartAttackCase = false;
  bool _traumaCase = false;

  @override
  void dispose() {
    _cityController.dispose();
    _careTypeController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    try {
      await widget.gateway.create(
        ClientRequestDraft(
          city: _cityController.text,
          careType: _careTypeController.text,
          description: _descriptionController.text,
          contactPhone: _phoneController.text,
          needsLiveIn: _needsLiveIn,
          needsNightShifts: _needsNightShifts,
          dementiaCase: _dementiaCase,
          bedriddenCase: _bedriddenCase,
          strokeCase: _strokeCase,
          heartAttackCase: _heartAttackCase,
          traumaCase: _traumaCase,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Заявка сохранена')));
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить заявку: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Поиск сиделки')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Заявка на подбор сиделки',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Опиши потребность — заявку можно будет дополнить позднее.',
              ),
              const SizedBox(height: 24),
              _requiredField(controller: _cityController, label: 'Город'),
              _requiredField(
                controller: _careTypeController,
                label: 'Тип ухода',
              ),
              _requiredField(
                controller: _descriptionController,
                label: 'Описание ситуации',
                maxLines: 4,
              ),
              _requiredField(controller: _phoneController, label: 'Телефон'),
              const SizedBox(height: 8),
              Text(
                'Особенности ухода',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              _checkbox(
                'Требуется проживание',
                _needsLiveIn,
                (value) => _needsLiveIn = value,
              ),
              _checkbox(
                'Нужны ночные смены',
                _needsNightShifts,
                (value) => _needsNightShifts = value,
              ),
              _checkbox(
                'Деменция',
                _dementiaCase,
                (value) => _dementiaCase = value,
              ),
              _checkbox(
                'Лежачий пациент',
                _bedriddenCase,
                (value) => _bedriddenCase = value,
              ),
              _checkbox(
                'После инсульта',
                _strokeCase,
                (value) => _strokeCase = value,
              ),
              _checkbox(
                'После инфаркта',
                _heartAttackCase,
                (value) => _heartAttackCase = value,
              ),
              _checkbox(
                'После травмы',
                _traumaCase,
                (value) => _traumaCase = value,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: Text(_isSaving ? 'Сохранение…' : 'Сохранить заявку'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _requiredField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey(label),
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'Поле обязательно' : null,
    ),
  );

  Widget _checkbox(String label, bool value, ValueChanged<bool> onChanged) =>
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value,
        onChanged: (value) => setState(() => onChanged(value ?? false)),
      );
}
