import 'package:care_platform_app/features/auth/domain/auth_gateway.dart';
import 'package:care_platform_app/features/auth/domain/auth_registration_request.dart';
import 'package:care_platform_app/navigation/app_routes.dart';
import 'package:flutter/material.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({required this.authGateway, super.key});

  final AuthGateway authGateway;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  AppRole _role = AppRole.caregiver;
  bool _acceptedTerms = false;
  bool _passwordVisible = false;
  bool _isSubmitting = false;
  String? _consentError;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formIsValid = _formKey.currentState!.validate();
    setState(() {
      _consentError = _acceptedTerms
          ? null
          : 'Подтвердите согласие с правилами';
    });
    if (!formIsValid || !_acceptedTerms) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final result = await widget.authGateway.signUp(
        AuthRegistrationRequest(
          fullName: _fullNameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          password: _passwordController.text,
          role: _role,
        ),
      );
      if (!mounted) {
        return;
      }
      if (result.needsEmailConfirmation) {
        await _showConfirmationNotice();
        return;
      }
      final route = switch (_role) {
        AppRole.caregiver => AppRoutes.caregiver,
        AppRole.client => AppRoutes.client,
        AppRole.admin => AppRoutes.admin,
      };
      await Navigator.pushReplacementNamed(context, route);
    } on Object catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось зарегистрироваться. Попробуйте ещё раз.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _showConfirmationNotice() {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Подтвердите email'),
        content: const Text(
          'Мы отправили письмо для подтверждения адреса. После подтверждения войдите в приложение.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Создайте аккаунт',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Выберите роль, которая соответствует вашей цели.',
                    ),
                    const SizedBox(height: 20),
                    RadioGroup<AppRole>(
                      groupValue: _role,
                      onChanged: (value) {
                        if (!_isSubmitting && value != null) {
                          setState(() => _role = value);
                        }
                      },
                      child: const Column(
                        children: [
                          RadioListTile<AppRole>(
                            value: AppRole.caregiver,
                            title: Text('Я предлагаю услуги сиделки'),
                            contentPadding: EdgeInsets.zero,
                          ),
                          RadioListTile<AppRole>(
                            value: AppRole.client,
                            title: Text('Я ищу сиделку'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _fullNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'ФИО'),
                      validator: _validateFullName,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Телефон (необязательно)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_passwordVisible,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'Пароль',
                        helperText: 'Не менее 8 символов',
                        suffixIcon: IconButton(
                          tooltip: _passwordVisible
                              ? 'Скрыть пароль'
                              : 'Показать пароль',
                          icon: Icon(
                            _passwordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: _isSubmitting
                              ? null
                              : () => setState(
                                  () => _passwordVisible = !_passwordVisible,
                                ),
                        ),
                      ),
                      validator: _validatePassword,
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: _acceptedTerms,
                      onChanged: _isSubmitting
                          ? null
                          : (value) => setState(() {
                              _acceptedTerms = value ?? false;
                              _consentError = _acceptedTerms
                                  ? null
                                  : _consentError;
                            }),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Согласен с правилами платформы'),
                    ),
                    if (_consentError != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, bottom: 12),
                        child: Text(
                          _consentError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Создать аккаунт'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _validateFullName(String? value) {
    if ((value?.trim().length ?? 0) < 2) {
      return 'Введите ФИО';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty || !email.contains('@')) {
      return 'Введите корректный email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').length < 8) {
      return 'Пароль должен содержать не менее 8 символов';
    }
    return null;
  }
}
