import 'package:flutter/material.dart';
import '../screens/add_expense_screen.dart';
import '../screens/monthly_analysis_screen.dart';
import '../screens/yearly_analysis_screen.dart';
import '../screens/import_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Drawer Header ─────────────────────────────────────────────
          DrawerHeader(
            padding: EdgeInsets.zero,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF30437A), Color(0xFF4A6FA5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Logo icon in a white circle
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.savings_rounded,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 12),
                    const Text(
                      'Expense Tracker',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      'Manage your money wisely',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Main Nav ──────────────────────────────────────────────────
          _DrawerTile(
            icon: Icons.home_rounded,
            label: 'Home',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
          ),
          _DrawerTile(
            icon: Icons.add_circle_rounded,
            label: 'Add Expense',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddExpenseScreen(),
                ),
              );
            },
          ),

          _SectionLabel('ANALYSIS'),

          _DrawerTile(
            icon: Icons.calendar_month_rounded,
            label: 'Monthly Analysis',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MonthlyAnalysisScreen(),
                ),
              );
            },
          ),
          _DrawerTile(
            icon: Icons.bar_chart_rounded,
            label: 'Yearly Analysis',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const YearlyAnalysisScreen(),
                ),
              );
            },
          ),

          _SectionLabel('DATA'),

          _DrawerTile(
            icon: Icons.upload_file_rounded,
            label: 'Import Expenses',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ImportScreen()),
              );
            },
          ),

          const Divider(height: 24),

          _DrawerTile(
            icon: Icons.info_rounded,
            label: 'About',
            onTap: () {
              Navigator.pop(context);
              showAboutDialog(
                context: context,
                applicationName: 'Expense Tracker',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(
                  Icons.savings_rounded,
                  size: 36,
                  color: Color(0xFF30437A),
                ),
                children: const [
                  Text('Track your expenses with beautiful charts.'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF30437A), size: 22),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2D2D2D),
        ),
      ),
      horizontalTitleGap: 4,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color(0xFF9CA3AF),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
