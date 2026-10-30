/// « Mes signalements » (audit F3) : l'eleveur retrouve chaque signalement,
/// son statut, le veterinaire a qui il est confie (avec le bouton
/// Appeler), la reponse du veterinaire et la maladie qu'il a confirmee.
///
/// Sources : GET /api/signalements/mes (liste, plus recent d'abord) et
/// GET /api/signalements/{id} (detail).
library;

import 'package:flutter/material.dart';

import '../../../api/modeles.dart';
import '../../../api/services.dart';
import '../../../theme/palette.dart';
import '../../../theme/dimensions.dart';
import '../../../theme/format.dart';
import '../../../theme/typographie.dart';
import '../../../widgets/boutons.dart';
import '../../../widgets/dialogues.dart';
import '../../../widgets/eleveur/ecran_vivant.dart';
import '../../../widgets/etats.dart';
import '../../../widgets/navigation.dart';
import '../../../widgets/pastille.dart';
import '../../../widgets/vivant.dart';
import 'signalement.dart';
import 'vocabulaire_sante.dart';
import '../../../widgets/mise_en_page.dart';

class EcranMesSignalements extends StatelessWidget {
  const EcranMesSignalements({super.key, this.charger = SuiviSignalementApi.mes});

  /// Source de la liste ; remplacable dans les tests.
  final Future<List<SuiviSignalement>> Function() charger;

  @override
  Widget build(BuildContext context) => EcranVivant(
        titre: 'Mes signalements',
        sousTitre: 'Les réponses des vétérinaires',
        corps: ChargeurVivant<List<SuiviSignalement>>(
          charger: charger,
          construire: (context, liste, recharger) => RefreshIndicator(
            onRefresh: recharger,
            color: context.couleurs.marque,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: lisible(context, const EdgeInsets.fromLTRB(Dim.gouttiere, 16, Dim.gouttiere, 32)),
              children: [
                if (liste.isEmpty) ...[
                  const EtatVide('Aucun signalement pour le moment. '
                      'Si un animal est malade, signalez-le : un vétérinaire vous répondra.',
                      icone: Icons.health_and_safety_outlined),
                  BoutonPrincipal('Signaler un animal malade',
                      onPressed: () => ouvrir<void>(context, const EcranSignalementChoix())),
                ],
                for (var i = 0; i < liste.length; i++)
                  Apparition(
                    rang: i,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: CarteSuivi(
                        suivi: liste[i],
                        onTap: () async {
                          await ouvrir<void>(
                              context,
                              EcranDetailSignalement(
                                  signalementId: liste[i].signalement.id,
                                  initial: liste[i]));
                          await recharger();
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

/// Ce que l'on montre de la maladie : confirmee par le veterinaire, sinon
/// probable selon l'application, sinon rien.
(String, String) maladieAffichee(Signalement s) {
  if (s.maladieConfirmee != null && s.maladieConfirmee!.trim().isNotEmpty) {
    return ('Confirmée par le vétérinaire', s.maladieConfirmee!);
  }
  if (s.maladie != null) return ('Maladie probable', s.maladie!);
  return ('Maladie', 'Non identifiée');
}

/// Une ligne de « Mes signalements ».
class CarteSuivi extends StatelessWidget {
  const CarteSuivi({super.key, required this.suivi, required this.onTap});
  final SuiviSignalement suivi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = suivi.signalement;
    final v = suivi.veterinaire;
    final (qualif, maladie) = maladieAffichee(s);
    final gravite = s.gravite;
    return Pressable(
      onTap: onTap,
      rayon: 16,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Liseré de gravite : couleur ET libelle (dans la pastille).
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: s.maladie == null ? context.couleurs.sante : couleurGravite(context, gravite),
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                              [
                                if (s.uniteCode != null) s.uniteCode!,
                                Fmt.signale(s.dateSignalement),
                              ].join(' · '),
                              style: context.typo.legendeForte),
                        ),
                        const SizedBox(width: 8),
                        PastilleStatut(
                            libelle: statutPourEleveur(s.statut),
                            couleur: couleurStatut(context, s.statut)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(qualif, style: context.typo.legende),
                    Text(maladie, style: context.typo.titreSection.copyWith(height: 1.15)),
                    if (s.traite && s.compteRendu != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: context.couleurs.fondMarquePale,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.format_quote_rounded,
                                size: 20, color: context.couleurs.marque),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(s.compteRendu!,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.typo.corps),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (v != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Avatar(Fmt.initiales(v.nom), taille: 36, pale: true),
                          const SizedBox(width: 10),
                          Expanded(child: Text(v.nom, style: context.typo.corpsFort)),
                          if (v.telephone != null)
                            _BoutonAppelRond(
                              nom: v.nom,
                              onTap: () => appeler(context, v.telephone),
                            ),
                        ],
                      ),
                    ] else if (s.statut == 'NOUVEAU') ...[
                      const SizedBox(height: 6),
                      Text('En attente d’un vétérinaire.', style: context.typo.corpsDiscret),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoutonAppelRond extends StatelessWidget {
  const _BoutonAppelRond({required this.nom, required this.onTap});
  final String nom;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Appeler $nom',
        excludeSemantics: true,
        child: Material(
          color: context.couleurs.marque,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox(
                height: 48,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.call_rounded, size: 20, color: context.couleurs.surMarque),
                    const SizedBox(width: 6),
                    Text('Appeler', style: Typo.bouton.copyWith(color: context.couleurs.surMarque)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

// ── detail ────────────────────────────────────────────────────────────────

class EcranDetailSignalement extends StatelessWidget {
  const EcranDetailSignalement({
    super.key,
    required this.signalementId,
    this.initial,
    this.charger,
  });

  final int signalementId;

  /// Deja connu (depuis la liste) : affiche sans attendre, puis actualise.
  final SuiviSignalement? initial;

  /// Source ; par defaut GET /api/signalements/{id}. Remplacable en test.
  final Future<SuiviSignalement> Function(int id)? charger;

  @override
  Widget build(BuildContext context) {
    final source = charger ?? SuiviSignalementApi.detail;
    return EcranVivant(
      titre: 'Mon signalement',
      sousTitre: initial?.signalement.uniteCode,
      corps: ChargeurVivant<SuiviSignalement>(
        charger: () => source(signalementId),
        construire: (context, suivi, recharger) => RefreshIndicator(
          onRefresh: recharger,
          color: context.couleurs.marque,
          child: _Detail(suivi: suivi),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.suivi});
  final SuiviSignalement suivi;

  @override
  Widget build(BuildContext context) {
    final s = suivi.signalement;
    final d = s.diagnostic;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: lisible(context, const EdgeInsets.fromLTRB(Dim.gouttiere, 16, Dim.gouttiere, 32)),
      children: [
        Text(
            [
              if (s.uniteCode != null) s.uniteCode!,
              if (s.uniteType != null) s.uniteType!,
              Fmt.signale(s.dateSignalement),
            ].join(' · '),
            style: context.typo.legendeForte),
        const SizedBox(height: 12),
        _Suivi(statut: s.statut),
        const SizedBox(height: 16),
        if (s.traite) ...[
          _Reponse(signalement: s),
          const SizedBox(height: 16),
        ],
        BandeauDiagnostic(
            diagnostic: d,
            surtitre: s.traite ? "proposée par l'application" : 'Maladie probable'),
        const SizedBox(height: 14),
        if (!s.traite) ...[
          CarteConduite(
              gravite: d?.gravite ?? d?.probable?.gravite,
              orientation: d?.orientationRequise ?? true,
              traitement: d?.orientationRequise == false ? d?.probable?.traitement : null),
          const SizedBox(height: 14),
        ],
        BlocVeterinaire(
            signalementId: s.id,
            statut: s.statut,
            veterinaire: suivi.veterinaire,
            diagnostic: d,
            refus: s.refus),
        const SizedBox(height: 18),
        Text('Ce que vous avez vu', style: context.typo.titreSection),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final x in s.symptomes)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: context.couleurs.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.couleurs.filetLeger),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(iconeSymptome(x.libelle), size: 20, color: context.couleurs.marque),
                    const SizedBox(width: 6),
                    Text(x.libelle, style: context.typo.corps),
                  ],
                ),
              ),
          ],
        ),
        if (s.precision != null && s.precision!.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('« ${s.precision!.trim()} »', style: context.typo.corpsDiscret),
        ],
      ],
    );
  }
}

/// Les quatre etapes du suivi, la courante en orange.
class _Suivi extends StatelessWidget {
  const _Suivi({required this.statut});
  final String statut;

  static const _etapes = [
    ('NOUVEAU', 'Envoyé'),
    ('ORIENTE', 'Confié'),
    ('EN_COURS', 'Accepté'),
    ('TRAITE', 'Réponse'),
  ];

  @override
  Widget build(BuildContext context) {
    final rang = rangStatut(statut);
    return Semantics(
      label: 'Suivi : ${statutPourEleveur(statut)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
        decoration: BoxDecoration(
          color: context.couleurs.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < _etapes.length; i++)
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                              height: 3,
                              color: i == 0
                                  ? Colors.transparent
                                  : (i <= rang ? context.couleurs.marque : context.couleurs.sable)),
                        ),
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == rang
                                ? context.couleurs.accent
                                : (i < rang ? context.couleurs.marque : context.couleurs.sable),
                          ),
                          child: i < rang
                              ? Icon(Icons.check_rounded,
                                  size: 16, color: context.couleurs.surMarque)
                              : null,
                        ),
                        Expanded(
                          child: Container(
                              height: 3,
                              color: i == _etapes.length - 1
                                  ? Colors.transparent
                                  : (i < rang ? context.couleurs.marque : context.couleurs.sable)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(_etapes[i].$2,
                        textAlign: TextAlign.center,
                        style: i == rang
                            ? context.typo.legendeForte.copyWith(color: context.couleurs.texte)
                            : context.typo.legende),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// La reponse du veterinaire : maladie confirmee et compte rendu.
class _Reponse extends StatelessWidget {
  const _Reponse({required this.signalement});
  final Signalement signalement;

  @override
  Widget build(BuildContext context) {
    final s = signalement;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.couleurs.fondMarquePale,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: context.couleurs.marque, width: 5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.medical_services_rounded, color: context.couleurs.marque),
              const SizedBox(width: 8),
              Expanded(child: Text('Réponse du vétérinaire', style: context.typo.titreSection)),
              if (s.dateTraitement != null) Text(Fmt.dateCourte(s.dateTraitement), style: context.typo.legende),
            ],
          ),
          const SizedBox(height: 10),
          if (s.maladieConfirmee != null && s.maladieConfirmee!.trim().isNotEmpty) ...[
            Text('Maladie confirmée', style: context.typo.legende),
            Text(s.maladieConfirmee!, style: context.typo.chiffre.copyWith(fontSize: 24)),
            const SizedBox(height: 10),
          ] else ...[
            Text('Le vétérinaire n’a pas confirmé de maladie.', style: context.typo.corpsDiscret),
            const SizedBox(height: 8),
          ],
          Text(s.compteRendu ?? 'Pas de compte rendu.', style: context.typo.corps.copyWith(height: 1.45)),
        ],
      ),
    );
  }
}
