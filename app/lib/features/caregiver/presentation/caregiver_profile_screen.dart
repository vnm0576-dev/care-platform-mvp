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
  bool _isLoading = true;
  CaregiverProfileRecord? _record;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  Future<void> _loadExistingProfile() async {
    try {
      final record = await widget.gateway.loadOwnProfile();
      if (!mounted) return;
      _hydrateDraft(record?.draft);
      setState(() {
        _record = record;
        _isLoading = false;
      });
    } on Object {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _hydrateDraft(CaregiverProfileDraft? draft) {
    if (draft == null) return;
    _fullNameController.text = draft.fullName;
    _cityController.text = draft.city;
    _phoneController.text = draft.contactPhone;
    _experienceController.text = draft.experience;
    _scheduleController.text = draft.schedule;
    _descriptionController.text = draft.description;
    _skills
      ..clear()
      ..addAll(draft.skills);
  }

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

  CaregiverProfileDraft _currentDraft() => CaregiverProfileDraft(
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
  );

  Future<CaregiverProfileRecord?> _persistCurrentDraft({
    bool showSuccess = true,
  }) async {
    final record = await widget.gateway.saveDraft(
      draft: _currentDraft(),
      existingProfileId: _record?.id,
    );
    if (!mounted) return null;
    setState(() => _record = record);
    if (showSuccess) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Черновик сохранён')));
    }
    return record;
  }

  Future<void> _saveDraft() async {
    if (_isLoading || !_isEditable) return;
    setState(() => _isSaving = true);
    try {
      await _persistCurrentDraft();
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
    if (_isLoading || !_isEditable) return;
    setState(() => _isSaving = true);
    try {
      final record = await _persistCurrentDraft(showSuccess: false);
      if (record == null) return;
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

  bool get _isEditable => switch (_record?.status) {
    null ||
    CaregiverProfileStatus.draft ||
    CaregiverProfileStatus.rejected => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final canEdit = !_isLoading && _isEditable;
    final canSubmit =
        _record == null ||
        _record?.status == CaregiverProfileStatus.draft ||
        _record?.status == CaregiverProfileStatus.rejected;
    final isReadOnly = !_isLoading && _record != null && !_isEditable;
    return Scaffold(
      appBar: AppBar(title: const Text('Анкета сиделки')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoading)
              const Text('Загрузка анкеты…')
            else if (isReadOnly)
              Text(_readOnlyStatusMessage(_record!.status))
            else ...[
              FilledButton(
                onPressed: _isSaving ? null : _saveDraft,
                child: Text(_isSaving ? 'Сохранение…' : 'Сохранить черновик'),
              ),
              if (canSubmit) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _isSaving || _skills.isEmpty
                      ? null
                      : _submitForReview,
                  child: const Text('Отправить на модерацию'),
                ),
              ],
            ],
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Черновик анкеты сиделки',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Черновик можно сохранить неполным. Полнота проверяется при отправке на модерацию.',
            ),
            const SizedBox(height: 24),
            _field(
              controller: _fullNameController,
              label: 'ФИО',
              enabled: canEdit,
            ),
            _field(
              controller: _cityController,
              label: 'Город',
              enabled: canEdit,
            ),
            _field(
              controller: _phoneController,
              label: 'Телефон',
              enabled: canEdit,
            ),
            _field(
              controller: _experienceController,
              label: 'Опыт работы',
              maxLines: 3,
              enabled: canEdit,
            ),
            _field(
              controller: _scheduleController,
              label: 'График',
              maxLines: 2,
              enabled: canEdit,
            ),
            _field(
              controller: _descriptionController,
              label: 'О себе',
              maxLines: 4,
              enabled: canEdit,
            ),
            const Text('Навыки'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableSkills
                  .map(
                    (skill) => FilterChip(
                      label: Text(skill),
                      selected: _skills.contains(skill),
                      onSelected: !canEdit
                          ? null
                          : (selected) {
                              setState(() {
                                if (selected) {
                                  _skills.add(skill);
                                } else {
                                  _skills.remove(skill);
                                }
                              });
                            },
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    bool enabled = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      key: ValueKey(label),
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
    ),
  );

  String _readOnlyStatusMessage(CaregiverProfileStatus status) =>
      switch (status) {
        CaregiverProfileStatus.approved =>
          'Анкета одобрена и недоступна для редактирования.',
        CaregiverProfileStatus.pendingReview =>
          'Анкета на модерации и недоступна для редактирования.',
        CaregiverProfileStatus.hidden =>
          'Анкета скрыта и недоступна для редактирования.',
        _ => '',
      };
}
