import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../services/auth_service.dart';
import '../../core/theme/custom_animations.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (context, child) {
        final state = AppState.instance;
        final user = FirebaseAuth.instance.currentUser;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        final email = user?.email ?? "dakshin.spendify@gmail.com";
        final defaultName = state.userName.isNotEmpty
            ? state.userName
            : email.split('@')[0];

        final avatarColor = isDark ? AppColors.accentNeon : AppColors.lightGradient[0];
        final avatarBgColor = isDark ? const Color(0xFF141A15) : const Color(0xFFE8F5E9);

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
          appBar: AppBar(
            backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
                size: 20,
              ),
              onPressed: () => state.setTab(0),
            ),
            title: Text(
              "Profile",
              style: GoogleFonts.outfit(
                color: isDark ? Colors.white : AppColors.lightTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 16),
                
                // Profile Header Card
                _buildProfileHeaderCard(isDark, defaultName, email, avatarBgColor, avatarColor),
                const SizedBox(height: 24),
                
                // Account Group
                _buildGroupHeader("Account", isDark),
                const SizedBox(height: 8),
                _buildGroupedCard(isDark, [
                  _buildSettingsRow(
                    icon: Icons.person_outline_rounded,
                    label: "Edit Profile",
                    isDark: isDark,
                    onTap: () => _showEditProfileSheet(context, defaultName),
                  ),
                  _buildSettingsRow(
                    icon: Icons.lock_outline_rounded,
                    label: "Change Password",
                    isDark: isDark,
                    onTap: () => _showWIPDialog(context, "Change Password"),
                  ),
                  _buildSettingsRow(
                    icon: Icons.notifications_none_rounded,
                    label: "Notifications",
                    isDark: isDark,
                    onTap: () => _showWIPDialog(context, "Notifications"),
                  ),
                  _buildSettingsRow(
                    icon: Icons.account_balance_rounded,
                    label: "Linked Banks",
                    isDark: isDark,
                    onTap: () => _showWIPDialog(context, "Linked Banks"),
                  ),
                ]),
                const SizedBox(height: 20),

                // Data & Privacy Group
                _buildGroupHeader("Data & Privacy", isDark),
                const SizedBox(height: 8),
                _buildGroupedCard(isDark, [
                  _buildSettingsRow(
                    icon: Icons.sms_rounded,
                    label: "Auto Add Transactions",
                    subtitle: state.autoAddTransactions
                        ? "Transactions from SMS will automatically be added."
                        : "You will review transactions before adding.",
                    valueWidget: Switch(
                      value: state.autoAddTransactions,
                      activeColor: AppColors.accentNeon,
                      onChanged: (val) {
                        state.setAutoAddTransactions(val);
                        HapticFeedback.lightImpact();
                      },
                    ),
                    isDark: isDark,
                    onTap: () {},
                  ),
                  _buildSettingsRow(
                    icon: Icons.file_download_outlined,
                    label: "Export My Data",
                    isDark: isDark,
                    onTap: () => _showWIPDialog(context, "Export Data"),
                  ),
                  _buildSettingsRow(
                    icon: Icons.delete_sweep_rounded,
                    label: "Delete All Transactions",
                    labelColor: AppColors.errorRed,
                    isDark: isDark,
                    onTap: () => _showDeleteAllDialog(context, state),
                  ),
                ]),
                const SizedBox(height: 20),

                // App Preferences Group
                _buildGroupHeader("App Preferences", isDark),
                const SizedBox(height: 8),
                _buildGroupedCard(isDark, [
                  _buildSettingsRow(
                    icon: Icons.palette_outlined,
                    label: "App Theme",
                    valueWidget: Container(
                      height: 32,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEFEFEF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.08) : AppColors.lightBorder,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (isDark) {
                                state.toggleTheme();
                                HapticFeedback.lightImpact();
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: !isDark
                                    ? AppColors.lightGradient[0]
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.light_mode_rounded,
                                    size: 13,
                                    color: !isDark ? Colors.white : Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Light",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: !isDark ? Colors.white : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              if (!isDark) {
                                state.toggleTheme();
                                HapticFeedback.lightImpact();
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.accentNeon
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.dark_mode_rounded,
                                    size: 13,
                                    color: isDark ? Colors.black : Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Dark",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.black : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    isDark: isDark,
                    onTap: () {},
                  ),
                  _buildSettingsRow(
                    icon: Icons.currency_rupee_rounded,
                    label: "Currency",
                    value: "₹ INR",
                    isDark: isDark,
                    onTap: () => _showWIPDialog(context, "Currency Settings"),
                  ),
                  _buildSettingsRow(
                    icon: Icons.calendar_month_outlined,
                    label: "Default Date Range",
                    value: "This Month",
                    isDark: isDark,
                    onTap: () => _showWIPDialog(context, "Date Range Settings"),
                  ),
                  _buildSettingsRow(
                    icon: Icons.today_outlined,
                    label: "Budget Reset Day",
                    value: "1st",
                    isDark: isDark,
                    onTap: () => _showWIPDialog(context, "Reset Day Settings"),
                  ),
                ]),
                const SizedBox(height: 20),

                // About Group
                _buildGroupHeader("About", isDark),
                const SizedBox(height: 8),
                _buildGroupedCard(isDark, [
                  _buildSettingsRow(
                    icon: Icons.info_outline_rounded,
                    label: "App Version",
                    value: "1.0.0",
                    isDark: isDark,
                    onTap: () {},
                  ),
                  _buildSettingsRow(
                    icon: Icons.privacy_tip_outlined,
                    label: "Privacy Policy",
                    isDark: isDark,
                    onTap: () => _showWIPDialog(context, "Privacy Policy"),
                  ),
                  _buildSettingsRow(
                    icon: Icons.gavel_rounded,
                    label: "Terms of Service",
                    isDark: isDark,
                    onTap: () => _showWIPDialog(context, "Terms of Service"),
                  ),
                  _buildSettingsRow(
                    icon: Icons.star_outline_rounded,
                    label: "Rate Spendify ⭐",
                    isDark: isDark,
                    onTap: () => _showWIPDialog(context, "App Store Rating"),
                  ),
                ]),
                const SizedBox(height: 20),

                // Danger Zone Group
                _buildGroupHeader("Danger Zone", isDark),
                const SizedBox(height: 8),
                _buildGroupedCard(isDark, [
                  _buildSettingsRow(
                    icon: Icons.restore_rounded,
                    label: "Reset All App Data",
                    subtitle: "Wipes all transactions, settings & cache",
                    labelColor: AppColors.errorRed,
                    isDark: isDark,
                    onTap: () => _showResetAllDataDialog(context, state),
                  ),
                  _buildSettingsRow(
                    icon: Icons.no_accounts_rounded,
                    label: "Delete Account",
                    labelColor: AppColors.errorRed,
                    isDark: isDark,
                    onTap: () => _showDeleteAccountDialog(context),
                  ),
                ]),
                const SizedBox(height: 32),

                // Logout button at bottom
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: const BorderSide(color: AppColors.errorRed, width: 1.5),
                    ),
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      await _authService.logout();
                    },
                    child: Text(
                      "Log Out",
                      style: GoogleFonts.outfit(
                        color: AppColors.errorRed,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 120), // Spacing for floating navigation bar
              ],
            ),
          ),
        );
      },
    );
  }

  // Group Header
  Widget _buildGroupHeader(String title, bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 6.0),
        child: Text(
          title.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ),
    );
  }

  // Profile Header Card
  Widget _buildProfileHeaderCard(
      bool isDark, String name, String email, Color avatarBg, Color avatarBorder) {
    final initials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : "U";
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : AppColors.lightBorder;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        children: [
          // Avatar (72px)
          Container(
            height: 72,
            width: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: avatarBg,
              border: Border.all(color: avatarBorder, width: 2),
            ),
            child: Center(
              child: Text(
                initials,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Name (20px bold)
          Text(
            name,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 4),

          // Email (14px muted)
          Text(
            email,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 14),

          // Member since (12px muted green)
          Text(
            "Member since May 2026",
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.accentNeon : AppColors.lightGradient[0],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Grouped Card container
  Widget _buildGroupedCard(bool isDark, List<Widget> rows) {
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : AppColors.lightBorder;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        children: List.generate(rows.length * 2 - 1, (index) {
          if (index.isOdd) {
            return Divider(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
              height: 1,
              thickness: 0.5,
            );
          }
          return rows[index ~/ 2];
        }),
      ),
    );
  }

  // Row (56px tall or dynamic if subtitle exists)
  Widget _buildSettingsRow({
    required IconData icon,
    required String label,
    String? subtitle,
    Color? labelColor,
    String? value,
    Widget? valueWidget,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final textTheme = isDark ? Colors.white : AppColors.lightTextPrimary;

    return SpringScaleButton(
      scaleDownFactor: 0.99, // scale 0.99 on tap
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        alignment: Alignment.center,
        child: Row(
          children: [
            // Left icon (20px, muted white)
            Icon(
              icon,
              color: labelColor ?? (isDark ? Colors.white70 : Colors.black54),
              size: 20,
            ),
            const SizedBox(width: 14),

            // Center Label and optional Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: labelColor ?? textTheme,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Right content
            if (valueWidget != null)
              valueWidget
            else ...[
              if (value != null)
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white24 : Colors.black26,
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Edit Profile bottom sheet
  void _showEditProfileSheet(BuildContext context, String currentName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController(text: currentName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Edit Profile",
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: const InputDecoration(
                  labelText: "Your Name",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.accentNeon : AppColors.lightGradient[0],
                  ),
                  onPressed: () async {
                    final name = controller.text.trim();
                    if (name.isNotEmpty) {
                      await AppState.instance.completeOnboarding(
                        name: name,
                        income: AppState.instance.monthlyIncome,
                        budget: AppState.instance.totalBudgetLimit,
                        categories: AppState.instance.categoryLimits,
                      );
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Text(
                    "Save",
                    style: TextStyle(color: isDark ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Purge/Delete all transactions confirmation dialog
  void _showDeleteAllDialog(BuildContext context, AppState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Delete All Transactions?"),
          content: const Text(
            "This will clear all your transaction history from local storage. "
            "Your settings and profile will remain unchanged.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                await state.resetAllData();
                await state.loadTransactions();
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("All transactions deleted ✓")),
                  );
                }
              },
              child: const Text("Delete All", style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // Full wipe — transactions + cache + SharedPreferences + DB file
  void _showResetAllDataDialog(BuildContext context, AppState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.errorRed.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded, color: AppColors.errorRed, size: 28),
          ),
          title: Text(
            "Reset All App Data?",
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "This will permanently erase:",
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 10),
              _buildResetItem("All transactions & history", isDark),
              _buildResetItem("All settings & preferences", isDark),
              _buildResetItem("File picker cache", isDark),
              _buildResetItem("Local SQLite database", isDark),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "⚠️  This action cannot be undone. You will be sent back to the onboarding screen.",
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.errorRed,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                "Cancel",
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: () async {
                HapticFeedback.heavyImpact();
                Navigator.pop(ctx);
                // Show progress
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Resetting all data..."),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
                await state.resetAllAppData();
                // App will rebuild via notifyListeners + AuthWrapper detecting !isOnboarded
              },
              child: Text(
                "Reset Everything",
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResetItem(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.close_rounded, size: 14, color: AppColors.errorRed),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // Delete Account confirmation dialog
  void _showDeleteAccountDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Delete Account?"),
          content: const Text("Are you sure you want to permanently delete your Spendify profile and clear all local databases?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                await AppState.instance.resetAllAppData();
                await _authService.logout();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text("Delete Account", style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showWIPDialog(BuildContext context, String featureName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(featureName),
          content: Text("$featureName is currently being simulated locally on-device. Production settings endpoints will be deployed in the next sprint!"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Got It"),
            ),
          ],
        );
      },
    );
  }
}