import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/history_screen.dart';
import '../screens/reservation_screen.dart';
import '../screens/profile_screen.dart';
import '../utils/page_transitions.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex    = 0;
  int _previousIndex   = 0;

  void _onNavTap(int index) {
    if (index == 2) {
      // Reservasi — slide dari bawah
      Navigator.push(
        context,
        SlideUpPageRoute(page: const ReservationScreen()),
      );
      return;
    }
    if (index == _currentIndex) return;
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex  = index;
    });
  }

  Widget _buildNavbar() {
    return Container(
      decoration: const BoxDecoration(
        color : Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
        ),
      ),
      child: SafeArea(
        top  : false,
        child: SizedBox(
          height: 68,
          child : Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _NavItem(index: 0, currentIndex: _currentIndex, icon: Icons.home_outlined,    activeIcon: Icons.home_rounded,   label: 'Beranda',  onTap: _onNavTap),
              _NavItem(index: 1, currentIndex: _currentIndex, icon: Icons.history_outlined,  activeIcon: Icons.history,        label: 'Riwayat',  onTap: _onNavTap),
              _NavItem(index: 2, currentIndex: _currentIndex, icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month, label: 'Reservasi', onTap: _onNavTap),
              _NavItem(index: 3, currentIndex: _currentIndex, icon: Icons.person_outline,   activeIcon: Icons.person_rounded, label: 'Profil',   onTap: _onNavTap),
            ],
          ),
        ),
      ),
    );
  }

  // Tentukan arah animasi berdasarkan index sebelumnya
  SlideDirection _getDirection(int index) {
    return index > _previousIndex
        ? SlideDirection.left
        : SlideDirection.right;
  }

  @override
  Widget build(BuildContext context) {
    final navbar = _buildNavbar();

    final screens = [
      HomeScreen(bottomNavbar: navbar),
      HistoryScreen(bottomNavbar: navbar),
      null,
      ProfileScreen(bottomNavbar: navbar),
    ];

    return AnimatedSwitcher(
      duration        : const Duration(milliseconds: 280),
      transitionBuilder: (child, animation) {
        final direction = _getDirection(_currentIndex);

        final begin = direction == SlideDirection.left
            ? const Offset(1.0, 0.0)
            : const Offset(-1.0, 0.0);

        final tween = Tween(begin: begin, end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutCubic));

        // Halaman lama geser keluar
        final outBegin = direction == SlideDirection.left
            ? const Offset(-0.25, 0.0)
            : const Offset(0.25, 0.0);

        final outTween = Tween(begin: Offset.zero, end: outBegin)
            .chain(CurveTween(curve: Curves.easeOutCubic));

        return SlideTransition(
          position: animation.drive(tween),
          child   : FadeTransition(
            opacity: animation.drive(
              Tween<double>(begin: 0.0, end: 1.0)
                  .chain(CurveTween(curve: Curves.easeOut)),
            ),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key  : ValueKey<int>(_currentIndex),
        child: screens[_currentIndex] ?? const SizedBox.shrink(),
      ),
    );
  }
}

// ════════════════════════════════════════════════════
//  Nav item
// ════════════════════════════════════════════════════
class _NavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final void Function(int) onTap;

  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const Color primary  = Color(0xFF2563EB);
    const Color textGrey = Color(0xFF94A3B8);
    final bool isActive  = currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap            : () => onTap(index),
        behavior         : HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child  : Column(
            mainAxisSize     : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AnimatedContainer(
                duration : const Duration(milliseconds: 200),
                curve    : Curves.easeOut,
                padding  : const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive
                      ? primary.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  isActive ? activeIcon : icon,
                  color: isActive ? primary : textGrey,
                  size : 22,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedContainer(
                duration  : const Duration(milliseconds: 200),
                width     : isActive ? 4 : 0,
                height    : isActive ? 4 : 0,
                decoration: const BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize  : 11,
                  fontWeight: isActive
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: isActive ? primary : textGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}