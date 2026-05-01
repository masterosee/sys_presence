/// Écran de connexion - CONATEL Présence
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_usernameCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) {
      setState(() => _error = 'Veuillez remplir tous les champs');
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.login(
        _usernameCtrl.text.trim(),
        _passwordCtrl.text,
      );
      if (mounted) {
        // Naviguer selon le rôle
        if (response.role == 'admin' || response.role == 'rh') {
          context.go('/dashboard');
        } else {
          context.go('/home');
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString().contains('401')
            ? 'Nom d\'utilisateur ou mot de passe incorrect'
            : 'Erreur de connexion. Vérifiez votre réseau.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 60),
              _buildLogo(),
              const SizedBox(height: 48),
              _buildForm(),
              const SizedBox(height: 32),
              _buildKioskButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Logo + titre ──────────────────────────────────────
  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primary, AppTheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.fingerprint, color: Colors.white, size: 46),
        ),
        const SizedBox(height: 20),
        const Text(
          'CONATEL',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Système de Présence',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  // ─── Formulaire ───────────────────────────────────────
  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Connexion',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        const SizedBox(height: 6),
        Text('Entrez vos identifiants', style: TextStyle(color: Colors.grey.shade500)),
        const SizedBox(height: 28),

        // Champ username
        TextField(
          controller: _usernameCtrl,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Nom d\'utilisateur',
            prefixIcon: Icon(Icons.person_outline, color: AppTheme.primary),
            hintText: 'ex: jdupont',
          ),
        ),
        const SizedBox(height: 16),

        // Champ mot de passe
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _login(),
          decoration: InputDecoration(
            labelText: 'Mot de passe',
            prefixIcon: Icon(Icons.lock_outline, color: AppTheme.primary),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),

        // Message d'erreur
        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.error.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: AppTheme.error, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: TextStyle(color: AppTheme.error, fontSize: 13))),
              ],
            ),
          ),
        ],

        const SizedBox(height: 28),

        // Bouton connexion
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _login,
            child: _loading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : const Text('Se connecter'),
          ),
        ),
      ],
    );
  }

  // ─── Bouton kiosque ───────────────────────────────────
  Widget _buildKioskButton() {
    return Column(
      children: [
        Divider(color: Colors.grey.shade200),
        const SizedBox(height: 16),
        Text('Tablette ou kiosque à l\'entrée ?',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => context.go('/kiosk'),
          icon: const Icon(Icons.tablet_android_outlined),
          label: const Text('Mode kiosque (QR Code)'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            side: BorderSide(color: AppTheme.primary.withOpacity(0.4)),
            foregroundColor: AppTheme.primary,
          ),
        ),
      ],
    );
  }
}
