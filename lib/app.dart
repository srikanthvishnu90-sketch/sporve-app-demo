import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'core/routes/app_pages.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_typography.dart';
import 'core/ui/ambient_surface.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: AppTypography.fontFamily,
    );
    return GetMaterialApp(
      title: 'Sporve',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        // Transparent so the single ambient canvas in [builder] shows through
        // behind every screen — the base color is still ink (see AmbientSurface).
        scaffoldBackgroundColor: Colors.transparent,
        primaryColor: AppColors.slate,
        colorScheme: base.colorScheme.copyWith(
          brightness: Brightness.dark,
          primary: AppColors.slate,
          onPrimary: AppColors.onSlate,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
        ),
        // Hanken is the Material default; display and data styles opt into
        // Oswald/JetBrains through AppTypography.
        textTheme: base.textTheme.apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        dividerColor: AppColors.hairline,
        // Any Material route (Navigator.push) also swaps instantly — no native
        // slide/zoom — so it matches the GetX no-transition behaviour below.
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _NoTransitionsBuilder(),
            TargetPlatform.iOS: _NoTransitionsBuilder(),
            TargetPlatform.macOS: _NoTransitionsBuilder(),
            TargetPlatform.windows: _NoTransitionsBuilder(),
            TargetPlatform.linux: _NoTransitionsBuilder(),
            TargetPlatform.fuchsia: _NoTransitionsBuilder(),
          },
        ),
      ),
      // On wide screens (desktop web), render inside a centered phone-width
      // frame so the mobile app keeps its intended proportions instead of being
      // stretched across the whole window.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        const frameWidth = 440.0;
        const minFrameHeight = 720.0;
        // Near-black canvas behind EVERY screen, lit only by a faint crown of
        // light at the very top. Base color is unchanged (ink); the treatment
        // is static and paints once.
        final canvas = AmbientSurface(
          baseColor: AppColors.ink,
          focal: const Alignment(0, -0.9),
          radius: 1.4,
          glowOpacity: 0.035,
          counterGlow: false,
          child: child ?? const SizedBox.shrink(),
        );
        if (media.size.width <= 480 || child == null) {
          return canvas;
        }
        final framedHeight = math
            .max(media.size.height, minFrameHeight)
            .toDouble();
        final framed = SizedBox(
          width: frameWidth,
          height: framedHeight,
          child: MediaQuery(
            data: media.copyWith(size: Size(frameWidth, framedHeight)),
            child: canvas,
          ),
        );
        return ColoredBox(
          color: AppColors.frame,
          child: media.size.height >= minFrameHeight
              ? Center(child: framed)
              : SingleChildScrollView(
                  child: Align(alignment: Alignment.topCenter, child: framed),
                ),
        );
      },
      // A quick, subtle FADE on route pushes — keeps the clean/direct feel (no
      // heavy native slides) while softening the hard cut. Tab content still
      // switches instantly via IndexedStack.
      defaultTransition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 170),
      initialRoute: AppPages.initial,
      unknownRoute: AppPages.unknownRoute,
      getPages: AppPages.routes,
    );
  }
}

/// A page-transition builder that performs NO animation — the new page appears
/// immediately. Applied to every platform so Material routes match the GetX
/// no-transition behaviour for a clean, direct page-to-page swap.
class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
