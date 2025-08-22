import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:diagnosis_ai/app_colors.dart';

class AppDrawer extends StatelessWidget {
  final String selectedLanguage;
  final ValueChanged<String> onLanguageChanged;

  const AppDrawer({
    required this.selectedLanguage,
    required this.onLanguageChanged,
    Key? key,
  }) : super(key: key);

  String _mapCodeToLabel(String code) {
    switch (code) {
      case 'ru':
        return 'Русский';
      case 'el':
        return 'Ελληνικά';
      default:
        return 'English';
    }
  }

  Locale _mapLabelToLocale(String label) {
    switch (label) {
      case 'Русский':
        return const Locale('ru');
      case 'Ελληνικά':
        return const Locale('el');
      default:
        return const Locale('en');
    }
  }

  void _goTo(BuildContext context, String routeName) {
    Navigator.of(context).pop();
    Navigator.of(context).pushNamedAndRemoveUntil(routeName, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String currentLanguageLabel = _mapCodeToLabel(context.locale.languageCode);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // logo header
          DrawerHeader(
            margin: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : const Color(0xFF63E6AB),
            ),
            child: Center(
              child: Image.asset(
                'assets/logo.png',
                height: 150,
                fit: BoxFit.contain,
              ),
            ),
          ),
          _buildTile(
            context,
            Icons.home,
            'menu.home'.tr(),
            isDark,
            onTap: () => _goTo(context, '/'),
          ),
          _buildTile(
            context,
            Icons.chat_rounded,
            'menu.chat'.tr(),
            isDark,
            onTap: () {


            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.lightPrimary),
                borderRadius: BorderRadius.circular(6),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: currentLanguageLabel,
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: isDark ? Colors.white : AppColors.lightPrimary,
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white : AppColors.lightPrimary,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'English',
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [Text('English'), SizedBox(width: 8), Text('🇬🇧')],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Русский',
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [Text('Русский'), SizedBox(width: 8), Text('🇷🇺')],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Ελληνικά',
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [Text('Ελληνικά'), SizedBox(width: 8), Text('🇬🇷')],
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      final locale = _mapLabelToLocale(value);
                      context.setLocale(locale);
                      onLanguageChanged(locale.languageCode);
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildTile(
      BuildContext context,
      IconData icon,
      String title,
      bool isDark, {
        VoidCallback? onTap,
      }) {
    return ListTile(
      leading: Icon(icon, color: isDark ? Colors.white : AppColors.lightPrimary),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : AppColors.lightPrimary,
        ),
      ),
      onTap: onTap,
    );
  }
}
