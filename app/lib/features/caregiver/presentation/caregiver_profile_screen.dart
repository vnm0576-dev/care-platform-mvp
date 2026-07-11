import 'package:care_platform_app/features/caregiver/domain/caregiver_profile.dart';
import 'package:care_platform_app/features/caregiver/domain/caregiver_profile_gateway.dart';
import 'package:flutter/material.dart';

class CaregiverProfileScreen extends StatefulWidget {
  const CaregiverProfileScreen({required this.gateway, super.key});

  final CaregiverProfileGateway gateway;

  @override
  State<CaregiverProfileScreen> createState() => _CaregiverProfileScreenState();
}

class _CaregiverProfileScreenState extends State<CaregiverProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _experienceController = TextEditingController();
  final _scheduleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _skills = <String>{};

  static const _availableSkills = [
    'Уход при деменции',
    'Уход за лежачим пациентом',
    'Восстановление после инсульта',
    'Контроль приёма лекарств',
    'Ночные смены',
    'Приготовление пищи',
  ];

  bool _isSaving = false;
  CaregiverProfileRecord? _record;

  @override
  void dispose() {
    _fullNameController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _experienceController.dispose();
    _scheduleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveDraft() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    try {
      final record = await widget.gateway.saveDraft(
        draft: CaregiverProfileDraft(
          fullName: _fullNameController.text,
          city: _cityController.text,
          district: '',
          contactPhone: _phoneController.text,
          experience: _experienceController.text,
          education: '',
          certificates: const [],
          skills: _skills.toList(growable: false),
          schedule: _scheduleController.text,
          description: _descriptionController.text,
          desiredPayment: null,
          readyForLiveIn: false,
          readyForNightShifts: false,
          dementiaExperience: false,
          bedriddenExperience: false,
          strokeExperience: false,
          heartAttackExperience: false,
          traumaExperience: false,
        ),
      );
      if (!mounted) return;
      setState(() => _record = record);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Черновик сохранён')));
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить черновик: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _submitForReview() async {
    final record = _record;
    if (record == null) return;

    setState(() => _isSaving = true);
    try {
      await widget.gateway.submitForReview(record.id);
      if (!mounted) return;
      setState(
        () => _record = CaregiverProfileRecord(
          id: record.id,
          status: CaregiverProfileStatus.pendingReview,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Анкета отправлена на модерацию')),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отправить анкету: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Анкета сиделки')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Черновик анкеты сиделки',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Заполни базовые сведения. Анкету можно сохранить и дополнить до отправки на модерацию.',
              ),
              const SizedBox(height: 24),
              _requiredField(controller: _fullNameController, label: 'ФИО'),
              _requiredField(controller: _cityController, label: 'Город'),
              _requiredField(controller: _phoneController, label: 'Телефон'),
              _requiredField(
                controller: _experienceController,
                label: 'Опыт работы',
                maxLines: 3,
              ),
              _requiredField(
                controller: _scheduleController,
                label: 'График',
                maxLines: 2,
              ),
              _requiredField(
                controller: _descriptionController,
                label: 'О себе',
                maxLines: 4,
              ),
              const Text('Навыки'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableSkills
                    .map((skill) {
                      return FilterChip(
                        label: Text(skill),
                        selected: _skills.contains(skill),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _skills.add(skill);
                            } else {
                              _skills.remove(skill);
                            }
                          });
                        },
                      );
                    })
                    .toList(growable: false),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isSaving ? null : _saveDraft,
                child: Text(_isSaving ? 'Сохранение…' : 'Сохранить черновик'),
              ),
              if (_record?.status == CaregiverProfileStatus.draft) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _isSaving || _skills.isEmpty
                      ? null
                      : _submitForReview,
                  child: const Text('Отправить на модерацию'),
                ),
              ],
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
}
