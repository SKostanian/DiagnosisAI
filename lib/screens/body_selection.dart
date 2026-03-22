import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:diagnosis_ai/app_drawer.dart';
import 'package:diagnosis_ai/app_colors.dart';
import 'package:diagnosis_ai/screens/chat_screen.dart';

class BodyPartSelectionScreen extends StatefulWidget {
  final void Function(bool) onThemeChanged;

  const BodyPartSelectionScreen({
    required this.onThemeChanged,
    Key? key,
  }) : super(key: key);

  @override
  _BodyPartSelectionScreenState createState() => _BodyPartSelectionScreenState();
}

class _BodyItem {
  // localization key, for instance body.head
  final String keyName;
  final String iconFile;
  const _BodyItem(this.keyName, this.iconFile);
}

// unified list, key + icon
const List<_BodyItem> _bodyItems = [
  _BodyItem('body.head', 'head.png'),
  _BodyItem('body.eyes', 'eyes.png'),
  _BodyItem('body.ears', 'ears.png'),
  _BodyItem('body.mouth_throat', 'mouth.png'),
  _BodyItem('body.chest_breath', 'chest.png'),
  _BodyItem('body.abdomen_stomach', 'abdomen.png'),
  _BodyItem('body.arms', 'arms.png'),
  _BodyItem('body.back', 'back.png'),
  _BodyItem('body.legs', 'legs.png'),
  _BodyItem('body.pelvic', 'pelvic-area.png'),
  _BodyItem('body.skin', 'skin.png'),
  _BodyItem('body.general_other', 'general.png'),
];

class _BodyPartSelectionScreenState extends State<BodyPartSelectionScreen> {
  // save selected keys
  final Set<String> selectedKeys = {};

  void toggleSelection(String key) {
    setState(() {
      if (selectedKeys.contains(key)) {
        selectedKeys.remove(key);
      } else {
        selectedKeys.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      endDrawer: AppDrawer(
        selectedLanguage: context.locale.languageCode,
        onLanguageChanged: (_) => setState(() {}),
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Switch(
            value: isDarkMode,
            onChanged: widget.onThemeChanged,
            activeColor: Colors.white,
            inactiveThumbColor: AppColors.lightPrimary,
          ),
        ),
        title: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 58),
          child: Image.asset('assets/logo.png', fit: BoxFit.contain),
        ),
        actions: [
          Builder(
            builder: (context) => Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFFFFF),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.menu, size: 20, color: AppColors.lightPrimary),
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                  splashRadius: 24,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDarkMode
              ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.black87, Colors.grey.shade900],
          )
              : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF63E6AB), Color(0xFFD2F4FF)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'body.title'.tr(), // "Where are you feeling discomfort?"
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : AppColors.lightPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'body.subtitle'.tr(), // новый ключ
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : AppColors.lightPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: AnimationLimiter(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: _bodyItems.length,
                      itemBuilder: (context, index) {
                        final item = _bodyItems[index];
                        final isSelected = selectedKeys.contains(item.keyName);
                        final iconPath = isDarkMode
                            ? 'assets/icons_white/${item.iconFile}'
                            : 'assets/icons/${item.iconFile}';

                        return AnimationConfiguration.staggeredGrid(
                          position: index,
                          duration: const Duration(milliseconds: 500),
                          columnCount: 3,
                          child: ScaleAnimation(
                            scale: 0.95,
                            child: FadeInAnimation(
                              child: _BodyTile(
                                label: item.keyName.tr(),
                                iconPath: iconPath,
                                selected: isSelected,
                                isDark: isDarkMode,
                                onTap: () => toggleSelection(item.keyName),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Builder(builder: (context) {
                  final canContinue = selectedKeys.isNotEmpty;
                  final accent = isDarkMode ? AppColors.darkAccent : AppColors.lightPrimary;

                  final bg   = canContinue ? accent : (isDarkMode ? const Color(0xFF2C2C2E) : Colors.white);
                  final fg   = canContinue ? Colors.white : (isDarkMode ? Colors.white70 : accent);
                  final side = canContinue ? accent : (isDarkMode ? Colors.white24 : accent);

                  // continue button which counts selected icons
                  final count = selectedKeys.length;
                  final base  = 'body.continue'.tr();
                  final label = count > 0
                      ? '$base (${ "body.selected_fmt".tr(args: [count.toString()]) })'
                      : base;

                  return ElevatedButton(
                    onPressed: canContinue
                        ? () {
                      Navigator.pushNamed(
                        context,
                        TriageChatScreen.routeName,
                        arguments: TriageChatArgs(selectedKeys.toList()),
                      );
                    }
                    : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      backgroundColor: bg,
                      foregroundColor: fg,
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      side: BorderSide(color: side, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(label),
                  );
                }),
                const SizedBox(height: 10),
                Text(
                  'DiagnosisAI © 2026. All rights reserved.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white70 : AppColors.lightPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BodyTile extends StatefulWidget {
  final String label;
  final String iconPath;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _BodyTile({
    required this.label,
    required this.iconPath,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_BodyTile> createState() => _BodyTileState();
}

class _BodyTileState extends State<_BodyTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.isDark ? AppColors.darkAccent : AppColors.lightPrimary;

    final borderColor = widget.selected
        ? accent
        : (widget.isDark ? Colors.white24 : Colors.black26);

    final baseBg = widget.isDark ? const Color(0xFF1F1F22) : Colors.white;
    final selectedTint = accent.withOpacity(.12);

    // Flutter Artist (2024) Animated scale | flutter. Youtube.
    // Available at: https://www.youtube.com/watch?v=mIPlugtbi-s&t=26s (Accessed: March 22, 2026).

    // I used here the same as in video, but my scale value is static,
    // and milliseconds, I believe it is more professional
    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      // I have decrease -2, as it looked cool
      scale: _pressed ? 0.98 : 1.0,

      child: Material(
        color: Colors.transparent,
        // if true then elevation on 4
        elevation: widget.selected ? 4 : 1,
        shadowColor: Colors.black.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),

        // I used inkwell for different taps
        // Flutter - InkWell widget (2021) GeeksforGeeks.
        // Available at: https://www.geeksforgeeks.org/flutter/flutter-inkwell-widget/ (Accessed: March 22, 2026).
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          borderRadius: BorderRadius.circular(14),
          splashColor: accent.withOpacity(0.12),
          highlightColor: Colors.transparent,
          // ink here provides surface for inkwell
          child: Ink(
            decoration: BoxDecoration(
              color: baseBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: widget.selected ? 2 : 1.2),
            ),
            child: Stack(
              children: [
                if (widget.selected)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: selectedTint,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Image.asset(widget.iconPath),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        // Flutter - TextOverFlow (2022) GeeksforGeeks.
                        // Available at: https://www.geeksforgeeks.org/flutter/flutter-textoverflow/ (Accessed: March 22, 2026).
                        overflow: TextOverflow.ellipsis,

                        // (2024) Stackoverflow.com.
                        // Available at: https://stackoverflow.com/a/77730517 (Accessed: March 22, 2026).
                        // softwrap breaks to new line
                        softWrap: true,
                        style: TextStyle(
                          height: 1.1,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: widget.selected
                              ? accent
                              : (widget.isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.selected)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Icon(Icons.check_circle, size: 18, color: accent),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
