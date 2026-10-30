/// En-tete des ecrans secondaires (fleche retour + titre) et petits blocs de
/// mise en page recurrents.
library;

import 'package:flutter/material.dart';

import '../theme/barre_etat.dart';
import '../theme/palette.dart';
import '../theme/dimensions.dart';
import '../theme/typographie.dart';
import 'mise_en_page.dart';

/// En-tete d'un ecran secondaire : fleche retour, titre, sous-titre.
///
/// [clair] : fond clair et titre noir, comme toute la maquette du parcours
/// veterinaire. Sans lui, en-tete vert de l'espace eleveur. La couleur des
/// icones de la barre d'etat suit le fond (voir theme/barre_etat.dart).
AppBar barreSecondaire(
  BuildContext context, {
  required String titre,
  String? sousTitre,
  bool clair = false,
  List<Widget> actions = const [],
}) {
  final c = context.couleurs;
  final encre = clair ? c.titre : c.surEntete;
  return AppBar(
    backgroundColor: clair ? c.fond : null,
    foregroundColor: clair ? encre : null,
    systemOverlayStyle: clair ? BarreEtat.pourFond(c) : BarreEtat.pourEntete(c),
    // Le meme degrade que les en-tetes vivants.
    flexibleSpace: clair
        ? null
        : DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.enteteDebut, c.enteteFin],
              ),
            ),
          ),
    title: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titre, style: Typo.titreEcran.copyWith(color: encre)),
        if (sousTitre != null)
          Text(sousTitre,
              style: context.typo.legende.copyWith(
                  color: clair ? context.couleurs.texteDiscret : context.couleurs.surMarqueDiscret)),
      ],
    ),
    actions: actions,
  );
}

/// Ecran secondaire : en-tete avec retour, corps defilant.
///
/// [pied] : bouton(s) colles en bas, au-dessus du clavier — l'action
/// principale d'un formulaire reste visible sans faire defiler.
class EcranSecondaire extends StatelessWidget {
  const EcranSecondaire({
    super.key,
    required this.titre,
    this.sousTitre,
    required this.corps,
    this.pied,
    this.actions = const [],
    this.clair = false,
  });

  final String titre;
  final String? sousTitre;
  final Widget corps;
  final Widget? pied;
  final List<Widget> actions;

  /// En-tete clair (parcours veterinaire). Voir [barreSecondaire].
  final bool clair;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.couleurs.fond,
      appBar: barreSecondaire(
          context,
          titre: titre, sousTitre: sousTitre, clair: clair, actions: actions),
      // Sans pied, le corps s'arrete au-dessus de la barre de gestes
      // d'Android : le dernier element d'une liste reste atteignable.
      body: pied == null ? SafeArea(top: false, child: corps) : corps,
      // Le pied est decale de la hauteur du clavier : l'action principale
      // reste visible pendant la saisie.
      bottomNavigationBar: pied == null
          ? null
          : Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.couleurs.surface,
                  // Ombre vers le haut plutot qu'un filet : le contenu
                  // defile SOUS le pied, et l'ombre le montre.
                  boxShadow: [
                    BoxShadow(
                        color: context.couleurs.ombrePanneau,
                        blurRadius: 12,
                        offset: const Offset(0, -2)),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  // Material transparent : l'effet d'encre d'un element du
                  // pied (case a cocher...) se dessine AU-DESSUS du fond
                  // blanc, et non dessous ou il serait invisible.
                  child: Material(
                    type: MaterialType.transparency,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          Dim.gouttiere, 12, Dim.gouttiere, 12),
                      child: LargeurLisible(child: pied!),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// Titre de section dans un corps d'ecran, avec action optionnelle a droite
/// (« Derniers événements      + Ajouter »).
class TitreSection extends StatelessWidget {
  const TitreSection(this.texte, {super.key, this.action, this.onAction});
  final String texte;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        // Avec une action, sa zone tactile de 48 px fait elle-meme la marge
        // du bas et du bord droit.
        padding: EdgeInsets.fromLTRB(
            Dim.gouttiere, Dim.ecartSection, action == null ? Dim.gouttiere : 4,
            action == null ? 10 : 0),
        child: Row(
          children: [
            Expanded(child: Text(texte, style: context.typo.titreSection)),
            if (action != null)
              InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(Dim.rayon),
                // 48 x 48 au minimum : un lien de 20 px de haut se rate au
                // pouce.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                      minHeight: Dim.hauteurTactile, minWidth: Dim.hauteurTactile),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Center(
                      widthFactor: 1,
                      child: Text(action!,
                          style: context.typo.legendeForte.copyWith(color: context.couleurs.marque)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

/// Ligne « libelle ........ valeur », dans une carte de detail.
class LigneValeur extends StatelessWidget {
  const LigneValeur(this.libelle, this.valeur, {super.key, this.fort = false, this.couleur});
  final String libelle;
  final String valeur;
  final bool fort;
  final Color? couleur;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: Text(libelle, style: fort ? context.typo.corpsFort : context.typo.corpsDiscret)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                valeur,
                textAlign: TextAlign.right,
                style: (fort ? context.typo.corpsFort : context.typo.corps)
                    .copyWith(color: couleur),
              ),
            ),
          ],
        ),
      );
}

/// Bandeau d'explication discret, sous un formulaire ou un chiffre.
class Note extends StatelessWidget {
  const Note(this.texte, {super.key, this.icone = Icons.info_outline});
  final String texte;
  final IconData icone;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, size: 18, color: context.couleurs.texteDiscret),
            const SizedBox(width: 8),
            Expanded(child: Text(texte, style: context.typo.legende)),
          ],
        ),
      );
}

/// Corps de formulaire standard : marges, defilement, clavier.
class CorpsFormulaire extends StatelessWidget {
  const CorpsFormulaire({super.key, required this.cle, required this.enfants});
  final GlobalKey<FormState> cle;
  final List<Widget> enfants;

  @override
  Widget build(BuildContext context) => Form(
        key: cle,
        child: ListView(
          padding: lisible(context, const EdgeInsets.fromLTRB(
              Dim.gouttiere, 20, Dim.gouttiere, 32)),
          // Faire glisser le formulaire range le clavier, comme dans les
          // applications systeme.
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: enfants,
        ),
      );
}

/// Bandeau vert pale sous l'en-tete : « Filière Volaille — suivi par lots ».
class BandeauContexte extends StatelessWidget {
  const BandeauContexte(this.texte, {super.key});
  final String texte;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: context.couleurs.fondMarquePale2,
        padding: const EdgeInsets.symmetric(horizontal: Dim.gouttiere, vertical: 10),
        child: Text(texte, style: context.typo.contexte),
      );
}

/// Grand bouton de tableau de bord, 64 px, icone a gauche.
class GrosBouton extends StatelessWidget {
  const GrosBouton({
    super.key,
    required this.libelle,
    required this.icone,
    required this.onTap,
    this.plein = true,
  });
  final String libelle;
  final IconData icone;
  final VoidCallback onTap;
  final bool plein;

  @override
  Widget build(BuildContext context) {
    final encre = plein ? context.couleurs.surMarque : context.couleurs.marque;
    return Material(
      color: plein ? context.couleurs.marque : context.couleurs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dim.rayon),
        side: plein ? BorderSide.none : BorderSide(color: context.couleurs.marque),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Dim.rayon),
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone, color: encre, size: 22),
              const SizedBox(width: 8),
              Flexible(
                child: Text(libelle,
                    overflow: TextOverflow.ellipsis,
                    style: Typo.bouton.copyWith(color: encre)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Panneau de l'historique et des alertes.
///
/// Demande du 6 octobre : ce qui DECOULE de l'usage de l'application
/// (alertes, rappels, historique des soins, operations) doit se detacher de
/// la partie haute (chiffres et actions). Le panneau est une surface
/// blanche aux coins hauts arrondis, portee par une ombre vers le haut — la
/// separation se lit sans trait ni titre supplementaire.
///
/// S'emploie dans un [DefilementFlux], qui l'etire jusqu'au bas de l'ecran.
class PanneauFlux extends StatelessWidget {
  const PanneauFlux({
    super.key,
    required this.titre,
    this.action,
    this.onAction,
    required this.enfants,
    this.margeBas = 24,
  });

  final String titre;
  final String? action;
  final VoidCallback? onAction;
  final List<Widget> enfants;

  /// Espace sous le dernier element : a agrandir quand un bouton flottant
  /// couvre le bas de l'ecran.
  final double margeBas;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.couleurs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Dim.rayonPanneau)),
        boxShadow: [
          BoxShadow(color: context.couleurs.ombrePanneau, blurRadius: 18, offset: const Offset(0, -4)),
        ],
      ),
      // Meme raison que pour le pied : l'encre de « + Ajouter » doit se voir.
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
        padding: EdgeInsets.only(bottom: margeBas),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            TitreSection(titre, action: action, onAction: onAction),
            ...enfants,
          ],
        ),
        ),
      ),
    );
  }
}

/// Defilement d'un ecran a deux parties : un haut (chiffres, actions) et un
/// [PanneauFlux] qui occupe tout le reste, jusqu'en bas, meme s'il est
/// presque vide.
///
/// Toujours defilable ([AlwaysScrollableScrollPhysics]) : « tirer pour
/// actualiser » doit marcher aussi quand le contenu est plus court que
/// l'ecran. C'est deja le defaut d'une liste verticale principale ; on
/// l'ecrit pour que la regle se lise dans le code.
class DefilementFlux extends StatelessWidget {
  const DefilementFlux({
    super.key,
    required this.haut,
    required this.panneau,
    this.onRefresh,
  });

  final List<Widget> haut;
  final Widget panneau;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final vue = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.only(top: 12, bottom: 20),
          sliver: SliverList.list(children: haut),
        ),
        SliverFillRemaining(hasScrollBody: false, child: panneau),
      ],
    );
    if (onRefresh == null) return vue;
    return RefreshIndicator(onRefresh: onRefresh!, color: context.couleurs.marque, child: vue);
  }
}
