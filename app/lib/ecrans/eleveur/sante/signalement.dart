/// Parcours « Un animal est malade ? », en trois etapes visibles :
///
///   1. choisir UN lot ou UN animal actif       GET  /api/cheptel?statut=ACTIF
///   2. toucher les symptomes (grandes tuiles)  GET  /api/signalements/symptomes
///      et dire combien sont touches            POST /api/signalements
///   3. lire le resultat : gravite en couleur pleine, conduite a tenir en
///      phrases courtes, et le bouton d'appel du veterinaire.
///
/// L'application ne calcule RIEN : le diagnostic vient du back, a partir
/// des ponderations symptome/maladie de la base.
library;

import 'package:flutter/material.dart';

import '../../../api/client_api.dart';
import '../../../api/modeles.dart';
import '../../../api/services.dart';
import '../../../libelles.dart';
import '../../../theme/palette.dart';
import '../../../theme/dimensions.dart';
import '../../../theme/format.dart';
import '../../../widgets/boutons.dart';
import '../../../widgets/dialogues.dart';
import '../../../widgets/eleveur/ecran_vivant.dart';
import '../../../widgets/etats.dart';
import '../../../widgets/navigation.dart';
import '../../../widgets/vivant.dart';
import 'mes_signalements.dart';
import 'veterinaires.dart';
import 'vocabulaire_sante.dart';
import '../../../widgets/mise_en_page.dart';

const List<String> _etapes = ['Animal', 'Symptômes', 'Résultat'];

/// « Volaille — 180 têtes » / « Bovins — Zébu femelle ».
String _resumeUnite(Unite u) {
  final detail = u.estLot
      ? Fmt.tetes(u.effectifRestant)
      : [u.race ?? u.typeElevage, if (u.sexe != null) L.sexe(u.sexe).toLowerCase()].join(' ');
  return '${L.filiere(u.filiere)} — $detail';
}

/// Tranches « combien de sujets sont touches ? » qui ont un sens pour [u].
///
/// Elles dependent de l'effectif restant :
///  - un animal suivi individuellement est UN sujet : seule « moins de 10 »
///    existe, et la question n'est pas posee ;
///  - un lot de 20 tetes ne propose pas « plus de 50 », et sa tranche du
///    milieu s'affiche « 10 à 20 » au lieu de « 10 à 50 » ;
///  - un lot de moins de 10 tetes n'a qu'une tranche possible.
///
/// Les CODES envoyes au back ne changent pas (MOINS_DE_10, DE_10_A_50,
/// PLUS_DE_50) : seul le libelle s'adapte. Le back refuse de son cote une
/// tranche superieure a l'effectif du lot.
List<(String, String)> tranchesPour(Unite u) {
  if (!u.estLot) return const [('MOINS_DE_10', '1 animal')];
  final n = u.effectifRestant;
  return [
    ('MOINS_DE_10', n < 10 ? '1 à $n' : 'Moins de 10'),
    if (n >= 10) ('DE_10_A_50', n == 10 ? 'Les 10' : (n <= 50 ? '10 à $n' : '10 à 50')),
    if (n > 50) ('PLUS_DE_50', 'Plus de 50'),
  ];
}

// ── 1. Choix de l'unite ───────────────────────────────────────────────────

class EcranSignalementChoix extends StatefulWidget {
  const EcranSignalementChoix({super.key});

  @override
  State<EcranSignalementChoix> createState() => _EcranSignalementChoixState();
}

class _EcranSignalementChoixState extends State<EcranSignalementChoix> {
  Unite? _choisie;

  /// Ouvre les symptomes. Si un signalement part, cet ecran de choix se
  /// retire de la pile (audit du 10 octobre) : « Retour » depuis le
  /// resultat y ramenait, l'unite encore cochee, et un second appui sur
  /// « Continuer » creait un doublon.
  Future<void> _ouvrirSymptomes(BuildContext context, Unite unite) async {
    final navigateur = Navigator.of(context);
    final route = ModalRoute.of(context);
    final envoye = await navigateur.push<bool>(
        MaterialPageRoute<bool>(builder: (_) => EcranSignalementSymptomes(unite: unite)));
    if (envoye == true && route != null && route.isActive) {
      navigateur.removeRoute(route);
    }
  }

  @override
  Widget build(BuildContext context) => EcranVivant(
        titre: 'Un animal est malade ?',
        bas: const EtapesParcours(etapes: _etapes, courante: 0),
        corps: ChargeurVivant<List<Unite>>(
          charger: () => CheptelApi.lister(statut: 'ACTIF'),
          construire: (context, unites, _) {
            if (unites.isEmpty) {
              return const EtatVide("Aucun lot ni animal actif. Ajoutez d'abord vos animaux.",
                  icone: Icons.pets_outlined);
            }
            return ListView(
              padding: lisible(context, const EdgeInsets.fromLTRB(Dim.gouttiere, 16, Dim.gouttiere, 24)),
              children: [
                Text('Lequel est malade ?', style: context.typo.titreSection),
                const SizedBox(height: 2),
                Text('Un seul à la fois.', style: context.typo.corpsDiscret),
                const SizedBox(height: 14),
                for (var i = 0; i < unites.length; i++)
                  Apparition(
                    rang: i,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CarteUnite(
                        unite: unites[i],
                        choisie: _choisie?.id == unites[i].id,
                        onTap: () => setState(() => _choisie = unites[i]),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        pied: BoutonPrincipal('Continuer',
            icone: Icons.arrow_forward_rounded,
            iconeApres: true,
            onPressed: _choisie == null
                ? null
                : () => _ouvrirSymptomes(context, _choisie!)),
      );
}

class _CarteUnite extends StatelessWidget {
  const _CarteUnite({required this.unite, required this.choisie, required this.onTap});
  final Unite unite;
  final bool choisie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: choisie,
        button: true,
        label: '${unite.code}, ${_resumeUnite(unite)}',
        onTap: onTap,
        excludeSemantics: true,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: choisie ? context.couleurs.accent : Colors.transparent, width: 2.5),
          ),
          child: Pressable(
            onTap: onTap,
            rayon: 14,
            couleur: choisie ? context.couleurs.fondAccentPale : context.couleurs.surface,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: choisie ? context.couleurs.accent : context.couleurs.fondMarquePale,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(iconeFiliere(unite.filiere),
                        size: 28, color: choisie ? context.couleurs.surAccent : context.couleurs.marque),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(unite.code, style: context.typo.titreSection.copyWith(fontSize: 19)),
                        Text(_resumeUnite(unite), style: context.typo.corpsDiscret),
                      ],
                    ),
                  ),
                  Icon(choisie ? Icons.check_circle_rounded : Icons.circle_outlined,
                      size: 28, color: choisie ? context.couleurs.marque : context.couleurs.filet),
                ],
              ),
            ),
          ),
        ),
      );
}

// ── 2. Symptomes ──────────────────────────────────────────────────────────

class EcranSignalementSymptomes extends StatefulWidget {
  const EcranSignalementSymptomes({super.key, required this.unite});
  final Unite unite;

  @override
  State<EcranSignalementSymptomes> createState() => _EcranSignalementSymptomesState();
}

class _EcranSignalementSymptomesState extends State<EcranSignalementSymptomes> {
  final Set<int> _symptomes = {};

  /// Tranches proposees pour CETTE unite (voir [tranchesPour]).
  late final List<(String, String)> _tranches = tranchesPour(widget.unite);

  /// Une seule tranche possible (animal seul, ou lot de moins de 10 tetes) :
  /// elle est retenue d'office et la question n'est pas posee.
  late String? _tranche = _tranches.length == 1 ? _tranches.first.$1 : null;
  final _precision = TextEditingController();
  bool _envoi = false;

  @override
  void dispose() {
    _precision.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    // Garde contre le double appui sur un reseau lent.
    if (_envoi) return;
    setState(() => _envoi = true);
    try {
      final s = await SignalementApi.signaler(
        uniteId: widget.unite.id,
        symptomeIds: _symptomes,
        trancheEffectif: _tranche!,
        precision: _precision.text,
      );
      if (!mounted) return;
      // `result: true` previent l'ecran de choix qu'un signalement est parti :
      // il se retire alors de la pile (voir _ouvrirSymptomes).
      Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
              builder: (_) => EcranSignalementResultat(signalement: s, unite: widget.unite)),
          result: true);
    } on ApiException catch (e) {
      if (mounted) await afficherErreur(context, e, titre: 'Signalement non envoyé');
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.unite;
    final n = _symptomes.length;
    final pret = n > 0 && _tranche != null && !_envoi;
    return EcranVivant(
      titre: 'Que voyez-vous ?',
      sousTitre: '${u.code} · ${_resumeUnite(u)}',
      bas: const EtapesParcours(etapes: _etapes, courante: 1),
      corps: ChargeurVivant<List<Symptome>>(
        charger: () => SignalementApi.symptomes(u.filiere),
        squelettes: 4,
        construire: (context, symptomes, _) => ListView(
          padding: lisible(context, const EdgeInsets.fromLTRB(Dim.gouttiere, 16, Dim.gouttiere, 24)),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text('Touchez ce que vous voyez', style: context.typo.titreSection)),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: n == 0
                      ? const SizedBox.shrink()
                      : PastilleStatut(
                          key: ValueKey(n),
                          libelle: '$n choisi${n > 1 ? 's' : ''}',
                          couleur: context.couleurs.accent,
                          fond: context.couleurs.fondAccentPale),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, c) {
                final n = colonnesGrille(c.maxWidth, null, ecart: 10);
          final largeur = (c.maxWidth - 10 * (n - 1)) / n;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final s in symptomes)
                      SizedBox(
                        width: largeur,
                        child: TuileSymptome(
                          libelle: s.libelle,
                          choisie: _symptomes.contains(s.id),
                          onTap: () => setState(() {
                            if (!_symptomes.remove(s.id)) _symptomes.add(s.id);
                          }),
                        ),
                      ),
                  ],
                );
              },
            ),
            if (_tranches.length > 1) ...[
              const SizedBox(height: 26),
              Text('Combien sont malades ?', style: context.typo.titreSection),
              Text('Sur ${Fmt.tetes(u.effectifRestant)}.', style: context.typo.corpsDiscret),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < _tranches.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _TuileTranche(
                        niveau: i,
                        libelle: _tranches[i].$2,
                        choisie: _tranche == _tranches[i].$1,
                        onTap: () => setState(() => _tranche = _tranches[i].$1),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 26),
            Text('Autre chose ? (facultatif)', style: context.typo.corpsFort),
            const SizedBox(height: 6),
            TextField(
              controller: _precision,
              minLines: 2,
              maxLines: 4,
              maxLength: 1000,
              style: context.typo.corps,
              decoration: const InputDecoration(
                hintText: 'Ce que la liste ne dit pas',
                counterText: '',
              ),
            ),
          ],
        ),
      ),
      pied: BoutonPrincipal(
          _envoi
              ? 'Envoi…'
              : n == 0
                  ? 'Choisissez au moins un symptôme'
                  : _tranche == null
                      ? 'Dites combien sont malades'
                      : 'Envoyer',
          icone: pret ? Icons.send_rounded : null,
          onPressed: pret ? _envoyer : null),
    );
  }
}

/// Grande tuile de symptome : pictogramme, libelle, coche orange.
class TuileSymptome extends StatelessWidget {
  const TuileSymptome(
      {super.key, required this.libelle, required this.choisie, required this.onTap});
  final String libelle;
  final bool choisie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: choisie,
        button: true,
        label: libelle,
        onTap: onTap,
        excludeSemantics: true,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: choisie ? context.couleurs.marque : context.couleurs.filetLeger, width: choisie ? 2.5 : 1),
          ),
          child: Pressable(
            onTap: onTap,
            rayon: 14,
            ombre: !choisie,
            couleur: choisie ? context.couleurs.fondMarquePale : context.couleurs.surface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 96),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(iconeSymptome(libelle),
                            size: 34, color: context.couleurs.marque),
                        const SizedBox(height: 8),
                        Text(libelle, style: context.typo.corpsFort),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: AnimatedScale(
                      scale: choisie ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                            color: context.couleurs.accent, shape: BoxShape.circle),
                        child: Icon(Icons.check_rounded,
                            size: 18, color: context.couleurs.surAccent),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Tranche d'effectif : quelques points (peu), plus de points (une
/// partie), beaucoup (presque tous), et le libelle chiffre dessous.
class _TuileTranche extends StatelessWidget {
  const _TuileTranche(
      {required this.niveau, required this.libelle, required this.choisie, required this.onTap});
  final int niveau;
  final String libelle;
  final bool choisie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final malades = [1, 3, 6][niveau.clamp(0, 2)];
    return Semantics(
      selected: choisie,
      button: true,
      label: libelle,
      onTap: onTap,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: choisie ? context.couleurs.marque : context.couleurs.filetLeger, width: choisie ? 2.5 : 1),
        ),
        child: Pressable(
          onTap: onTap,
          rayon: 14,
          couleur: choisie ? context.couleurs.fondMarquePale : context.couleurs.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 3,
                  runSpacing: 3,
                  children: [
                    for (var i = 0; i < 8; i++)
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < malades ? context.couleurs.graviteHaute : context.couleurs.sable,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(libelle, textAlign: TextAlign.center, style: context.typo.corpsFort),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 3. Resultat ───────────────────────────────────────────────────────────

class EcranSignalementResultat extends StatelessWidget {
  const EcranSignalementResultat({super.key, required this.signalement, required this.unite});
  final Signalement signalement;
  final Unite unite;

  @override
  Widget build(BuildContext context) {
    final s = signalement;
    final d = s.diagnostic;
    final tranche = tranchesPour(unite)
        .firstWhere((t) => t.$1 == s.trancheEffectif,
            orElse: () => (s.trancheEffectif, L.tranche(s.trancheEffectif)))
        .$2;

    return EcranVivant(
      titre: 'Signalement envoyé',
      sousTitre: unite.estLot
          ? '${unite.code} · ${tranche.toLowerCase()} malades'
          : '${unite.code} · ${_resumeUnite(unite)}',
      bas: const EtapesParcours(etapes: _etapes, courante: 2),
      corps: ListView(
        padding: lisible(context, const EdgeInsets.fromLTRB(Dim.gouttiere, 16, Dim.gouttiere, 24)),
        children: [
          Apparition(child: BandeauDiagnostic(diagnostic: d)),
          const SizedBox(height: 14),
          Apparition(
              rang: 1,
              child: CarteConduite(
                  gravite: d?.gravite ?? d?.probable?.gravite,
                  orientation: d?.orientationRequise ?? true,
                  traitement: d?.orientationRequise == false ? d?.probable?.traitement : null)),
          const SizedBox(height: 14),
          Apparition(
              rang: 2,
              child: BlocVeterinaire(
                  signalementId: s.id,
                  statut: s.statut,
                  veterinaire: d?.veterinaire,
                  diagnostic: d,
                  refus: s.refus)),
          const SizedBox(height: 14),
          Text('Symptômes : ${s.symptomes.map((x) => x.libelle.toLowerCase()).join(', ')}',
              style: context.typo.corpsDiscret),
          const SizedBox(height: 10),
          const _Avertissement(),
        ],
      ),
      pied: Row(
        children: [
          Expanded(
            child: BoutonSecondaire('Accueil',
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst)),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: BoutonPrincipal('Mes signalements',
                onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
                    builder: (_) => const EcranMesSignalements()))),
          ),
        ],
      ),
    );
  }
}

class _Avertissement extends StatelessWidget {
  const _Avertissement();
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: context.couleurs.texteDiscret),
          const SizedBox(width: 8),
          Expanded(
            child: Text("Ce n'est pas un diagnostic. Seul un vétérinaire peut le confirmer.",
                style: context.typo.corpsDiscret),
          ),
        ],
      );
}

/// Bandeau plein de la couleur de la gravite : pictogramme, gravite en un
/// mot, nom de la maladie probable.
class BandeauDiagnostic extends StatelessWidget {
  const BandeauDiagnostic({super.key, required this.diagnostic, this.surtitre = 'Maladie probable'});
  final Diagnostic? diagnostic;
  final String surtitre;

  @override
  Widget build(BuildContext context) {
    final d = diagnostic;
    final m = d?.probable;
    final gravite = d?.gravite ?? m?.gravite;
    final couleur = m == null ? context.couleurs.sante : couleurGravite(context, gravite);
    final encre = encreSur(couleur);
    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: couleur,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: couleur.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(m == null ? Icons.help_rounded : iconeGravite(gravite),
                size: 44, color: encre),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (m == null) ...[
                    Text('Aucune maladie reconnue',
                        style: context.typo.titreSection.copyWith(color: encre)),
                    const SizedBox(height: 4),
                    Text('Un vétérinaire doit examiner vos animaux.',
                        style: context.typo.corps.copyWith(color: encre)),
                  ] else ...[
                    Text('${graviteSimple(gravite).toUpperCase()} · $surtitre',
                        style: context.typo.legendeForte.copyWith(color: encre)),
                    const SizedBox(height: 2),
                    Text(m.nom, style: context.typo.chiffre.copyWith(color: encre)),
                    if (d?.alternative != null) ...[
                      const SizedBox(height: 4),
                      Text('Ou peut-être : ${d!.alternative!.nom}',
                          style: context.typo.corps.copyWith(color: encre)),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// « Que faire maintenant ? » : des phrases courtes, numerotees.
class CarteConduite extends StatelessWidget {
  const CarteConduite(
      {super.key, required this.gravite, required this.orientation, this.traitement});
  final String? gravite;
  final bool orientation;

  /// Traitement de premiere intention, quand le back le donne (maladie
  /// benigne, pas d'orientation).
  final String? traitement;

  @override
  Widget build(BuildContext context) {
    final etapes = conduiteATenir(gravite: gravite, orientation: orientation);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.couleurs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.couleurs.filetLeger),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Que faire maintenant ?', style: context.typo.titreSection),
          const SizedBox(height: 10),
          for (var i = 0; i < etapes.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration:
                        BoxDecoration(color: context.couleurs.fondAccentPale, shape: BoxShape.circle),
                    child: Text('${i + 1}',
                        style: context.typo.corpsFort.copyWith(color: context.couleurs.attentionTexte)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(etapes[i], style: context.typo.corpsFort),
                  )),
                ],
              ),
            ),
          if (traitement != null && traitement!.trim().isNotEmpty) ...[
            const Divider(height: 18),
            Text('Premier soin conseillé', style: context.typo.corpsFort),
            const SizedBox(height: 4),
            Text(traitement!, style: context.typo.corps),
          ],
        ],
      ),
    );
  }
}

/// Le veterinaire du signalement.
///
///  - deja confie : bouton geant « Appeler », et tant que le cas n'est pas
///    ouvert, « Changer de vétérinaire » ;
///  - pas encore confie : TOUS les veterinaires de la zone de l'eleveur qui
///    traitent la maladie, dans un ordre aleatoire tire par le serveur a
///    chaque affichage. L'eleveur touche « Choisir » sur celui qu'il veut.
class BlocVeterinaire extends StatefulWidget {
  const BlocVeterinaire({
    super.key,
    required this.signalementId,
    required this.statut,
    required this.veterinaire,
    this.diagnostic,
    this.proposes,
    this.refus = const [],
  });

  final int signalementId;
  final String statut;
  final VeterinaireResume? veterinaire;
  final Diagnostic? diagnostic;

  /// Les veterinaires qui ont refuse ce cas (V14), le plus recent d'abord.
  final List<RefusCas> refus;

  /// Source de la liste ; par defaut GET /api/signalements/{id}/veterinaires.
  /// Remplacable en test.
  final Future<List<VeterinaireResume>> Function(int id)? proposes;

  @override
  State<BlocVeterinaire> createState() => _BlocVeterinaireState();
}

class _BlocVeterinaireState extends State<BlocVeterinaire> {
  VeterinaireResume? _veterinaire;
  late String _statut;
  bool _changer = false;
  bool _envoi = false;
  Future<List<VeterinaireResume>>? _liste;

  @override
  void initState() {
    super.initState();
    _veterinaire = widget.veterinaire;
    _statut = widget.statut;
    if (_veterinaire == null && _statut != 'TRAITE') _charger();
  }

  void _charger() {
    final source = widget.proposes ?? SignalementApi.veterinairesProposes;
    _liste = source(widget.signalementId);
  }

  Future<void> _choisir(VeterinaireResume v) async {
    final ok = await confirmer(context, 'Confier le cas à ${v.nom} ?',
        message: "Il recevra votre signalement et devra l'accepter. "
            'Vous serez prévenu de sa réponse.',
        confirmer: 'Oui, confier');
    if (!ok || !mounted) return;
    setState(() => _envoi = true);
    try {
      final suivi = await SignalementApi.choisirVeterinaire(widget.signalementId, v.id);
      if (!mounted) return;
      setState(() {
        _veterinaire = suivi.veterinaire ?? v;
        _statut = suivi.signalement.statut;
        _changer = false;
        _envoi = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _envoi = false);
      await afficherErreur(context, e);
      if (mounted) setState(_charger);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _veterinaire;
    if (v != null && !_changer) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // V14 : le veterinaire accepte ou refuse ; l'eleveur sait ou il en est.
          if (_statut == 'ORIENTE' || _statut == 'EN_COURS') ...[
            _EtatReponse(nom: v.nom, accepte: _statut == 'EN_COURS'),
            const SizedBox(height: 10),
          ],
          BoutonAppelGeant(
            libelle: 'Appeler ${v.nom}',
            detail: v.telephone ?? 'Numéro non renseigné',
            onTap: v.telephone == null ? null : () => appeler(context, v.telephone),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => ouvrir<void>(context, EcranFicheVeterinaire(veterinaire: v)),
            child: Text('Voir la fiche du vétérinaire',
                style: context.typo.corpsFort.copyWith(color: context.couleurs.marque)),
          ),
          if (_statut == 'ORIENTE')
            TextButton(
              onPressed: () => setState(() {
                _changer = true;
                _charger();
              }),
              child: Text('Changer de vétérinaire',
                  style: context.typo.corps.copyWith(color: context.couleurs.texteDiscret)),
            ),
        ],
      );
    }
    if (_statut == 'TRAITE') return const SizedBox.shrink();
    return FutureBuilder<List<VeterinaireResume>>(
      future: _liste,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final vets = snap.data ?? const <VeterinaireResume>[];
        final dernierRefus = widget.refus.isEmpty || _changer ? null : widget.refus.first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (dernierRefus != null) ...[
              _BandeauRefus(refus: dernierRefus),
              const SizedBox(height: 12),
            ],
            Text(dernierRefus != null ? 'Choisissez un autre vétérinaire' : 'Choisissez votre vétérinaire',
                style: context.typo.titreSection),
            const SizedBox(height: 4),
            Text(
                snap.hasError
                    ? "La liste n'a pas pu être chargée."
                    : vets.isEmpty
                        ? "Aucun vétérinaire de votre zone ne traite cette maladie pour l'instant. "
                            "L'administration va confier votre cas à un vétérinaire."
                        : 'Les vétérinaires de votre zone qui traitent cette maladie. '
                            "L'ordre change à chaque affichage.",
                style: context.typo.corpsDiscret),
            const SizedBox(height: 10),
            for (final x in vets)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CarteChoix(
                  veterinaire: x,
                  envoi: _envoi,
                  onChoisir: () => _choisir(x),
                ),
              ),
            if (snap.hasError)
              BoutonSecondaire('Réessayer', onPressed: () => setState(_charger)),
            if (_changer)
              TextButton(
                onPressed: () => setState(() => _changer = false),
                child: Text('Garder mon vétérinaire actuel',
                    style: context.typo.corps.copyWith(color: context.couleurs.texteDiscret)),
              ),
            if (vets.isEmpty && !snap.hasError)
              BoutonPrincipal('Voir les vétérinaires de ma zone',
                  icone: Icons.medical_services_outlined,
                  onPressed: () => ouvrir<void>(context, const EcranVeterinaires())),
          ],
        );
      },
    );
  }
}

/// Ou en est la reponse du veterinaire choisi (V14).
class _EtatReponse extends StatelessWidget {
  const _EtatReponse({required this.nom, required this.accepte});
  final String nom;
  final bool accepte;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: accepte ? context.couleurs.fondAccentPale : context.couleurs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.couleurs.filetLeger),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(accepte ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                color: accepte ? context.couleurs.marque : context.couleurs.graviteMoyenne),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(accepte ? '$nom a accepté votre cas' : 'En attente de la réponse de $nom',
                      style: context.typo.corpsFort),
                  const SizedBox(height: 2),
                  Text(
                      accepte
                          ? 'Il vous contactera prochainement.'
                          : "Vous serez prévenu dès qu'il aura accepté ou refusé. "
                              'Vous pouvez aussi l’appeler.',
                      style: context.typo.corpsDiscret),
                ],
              ),
            ),
          ],
        ),
      );
}

/// Le dernier veterinaire choisi a refuse le cas (V14).
class _BandeauRefus extends StatelessWidget {
  const _BandeauRefus({required this.refus});
  final RefusCas refus;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.couleurs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.couleurs.graviteMoyenne),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: context.couleurs.graviteMoyenne),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${refus.veterinaireNom} ne peut pas prendre votre cas',
                      style: context.typo.corpsFort),
                  if (refus.motif != null) ...[
                    const SizedBox(height: 2),
                    Text('« ${refus.motif} »', style: context.typo.corpsDiscret),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}

/// Une ligne de la liste a choisir : nom, specialite, Appeler et Choisir.
class _CarteChoix extends StatelessWidget {
  const _CarteChoix({required this.veterinaire, required this.envoi, required this.onChoisir});
  final VeterinaireResume veterinaire;
  final bool envoi;
  final VoidCallback onChoisir;

  @override
  Widget build(BuildContext context) {
    final v = veterinaire;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.couleurs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.couleurs.filetLeger),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CarteVeterinaire(
            veterinaire: v,
            onTap: () => ouvrir<void>(context, EcranFicheVeterinaire(veterinaire: v)),
            onAppeler: v.telephone == null ? null : () => confirmerAppel(context, v.nom, v.telephone),
          ),
          const SizedBox(height: 8),
          BoutonPrincipal(v.disponible ? 'Choisir ce vétérinaire' : 'Indisponible',
              icone: Icons.check_circle_outline,
              onPressed: (!v.disponible || envoi) ? null : onChoisir),
        ],
      ),
    );
  }
}
