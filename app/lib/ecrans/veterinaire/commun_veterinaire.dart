/// Ce que partagent les ecrans de l'espace veterinaire : chargement de la
/// file des demandes, filieres deduites des competences, langage de tri
/// (liseré de gravite, anciennete coloree), carte de cas avec appel direct.
library;

import 'package:flutter/material.dart';

import '../../api/modeles.dart';
import '../../api/services.dart';
import '../../libelles.dart';
import '../../theme/palette.dart';
import '../../theme/dimensions.dart';
import '../../theme/format.dart';
import '../../widgets/dialogues.dart';
import '../../widgets/etats.dart';
import '../../widgets/pastille.dart';
import '../../widgets/vivant.dart';

/// Onglets de la coquille veterinaire, dans l'ordre de la barre du bas.
abstract final class OngletVeto {
  static const int accueil = 0;
  static const int eleveurs = 1;
  static const int conseils = 2;
  static const int profil = 3;
}

/// Au-dela, la liste s'arrete : 10 pages de 20, soit 200 demandes. Une file
/// d'attente n'en compte jamais autant ; l'historique des cas traites, si,
/// au bout de quelques annees — il faudra alors une pagination a l'ecran.
const int _pagesMax = 10;

/// Une liste de demandes et le nombre total que le back en connait.
typedef Demandes = ({List<Signalement> liste, int total});

/// Toutes les demandes d'un statut, page apres page.
///
/// GET /api/signalements/file?statut=X&page=N, jusqu'a la derniere page.
Future<Demandes> chargerDemandes(String statut) async {
  final liste = <Signalement>[];
  var total = 0;
  for (var page = 0; page < _pagesMax; page++) {
    final p = await SignalementApi.file(statut: statut, page: page);
    liste.addAll(p.elements);
    total = p.total;
    if (p.derniere) break;
  }
  return (liste: liste, total: total);
}

/// « En attente » = orientees (pas encore ouvertes) + prises en charge.
///
/// Deux appels en parallele, fusionnes puis tries : gravite elevee
/// d'abord, puis la plus ancienne — celle qui attend depuis le plus
/// longtemps.
Future<Demandes> chargerEnAttente() async {
  final r = await Future.wait([chargerDemandes('ORIENTE'), chargerDemandes('EN_COURS')]);
  final liste = [...r[0].liste, ...r[1].liste]..sort(_parPriorite);
  return (liste: liste, total: r[0].total + r[1].total);
}

/// Accueil « poste de garde » : la premiere page seulement de chaque statut.
/// Le back trie deja par gravite puis anciennete ; l'accueil n'en montre
/// que quelques-uns, la liste complete est dans l'onglet Éleveurs.
Future<Demandes> chargerEnAttenteRapide() async {
  final r = await Future.wait([
    SignalementApi.file(statut: 'ORIENTE'),
    SignalementApi.file(statut: 'EN_COURS'),
  ]);
  final liste = [...r[0].elements, ...r[1].elements]..sort(_parPriorite);
  return (liste: liste, total: r[0].total + r[1].total);
}

/// Les cas traites, le plus recemment traite en tete.
Future<Demandes> chargerTraites() async {
  final r = await chargerDemandes('TRAITE');
  final liste = [...r.liste]
    ..sort((a, b) => (b.dateTraitement ?? DateTime(0)).compareTo(a.dateTraitement ?? DateTime(0)));
  return (liste: liste, total: r.total);
}

int rangGravite(String? g) => _rangGravite(g);

int _rangGravite(String? g) => switch (g) { 'ELEVE' => 3, 'MOYEN' => 2, _ => 1 };

int _parPriorite(Signalement a, Signalement b) {
  final g = _rangGravite(b.gravite).compareTo(_rangGravite(a.gravite));
  if (g != 0) return g;
  return (a.dateSignalement ?? DateTime(0)).compareTo(b.dateSignalement ?? DateTime(0));
}

/// Les filieres du veterinaire, deduites des maladies qu'il traite.
///
/// Le back ne stocke pas de filieres pour un veterinaire : ce sont ses
/// competences qui disent sur quels animaux il intervient.
List<String> filieresDesCompetences(Iterable<Maladie> competences) =>
    L.trierFilieres({for (final m in competences) ...m.filieres});

/// « LOT #024 · 850 sujets · Bamako » ; pour un animal suivi seul,
/// « BOV-031 · Zébu · Koulikoro ».
String ligneUnite(Signalement s) {
  final n = s.uniteEffectif;
  return [
    if (s.uniteCode != null) s.uniteCode!,
    if (n != null && n > 1) '$n sujets' else if (s.uniteType != null) s.uniteType!,
    if (s.eleveurZone != null) s.eleveurZone!,
  ].join(' · ');
}

/// Intitule en capitales d'une carte de detail : « L'ÉLEVEUR ».
class TitreCarte extends StatelessWidget {
  const TitreCarte(this.texte, {super.key});
  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(texte,
            style: context.typo.legende.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4)),
      );
}

/// Rubrique en capitales entre deux groupes de cartes : « EXERCICE ».
class RubriqueVeto extends StatelessWidget {
  const RubriqueVeto(this.texte, {super.key});
  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Dim.gouttiere, 20, Dim.gouttiere, 8),
        child: Text(texte,
            style: context.typo.legende.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4)),
      );
}

/// Etiquette grise d'un symptome declare.
class PuceSymptome extends StatelessWidget {
  const PuceSymptome(this.libelle, {super.key});
  final String libelle;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: context.couleurs.fond,
          borderRadius: BorderRadius.circular(Dim.rayonPastille),
        ),
        child: Text(libelle, style: context.typo.legendeForte.copyWith(color: context.couleurs.texte)),
      );
}

// ── identite ──────────────────────────────────────────────────────────────

/// « Dr Aminata Sow » : jamais « Docteur vétérinaire Dr Aminata Sow ».
///
/// L'administration saisit parfois le titre long (« Docteur vétérinaire »)
/// ET un nom deja prefixe de « Dr ». Le titre d'appel est toujours « Dr ».
String nomVeto(Profil p) {
  final nom = p.nom.trim();
  if (RegExp(r'^(dr\.?|docteur)\s', caseSensitive: false).hasMatch(nom)) return nom;
  final t = p.titre?.trim() ?? '';
  if (t.isEmpty) return nom;
  final docteur = RegExp(r'^(dr\b|docteur)', caseSensitive: false).hasMatch(t);
  return docteur ? 'Dr $nom' : '$t $nom';
}

// ── langage de tri ────────────────────────────────────────────────────────

/// Couleur du liseré d'un cas (jamais employee seule pour du texte).
/// Gravite elevee : orange leger de la charte ([attention]) au lieu du
/// rouge vif, pour les bandes du tableau de bord (demande du 28/10).
Color couleurGravite(BuildContext context, String? g) => switch (g) {
      'ELEVE' => context.couleurs.attention,
      'MOYEN' => context.couleurs.graviteMoyenne,
      _ => context.couleurs.graviteFaible,
    };

/// Couleur de TEXTE lisible (AA) sur fond clair pour une gravite.
Color encreGravite(BuildContext context, String? g) => switch (g) {
      'ELEVE' => context.couleurs.erreur,
      'MOYEN' => context.couleurs.attentionTexte,
      _ => context.couleurs.graviteFaible,
    };

/// « 35 min », « 3 h », « 2 j » : depuis combien de temps l'eleveur attend.
String ancienneteCourte(DateTime? d, [DateTime? maintenant]) {
  if (d == null) return '—';
  final e = (maintenant ?? DateTime.now()).difference(d);
  if (e.inMinutes < 1) return 'à l’instant';
  if (e.inMinutes < 60) return '${e.inMinutes} min';
  if (e.inHours < 24) return '${e.inHours} h';
  return '${e.inDays} j';
}

/// L'anciennete vire a l'orange puis au rouge : au-dela de 2 h et de 24 h
/// pour un cas eleve, de 24 h et 72 h pour les autres. Couleurs de texte AA.
Color couleurAnciennete(BuildContext context, Signalement s, [DateTime? maintenant]) {
  final d = s.dateSignalement;
  if (d == null || s.traite) return context.couleurs.texteDiscret;
  final h = (maintenant ?? DateTime.now()).difference(d).inHours;
  final (orange, rouge) = s.gravite == 'ELEVE' ? (2, 24) : (24, 72);
  if (h >= rouge) return context.couleurs.erreur;
  if (h >= orange) return context.couleurs.attentionTexte;
  return context.couleurs.texteDiscret;
}

/// « Sujets touchés » n'a de sens que pour un lot : un animal suivi seul
/// porte toujours la tranche « Moins de 10 », forcee par le back.
bool afficherSujetsTouches(Signalement s) => (s.uniteEffectif ?? 2) > 1;

bool aUnNumero(String? n) => n != null && n.trim().isNotEmpty;

/// Rond d'appel de 48 px, a portee de pouce sur une carte de cas.
class BoutonAppelRond extends StatelessWidget {
  const BoutonAppelRond({super.key, required this.nom, required this.numero});
  final String nom;
  final String? numero;

  @override
  Widget build(BuildContext context) {
    final actif = aUnNumero(numero);
    return Tooltip(
      message: actif ? 'Appeler $nom' : 'Numéro non renseigné',
      child: Semantics(
        button: true,
        enabled: actif,
        label: actif ? 'Appeler $nom' : 'Numéro non renseigné',
        excludeSemantics: true,
        child: Material(
          color: actif ? context.couleurs.marque : context.couleurs.sable,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: actif ? () => appeler(context, numero) : null,
            child: SizedBox.square(
              dimension: Dim.hauteurTactile,
              child: Icon(actif ? Icons.call_rounded : Icons.phone_disabled_outlined,
                  color: actif ? context.couleurs.surMarque : context.couleurs.texteDiscret, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

/// Une carte de cas de la file : liseré de gravite a gauche, eleveur,
/// maladie, unite, anciennete coloree, et le bouton d'appel direct.
class CarteCas extends StatelessWidget {
  const CarteCas({super.key, required this.signalement, required this.onTap, this.appel = true});
  final Signalement signalement;
  final VoidCallback onTap;

  /// Montre le rond d'appel (pas pour un cas traite).
  final bool appel;

  @override
  Widget build(BuildContext context) {
    final s = signalement;
    final nom = s.eleveurNom ?? 'Éleveur';
    final etat = s.traite
        ? 'Traité le ${Fmt.date(s.dateTraitement)}'
        : s.statut == 'EN_COURS'
            ? 'Accepté'
            : 'À accepter';
    return Pressable(
      onTap: onTap,
      libelle: [
        nom,
        s.maladie ?? 'Maladie non identifiée',
        L.graviteLongue(s.gravite),
        if (!s.traite) 'attend depuis ${ancienneteCourte(s.dateSignalement)}',
        etat,
      ].join(', '),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 6, color: couleurGravite(context, s.gravite)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(nom,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: context.typo.corpsFort),
                        ),
                        if (!s.traite) ...[
                          Icon(Icons.schedule_rounded, size: 16, color: couleurAnciennete(context, s)),
                          const SizedBox(width: 3),
                          Text(ancienneteCourte(s.dateSignalement),
                              style: context.typo.legendeForte.copyWith(
                                  color: couleurAnciennete(context, s), fontWeight: FontWeight.w800)),
                        ],
                      ]),
                      const SizedBox(height: 2),
                      Text(s.maladie ?? 'Maladie non identifiée',
                          style: context.typo.corps.copyWith(color: encreGravite(context, s.gravite))),
                      Text(ligneUnite(s),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: context.typo.legende),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        if (s.gravite != null)
                          Pastille(L.gravite(s.gravite), ton: L.tonGravite(s.gravite)),
                        Pastille(etat,
                            ton: s.statut == 'ORIENTE' ? TonPastille.marque : TonPastille.neutre),
                        if (s.traite && s.maladieConfirmee != null)
                          Pastille(s.maladieConfirmee!, ton: TonPastille.marque),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
            if (appel && !s.traite)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Center(child: BoutonAppelRond(nom: nom, numero: s.eleveurTelephone)),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(child: Icon(Icons.chevron_right, color: context.couleurs.texteDiscret)),
              ),
          ],
        ),
      ),
    );
  }
}

// ── chargement ────────────────────────────────────────────────────────────

/// Comme `Chargeur`, mais avec un squelette au lieu d'un rond qui tourne,
/// et un [entete] montre aussi pendant le chargement et en cas d'erreur
/// (l'onglet garde son titre, B13).
class ChargeurVeto<T> extends StatefulWidget {
  const ChargeurVeto({
    super.key,
    required this.charger,
    required this.construire,
    this.entete,
    this.squelettes = 3,
  });

  final Future<T> Function() charger;
  final Widget Function(BuildContext context, T donnee, Future<void> Function() recharger)
      construire;
  final Widget? entete;
  final int squelettes;

  @override
  State<ChargeurVeto<T>> createState() => _ChargeurVetoState<T>();
}

class _ChargeurVetoState<T> extends State<ChargeurVeto<T>> {
  late Future<T> _future = widget.charger();

  Future<void> _recharger() async {
    final f = widget.charger();
    if (!mounted) return;
    setState(() {
      _future = f;
    });
    try {
      await f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: _future,
        builder: (context, f) {
          if (f.hasData) return widget.construire(context, f.data as T, _recharger);
          final corps = f.hasError
              ? EtatErreur(erreur: f.error!, onReessayer: _recharger)
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ListeSquelette(nombre: widget.squelettes),
                );
          if (widget.entete == null) return corps;
          return Column(children: [widget.entete!, Expanded(child: corps)]);
        },
      );
}
