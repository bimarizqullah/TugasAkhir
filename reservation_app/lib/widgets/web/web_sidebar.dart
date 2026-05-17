import 'dart:convert';
import 'package:flutter/material.dart';
import '../../utils/storage.dart';
import '../../services/auth_service.dart';
import '../../screens/shared/edit_profile_screen.dart';

/// Sidebar navigasi untuk tampilan Web/Desktop.
class WebSidebar extends StatefulWidget {
  final int currentIndex;
  final void Function(int) onTap;
  final VoidCallback? onReservationTap;

  const WebSidebar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onReservationTap,
  });

  @override
  State<WebSidebar> createState() => _WebSidebarState();
}

class _WebSidebarState extends State<WebSidebar> {
  Map<String, dynamic>? _user;
  bool _profileMenuOpen = false;

  static const Color _primary     = Color(0xFF2563EB);
  static const Color _primarySoft = Color(0xFFEFF6FF);
  static const Color _textGrey    = Color(0xFF94A3B8);
  static const Color _textDark    = Color(0xFF1E293B);
  static const Color _bgSidebar   = Color(0xFFFFFFFF);
  static const Color _border      = Color(0xFFE2E8F0);
  static const Color _danger      = Color(0xFFDC2626);

  static const _items = [
    _SidebarItem(icon: Icons.home_outlined,           activeIcon: Icons.home_rounded,   label: 'Beranda'),
    _SidebarItem(icon: Icons.history_outlined,        activeIcon: Icons.history,        label: 'Riwayat'),
    _SidebarItem(icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month, label: 'Reservasi'),
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final userStr = await Storage.getUser();
    if (userStr != null && mounted) {
      setState(() => _user = jsonDecode(userStr));
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  void _openEditProfile() {
    setState(() => _profileMenuOpen = false);
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: EditProfileScreen(user: _user ?? {}, isDialog: true),
      ),
    ).then((updatedUser) {
      if (updatedUser != null && mounted) {
        setState(() => _user = updatedUser as Map<String, dynamic>);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: _bgSidebar,
        border: Border(right: BorderSide(color: _border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBrand(),
          const Divider(height: 1, color: _border),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _items.length,
              itemBuilder: (_, i) => _buildNavItem(
                item: _items[i],
                index: i,
                isActive: widget.currentIndex == i,
              ),
            ),
          ),
          _buildProfileSection(),
        ],
      ),
    );
  }

  Widget _buildBrand() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset(
              'assets/images/brand.png',
              width: 130,
              height: 130,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Etan Patung',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold, color: _textDark)),
                Text('Booking System',
                    style: TextStyle(fontSize: 11, color: _textGrey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required _SidebarItem item,
    required int index,
    required bool isActive,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (index == 2 && widget.onReservationTap != null) {
              widget.onReservationTap!();
            } else {
              widget.onTap(index);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isActive ? _primarySoft : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  isActive ? item.activeIcon : item.icon,
                  size: 20,
                  color: isActive ? _primary : _textGrey,
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive ? _primary : _textGrey,
                  ),
                ),
                if (isActive) ...[
                  const Spacer(),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: _primary, shape: BoxShape.circle),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    final name  = _user?['name']  as String? ?? 'User';
    final role  = _user?['role']  as String? ?? '-';
    final photo = _user?['photo'] as String?;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dropdown muncul di atas card
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: _profileMenuOpen
              ? Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: Row(
                          children: [
                            _buildAvatar(photo, name, size: 36),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: _textDark),
                                      overflow: TextOverflow.ellipsis),
                                  Text(role.toUpperCase(),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: _primary,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: _border),
                      _buildMenuTile(
                        icon: Icons.edit_outlined,
                        label: 'Edit Profil',
                        onTap: _openEditProfile,
                      ),
                      _buildMenuTile(
                        icon: Icons.logout,
                        label: 'Keluar',
                        color: _danger,
                        onTap: _logout,
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),

        // Profile card toggle
        GestureDetector(
          onTap: () => setState(() => _profileMenuOpen = !_profileMenuOpen),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _profileMenuOpen ? _primarySoft : Colors.white,
              border: Border(top: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                _buildAvatar(photo, name, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _textDark),
                          overflow: TextOverflow.ellipsis),
                      Text(role.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 10, color: _textGrey)),
                    ],
                  ),
                ),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 200),
                  turns: _profileMenuOpen ? -0.5 : 0,
                  child: const Icon(Icons.keyboard_arrow_up,
                      size: 18, color: _textGrey),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(String? photo, String name, {double size = 34}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _primary.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: photo != null && photo.startsWith('http')
          ? ClipOval(
              child: Image.network(photo, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.person, size: size * 0.55, color: _primary)))
          : Icon(Icons.person, size: size * 0.55, color: _primary),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? _textDark;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 16, color: c),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 13, color: c, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
} // ← _WebSidebarState

// ════════════════════════════════════════════════════
//  Data class — di luar semua class lain
// ════════════════════════════════════════════════════
class _SidebarItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}