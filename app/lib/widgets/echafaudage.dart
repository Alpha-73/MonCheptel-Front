/// En-tete de marque, barre de navigation du bas, et l'echafaudage qui les
/// assemble — la coquille commune a tous les ecrans de l'espace eleveur.
library;

import 'package:flutter/material.dart';
import '../theme/palette.dart';
import '../theme/dimensions.dart';
import '../theme/typographie.dart';
import 'mise_en_page.dart';
import 'vivant.dart';

/// En-tete vert : nom de l'application, identite de l'utilisateur, cloche.
class EnteteMarque extends StatelessWidget {
  const EnteteMarque({
    super.key,
    required this.titre,
    this.sousTitre,
    this.notificationsNonLues = 0,
    this.onCloche,
    this.logo = false,
  });

  /// Le logo en blanc a la place du titre (accueil de l'eleveur). Le
  /// [titre] reste lu par le lecteur d'ecran.
  final bool logo;

  final String titre;
  final String? sousTitre;
  final int notificationsNonLues;
  final VoidCallback? onCloche;

  @override
  Widget build(BuildContext context) {
    // Refonte du 7 octobre : l'en-tete est desormais l'[EnteteVivant]
    // (degrade, logo). La signature reste la meme.
    return EnteteVivant(
      titre: titre,
      sousTitre: sousTitre,
      grand: logo,
      aDroite: onCloche == null
          ? null
          : BoutonEntete(
              icone: Icons.notifications_none_rounded,
              libelle: 'Notifications',
              badge: notificationsNonLues,
              onTap: onCloche!),
    );
  }
}

/// En-tete clair des onglets de l'espace veterinaire : titre noir sur le
/// fond de l'ecran, comme dans la maquette de ce parcours.
///
/// [surtitre] : la ligne discrete au-dessus du titre (« Bonjour, »).
/// [aDroite] : l'avatar de l'accueil, par exemple.
class EnteteClair extends StatelessWidget {
  const EnteteClair({super.key, required this.titre, this.surtitre, this.aDroite});

  final String titre;
  final String? surtitre;
  final Widget? aDroite;

  @override
  Widget build(BuildContext context) {
    // Refonte du 7 octobre : l'espace veterinaire porte lui aussi la
    // marque, en vert sombre pour se distinguer de l'espace eleveur.
    return EnteteVivant(titre: titre, surtitre: surtitre, aDroite: aDroite, sombre: true);
  }
}

/// Une entree de la barre du bas : icone au repos (contour), icone active
/// (pleine), libelle.
typedef EntreeNav = ({IconData icone, IconData iconeActive, String libelle});

/// Barre de navigation du bas, cinq entrees pour l'eleveur, quatre pour le
/// veterinaire.
///
/// Construite a la main plutot qu'avec `NavigationBar` : le composant
/// Material a change de theme deux fois (WidgetStateProperty) et ne
/// compilerait pas a l'identique sur toutes les versions de Flutter. Elle en
/// reprend les principes :
///  - un INDICATEUR (pilule vert pale) derriere l'icone active, en plus de
///    la couleur — l'etat ne repose jamais sur la seule couleur (WCAG 1.4.1) ;
///  - icone pleine pour l'onglet actif, contour pour les autres ;
///  - chaque entree annonce son etat aux lecteurs d'ecran (« selectionne ») ;
///  - les libelles grossissent avec le reglage du telephone, jusqu'a 1,3 fois
///    — au-dela, cinq mots ne tiennent plus sur une ligne.
class BarreNavigation extends StatelessWidget {
  const BarreNavigation({
    super.key,
    required this.entrees,
    required this.indexActif,
    required this.onChange,
    this.actionCentrale,
    this.pictogrammes = const {},
  });

  final List<EntreeNav> entrees;
  final int indexActif;
  final ValueChanged<int> onChange;

  /// Bouton orange rond au milieu de la barre (« Agir vite » de l'eleveur).
  /// Avec un nombre pair d'entrees, il se place entre les deux moities.
  final VoidCallback? actionCentrale;

  /// Pictogramme dessine a la place de l'icone, par index d'entree (la
  /// tete de vache de l'onglet Animaux) : (couleur, actif) -> widget 24 px.
  final Map<int, Widget Function(Color couleur, bool actif)> pictogrammes;

  @override
  Widget build(BuildContext context) {
    final milieu = entrees.length ~/ 2;
    final cases = <Widget>[
      for (var i = 0; i < entrees.length; i++)
        Expanded(
          child: _EntreeBarre(
            entree: entrees[i],
            picto: pictogrammes[i],
            active: i == indexActif,
            onTap: () => onChange(i),
          ),
        ),
    ];
    if (actionCentrale != null) {
      cases.insert(milieu, SizedBox(width: 72, child: _ActionCentrale(onTap: actionCentrale!)));
    }
    // Barre FIXE, ancree au bas de l'ecran sur toute la largeur : fond
    // surface, filet et ombre legere en haut, zone sure respectee. Sur
    // tablette ou en paysage, les entrees se regroupent au centre.
    final c = context.couleurs;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.filetLeger)),
        boxShadow: [BoxShadow(color: c.ombre, blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: LargeurLisible(
            largeur: 600,
            child: SizedBox(height: Dim.hauteurBarre, child: Row(children: cases)),
          ),
        ),
      ),
    );
  }
}

class _ActionCentrale extends StatelessWidget {
  const _ActionCentrale({required this.onTap});
  final VoidCallback onTap;

  @override
  // Depasse de quelques pixels vers le haut, mais reste dans la barre :
  // toute sa surface se touche.
  Widget build(BuildContext context) => Center(
        child: Transform.translate(
          offset: const Offset(0, -4),
          child: Semantics(
          button: true,
          label: 'Agir vite : signaler, ajouter, noter',
          excludeSemantics: true,
          onTap: onTap,
          child: Material(
            color: context.couleurs.accent,
            shape: const CircleBorder(),
            elevation: 4,
            shadowColor: const Color(0x66EF9429),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 54,
                height: 54,
                child: Icon(Icons.add_rounded, size: 32, color: context.couleurs.surAccent),
              ),
            ),
          ),
          ),
        ),
      );
}

class _EntreeBarre extends StatelessWidget {
  const _EntreeBarre(
      {required this.entree, required this.active, required this.onTap, this.picto});
  final Widget Function(Color couleur, bool actif)? picto;
  final EntreeNav entree;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final encre = active ? context.couleurs.marque : context.couleurs.texteDiscret;
    return Semantics(
      selected: active,
      button: true,
      label: entree.libelle,
      onTap: active ? null : onTap,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: active ? null : onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Indicateur de taille CONSTANTE : seul son remplissage change,
            // les icones ne bougent pas d'un onglet a l'autre.
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: 52,
              height: 30,
              decoration: BoxDecoration(
                color: active ? context.couleurs.fondMarquePale : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: picto != null
                  ? Center(child: picto!(encre, active))
                  : Icon(active ? entree.iconeActive : entree.icone, size: 24, color: encre),
            ),
            const SizedBox(height: 3),
            Text(
              entree.libelle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // Meme graisse actif ou non : le libelle ne change pas de largeur.
              style: Typo.pastille.copyWith(color: encre, fontSize: 12.5),
            ),
            // Point orange sous l'onglet actif : le signal du logo.
            AnimatedOpacity(
              opacity: active ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                margin: const EdgeInsets.only(top: 2),
                width: 4,
                height: 4,
                decoration:
                    BoxDecoration(color: context.couleurs.accent, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Les cinq entrees de l'espace eleveur, dans l'ordre de la maquette.
const List<EntreeNav> navEleveur = [
  (icone: Icons.home_outlined, iconeActive: Icons.home_rounded, libelle: 'Accueil'),
  (icone: Icons.pets_outlined, iconeActive: Icons.pets, libelle: 'Animaux'),
  (icone: Icons.health_and_safety_outlined, iconeActive: Icons.health_and_safety, libelle: 'Santé'),
  (icone: Icons.menu_book_outlined, iconeActive: Icons.menu_book, libelle: 'Conseils'),
  (icone: Icons.person_outline, iconeActive: Icons.person, libelle: 'Profil'),
];

/// Les quatre entrees de l'espace veterinaire.
const List<EntreeNav> navVeterinaire = [
  (icone: Icons.home_outlined, iconeActive: Icons.home_rounded, libelle: 'Accueil'),
  (icone: Icons.groups_outlined, iconeActive: Icons.groups, libelle: 'Éleveurs'),
  (icone: Icons.menu_book_outlined, iconeActive: Icons.menu_book, libelle: 'Conseils'),
  (icone: Icons.person_outline, iconeActive: Icons.person, libelle: 'Profil'),
];

/// Coquille d'un ecran : en-tete vert, corps defilant, barre du bas.
class EcranPrincipal extends StatelessWidget {
  const EcranPrincipal({
    super.key,
    required this.entete,
    required this.corps,
    required this.entrees,
    required this.indexActif,
    required this.onChange,
  });

  final Widget entete;
  final List<Widget> corps;
  final List<EntreeNav> entrees;
  final int indexActif;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.couleurs.fond,
      body: Column(
        children: [
          entete,
          Expanded(
            child: ListView(
              padding: lisible(context, const EdgeInsets.only(top: 8, bottom: 24)),
              children: corps,
            ),
          ),
        ],
      ),
      bottomNavigationBar: BarreNavigation(
        entrees: entrees, indexActif: indexActif, onChange: onChange),
    );
  }
}

/// Marge laterale standard, pour un bloc place dans le corps d'un ecran.
class Gouttiere extends StatelessWidget {
  const Gouttiere({super.key, required this.enfant});
  final Widget enfant;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Dim.gouttiere),
        child: enfant,
      );
}
