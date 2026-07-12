import 'package:care_platform_app/features/client/domain/caregiver_search.dart';
import 'package:care_platform_app/features/client/domain/caregiver_search_gateway.dart';
import 'package:flutter/material.dart';

class ClientCaregiverSearchScreen extends StatefulWidget {
  const ClientCaregiverSearchScreen({
    required this.gateway,
    required this.onLeaveRequest,
    super.key,
  });

  final CaregiverSearchGateway gateway;
  final VoidCallback onLeaveRequest;

  @override
  State<ClientCaregiverSearchScreen> createState() =>
      _ClientCaregiverSearchScreenState();
}

class _ClientCaregiverSearchScreenState
    extends State<ClientCaregiverSearchScreen> {
  static const _pageSize = 20;

  final _cityController = TextEditingController();
  List<CaregiverSearchCard> _items = const [];
  bool _isLoading = false;
  bool _searched = false;
  bool _hasMore = false;
  int _currentPage = 0;
  int _requestId = 0;
  String? _activeCity;
  String? _error;

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final city = _cityController.text.trim();
    if (city.isEmpty) return;

    final requestId = ++_requestId;
    setState(() {
      _isLoading = true;
      _searched = true;
      _error = null;
      _activeCity = city;
    });
    try {
      final result = await widget.gateway.loadApproved(
        city: city,
        page: 0,
        pageSize: _pageSize,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = result.items;
        _hasMore = result.hasMore;
        _currentPage = 0;
      });
    } on Object catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _error = 'Не удалось загрузить анкеты');
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoading || !_hasMore || _activeCity == null) return;

    final nextPage = _currentPage + 1;
    final requestId = _requestId;
    final city = _activeCity!;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await widget.gateway.loadApproved(
        city: city,
        page: nextPage,
        pageSize: _pageSize,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _items = [..._items, ...result.items];
        _hasMore = result.hasMore;
        _currentPage = nextPage;
      });
    } on Object catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _error = 'Не удалось загрузить следующую страницу');
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Поиск сиделки')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextField(
              key: const ValueKey('client-search-city'),
              controller: _cityController,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(labelText: 'Город'),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _isLoading ? null : _search,
              child: const Text('Найти сиделку'),
            ),
            if (_isLoading && _items.isEmpty) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_error != null) ...[
              const SizedBox(height: 24),
              Text(_error!, textAlign: TextAlign.center),
            ],
            if (!_isLoading &&
                _error == null &&
                _searched &&
                _items.isEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'По вашему запросу сиделок пока нет',
                textAlign: TextAlign.center,
              ),
              TextButton(
                onPressed: widget.onLeaveRequest,
                child: const Text('Оставить заявку'),
              ),
            ],
            if (_items.isNotEmpty) ...[
              for (final item in _items) _CaregiverCard(item: item),
              if (_hasMore)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _loadNextPage,
                    child: const Text('Показать ещё'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CaregiverCard extends StatelessWidget {
  const _CaregiverCard({required this.item});

  final CaregiverSearchCard item;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.fullName, style: Theme.of(context).textTheme.titleMedium),
            Text(item.city),
            Text('Опыт: ${item.experience}'),
            Text(item.schedule),
            const SizedBox(height: 8),
            Text(item.description),
          ],
        ),
      ),
    );
  }
}
