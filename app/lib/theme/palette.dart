/// Palette MonCheptel, en deux jeux : clair (la maquette) et sombre.
///
/// Les widgets lisent leurs couleurs par `context.couleurs.x` (et leurs
/// styles de texte par `context.typo.x`), jamais par une constante : le
/// theme peut changer pendant que l'application tourne (reglage du
/// telephone, ou choix « Apparence » du Profil).
///
/// Le jeu clair reprend [Couleurs] a l'identique. Le jeu sombre est verifie
/// au contraste WCAG AA (calcul de luminance relative) :
///  - fonds vert-noir profonds ([fond] #0C1716), surfaces un peu plus
///    claires ([surface] #15241F, [sable] #1E2E2A) ;
///  - texte 12,6:1, texte discret 7:1, indications 4,6:1 sur [surface] ;
///  - vert de marque eclairci #5EC4B7 (7,7:1 sur [surface]) ; le texte d'un
///    bouton vert devient fonce ([surMarque], 8:1) ;
///  - orange #EF9429 garde pour les touches cles ([surAccent] dessus, 5:1) ;
///  - en-tetes : degrade vert plus sombre, texte blanc 9 a 13:1.
library;

import 'package:flutter/material.dart';

import 'couleurs.dart';
import 'typographie.dart';

@immutable
class PaletteMonCheptel extends ThemeExtension<PaletteMonCheptel> {
  const PaletteMonCheptel({
    required this.sombre,
    required this.marque,
    required this.surMarque,
    required this.surMarqueDiscret,
    required this.surEntete,
    required this.enteteDebut,
    required this.enteteFin,
    required this.enteteSombreDebut,
    required this.enteteSombreFin,
    required this.fondFonce,
    required this.encreFonce,
    required this.surAccent,
    required this.accent,
    required this.fondAccueilHaut,
    required this.fondAccueilBas,
    required this.fondConnexion,
    required this.sante,
    required this.attention,
    required this.attentionTexte,
    required this.erreur,
    required this.graviteHaute,
    required this.graviteMoyenne,
    required this.graviteFaible,
    required this.fond,
    required this.sable,
    required this.terre,
    required this.fondAccentPale,
    required this.surface,
    required this.filet,
    required this.filetLeger,
    required this.fondMarquePale,
    required this.fondMarquePale2,
    required this.fondAttentionPale,
    required this.fondErreurPale,
    required this.titre,
    required this.texte,
    required this.texteDiscret,
    required this.texteIndicatif,
    required this.ombre,
    required this.ombrePanneau,
    required this.ombreBarre,
    required this.graphiqueRevenus,
    required this.graphiqueDepenses,
    required this.graphiqueRevenusAttenue,
    required this.graphiqueDepensesAttenue,
  });

  /// Vrai pour le jeu sombre.
  final bool sombre;

  /// Vert de marque : boutons principaux, liens, etats actifs. En sombre, eclairci (7,7:1 sur [surface]) ; le texte pose dessus devient alors [surMarque] fonce.
  final Color marque;
  /// Texte et icones poses sur un aplat [marque].
  final Color surMarque;
  /// Texte secondaire sur les en-tetes et les aplats fonces ([fondFonce]).
  final Color surMarqueDiscret;
  /// Texte et icones sur l'en-tete degrade, sur [fondFonce] et sur [graviteHaute] : blanc dans les deux themes.
  final Color surEntete;
  /// Degrade de l'en-tete eleveur (haut gauche, bas droite).
  final Color enteteDebut;
  final Color enteteFin;
  /// Degrade de l'en-tete veterinaire, plus sombre.
  final Color enteteSombreDebut;
  final Color enteteSombreFin;
  /// Aplat vert fonce qui porte du texte blanc (carte du solde, rentabilite).
  final Color fondFonce;
  /// Encre la plus appuyee sur un fond pale (tuile sable, onglet de filiere).
  final Color encreFonce;
  /// Texte et icones poses sur l'orange [accent] : vert tres sombre dans les deux themes (5:1).
  final Color surAccent;
  /// Orange du logo, pour les moments cles. Jamais texte sur fond clair.
  final Color accent;
  /// Fonds des ecrans d'accueil et de connexion.
  final Color fondAccueilHaut;
  final Color fondAccueilBas;
  final Color fondConnexion;
  /// Sante et information.
  final Color sante;
  /// Attention : fonds et bordures seulement.
  final Color attention;
  /// Attention, version texte.
  final Color attentionTexte;
  /// Destructif et erreurs. En sombre, rose clair lisible ; le texte pose dessus est [surMarque].
  final Color erreur;
  /// Gravite d'un cas ; [graviteHaute] porte aussi du texte blanc ([surEntete]).
  final Color graviteHaute;
  final Color graviteMoyenne;
  final Color graviteFaible;
  /// Fond des ecrans : sable clair, ou vert-noir profond.
  final Color fond;
  /// Fonds de tuiles, pistes de jauge, squelettes.
  final Color sable;
  /// Touches decoratives.
  final Color terre;
  /// Fond teinte orange (moments cles).
  final Color fondAccentPale;
  /// Cartes et surfaces elevees.
  final Color surface;
  /// Bordures.
  final Color filet;
  final Color filetLeger;
  /// Fonds teintes des encarts.
  final Color fondMarquePale;
  final Color fondMarquePale2;
  final Color fondAttentionPale;
  final Color fondErreurPale;
  /// Titres.
  final Color titre;
  /// Corps de texte.
  final Color texte;
  /// Texte secondaire (7:1 sur [surface] en sombre).
  final Color texteDiscret;
  /// Indications des champs vides.
  final Color texteIndicatif;
  /// Ombre douce des cartes.
  final Color ombre;
  /// Ombre des panneaux.
  final Color ombrePanneau;
  /// Ombre de la barre du bas (ancienne pilule flottante).
  final Color ombreBarre;
  /// Graphiques : revenus et depenses (>= 3:1 sur [surface]).
  final Color graphiqueRevenus;
  final Color graphiqueDepenses;
  final Color graphiqueRevenusAttenue;
  final Color graphiqueDepensesAttenue;

  static const PaletteMonCheptel clair = PaletteMonCheptel(
    sombre: false,
    marque: Couleurs.marque,
    surMarque: Couleurs.surMarque,
    surMarqueDiscret: Couleurs.surMarqueDiscret,
    surEntete: Couleurs.surMarque,
    enteteDebut: Couleurs.logoVert,
    enteteFin: Couleurs.marque,
    enteteSombreDebut: Couleurs.marqueSombre,
    enteteSombreFin: Couleurs.logoVert,
    fondFonce: Couleurs.marqueSombre,
    encreFonce: Couleurs.marqueSombre,
    surAccent: Couleurs.marqueSombre,
    accent: Couleurs.accent,
    fondAccueilHaut: Couleurs.fondAccueilHaut,
    fondAccueilBas: Couleurs.fondAccueilBas,
    fondConnexion: Couleurs.fondConnexion,
    sante: Couleurs.sante,
    attention: Couleurs.attention,
    attentionTexte: Couleurs.attentionTexte,
    erreur: Couleurs.erreur,
    graviteHaute: Couleurs.graviteHaute,
    graviteMoyenne: Couleurs.graviteMoyenne,
    graviteFaible: Couleurs.graviteFaible,
    fond: Couleurs.fond,
    sable: Couleurs.sable,
    terre: Couleurs.terre,
    fondAccentPale: Couleurs.fondAccentPale,
    surface: Couleurs.surface,
    filet: Couleurs.filet,
    filetLeger: Couleurs.filetLeger,
    fondMarquePale: Couleurs.fondMarquePale,
    fondMarquePale2: Couleurs.fondMarquePale2,
    fondAttentionPale: Couleurs.fondAttentionPale,
    fondErreurPale: Couleurs.fondErreurPale,
    titre: Couleurs.titre,
    texte: Couleurs.texte,
    texteDiscret: Couleurs.texteDiscret,
    texteIndicatif: Couleurs.texteIndicatif,
    ombre: Couleurs.ombre,
    ombrePanneau: Couleurs.ombrePanneau,
    ombreBarre: Color(0x290B5653),
    graphiqueRevenus: Couleurs.graphiqueRevenus,
    graphiqueDepenses: Couleurs.graphiqueDepenses,
    graphiqueRevenusAttenue: Couleurs.graphiqueRevenusAttenue,
    graphiqueDepensesAttenue: Couleurs.graphiqueDepensesAttenue,
  );

  static const PaletteMonCheptel nuit = PaletteMonCheptel(
    sombre: true,
    marque: Color(0xFF5EC4B7),
    surMarque: Color(0xFF04221F),
    surMarqueDiscret: Color(0xFFD6E6E4),
    surEntete: Color(0xFFFFFFFF),
    enteteDebut: Color(0xFF072C29),
    enteteFin: Color(0xFF0F4A45),
    enteteSombreDebut: Color(0xFF041B19),
    enteteSombreFin: Color(0xFF0A3633),
    fondFonce: Color(0xFF1B4B46),
    encreFonce: Color(0xFFCDE8E3),
    surAccent: Color(0xFF0E3F3C),
    accent: Color(0xFFEF9429),
    fondAccueilHaut: Color(0xFF0C1716),
    fondAccueilBas: Color(0xFF0F2E2A),
    fondConnexion: Color(0xFF0F1C1A),
    sante: Color(0xFF86C1E6),
    attention: Color(0xFFF4A259),
    attentionTexte: Color(0xFFF2A65A),
    erreur: Color(0xFFF28B82),
    graviteHaute: Color(0xFFC9443F),
    graviteMoyenne: Color(0xFFEF9429),
    graviteFaible: Color(0xFF4CB894),
    fond: Color(0xFF0C1716),
    sable: Color(0xFF1E2E2A),
    terre: Color(0xFFC99B6E),
    fondAccentPale: Color(0xFF3A2914),
    surface: Color(0xFF15241F),
    filet: Color(0xFF3A4D47),
    filetLeger: Color(0xFF26372F),
    fondMarquePale: Color(0xFF173A35),
    fondMarquePale2: Color(0xFF183D38),
    fondAttentionPale: Color(0xFF3A2A16),
    fondErreurPale: Color(0xFF3E1F1F),
    titre: Color(0xFFF2F6F4),
    texte: Color(0xFFDDE6E3),
    texteDiscret: Color(0xFF9FB1AB),
    texteIndicatif: Color(0xFF7D8D88),
    ombre: Color(0x33000000),
    ombrePanneau: Color(0x66000000),
    ombreBarre: Color(0x80000000),
    graphiqueRevenus: Color(0xFF2BB3A3),
    graphiqueDepenses: Color(0xFFE8893A),
    graphiqueRevenusAttenue: Color(0x592BB3A3),
    graphiqueDepensesAttenue: Color(0x59E8893A),
  );

  @override
  PaletteMonCheptel copyWith({
    bool? sombre,
    Color? marque,
    Color? surMarque,
    Color? surMarqueDiscret,
    Color? surEntete,
    Color? enteteDebut,
    Color? enteteFin,
    Color? enteteSombreDebut,
    Color? enteteSombreFin,
    Color? fondFonce,
    Color? encreFonce,
    Color? surAccent,
    Color? accent,
    Color? fondAccueilHaut,
    Color? fondAccueilBas,
    Color? fondConnexion,
    Color? sante,
    Color? attention,
    Color? attentionTexte,
    Color? erreur,
    Color? graviteHaute,
    Color? graviteMoyenne,
    Color? graviteFaible,
    Color? fond,
    Color? sable,
    Color? terre,
    Color? fondAccentPale,
    Color? surface,
    Color? filet,
    Color? filetLeger,
    Color? fondMarquePale,
    Color? fondMarquePale2,
    Color? fondAttentionPale,
    Color? fondErreurPale,
    Color? titre,
    Color? texte,
    Color? texteDiscret,
    Color? texteIndicatif,
    Color? ombre,
    Color? ombrePanneau,
    Color? ombreBarre,
    Color? graphiqueRevenus,
    Color? graphiqueDepenses,
    Color? graphiqueRevenusAttenue,
    Color? graphiqueDepensesAttenue,
  }) =>
      PaletteMonCheptel(
        sombre: sombre ?? this.sombre,
        marque: marque ?? this.marque,
        surMarque: surMarque ?? this.surMarque,
        surMarqueDiscret: surMarqueDiscret ?? this.surMarqueDiscret,
        surEntete: surEntete ?? this.surEntete,
        enteteDebut: enteteDebut ?? this.enteteDebut,
        enteteFin: enteteFin ?? this.enteteFin,
        enteteSombreDebut: enteteSombreDebut ?? this.enteteSombreDebut,
        enteteSombreFin: enteteSombreFin ?? this.enteteSombreFin,
        fondFonce: fondFonce ?? this.fondFonce,
        encreFonce: encreFonce ?? this.encreFonce,
        surAccent: surAccent ?? this.surAccent,
        accent: accent ?? this.accent,
        fondAccueilHaut: fondAccueilHaut ?? this.fondAccueilHaut,
        fondAccueilBas: fondAccueilBas ?? this.fondAccueilBas,
        fondConnexion: fondConnexion ?? this.fondConnexion,
        sante: sante ?? this.sante,
        attention: attention ?? this.attention,
        attentionTexte: attentionTexte ?? this.attentionTexte,
        erreur: erreur ?? this.erreur,
        graviteHaute: graviteHaute ?? this.graviteHaute,
        graviteMoyenne: graviteMoyenne ?? this.graviteMoyenne,
        graviteFaible: graviteFaible ?? this.graviteFaible,
        fond: fond ?? this.fond,
        sable: sable ?? this.sable,
        terre: terre ?? this.terre,
        fondAccentPale: fondAccentPale ?? this.fondAccentPale,
        surface: surface ?? this.surface,
        filet: filet ?? this.filet,
        filetLeger: filetLeger ?? this.filetLeger,
        fondMarquePale: fondMarquePale ?? this.fondMarquePale,
        fondMarquePale2: fondMarquePale2 ?? this.fondMarquePale2,
        fondAttentionPale: fondAttentionPale ?? this.fondAttentionPale,
        fondErreurPale: fondErreurPale ?? this.fondErreurPale,
        titre: titre ?? this.titre,
        texte: texte ?? this.texte,
        texteDiscret: texteDiscret ?? this.texteDiscret,
        texteIndicatif: texteIndicatif ?? this.texteIndicatif,
        ombre: ombre ?? this.ombre,
        ombrePanneau: ombrePanneau ?? this.ombrePanneau,
        ombreBarre: ombreBarre ?? this.ombreBarre,
        graphiqueRevenus: graphiqueRevenus ?? this.graphiqueRevenus,
        graphiqueDepenses: graphiqueDepenses ?? this.graphiqueDepenses,
        graphiqueRevenusAttenue: graphiqueRevenusAttenue ?? this.graphiqueRevenusAttenue,
        graphiqueDepensesAttenue: graphiqueDepensesAttenue ?? this.graphiqueDepensesAttenue,
      );

  @override
  PaletteMonCheptel lerp(covariant ThemeExtension<PaletteMonCheptel>? other, double t) {
    if (other is! PaletteMonCheptel) return this;
    Color m(Color a, Color b) => Color.lerp(a, b, t)!;
    return PaletteMonCheptel(
      sombre: t < 0.5 ? sombre : other.sombre,
      marque: m(marque, other.marque),
      surMarque: m(surMarque, other.surMarque),
      surMarqueDiscret: m(surMarqueDiscret, other.surMarqueDiscret),
      surEntete: m(surEntete, other.surEntete),
      enteteDebut: m(enteteDebut, other.enteteDebut),
      enteteFin: m(enteteFin, other.enteteFin),
      enteteSombreDebut: m(enteteSombreDebut, other.enteteSombreDebut),
      enteteSombreFin: m(enteteSombreFin, other.enteteSombreFin),
      fondFonce: m(fondFonce, other.fondFonce),
      encreFonce: m(encreFonce, other.encreFonce),
      surAccent: m(surAccent, other.surAccent),
      accent: m(accent, other.accent),
      fondAccueilHaut: m(fondAccueilHaut, other.fondAccueilHaut),
      fondAccueilBas: m(fondAccueilBas, other.fondAccueilBas),
      fondConnexion: m(fondConnexion, other.fondConnexion),
      sante: m(sante, other.sante),
      attention: m(attention, other.attention),
      attentionTexte: m(attentionTexte, other.attentionTexte),
      erreur: m(erreur, other.erreur),
      graviteHaute: m(graviteHaute, other.graviteHaute),
      graviteMoyenne: m(graviteMoyenne, other.graviteMoyenne),
      graviteFaible: m(graviteFaible, other.graviteFaible),
      fond: m(fond, other.fond),
      sable: m(sable, other.sable),
      terre: m(terre, other.terre),
      fondAccentPale: m(fondAccentPale, other.fondAccentPale),
      surface: m(surface, other.surface),
      filet: m(filet, other.filet),
      filetLeger: m(filetLeger, other.filetLeger),
      fondMarquePale: m(fondMarquePale, other.fondMarquePale),
      fondMarquePale2: m(fondMarquePale2, other.fondMarquePale2),
      fondAttentionPale: m(fondAttentionPale, other.fondAttentionPale),
      fondErreurPale: m(fondErreurPale, other.fondErreurPale),
      titre: m(titre, other.titre),
      texte: m(texte, other.texte),
      texteDiscret: m(texteDiscret, other.texteDiscret),
      texteIndicatif: m(texteIndicatif, other.texteIndicatif),
      ombre: m(ombre, other.ombre),
      ombrePanneau: m(ombrePanneau, other.ombrePanneau),
      ombreBarre: m(ombreBarre, other.ombreBarre),
      graphiqueRevenus: m(graphiqueRevenus, other.graphiqueRevenus),
      graphiqueDepenses: m(graphiqueDepenses, other.graphiqueDepenses),
      graphiqueRevenusAttenue: m(graphiqueRevenusAttenue, other.graphiqueRevenusAttenue),
      graphiqueDepensesAttenue: m(graphiqueDepensesAttenue, other.graphiqueDepensesAttenue),
    );
  }
}

/// Styles de texte de [Typo], recolores selon la palette du theme.
class TypoTheme {
  const TypoTheme(this._c);
  final PaletteMonCheptel _c;

  TextStyle get accroche => Typo.accroche;
  TextStyle get titreEcran => Typo.titreEcran;
  TextStyle get bouton => Typo.bouton;
  TextStyle get pastille => Typo.pastille;
  TextStyle get chiffreHeros => Typo.chiffreHeros.copyWith(color: _c.titre);
  TextStyle get titreSection => Typo.titreSection.copyWith(color: _c.titre);
  TextStyle get chiffre => Typo.chiffre.copyWith(color: _c.titre);
  TextStyle get corps => Typo.corps.copyWith(color: _c.texte);
  TextStyle get corpsDiscret => Typo.corpsDiscret.copyWith(color: _c.texteDiscret);
  TextStyle get corpsFort => Typo.corpsFort.copyWith(color: _c.texte);
  TextStyle get legende => Typo.legende.copyWith(color: _c.texteDiscret);
  TextStyle get legendeForte => Typo.legendeForte.copyWith(color: _c.texteDiscret);
  TextStyle get contexte => Typo.contexte.copyWith(color: _c.marque);
}

/// `context.couleurs.marque`, `context.typo.corps`.
extension PaletteDuContexte on BuildContext {
  PaletteMonCheptel get couleurs =>
      Theme.of(this).extension<PaletteMonCheptel>() ?? PaletteMonCheptel.clair;
  TypoTheme get typo => TypoTheme(couleurs);
}

/// Encre lisible sur un aplat de couleur variable (bandeau de gravite) :
/// blanc sur un fond fonce, vert tres sombre sur un fond clair.
Color encreSur(Color fond) =>
    ThemeData.estimateBrightnessForColor(fond) == Brightness.dark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF04221F);
