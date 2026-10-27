import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/database/app_database.dart';
import '../models/task_models.dart';

// Database Provider
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// Secure Storage Provider
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

// Customizable Accent Color Provider
class CustomAccentColorNotifier extends Notifier<Color> {
  @override
  Color build() => const Color(0xFF0A84FF); // Apple System Blue

  void setColor(Color color) {
    state = color;
  }

  bool setHex(String hexString) {
    final cleaned = hexString.replaceAll('#', '').trim();
    if (cleaned.length == 6) {
      final val = int.tryParse('FF$cleaned', radix: 16);
      if (val != null) {
        state = Color(val);
        return true;
      }
    } else if (cleaned.length == 8) {
      final val = int.tryParse(cleaned, radix: 16);
      if (val != null) {
        state = Color(val);
        return true;
      }
    }
    return false;
  }
}

final customAccentColorProvider = NotifierProvider<CustomAccentColorNotifier, Color>(CustomAccentColorNotifier.new);

// Customizable Background State (Custom image upload or hex color)
class CustomBackgroundState {
  final Uint8List? imageBytes;
  final String? imageName;
  final Color backgroundColor;
  final double blurSigma;
  final double surfaceTranslucency;

  const CustomBackgroundState({
    this.imageBytes,
    this.imageName,
    this.backgroundColor = const Color(0xFF0A0B0E),
    this.blurSigma = 25.0,
    this.surfaceTranslucency = 0.65,
  });

  CustomBackgroundState copyWith({
    Uint8List? imageBytes,
    String? imageName,
    Color? backgroundColor,
    double? blurSigma,
    double? surfaceTranslucency,
    bool clearImage = false,
  }) {
    return CustomBackgroundState(
      imageBytes: clearImage ? null : (imageBytes ?? this.imageBytes),
      imageName: clearImage ? null : (imageName ?? this.imageName),
      backgroundColor: backgroundColor ?? this.backgroundColor,
      blurSigma: blurSigma ?? this.blurSigma,
      surfaceTranslucency: surfaceTranslucency ?? this.surfaceTranslucency,
    );
  }
}

class CustomBackgroundNotifier extends Notifier<CustomBackgroundState> {
  @override
  CustomBackgroundState build() => const CustomBackgroundState();

  void setImage(Uint8List bytes, String name) {
    state = state.copyWith(imageBytes: bytes, imageName: name);
  }

  void removeImage() {
    state = state.copyWith(clearImage: true);
  }

  void setBackgroundColor(Color color) {
    state = state.copyWith(backgroundColor: color);
  }

  bool setHexColor(String hexString) {
    final cleaned = hexString.replaceAll('#', '').trim();
    if (cleaned.length == 6) {
      final val = int.tryParse('FF$cleaned', radix: 16);
      if (val != null) {
        state = state.copyWith(backgroundColor: Color(val));
        return true;
      }
    } else if (cleaned.length == 8) {
      final val = int.tryParse(cleaned, radix: 16);
      if (val != null) {
        state = state.copyWith(backgroundColor: Color(val));
        return true;
      }
    }
    return false;
  }

  void setBlur(double blur) {
    state = state.copyWith(blurSigma: blur.clamp(0.0, 50.0));
  }

  void setTranslucency(double val) {
    state = state.copyWith(surfaceTranslucency: val.clamp(0.10, 0.95));
  }
}

final customBackgroundProvider = NotifierProvider<CustomBackgroundNotifier, CustomBackgroundState>(CustomBackgroundNotifier.new);

// TimeBlock Clipboard Provider (for Right Click Copy/Paste and Ctrl+C/V)
class TimeBlockClipboardNotifier extends Notifier<TimeBlock?> {
  @override
  TimeBlock? build() => null;

  void copy(TimeBlock block) {
    state = block;
  }

  void clear() {
    state = null;
  }
}

final timeBlockClipboardProvider = NotifierProvider<TimeBlockClipboardNotifier, TimeBlock?>(TimeBlockClipboardNotifier.new);

// Theme Mode Provider (System / Light / Dark)
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void setThemeMode(ThemeMode mode) {
    state = mode;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

// Active Theme Preset (Canvas wallpaper/tint)
class ThemePresetNotifier extends Notifier<String> {
  @override
  String build() => 'obsidian';

  void setTheme(String themeId) {
    state = themeId;
  }
}

final themePresetProvider = NotifierProvider<ThemePresetNotifier, String>(ThemePresetNotifier.new);

// Animations / Reduced Motion Provider
class AnimationsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle(bool enabled) {
    state = enabled;
  }
}

final animationsEnabledProvider = NotifierProvider<AnimationsEnabledNotifier, bool>(AnimationsEnabledNotifier.new);

// Resizable Column Widths Provider
class ColumnWidthsNotifier extends Notifier<Map<String, double>> {
  static const double defaultWidth = 320.0;
  static const double minWidth = 260.0;
  static const double maxWidth = 540.0;

  @override
  Map<String, double> build() => {};

  double getWidth(String colId) => state[colId] ?? defaultWidth;

  void setWidth(String colId, double width) {
    final clamped = width.clamp(minWidth, maxWidth);
    state = {...state, colId: clamped};
  }

  void resetWidth(String colId) {
    state = {...state, colId: defaultWidth};
  }
}

final columnWidthsProvider = NotifierProvider<ColumnWidthsNotifier, Map<String, double>>(ColumnWidthsNotifier.new);

// Time Block Days View Count (1, 3, 5, or 7 days)
class TimeBlockDaysCountNotifier extends Notifier<int> {
  @override
  int build() => 1;

  void setDays(int days) {
    if (days == 1 || days == 3 || days == 5 || days == 7) {
      state = days;
    }
  }
}

final timeBlockDaysCountProvider = NotifierProvider<TimeBlockDaysCountNotifier, int>(TimeBlockDaysCountNotifier.new);

// Selected Model (Locked to Gemini 3.5 Flash-Lite)
class SelectedModelNotifier extends Notifier<String> {
  @override
  String build() => 'gemini-3.5-flash-lite';

  void setModel(String model) {
    state = model;
  }
}

final selectedModelProvider = NotifierProvider<SelectedModelNotifier, String>(SelectedModelNotifier.new);

// Gemini API Key Provider (BYOK)
class ApiKeyNotifier extends AsyncNotifier<String?> {
  static const _key = 'tempo_gemini_api_key';

  @override
  Future<String?> build() async {
    final storage = ref.watch(secureStorageProvider);
    return await storage.read(key: _key);
  }

  Future<void> saveKey(String key) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final storage = ref.read(secureStorageProvider);
      await storage.write(key: _key, value: key.trim());
      return key.trim();
    });
  }

  Future<void> deleteKey() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final storage = ref.read(secureStorageProvider);
      await storage.delete(key: _key);
      return null;
    });
  }
}

final apiKeyProvider = AsyncNotifierProvider<ApiKeyNotifier, String?>(ApiKeyNotifier.new);

// Columns Stream
final columnsStreamProvider = StreamProvider<List<BoardColumn>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchColumns();
});

// Badges Stream
final badgesStreamProvider = StreamProvider<List<CustomBadge>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchBadges();
});

// Tasks with Badges & Subtasks Stream
final tasksStreamProvider = StreamProvider<List<TaskItem>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchTasksWithDetails();
});

// Selected Day for Time Blocking
class SelectedDayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void setDay(DateTime day) {
    state = DateTime(day.year, day.month, day.day);
  }
}

final selectedDayProvider = NotifierProvider<SelectedDayNotifier, DateTime>(SelectedDayNotifier.new);

// Time Blocks for Selected Day Stream
final timeBlocksStreamProvider = StreamProvider<List<TimeBlock>>((ref) {
  final db = ref.watch(databaseProvider);
  final day = ref.watch(selectedDayProvider);
  return db.watchTimeBlocksForDay(day);
});

// Multi-day Time Blocks Stream (for 1, 3, 5, 7 day views)
final multiDayTimeBlocksStreamProvider = StreamProvider<List<TimeBlock>>((ref) {
  final db = ref.watch(databaseProvider);
  final startDay = ref.watch(selectedDayProvider);
  final daysCount = ref.watch(timeBlockDaysCountProvider);
  return db.watchTimeBlocksForRange(startDay, daysCount);
});

// All Time Blocks Stream (for reactive unscheduled tracking)
final allTimeBlocksStreamProvider = StreamProvider<List<TimeBlock>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllTimeBlocks();
});

