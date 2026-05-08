import 'package:flutter/material.dart';
import '../screens/mobile/home_screen.dart';
import '../screens/mobile/history_screen.dart';
import '../screens/mobile/reservation_screen.dart';
import '../screens/mobile/profile_screen.dart';
import '../screens/web/home_web_screen.dart';
import '../screens/web/history_web_screen.dart';
import '../screens/web/reservation_web_screen.dart';
import '../screens/web/profile_web_screen.dart';
import '../utils/page_transitions.dart';
import '../utils/responsive_helper.dart';
import 'web/web_sidebar.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex  = 0;
  int _previousIndex = 0;

  // ── Navigasi (shared mobile & web) ──────────────────
  void _onNavTap(int index) {
    if (index == 2) {
      // Reservasi — mobile: slide dari bawah, web: push halaman
      if (ResponsiveHelper.isMobile(context)) {
        Navigator.push(
          context,
          SlideUpPageRoute(page: const ReservationScreen()),
        );
      } else {
        _showWebReservationDialog();
      }
      return;
    }
    if (index == _currentIndex) return;
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex  = index;
    });
  }

  /// Di web, tampilkan ReservationWebScreen sebagai dialog/panel
  void _showWebReservationDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: 560,
            height: MediaQuery.of(context).size.height * 0.85,
            child: const ReservationWebScreen(),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════
  //  BUILD — pilih layout berdasarkan lebar layar
  // ════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return ResponsiveHelper.isWeb(context)
        ? _buildWebLayout()
        : _buildMobileLayout();
  }

  // ── MOBILE LAYOUT ────────────────────────────────────
  Widget _buildMobileLayout() {
    final navbar = _buildMobileNavbar();

    final screens = [
      HomeScreen(bottomNavbar: navbar),
      HistoryScreen(bottomNavbar: navbar),
      null,
      ProfileScreen(bottomNavbar: navbar),
    ];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, animation) {
        final direction = _currentIndex > _previousIndex
            ? SlideDirection.left
            : SlideDirection.right;

        final begin = direction == SlideDirection.left
            ? const Offset(1.0, 0.0)
            : const Offset(-1.0, 0.0);

        final tween = Tween(begin: begin, end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutCubic));

        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(
            opacity: animation.drive(
              Tween<double>(begin: 0.0, end: 1.0)
                  .chain(CurveTween(curve: Curves.easeOut)),
            ),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(_currentIndex),
        child: screens[_currentIndex] ?? const SizedBox.shrink(),
      ),
    );
  }

  // ── WEB LAYOUT ──────────────────────────────────────
  Widget _buildWebLayout() {
    // Screen index → web screen (tanpa navbar mobile)
    final screens = [
      const HomeWebScreen(),
      const HistoryWebScreen(),
      null, // index 2 = Reservasi (dialog)
      const ProfileWebScreen(),
    ];

    return Scaffold(
      body: Row(
        children: [
          // Sidebar kiri
          WebSidebar(
            currentIndex: _currentIndex,
            onTap: _onNavTap,
            onReservationTap: _showWebReservationDialog,
          ),

          // Konten utama
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim.drive(
                  Tween<double>(begin: 0.0, end: 1.0)
                      .chain(CurveTween(curve: Curves.easeOut)),
                ),
                child: child,
              ),
              child: KeyedSubtree(
                key: ValueKey<int>(_currentIndex),
                child: screens[_currentIndex] ?? const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── MOBILE NAVBAR ────────────────────────────────────
  Widget _buildMobileNavbar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
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
}

// ════════════════════════════════════════════════════
//  Nav item (mobile only — sama persis seperti sebelumnya)
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
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive
                      ? primary.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  isActive ? activeIcon : icon,
                  color: isActive ? primary : textGrey,
                  size: 22,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isActive ? 4 : 0,
                height: isActive ? 4 : 0,
                decoration: const BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
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