import 'package:care_platform_app/features/admin/domain/admin_moderation.dart';
import 'package:care_platform_app/features/admin/domain/admin_moderation_gateway.dart';
import 'package:flutter/material.dart';

class AdminModerationScreen extends StatefulWidget {
  const AdminModerationScreen({required this.gateway, super.key});

  final AdminModerationGateway gateway;

  @override
  State<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends State<AdminModerationScreen> {
  final Map<String, TextEditingController> _reasonControllers = {};
  List<PendingCaregiverProfile> _profiles = const [];
  final Set<String> _moderatingIds = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  @override
  void dispose() {
    for (final controller in _reasonControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPending() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final profiles = await widget.gateway.loadPending();
      if (!mounted) return;
      setState(() => _profiles = profiles);
    } on Object catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось загрузить анкеты');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      setState(() {
        _profiles = _profiles.where((item) => item.id != profile.id).toList();
        _reasonControllers.remove(profile.id)?.dispose();
      });
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
      appBar: AppBar(title: const Text('Модерация анкет')),
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
                onPressed: _loadPending,
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
      itemCount: _profiles.length,
      itemBuilder: (context, index) => _PendingProfileCard(
        profile: _profiles[index],
        reasonController: _reasonControllerFor(_profiles[index].id),
        isModerating: _moderatingIds.contains(_profiles[index].id),
        onApprove: () => _moderate(_profiles[index], ModerationStatus.approved),
        onReject: () => _moderate(_profiles[index], ModerationStatus.rejected),
      ),
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
}
