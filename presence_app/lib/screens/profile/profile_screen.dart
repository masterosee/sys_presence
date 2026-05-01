// lib/screens/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api_client.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 16),
            _buildHeader(),
            const SizedBox(height: 24),
            _buildProfileCard(),
            const SizedBox(height: 20),
            _buildSection('Compte', [
              _buildMenuItem(
                icon: Icons.person_outline_rounded,
                label: 'Mes informations',
                onTap: () {},
              ),
              _buildMenuItem(
                icon: Icons.lock_outline_rounded,
                label: 'Changer le mot de passe',
                onTap: () {},
              ),
              _buildMenuItem(
                icon: Icons.pin_outlined,
                label: 'Modifier mon PIN',
                onTap: () {},
              ),
            ]),
            const SizedBox(height: 16),
            _buildSection('Préférences', [
              _buildMenuItem(
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                onTap: () {},
                trailing: Switch(
                  value: true,
                  onChanged: (_) {},
                  activeColor: AppColors.blue,
                  activeTrackColor: AppColors.blue.withOpacity(0.3),
                  inactiveThumbColor: AppColors.muted,
                  inactiveTrackColor: AppColors.border,
                ),
              ),
              _buildMenuItem(
                icon: Icons.language_rounded,
                label: 'Langue',
                onTap: () {},
                value: 'Français',
              ),
            ]),
            const SizedBox(height: 16),
            _buildSection('Support', [
              _buildMenuItem(
                icon: Icons.help_outline_rounded,
                label: 'Aide',
                onTap: () {},
              ),
              _buildMenuItem(
                icon: Icons.info_outline_rounded,
                label: 'À propos',
                onTap: () {},
                value: 'v1.0.0',
              ),
            ]),
            const SizedBox(height: 16),
            _buildLogoutButton(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Text(
      'Profil',
      style: GoogleFonts.dmSans(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.blue, AppColors.purple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                'OB',
                style: GoogleFonts.dmSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ossiny Bien-Aimé',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ingénieur Réseau',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.blue.withOpacity(0.3)),
                  ),
                  child: Text(
                    'CNT-001',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppColors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: List.generate(items.length, (i) {
              return Column(
                children: [
                  items[i],
                  if (i < items.length - 1)
                    Divider(height: 1, color: AppColors.border),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? value,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.muted, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.text),
              ),
            ),
            if (value != null)
              Text(
                value,
                style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted),
              ),
            if (trailing != null) trailing,
            if (trailing == null)
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.muted,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await ApiClient().logout();
        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          );
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.red.withOpacity(0.3)),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.logout_rounded, color: AppColors.red, size: 18),
              const SizedBox(width: 8),
              Text(
                'Se déconnecter',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
