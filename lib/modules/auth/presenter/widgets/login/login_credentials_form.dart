import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'login_palette.dart';
import 'login_validators.dart';

/// Email and password fields plus the Sign in button.
///
/// Owns no state about the request: the page passes [submitting] and receives
/// [onSubmit]. The button is disabled while the form is invalid or submitting.
class LoginCredentialsForm extends StatefulWidget {
  const LoginCredentialsForm({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.submitting,
    required this.onSubmit,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  State<LoginCredentialsForm> createState() => _LoginCredentialsFormState();
}

class _LoginCredentialsFormState extends State<LoginCredentialsForm> {
  bool _obscure = true;

  bool get _valid => LoginValidators.isValid(
        widget.emailController.text,
        widget.passwordController.text,
      );

  @override
  void initState() {
    super.initState();
    widget.emailController.addListener(_changed);
    widget.passwordController.addListener(_changed);
  }

  @override
  void dispose() {
    widget.emailController.removeListener(_changed);
    widget.passwordController.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _submitFromKeyboard() {
    if (_valid && !widget.submitting) widget.onSubmit();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.submitting;
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LoginTextField(
            controller: widget.emailController,
            label: 'Email',
            hint: 'name@company.com',
            icon: Icons.email_outlined,
            enabled: enabled,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            validator: LoginValidators.email,
          ),
          const SizedBox(height: 20),
          LoginTextField(
            controller: widget.passwordController,
            label: 'Password',
            hint: 'Enter your password',
            icon: Icons.lock_outline,
            enabled: enabled,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            validator: LoginValidators.password,
            onSubmitted: (_) => _submitFromKeyboard(),
            suffixIcon: IconButton(
              tooltip: _obscure ? 'Show password' : 'Hide password',
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: LoginPalette.white(0.6),
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _valid && enabled
                  ? () {
                      TextInput.finishAutofillContext();
                      widget.onSubmit();
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: LoginPalette.bgTop,
                disabledBackgroundColor: LoginPalette.white(0.3),
                disabledForegroundColor: LoginPalette.white(0.6),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: widget.submitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: LoginPalette.bgTop,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.login, size: 20),
                        SizedBox(width: 12),
                        Text(
                          'Sign in',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Text field styled for the dark login palette.
class LoginTextField extends StatelessWidget {
  const LoginTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onSubmitted,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  OutlineInputBorder _border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      autocorrect: false,
      enableSuggestions: !obscureText,
      style: loginText(context, text.bodyLarge),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: LoginPalette.white(0.5), size: 20),
        suffixIcon: suffixIcon,
        labelStyle: loginText(context, text.bodyMedium, alpha: 0.7),
        hintStyle: loginText(context, text.bodyMedium, alpha: 0.3),
        filled: true,
        fillColor: LoginPalette.white(0.05),
        border: _border(LoginPalette.white(0.1)),
        enabledBorder: _border(LoginPalette.white(0.1)),
        focusedBorder: _border(LoginPalette.white(0.4), 2),
        errorBorder: _border(Colors.red.withValues(alpha: 0.5)),
        focusedErrorBorder: _border(Colors.red.withValues(alpha: 0.7), 2),
        errorMaxLines: 3,
        errorStyle: text.bodySmall?.copyWith(color: LoginPalette.error),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
