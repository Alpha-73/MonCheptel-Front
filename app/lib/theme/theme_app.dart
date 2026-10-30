/// Theme Material, construit sur la palette mesuree dans la maquette.
///
/// Volontairement minimal : l'application ne s'appuie presque pas sur le
/// theme Material, parce que ses composants sont definis dans `widgets/`.
/// Le theme sert aux elements que Flutter dessine lui-meme — champs de
/// saisie, boites de dialogue, selection de texte, barre d'etat.
library;

import 'package:flutter/material.dart';
import 'barre_etat.dart';
import 'couleurs.dart';
import 'dimensions.dart';
import 'palette.dart';
import 'typographie.dart';

/// Theme clair (la maquette) ou sombre : meme construction, palette
/// differente. Les ecrans lisent la palette par `context.couleurs`.
ThemeData themeMonCheptel({Brightness luminosite = Brightness.light}) {
  final c = luminosite == Brightness.dark ? PaletteMonCheptel.nuit : PaletteMonCheptel.clair;
  final schema = ColorScheme(
    brightness: luminosite,
    primary: c.marque,
    onPrimary: c.surMarque,
    secondary: c.marque,
    onSecondary: c.surMarque,
    tertiary: c.accent,
    onTertiary: c.surAccent,
    surface: c.surface,
    onSurface: c.texte,
    onSurfaceVariant: c.texteDiscret,
    surfaceContainerLowest: c.fond,
    surfaceContainerLow: c.surface,
    surfaceContainer: c.surface,
    surfaceContainerHigh: c.surface,
    surfaceContainerHighest: c.sable,
    outline: c.filet,
    outlineVariant: c.filetLeger,
    error: c.erreur,
    onError: c.surMarque,
    inverseSurface: c.sombre ? c.titre : Couleurs.marqueSombre,
    onInverseSurface: c.sombre ? c.fond : Couleurs.surMarque,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: luminosite,
    colorScheme: schema,
    extensions: [c],
    fontFamily: Typo.police,
    scaffoldBackgroundColor: c.fond,
    canvasColor: c.fond,
    splashFactory: InkRipple.splashFactory,

    // L'en-tete vert occupe le haut de l'ecran : les icones systeme doivent
    // etre claires pour rester lisibles dessus. Le defaut (selon le fond)
    // est pose a la racine, dans main.dart — voir barre_etat.dart.
    appBarTheme: AppBarTheme(
      backgroundColor: c.enteteFin,
      foregroundColor: c.surEntete,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: BarreEtat.pourEntete(c),
    ),

    // Bouton flottant « Ajouter » de la liste des animaux.
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.marque,
      foregroundColor: c.surMarque,
      elevation: 3,
      highlightElevation: 6,
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.fond,
      modalBackgroundColor: c.fond,
      dragHandleColor: c.filet,
      surfaceTintColor: Colors.transparent,
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.sombre ? c.sable : Couleurs.marqueSombre,
      contentTextStyle: Typo.corps.copyWith(color: c.sombre ? c.titre : Couleurs.surMarque),
      actionTextColor: c.accent,
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (e) => e.contains(WidgetState.selected) ? c.surMarque : c.texteDiscret),
      trackColor: WidgetStateProperty.resolveWith(
          (e) => e.contains(WidgetState.selected) ? c.marque : c.sable),
      trackOutlineColor: WidgetStateProperty.resolveWith(
          (e) => e.contains(WidgetState.selected) ? c.marque : c.filet),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.marque),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      hintStyle: Typo.corps.copyWith(color: c.texteIndicatif),
      labelStyle: Typo.corps.copyWith(color: c.texteDiscret),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Dim.rayon),
        borderSide: BorderSide(color: c.filet, width: Dim.filet),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Dim.rayon),
        borderSide: BorderSide(color: c.filet, width: Dim.filet),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Dim.rayon),
        borderSide: BorderSide(color: c.marque, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Dim.rayon),
        borderSide: BorderSide(color: c.erreur, width: Dim.filet),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Dim.rayon),
        borderSide: BorderSide(color: c.erreur, width: 1.5),
      ),
      errorStyle: Typo.legende.copyWith(color: c.erreur),
    ),

    // Pas de dialogTheme ici : le type a ete renomme DialogTheme ->
    // DialogThemeData en cours de route, et on ne sait pas sur quelle
    // version de Flutter ce projet sera compile. Les boites de dialogue
    // de l'application sont des widgets a nous.

    // Passage d'un ecran a l'autre : fondu et leger glissement, 0,3 s,
    // ease-out (« Smart animate » des maquettes).
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: TransitionDouce(),
      TargetPlatform.iOS: TransitionDouce(),
      TargetPlatform.linux: TransitionDouce(),
      TargetPlatform.macOS: TransitionDouce(),
      TargetPlatform.windows: TransitionDouce(),
      TargetPlatform.fuchsia: TransitionDouce(),
    }),

    dividerTheme: DividerThemeData(color: c.filet, thickness: Dim.filet, space: Dim.filet),

    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.marque,
      selectionHandleColor: c.marque,
      selectionColor: c.marque.withAlpha(0x55),
    ),
  );
}

/// Transition entre ecrans : l'ecran qui arrive monte legerement en
/// apparaissant, au-dessus de celui qu'il recouvre.
class TransitionDouce extends PageTransitionsBuilder {
  const TransitionDouce();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context,
      Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final entree = CurvedAnimation(
        parent: animation, curve: Curves.easeOut, reverseCurve: Curves.easeIn);
    return FadeTransition(
      opacity: entree,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
            .animate(entree),
        child: child,
      ),
    );
  }
}
