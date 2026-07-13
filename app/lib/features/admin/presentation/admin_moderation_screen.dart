import 'package:care_platform_app/features/admin/domain/admin_moderation.dart';
import 'package:care_platform_app/features/admin/domain/admin_moderation_gateway.dart';
import 'package:flutter/material.dart';

class AdminModerationScreen extends StatefulWidget {
  const AdminModerationScreen({
    required this.gateway,
    this.onSignOut,
    super.key,
  });

  final AdminModerationGateway gateway;
  final VoidCallback? onSignOut;

  @override
  State<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends State<AdminModerationScreen> {
  static const _pageSize = 20;

  final Map<String, TextEditingController> _reasonControllers = {};
  List<PendingCaregiverProfile> _profiles = const [];
  final Set<String> _moderatingIds = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  PendingCaregiverCursor? _nextCursor;
  int _loadGeneration = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPending(reset: true);
  }

  @override
  void dispose() {
    for (final controller in _reasonControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPending({required bool reset}) async {
    final generation = reset ? ++_loadGeneration : _loadGeneration;
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }
    try {
      final result = await widget.gateway.loadPending(
        cursor: reset ? null : _nextCursor,
        pageSize: _pageSize,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _profiles = reset ? result.items : [..._profiles, ...result.items];
        _nextCursor = result.nextCursor;
        _hasMore = result.hasMore;
      });
    } on Object catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      if (reset) {
        setState(() => _error = 'Не удалось загрузить анкеты');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось загрузить ещё анкеты')),
        );
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  TextEditingController _reasonControllerFor(String profileId) =>
      _reasonControllers.putIfAbsent(profileId, TextEditingController.new);

  Future<void> _moderate(
    PendingCaregiverProfile profile,
    ModerationStatus status,
  ) async {
    final reason = _reasonControllerFor(profile.id).text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Укажите причину решения')));
      return;
    }

    setState(() => _moderatingIds.add(profile.id));
    try {
      await widget.gateway.moderate(
        caregiverProfileId: profile.id,
        newStatus: status,
        reason: reason,
      );
      if (!mounted) return;
      _reasonControllers.remove(profile.id)?.dispose();
      await _loadPending(reset: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == ModerationStatus.approved
                ? 'Анкета одобрена'
                : 'Анкета отклонена',
          ),
        ),
      );
    } on Object catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить решение')),
      );
    } finally {
      if (mounted) setState(() => _moderatingIds.remove(profile.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Модерация анкет'),
        actions: widget.onSignOut == null
            ? null
            : [
                IconButton(
                  onPressed: widget.onSignOut,
                  tooltip: 'Выйти',
                  icon: const Icon(Icons.logout),
                ),
              ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _loadPending(reset: true),
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }
    if (_profiles.isEmpty) {
      return const Center(child: Text('Анкеты ожидают модерации'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _profiles.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _profiles.length) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: OutlinedButton(
              onPressed: _isLoadingMore
                  ? null
                  : () => _loadPending(reset: false),
              child: _isLoadingMore
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Загрузить ещё'),
            ),
          );
        }
        final profile = _profiles[index];
        return _PendingProfileCard(
          profile: profile,
          reasonController: _reasonControllerFor(profile.id),
          isModerating: _moderatingIds.contains(profile.id),
          onApprove: () => _moderate(profile, ModerationStatus.approved),
          onReject: () => _moderate(profile, ModerationStatus.rejected),
        );
      },
    );
  }
}

class _PendingProfileCard extends StatelessWidget {
  const _PendingProfileCard({
    required this.profile,
    required this.reasonController,
    required this.isModerating,
    required this.onApprove,
    required this.onReject,
  });

  final PendingCaregiverProfile profile;
  final TextEditingController reasonController;
  final bool isModerating;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profile.fullName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('${profile.city} · ${profile.experience}'),
            if (profile.contactPhone.isNotEmpty)
              Text('Телефон: ${profile.contactPhone}'),
            if (profile.district case final district?) Text('Район: $district'),
            if (profile.education case final education?)
              Text('Образование: $education'),
            if (profile.photoUrl case final photoUrl?) Text('Фото: $photoUrl'),
            Text('Отправлено: ${_submittedAtText(profile.submittedAt)}'),
            if (profile.skills.isNotEmpty)
              Text('Навыки: ${profile.skills.join(', ')}'),
            if (profile.certificates.isNotEmpty)
              Text('Сертификаты: ${profile.certificates.join(', ')}'),
            if (profile.desiredPayment != null)
              Text('Желаемая оплата: ${profile.desiredPayment}'),
            Text('С проживанием: ${profile.readyForLiveIn ? 'Да' : 'Нет'}'),
            Text('Ночные смены: ${profile.readyForNightShifts ? 'Да' : 'Нет'}'),
            Text('Опыт: ${_experienceFlags.join('; ')}'),
            if (profile.schedule.isNotEmpty) Text(profile.schedule),
            if (profile.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(profile.description),
            ],
            const SizedBox(height: 16),
            TextField(
              key: ValueKey('moderation-reason-${profile.id}'),
              controller: reasonController,
              enabled: !isModerating,
              decoration: const InputDecoration(labelText: 'Причина решения'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  key: ValueKey('approve-${profile.id}'),
                  onPressed: isModerating ? null : onApprove,
                  child: const Text('Одобрить'),
                ),
                OutlinedButton(
                  key: ValueKey('reject-${profile.id}'),
                  onPressed: isModerating ? null : onReject,
                  child: const Text('Отклонить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<String> get _experienceFlags => [
    'деменция — ${profile.dementiaExperience ? 'Да' : 'Нет'}',
    'лежачие пациенты — ${profile.bedriddenExperience ? 'Да' : 'Нет'}',
    'инсульт — ${profile.strokeExperience ? 'Да' : 'Нет'}',
    'инфаркт — ${profile.heartAttackExperience ? 'Да' : 'Нет'}',
    'травмы — ${profile.traumaExperience ? 'Да' : 'Нет'}',
  ];

  String _submittedAtText(DateTime value) {
    final local = value.toLocal();
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }
}
