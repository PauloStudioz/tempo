import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/tempo_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/tempo_toast.dart';
import '../../../providers/tempo_providers.dart';
import '../../copilot/services/gemini_service.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _bgHexController = TextEditingController();
  final TextEditingController _accentHexController = TextEditingController();

  bool _obscureKey = true;
  bool _isTestingKey = false;
  bool? _connectionSuccess;

  static const _quickAccents = [
    Color(0xFF0A84FF), // System Blue
    Color(0xFFAF52DE), // Apple Purple
    Color(0xFF5856D6), // Apple Indigo
    Color(0xFFFF2D55), // Apple Rose
    Color(0xFF34C759), // Apple Mint
    Color(0xFFFF9500), // Apple Orange
    Color(0xFFFFCC00), // Apple Amber
    Color(0xFF94A3B8), // Oyster Slate
  ];

  static const _quickBgColors = [
    Color(0xFF0A0B0E), // Obsidian
    Color(0xFF111827), // Midnight Navy
    Color(0xFF1E293B), // Slate Charcoal
    Color(0xFF1B1226), // Deep Plum
    Color(0xFF0E1A16), // Deep Forest
    Color(0xFF000000), // Pure Black
    Color(0xFFF5F5F7), // Apple Light Gray
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = ref.read(apiKeyProvider).value;
      if (key != null) {
        _apiKeyController.text = key;
      }
      final bg = ref.read(customBackgroundProvider);
      _bgHexController.text = '#${bg.backgroundColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

      final accent = ref.read(customAccentColorProvider);
      _accentHexController.text = '#${accent.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _bgHexController.dispose();
    _accentHexController.dispose();
    super.dispose();
  }

  void _saveApiKey() async {
    HapticFeedback.lightImpact();
    final key = _apiKeyController.text.trim();
    await ref.read(apiKeyProvider.notifier).saveKey(key);
    if (mounted) {
      TempoToast.show(context, 'API Key saved.');
    }
  }

  void _testConnection() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) return;

    if (!mounted) return;
    setState(() {
      _isTestingKey = true;
      _connectionSuccess = null;
    });

    final success = await GeminiService.testConnection(key);

    if (!mounted) return;
    try {
      setState(() {
        _isTestingKey = false;
        _connectionSuccess = success;
      });
    } catch (_) {}

    if (mounted) {
      if (success) {
        TempoToast.show(context, 'Connection verified with Gemini 3.5 Flash-Lite.');
      } else {
        TempoToast.show(context, 'Connection failed. Verify API key.', isError: true);
      }
    }
  }

  void _pickBgImage() async {
    HapticFeedback.lightImpact();
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        ref.read(customBackgroundProvider.notifier).setImage(bytes, file.name);
        if (mounted) {
          TempoToast.show(context, 'Custom wallpaper "${file.name}" applied.');
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final currentThemeMode = ref.watch(themeModeProvider);
    final customBg = ref.watch(customBackgroundProvider);
    final accentColor = ref.watch(customAccentColorProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Settings & Preferences',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Customize appearance, colors, AI credentials, and horizons.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 14),

              // ==========================================
              // 1. API KEY SETTINGS (Moved to VERY TOP, SLIM & COMPACT)
              // ==========================================
              GlassContainer(
                borderRadius: 14,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                backgroundColor: isDark
                    ? TempoTheme.surfaceElevated.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.90),
                borderColor: Colors.transparent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(CupertinoIcons.lock_shield, color: accentColor, size: 15),
                        const SizedBox(width: 6),
                        Text(
                          'Gemini API Key (BYOK)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Gemini 3.5 Flash-Lite Fixed Model Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Gemini 3.5 Flash-Lite',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (_connectionSuccess != null) ...[
                          Icon(
                            _connectionSuccess! ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.xmark_seal_fill,
                            color: _connectionSuccess! ? TempoTheme.pastelMint : TempoTheme.pastelRose,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _connectionSuccess! ? 'Valid' : 'Failed',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: _connectionSuccess! ? TempoTheme.pastelMint : TempoTheme.pastelRose,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Slim Input Row
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: TextField(
                              controller: _apiKeyController,
                              obscureText: _obscureKey,
                              style: TextStyle(
                                color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter API Key...',
                                hintStyle: TextStyle(
                                  color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                                  fontSize: 11.5,
                                ),
                                filled: true,
                                fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                suffixIcon: GestureDetector(
                                  onTap: () => setState(() => _obscureKey = !_obscureKey),
                                  child: Icon(
                                    _obscureKey ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                                    size: 14,
                                    color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          onPressed: _saveApiKey,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Save', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton(
                          onPressed: _isTestingKey ? null : _testConnection,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: accentColor,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            side: BorderSide(color: accentColor.withValues(alpha: 0.6), width: 0.8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _isTestingKey
                              ? SizedBox(width: 11, height: 11, child: CircularProgressIndicator(strokeWidth: 1.5, color: accentColor))
                              : const Text('Test', style: TextStyle(fontSize: 11.5)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ==========================================
              // 2. APPEARANCE & CUSTOM ACCENT COLOR
              // ==========================================
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appearance & Accent',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Customize theme appearance and personal highlight accent.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              GlassContainer(
                borderRadius: 14,
                padding: const EdgeInsets.all(12),
                backgroundColor: isDark
                    ? TempoTheme.surfaceElevated.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.90),
                borderColor: Colors.transparent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Theme Mode Selector
                    Row(
                      children: [
                        Text(
                          'Theme Mode',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildThemeModePill('Dark', ThemeMode.dark, currentThemeMode, isDark),
                              _buildThemeModePill('Light', ThemeMode.light, currentThemeMode, isDark),
                              _buildThemeModePill('System', ThemeMode.system, currentThemeMode, isDark),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(color: isDark ? TempoTheme.dividerDark : TempoTheme.lightDivider, height: 1),
                    const SizedBox(height: 10),

                    // Customizable Accent Color
                    Row(
                      children: [
                        Text(
                          'Accent Color',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor,
                          ),
                        ),
                        const Spacer(),
                        // Custom Hex Input
                        SizedBox(
                          width: 90,
                          height: 28,
                          child: TextField(
                            controller: _accentHexController,
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                            decoration: InputDecoration(
                              hintText: '#0A84FF',
                              filled: true,
                              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                            ),
                            onSubmitted: (val) {
                              if (ref.read(customAccentColorProvider.notifier).setHex(val)) {
                                HapticFeedback.selectionClick();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Quick Palette Swatches
                    Wrap(
                      spacing: 8,
                      children: _quickAccents.map((c) {
                        final isSelected = c.toARGB32() == accentColor.toARGB32();
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref.read(customAccentColorProvider.notifier).setColor(c);
                            _accentHexController.text = '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
                          },
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 6),
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ==========================================
              // 3. CUSTOM WALLPAPER & BACKGROUND (NO HARDCODED THEMES)
              // ==========================================
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Background & Frosted Glass Customization',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Upload custom wallpapers, set blur, and adjust surface translucency.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              GlassContainer(
                borderRadius: 14,
                padding: const EdgeInsets.all(12),
                backgroundColor: isDark
                    ? TempoTheme.surfaceElevated.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.90),
                borderColor: Colors.transparent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Upload Image Section
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickBgImage,
                          icon: const Icon(CupertinoIcons.photo, size: 13),
                          label: Text(
                            customBg.imageBytes != null ? 'Change Image' : 'Upload Wallpaper Image',
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        if (customBg.imageBytes != null) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              ref.read(customBackgroundProvider.notifier).removeImage();
                            },
                            child: const Text('Remove Image', style: TextStyle(fontSize: 11.5, color: TempoTheme.pastelRose)),
                          ),
                          const Spacer(),
                          Text(
                            customBg.imageName ?? 'Custom Image',
                            style: TextStyle(fontSize: 11, color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Blur Slider
                    Row(
                      children: [
                        Text(
                          'Glass Blur:',
                          style: TextStyle(fontSize: 11.5, color: isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: accentColor,
                              thumbColor: accentColor,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              trackHeight: 3,
                            ),
                            child: Slider(
                              value: customBg.blurSigma,
                              min: 0,
                              max: 45,
                              onChanged: (val) {
                                ref.read(customBackgroundProvider.notifier).setBlur(val);
                              },
                            ),
                          ),
                        ),
                        Text(
                          '${customBg.blurSigma.round()}px',
                          style: TextStyle(fontSize: 11, color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Translucency Slider
                    Row(
                      children: [
                        Text(
                          'Translucency:',
                          style: TextStyle(fontSize: 11.5, color: isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: accentColor,
                              thumbColor: accentColor,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              trackHeight: 3,
                            ),
                            child: Slider(
                              value: customBg.surfaceTranslucency,
                              min: 0.10,
                              max: 0.95,
                              onChanged: (val) {
                                ref.read(customBackgroundProvider.notifier).setTranslucency(val);
                              },
                            ),
                          ),
                        ),
                        Text(
                          '${(customBg.surfaceTranslucency * 100).round()}%',
                          style: TextStyle(fontSize: 11, color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Divider(color: isDark ? TempoTheme.dividerDark : TempoTheme.lightDivider, height: 1),
                    const SizedBox(height: 10),

                    // Custom Color Tone (Hex Code Input + Palette)
                    Row(
                      children: [
                        Text(
                          'Color Tone (Hex):',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: customBg.backgroundColor,
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 90,
                          height: 28,
                          child: TextField(
                            controller: _bgHexController,
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                            decoration: InputDecoration(
                              hintText: '#0A0B0E',
                              filled: true,
                              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                            ),
                            onSubmitted: (val) {
                              if (ref.read(customBackgroundProvider.notifier).setHexColor(val)) {
                                HapticFeedback.selectionClick();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Quick Background Colors
                    Wrap(
                      spacing: 8,
                      children: _quickBgColors.map((c) {
                        final isSelected = c.toARGB32() == customBg.backgroundColor.toARGB32();
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref.read(customBackgroundProvider.notifier).setBackgroundColor(c);
                            _bgHexController.text = '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
                          },
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c,
                              border: Border.all(
                                color: isSelected ? accentColor : Colors.white24,
                                width: isSelected ? 2 : 0.8,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeModePill(String label, ThemeMode mode, ThemeMode currentMode, bool isDark) {
    final isSelected = mode == currentMode;
    final accentColor = ref.watch(customAccentColorProvider);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(themeModeProvider.notifier).setThemeMode(mode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? accentColor.withValues(alpha: 0.25) : accentColor.withValues(alpha: 0.15))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? accentColor
                : (isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted),
          ),
        ),
      ),
    );
  }
}
