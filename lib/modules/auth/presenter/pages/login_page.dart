import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/user_role.dart';
import '../../state/auth_state.dart';
import '../controllers/auth_controller.dart';
import '../widgets/role_selector.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  UserRole _selectedRole = UserRole.admin;
  bool _isLoading = false;
  String? _errorText;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // Helper: Trigger login flow (no breaking changes)
  Future<void> _onLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final notifier = ref.read(authStateProvider.notifier);
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    try {
      await notifier.login(
        role: _selectedRole,
        email: email,
        password: password,
      );

      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      setState(() {
        _errorText = 'Login failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Helper: Get icon for role
  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.tech:
        return Icons.engineering_outlined;
      case UserRole.supervisor:
        return Icons.supervisor_account_outlined;
      case UserRole.dispatcher:
        return Icons.headset_mic_outlined;
      case UserRole.admin:
        return Icons.admin_panel_settings_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 900;

    return Scaffold(
      body: isMobile ? _buildMobileLayout(auth) : _buildDesktopLayout(auth),
    );
  }

  // Mobile layout - single column with dark theme
  Widget _buildMobileLayout(AuthState auth) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1a1a2e),
            const Color(0xFF16213e),
          ],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildLoginForm(auth),
          ),
        ),
      ),
    );
  }

  // Desktop layout - split screen
  Widget _buildDesktopLayout(AuthState auth) {
    return Row(
      children: [
        // Left side - Dark form
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1a1a2e),
                  const Color(0xFF16213e),
                ],
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: _buildLoginForm(auth),
                ),
              ),
            ),
          ),
        ),

        // Right side - Illustration/Gradient
        Expanded(
          flex: 3,
          child: _buildBrandingPanel(context),
        ),
      ],
    );
  }

  // Helper: Build branding panel for right side
  Widget _buildBrandingPanel(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withValues(alpha: 0.8),
            colorScheme.secondary.withValues(alpha: 0.6),
            colorScheme.tertiary.withValues(alpha: 0.4),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Grid pattern overlay
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),

          // Content
          Center(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bolt,
                    size: 120,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Voltcore',
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withValues(alpha: 0.95),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Inspection Management System',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white.withValues(alpha: 0.8),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 48),
                  _buildFeatureBox(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper: Build feature box
  Widget _buildFeatureBox() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          _buildFeaturePill(Icons.checklist_rtl, 'Maintenance Tracking'),
          const SizedBox(height: 12),
          _buildFeaturePill(Icons.description_outlined, 'Digital Reports'),
          const SizedBox(height: 12),
          _buildFeaturePill(Icons.analytics_outlined, 'Real-time Analytics'),
        ],
      ),
    );
  }

  // Helper: Build feature pill
  Widget _buildFeaturePill(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 20),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Helper: Build login form (reusable for mobile and desktop)
  Widget _buildLoginForm(AuthState auth) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge
        _buildSignInBadge(),
        const SizedBox(height: 32),

        // Welcome heading
        Text(
          'Welcome!',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 16),

        // Subtitle
        Text(
          'Sign in with your credentials to access Voltcore inspection and maintenance management.',
          style: TextStyle(
            fontSize: 15,
            color: Colors.white.withValues(alpha: 0.7),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 40),

        // Current session banner (unchanged from original)
        if (auth.isAuthenticated) ...[
          _CurrentSessionBanner(state: auth),
          const SizedBox(height: 24),
        ],

        // Error message
        if (_errorText != null) ...[
          _buildErrorBanner(),
          const SizedBox(height: 24),
        ],

        // Form
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Email field
              _ModernTextField(
                controller: _emailCtrl,
                label: 'Email',
                hintText: 'Enter your email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                enabled: !_isLoading,
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'Please enter an email.';
                  if (!v.contains('@')) return 'Enter a valid email address.';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Password field
              _ModernTextField(
                controller: _passwordCtrl,
                label: 'Password',
                hintText: 'Enter your password',
                icon: Icons.lock_outline,
                obscureText: _obscurePassword,
                enabled: !_isLoading,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                validator: (value) {
                  final v = value ?? '';
                  if (v.isEmpty) return 'Please enter a password.';
                  if (v.length < 4) return 'Password is too short for this demo.';
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Divider with "SELECT ROLE"
              _buildRoleDivider(),
              const SizedBox(height: 24),

              // Role selector - modern wallet-style
              _ModernRoleSelector(
                selectedRole: _selectedRole,
                enabled: !_isLoading,
                getRoleIcon: _getRoleIcon,
                onChanged: (role) {
                  setState(() {
                    _selectedRole = role;
                  });
                },
              ),

              const SizedBox(height: 32),

              // Login button (unchanged functionality)
              _buildLoginButton(),

              // Logout button when authenticated (unchanged functionality)
              if (auth.isAuthenticated) ...[
                const SizedBox(height: 12),
                _buildLogoutButton(),
              ],

              const SizedBox(height: 32),

              // Footer links
              _buildFooterLinks(),
            ],
          ),
        ),
      ],
    );
  }

  // Helper: Build sign-in badge
  Widget _buildSignInBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        'SIGN IN',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  // Helper: Build error banner
  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[300], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorText!,
              style: TextStyle(
                color: Colors.red[300],
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper: Build role divider
  Widget _buildRoleDivider() {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: Colors.white.withValues(alpha: 0.1),
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'SELECT ROLE',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: Colors.white.withValues(alpha: 0.1),
            thickness: 1,
          ),
        ),
      ],
    );
  }

  // Helper: Build login button (unchanged functionality)
  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _onLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1a1a2e),
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.3),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: const Color(0xFF1a1a2e),
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.login, size: 20),
            const SizedBox(width: 12),
            Text(
              'Login as ${roleLabel(_selectedRole)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper: Build logout button (unchanged functionality)
  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: _isLoading
            ? null
            : () async {
          final controller = ref.read(authStateProvider.notifier);
          await controller.logout();
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.3),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, size: 20),
            const SizedBox(width: 12),
            Text(
              'Logout',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper: Build footer links
  Widget _buildFooterLinks() {
    return Center(
      child: Wrap(
        spacing: 16,
        children: [
          _FooterLink('Privacy'),
          _FooterLink('Terms'),
          _FooterLink('voltcore.app'),
        ],
      ),
    );
  }
}

/// Modern text field widget - helper component
class _ModernTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final bool enabled;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;

  const _ModernTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.enabled = true,
    this.keyboardType,
    this.validator,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        color: Colors.white,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.5), size: 20),
        suffixIcon: suffixIcon,
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 14,
        ),
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.3),
          fontSize: 14,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.red.withValues(alpha: 0.5),
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.red.withValues(alpha: 0.7),
            width: 2,
          ),
        ),
        errorStyle: TextStyle(
          color: Colors.red[300],
          fontSize: 12,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}

/// Modern role selector - styled like wallet connections
/// Helper component that uses existing roleLabel() function
class _ModernRoleSelector extends StatelessWidget {
  final UserRole selectedRole;
  final bool enabled;
  final IconData Function(UserRole) getRoleIcon;
  final ValueChanged<UserRole> onChanged;

  const _ModernRoleSelector({
    required this.selectedRole,
    required this.enabled,
    required this.getRoleIcon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: UserRole.values.map((role) {
        final isSelected = selectedRole == role;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _RoleOption(
            icon: getRoleIcon(role),
            label: roleLabel(role), // Uses existing roleLabel() function
            selected: isSelected,
            enabled: enabled,
            onTap: () => onChanged(role),
          ),
        );
      }).toList(),
    );
  }
}

/// Individual role option button - helper component
class _RoleOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _RoleOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.1),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Colors.white.withValues(alpha: selected ? 0.9 : 0.6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: selected ? 0.95 : 0.7),
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Current session banner - unchanged from original
class _CurrentSessionBanner extends StatelessWidget {
  const _CurrentSessionBanner({required this.state});

  final AuthState state;

  @override
  Widget build(BuildContext context) {
    final roleText =
    state.currentRole != null ? roleLabel(state.currentRole!) : 'Unknown';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: Colors.blue[300],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Signed in as $roleText'
                  '${state.email != null ? ' • ${state.email}' : ''}',
              style: TextStyle(
                color: Colors.blue[100],
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Footer link - helper component
class _FooterLink extends StatelessWidget {
  final String text;

  const _FooterLink(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.4),
        fontSize: 13,
      ),
    );
  }
}

/// Grid painter for background pattern - helper component
class _GridPainter extends CustomPainter {
  final Color color;

  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 40.0;

    // Draw vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}