/// Briques des ecrans secondaires de l'espace eleveur (sante, argent,
/// conseils, profil, notifications) : l'ecran a en-tete vivant, le
/// chargeur a squelette, les etapes d'un parcours et la grande tuile a
/// pictogramme.
///
/// Ajoutees le 7 octobre avec la refonte ; elles composent les pieces de
/// `vivant.dart` sans les modifier.
library;

import 'package:flutter/material.dart';

import '../../theme/palette.dart';
import '../../theme/dimensions.dart';
import '../../theme/typographie.dart';
import '../etats.dart';
import '../vivant.dart';
import '../mise_en_page.dart';

/// Ecran secondaire a la marque : en-tete vivant (courbe, motif, ondes)
/// avec retour, corps, et un pied colle en bas au-dessus du clavier.
class EcranVivant extends StatelessWidget {
  const EcranVivant({
    super.key,
    required this.titre,
    required this.corps,
    this.surtitre,
    this.sousTitre,
    this.aDroite,
    this.bas,
    this.pied,
    this.retour = true,
  });

  final String titre;
  final String? surtitre;
  final String? sousTitre;
  final Widget? aDroite;
  final Widget? bas;
  final Widget corps;
  final Widget? pied;
  final bool retour;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.couleurs.fond,
        body: Column(
          children: [
            EnteteVivant(
              titre: titre,
              surtitre: surtitre,
              sousTitre: sousTitre,
              aDroite: aDroite,
              bas: bas,
              retour: retour,
            ),
            Expanded(child: pied == null ? SafeArea(top: false, child: corps) : corps),
          ],
        ),
        bottomNavigationBar: pied == null
            ? null
            : Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
                child: SafeArea(
                  top: false,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.couleurs.fond,
                      border: Border(top: BorderSide(color: context.couleurs.filetLeger)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(Dim.gouttiere, 12, Dim.gouttiere, 12),
                      child: Material(type: MaterialType.transparency, child: pied),
                    ),
                  ),
                ),
              ),
      );
}

/// Charge une donnee et la montre ; squelettes pendant le chargement (pas
/// de rond qui tourne), erreur avec « Réessayer ».
///
/// [construire] recoit [recharger]. Les donnees deja affichees restent a
/// l'ecran pendant un rechargement.
class ChargeurVivant<T> extends StatefulWidget {
  const ChargeurVivant({
    super.key,
    required this.charger,
    required this.construire,
    this.squelettes = 3,
    this.titreEcran,
  });

  /// Renseigne quand [construire] rend un ECRAN entier : pendant le
  /// chargement et en cas d'erreur, un [EcranVivant] portant ce titre (et
  /// la fleche de retour) habille l'etat.
  final String? titreEcran;

  final Future<T> Function() charger;
  final Widget Function(BuildContext context, T donnee, Future<void> Function() recharger)
      construire;
  final int squelettes;

  @override
  State<ChargeurVivant<T>> createState() => _ChargeurVivantState<T>();
}

class _ChargeurVivantState<T> extends State<ChargeurVivant<T>> {
  T? _donnee;
  bool _aDonnee = false;
  Object? _erreur;

  @override
  void initState() {
    super.initState();
    _recharger();
  }

  Future<void> _recharger() async {
    if (mounted && _erreur != null) setState(() => _erreur = null);
    try {
      final d = await widget.charger();
      if (!mounted) return;
      setState(() {
        _donnee = d;
        _aDonnee = true;
        _erreur = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _erreur = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_aDonnee) return widget.construire(context, _donnee as T, _recharger);
    final etat = _erreur != null
        ? EtatErreur(erreur: _erreur!, onReessayer: _recharger)
        : ListView(
            padding: lisible(context, const EdgeInsets.only(top: 16)),
            physics: const NeverScrollableScrollPhysics(),
            children: [ListeSquelette(nombre: widget.squelettes)],
          );
    final titre = widget.titreEcran;
    return titre == null ? etat : EcranVivant(titre: titre, corps: etat);
  }
}

/// Avancement d'un parcours : « 1 Animal — 2 Symptômes — 3 Résultat ».
/// L'etape courante est pleine, les precedentes cochees.
class EtapesParcours extends StatelessWidget {
  const EtapesParcours({super.key, required this.etapes, required this.courante});
  final List<String> etapes;

  /// Index a partir de 0.
  final int courante;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Étape ${courante + 1} sur ${etapes.length} : ${etapes[courante]}',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Dim.gouttiere, 4, Dim.gouttiere, 4),
          child: Row(
            children: [
              for (var i = 0; i < etapes.length; i++) ...[
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: i <= courante ? context.couleurs.accent : const Color(0x40FFFFFF),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                _PointEtape(numero: i + 1, libelle: etapes[i], etat: i.compareTo(courante)),
              ],
            ],
          ),
        ),
      );
}

class _PointEtape extends StatelessWidget {
  const _PointEtape({required this.numero, required this.libelle, required this.etat});
  final int numero;
  final String libelle;

  /// -1 faite, 0 courante, 1 a venir.
  final int etat;

  @override
  Widget build(BuildContext context) {
    final courante = etat == 0;
    final faite = etat < 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: courante
                ? context.couleurs.accent
                : faite
                    ? context.couleurs.surEntete
                    : const Color(0x26FFFFFF),
          ),
          child: faite
              ? Icon(Icons.check_rounded, size: 18, color: context.couleurs.enteteDebut)
              : Text('$numero',
                  style: Typo.pastille.copyWith(
                      color: courante ? context.couleurs.surAccent : context.couleurs.surEntete)),
        ),
        if (courante) ...[
          const SizedBox(width: 6),
          Text(libelle, style: context.typo.corpsFort.copyWith(color: context.couleurs.surEntete)),
        ],
      ],
    );
  }
}

/// Grande tuile a pictogramme : un rond teinte, un libelle court, un
/// detail facultatif. Cible d'au moins 88 px de haut.
class TuilePicto extends StatelessWidget {
  const TuilePicto({
    super.key,
    required this.icone,
    required this.libelle,
    required this.onTap,
    this.detail,
    this.teinte,
    this.fondIcone,
    this.badge,
  });

  final IconData icone;
  final String libelle;
  final String? detail;
  final VoidCallback onTap;
  final Color? teinte;
  final Color? fondIcone;

  /// Petit compteur orange sur le pictogramme (« 2 en attente »).
  final int? badge;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        libelle: [libelle, if (detail != null) detail!].join(', '),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 96),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                          color: fondIcone ?? context.couleurs.fondMarquePale,
                          shape: BoxShape.circle),
                      child: Icon(icone, color: teinte ?? context.couleurs.marque, size: 26),
                    ),
                    if (badge != null && badge! > 0)
                      Positioned(
                        right: -6,
                        top: -4,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 22),
                          height: 22,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: context.couleurs.accent,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: context.couleurs.surface, width: 2),
                          ),
                          child: Text('${badge!}',
                              style: Typo.pastille
                                  .copyWith(fontSize: 12, color: context.couleurs.surAccent)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(libelle, style: context.typo.corpsFort),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(detail!, style: context.typo.legende),
                ],
              ],
            ),
          ),
        ),
      );
}

/// Pastille de statut lisible sans la couleur : un point, un libelle.
class PastilleStatut extends StatelessWidget {
  const PastilleStatut({super.key, required this.libelle, required this.couleur, this.fond});
  final String libelle;
  final Color couleur;
  final Color? fond;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: fond ?? couleur.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Dim.rayonPastille),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(libelle,
                  style: Typo.pastille.copyWith(color: context.couleurs.texte),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
}

/// Onglets en pilules a placer dans le `bas` d'un [EnteteVivant] : blanc
/// translucide au repos, blanc plein et texte vert quand actif.
class OngletsSurMarque extends StatelessWidget {
  const OngletsSurMarque({
    super.key,
    required this.libelles,
    required this.indexActif,
    required this.onChange,
  });

  final List<String> libelles;
  final int indexActif;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: Dim.hauteurTactile,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: libelles.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final actif = i == indexActif;
            return Semantics(
              selected: actif,
              button: true,
              child: Material(
                color: actif ? context.couleurs.surface : const Color(0x26FFFFFF),
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: actif ? null : () => onChange(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Center(
                      widthFactor: 1,
                      child: Text(libelles[i],
                          style: Typo.bouton.copyWith(
                              color: actif ? context.couleurs.marque : context.couleurs.surEntete)),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
}

/// Bouton d'appel geant : 64 px, vert plein, combine et nom.
class BoutonAppelGeant extends StatelessWidget {
  const BoutonAppelGeant({super.key, required this.libelle, required this.onTap, this.detail});
  final String libelle;
  final String? detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Material(
          color: context.couleurs.marque,
          borderRadius: BorderRadius.circular(18),
          elevation: 3,
          shadowColor: const Color(0x55146B66),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration:
                          BoxDecoration(color: context.couleurs.accent, shape: BoxShape.circle),
                      child: Icon(Icons.call_rounded, color: context.couleurs.surAccent),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(libelle,
                              style: context.typo.titreSection.copyWith(
                                  color: context.couleurs.surMarque, fontSize: 19, height: 1.15)),
                          if (detail != null)
                            Text(detail!,
                                style: context.typo.legendeForte.copyWith(
                                    color: context.couleurs.surMarque.withValues(alpha: 0.85))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
