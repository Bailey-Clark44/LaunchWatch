import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

// LaunchWatch design tokens. See DESIGN.md.
//
// Neutral, near-black surfaces with one cool accent. Colour is reserved for
// meaning: status, live, and the single primary action on a screen.
const launchCanvas = Color(0xFF05070A);
const launchBackground = Color(0xFF0A0D12);
const launchSurface = Color(0xFF11151C);
const launchSurfaceRaised = Color(0xFF171C25);
const launchInk = Color(0xFFEDF1F7);
const launchInkMuted = Color(0xFF8E99AB);
const launchInkFaint = Color(0xFF5F6B7D);
const launchLine = Color(0xFF1F2632);
const launchLineStrong = Color(0xFF2B3443);
const launchAccent = Color(0xFF7FB2FF);
const launchAction = Color(0xFFE9EEF6);
const launchActionInk = Color(0xFF0A0D12);
const launchSelection = Color(0xFF16233A);
const launchField = Color(0xFF131820);
const launchLive = Color(0xFFFF5D52);
const launchCrew = Color(0xFFC9A8FF);

const launchColumnWidth = 480.0;
const launchWideBreakpoint = 900.0;
const launchSplitBreakpoint = 1180.0;

class StatusTone {
  const StatusTone(this.label, this.color);

  final String label;
  final Color color;
}

String statusLabel(String rawName) {
  switch (rawName) {
    case 'Go for Launch':
      return 'Go';
    case 'To Be Determined':
      return 'Unconfirmed';
    case 'Launch Successful':
      return 'Success';
    case 'Launch Failure':
      return 'Failure';
    case 'On Hold':
      return 'Hold';
    case 'Launch in Flight':
      return 'In flight';
    case 'Launch was a Partial Failure':
      return 'Partial failure';
    case 'To Be Confirmed':
      return 'To be confirmed';
    case 'Payload Deployed':
      return 'Deployed';
    default:
      return rawName;
  }
}

StatusTone statusTone(String rawName) {
  final label = statusLabel(rawName);
  switch (label) {
    case 'Go':
    case 'Success':
    case 'Deployed':
      return StatusTone(label, const Color(0xFF4ED69A));
    case 'In flight':
      return StatusTone(label, launchLive);
    case 'Hold':
      return StatusTone(label, const Color(0xFFF2B84B));
    case 'Failure':
      return StatusTone(label, const Color(0xFFFF6B6B));
    case 'Partial failure':
      return StatusTone(label, const Color(0xFFFF9B54));
    default:
      return StatusTone(label, const Color(0xFF9AA6B8));
  }
}

TextTheme _textTheme() {
  const base = TextTheme(
    displaySmall: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.8, height: 1.1, color: launchInk),
    headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.15, color: launchInk),
    headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4, height: 1.2, color: launchInk),
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.3, height: 1.25, color: launchInk),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.1, height: 1.3, color: launchInk),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.3, color: launchInk),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5, color: launchInk),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.45, color: launchInk),
    bodySmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, height: 1.35, color: launchInkMuted),
    labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: launchInk),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: launchInkMuted),
    labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.9, color: launchInkMuted),
  );
  try {
    return GoogleFonts.interTextTheme(base);
  } catch (_) {
    return base;
  }
}

/// Monospaced figures for countdowns and clocks so digits do not jitter.
const tabularFigures = [FontFeature.tabularFigures()];

ThemeData launchWatchTheme() {
  final base = ColorScheme.fromSeed(seedColor: launchAccent, brightness: Brightness.dark);
  final scheme = base.copyWith(
    primary: launchAccent,
    onPrimary: launchActionInk,
    surface: launchSurface,
    onSurface: launchInk,
    surfaceContainerHighest: launchSurfaceRaised,
    outline: launchLineStrong,
    outlineVariant: launchLine,
    error: const Color(0xFFFF6B6B),
  );
  final text = _textTheme();
  final shape12 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: launchBackground,
    canvasColor: launchBackground,
    textTheme: text,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: launchBackground,
      surfaceTintColor: Colors.transparent,
      foregroundColor: launchInk,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
      shape: const Border(bottom: BorderSide(color: Colors.transparent)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: launchAction,
        foregroundColor: launchActionInk,
        disabledBackgroundColor: launchSurfaceRaised,
        minimumSize: const Size(64, 48),
        textStyle: text.labelLarge,
        shape: shape12,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: launchInk,
        minimumSize: const Size(64, 44),
        side: const BorderSide(color: launchLineStrong),
        textStyle: text.labelLarge?.copyWith(fontSize: 14),
        shape: shape12,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: launchAccent, textStyle: text.labelLarge?.copyWith(fontSize: 14), shape: shape12),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: launchInk)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: launchField,
      hintStyle: const TextStyle(color: launchInkFaint, fontSize: 15),
      labelStyle: const TextStyle(color: launchInkMuted, fontSize: 15),
      floatingLabelStyle: const TextStyle(color: launchAccent),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: launchLine)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: launchLine)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: launchAccent, width: 1.4)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFF6B6B))),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: launchBackground,
      surfaceTintColor: Colors.transparent,
      indicatorColor: launchSelection,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? launchInk : launchInkMuted);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? launchInk : launchInkMuted, size: 22);
      }),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: launchBackground,
      indicatorColor: launchSelection,
      selectedIconTheme: IconThemeData(color: launchInk),
      unselectedIconTheme: IconThemeData(color: launchInkMuted),
      selectedLabelTextStyle: TextStyle(color: launchInk, fontWeight: FontWeight.w600, fontSize: 14),
      unselectedLabelTextStyle: TextStyle(color: launchInkMuted, fontWeight: FontWeight.w500, fontSize: 14),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? launchActionInk : launchInkMuted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? launchAccent : launchField),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? launchAccent : launchLineStrong),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: launchInkMuted,
      textColor: launchInk,
      subtitleTextStyle: text.bodySmall,
      titleTextStyle: text.bodyLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    ),
    dividerTheme: const DividerThemeData(color: launchLine, thickness: 1, space: 1),
    dividerColor: launchLine,
    snackBarTheme: SnackBarThemeData(
      backgroundColor: launchSurfaceRaised,
      contentTextStyle: text.bodyMedium,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: launchLineStrong)),
      actionTextColor: launchAccent,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: launchSurface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: launchLineStrong,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: launchSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: launchLine)),
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyMedium?.copyWith(color: launchInkMuted),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: launchSurface,
      selectedColor: launchSelection,
      side: const BorderSide(color: launchLine),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      showCheckmark: false,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: launchAccent, linearTrackColor: launchLine),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: launchSurfaceRaised, borderRadius: BorderRadius.circular(8), border: Border.all(color: launchLineStrong)),
      textStyle: const TextStyle(color: launchInk, fontSize: 12),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}
