import 'package:flutter/material.dart';

/// Sidebar navigasi untuk tampilan Web/Desktop.
/// Menggantikan BottomNavigationBar yang dipakai di mobile.
class WebSidebar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;

  // Callback khusus untuk Reservasi (tetap pakai dialog/panel di web)
  final VoidCallback? onReservationTap;

  const WebSidebar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onReservationTap,
  });

  static const Color _primary     = Color(0xFF2563EB);
  static const Color _primarySoft = Color(0xFFEFF6FF);
  static const Color _textGrey    = Color(0xFF94A3B8);
  static const Color _textDark    = Color(0xFF1E293B);
  static const Color _bgSidebar   = Color(0xFFFFFFFF);
  static const Color _border      = Color(0xFFE2E8F0);

  static const _items = [
    _SidebarItem(icon: Icons.home_outlined,     activeIcon: Icons.home_rounded,         label: 'Beranda'),
    _SidebarItem(icon: Icons.history_outlined,  activeIcon: Icons.history,              label: 'Riwayat'),
    _SidebarItem(icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month, label: 'Reservasi'),
    _SidebarItem(icon: Icons.person_outline,    activeIcon: Icons.person_rounded,       label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: _bgSidebar,
        border: Border(right: BorderSide(color: _border, width: 1)),
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
          // ── Logo / Brand ──
          _buildBrand(),

          const Divider(height: 1, color: _border),
          const SizedBox(height: 12),

          // ── Navigation Items ──
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final item    = _items[i];
                final isActive = currentIndex == i;
                return _buildNavItem(
                  item: item,
                  index: i,
                  isActive: isActive,
                );
              },
            ),
          ),

          // ── Footer ──
          _buildFooter(),
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
              gradient: const LinearGradient(
                colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.sports_bar_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Etan Patung',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _textDark,
                  ),
                ),
                Text(
                  'Booking System',
                  style: TextStyle(fontSize: 11, color: _textGrey),
                ),
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
            if (index == 2 && onReservationTap != null) {
              onReservationTap!();
            } else {
              onTap(index);
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
                      color: _primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _border)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 14, color: _textGrey),
          SizedBox(width: 8),
          Text(
            'v1.0.0  •  Billiard App',
            style: TextStyle(fontSize: 11, color: _textGrey),
          ),
        ],
      ),
    );
  }
}

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