/// Onglet Santé de l'eleveur.
///
/// En haut, l'action qui compte : « Un animal est malade ? ». Puis le
/// dernier signalement et sa reponse, les acces (Mes signalements,
/// Vétérinaires, Maladies, Conseils) et les soins a faire bientot.
///
/// Sources : GET /api/sanitaire/rappels?horizonJours=30 et
/// GET /api/signalements/mes. Si la seconde echoue (back plus ancien), la
/// page s'affiche sans le dernier signalement.
library;

import 'package:flutter/material.dart';

import '../../../api/client_api.dart';
import '../../../api/modeles.dart';
import '../../../api/services.dart';
import '../../../theme/palette.dart';
import '../../../theme/dimensions.dart';
import '../../../theme/format.dart';
import '../../../widgets/dialogues.dart';
import '../../../widgets/echafaudage.dart';
import '../../../widgets/eleveur/ecran_vivant.dart';
import '../../../widgets/navigation.dart';
import '../../../widgets/vivant.dart';
import '../animaux/carnet.dart';
import '../conseils/conseils.dart';
import 'maladies.dart';
import 'mes_signalements.dart';
import 'signalement.dart';
import 'veterinaires.dart';
import '../../../widgets/mise_en_page.dart';

typedef _Donnees = ({List<Rappel> rappels, List<SuiviSignalement>? signalements});

class SanteAccueil extends StatelessWidget {
  const SanteAccueil({super.key});

  static Future<_Donnees> _charger() async {
    final r = await Future.wait<Object?>([
      SanitaireApi.rappels(horizonJours: 30),
      SuiviSignalementApi.mes().then<List<SuiviSignalement>?>((l) => l,
          onError: (Object _) => null),
    ]);
    return (rappels: r[0] as List<Rappel>, signalements: r[1] as List<SuiviSignalement>?);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const EnteteVivant(titre: 'Santé', sousTitre: 'Vos animaux et le vétérinaire'),
        Expanded(
          child: ChargeurVivant<_Donnees>(
            charger: _charger,
            construire: (context, d, recharger) {
              Future<void> puisRecharger(Widget ecran) async {
                await ouvrir<void>(context, ecran);
                await recharger();
              }

              final signalements = d.signalements ?? const <SuiviSignalement>[];
              final enCours = signalements.where((x) => !x.signalement.traite).length;
              return RefreshIndicator(
                onRefresh: recharger,
                color: context.couleurs.marque,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: lisible(context, const EdgeInsets.only(top: 8, bottom: 24)),
                  children: [
                    Apparition(
                      child: Gouttiere(
                        enfant: _CarteMalade(
                            onTap: () => puisRecharger(const EcranSignalementChoix())),
                      ),
                    ),
                    if (signalements.isNotEmpty) ...[
                      TitreSectionVivant('Dernier signalement',
                          action: 'Tout voir',
                          onAction: () => puisRecharger(const EcranMesSignalements())),
                      Apparition(
                        rang: 1,
                        child: Gouttiere(
                          enfant: CarteSuivi(
                            suivi: signalements.first,
                            onTap: () => puisRecharger(EcranDetailSignalement(
                                signalementId: signalements.first.signalement.id,
                                initial: signalements.first)),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Apparition(
                      rang: 2,
                      child: Gouttiere(
                        // 2 colonnes sur telephone, 4 sur tablette.
                        enfant: GrilleTuiles(
                          ecart: 10,
                          children: [
                            TuilePicto(
                              icone: Icons.assignment_outlined,
                              libelle: 'Mes signalements',
                              detail: enCours > 0 ? '$enCours en cours' : 'Les réponses',
                              badge: enCours,
                              onTap: () => puisRecharger(const EcranMesSignalements()),
                            ),
                            TuilePicto(
                              icone: Icons.medical_services_outlined,
                              libelle: 'Vétérinaires',
                              detail: 'Appeler',
                              teinte: context.couleurs.sante,
                              fondIcone: context.couleurs.fondMarquePale,
                              onTap: () => puisRecharger(const EcranVeterinaires()),
                            ),
                            TuilePicto(
                              icone: Icons.coronavirus_outlined,
                              libelle: 'Maladies',
                              detail: 'Les reconnaître',
                              teinte: context.couleurs.attentionTexte,
                              fondIcone: context.couleurs.fondAccentPale,
                              onTap: () =>
                                puisRecharger(const EcranCatalogueMaladies()),
                            ),
                            TuilePicto(
                              icone: Icons.lightbulb_outline_rounded,
                              libelle: 'Conseils',
                              detail: 'Des vétérinaires',
                              onTap: () => puisRecharger(const EcranConseils()),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const TitreSectionVivant('À faire bientôt'),
                    if (d.rappels.isEmpty)
                      Gouttiere(
                        enfant: Row(
                          children: [
                            Icon(Icons.event_available_rounded,
                                color: context.couleurs.graviteFaible, size: 28),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text('Aucun soin prévu ce mois-ci.',
                                  style: context.typo.corpsDiscret),
                            ),
                          ],
                        ),
                      )
                    else
                      for (var i = 0; i < d.rappels.length; i++)
                        Apparition(
                          rang: 3 + i,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                                Dim.gouttiere, 0, Dim.gouttiere, 10),
                            child: _LigneRappel(
                              rappel: d.rappels[i],
                              onTap: () => _surRappel(context, d.rappels[i], recharger),
                            ),
                          ),
                        ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _surRappel(
      BuildContext context, Rappel r, Future<void> Function() recharger) async {
    final voir = await choisirSuite(
      context,
      r.libelle,
      message: [if (r.uniteCode != null) r.uniteCode!, Fmt.date(r.dateEcheance)].join(' — '),
      premier: 'Ouvrir le carnet',
      second: 'Ignorer ce rappel',
    );
    if (!context.mounted || voir == null) return;
    if (voir) {
      if (r.uniteId != null) {
        await ouvrir<void>(context, EcranCarnet(uniteId: r.uniteId!));
      }
    } else {
      try {
        await SanitaireApi.ignorerRappel(r.id);
      } on ApiException catch (e) {
        if (context.mounted) await afficherErreur(context, e);
      }
    }
    await recharger();
  }
}

/// La grande carte « Un animal est malade ? » : vert profond, rond orange.
class _CarteMalade extends StatelessWidget {
  const _CarteMalade({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        rayon: 20,
        couleur: context.couleurs.fondFonce,
        libelle: 'Un animal est malade ? Signaler les symptômes',
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration:
                        BoxDecoration(color: context.couleurs.accent, shape: BoxShape.circle),
                    child: Icon(Icons.sick_outlined, size: 36, color: context.couleurs.surAccent),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Un animal est malade ?',
                            style: context.typo.titreSection.copyWith(color: context.couleurs.surEntete)),
                        const SizedBox(height: 2),
                        Text('Dites ce que vous voyez',
                            style: context.typo.corps.copyWith(color: context.couleurs.surMarqueDiscret)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, color: context.couleurs.surEntete, size: 28),
                ],
              ),
            ),
          ],
        ),
      );
}

/// Rappel : la date en gros dans un carre, le soin, l'elevage et le delai.
class _LigneRappel extends StatelessWidget {
  const _LigneRappel({required this.rappel, required this.onTap});
  final Rappel rappel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = rappel;
    final retard = r.joursRestants < 0;
    final proche = r.joursRestants <= 2;
    final couleur = retard
        ? context.couleurs.graviteHaute
        : proche
            ? context.couleurs.attentionTexte
            : context.couleurs.marque;
    final d = r.dateEcheance;
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: couleur.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(d == null ? '—' : '${d.day}',
                      style: context.typo.chiffre.copyWith(color: couleur, fontSize: 24, height: 1)),
                  Text(d == null ? '' : Fmt.dateCourte(d).split(' ').last,
                      style: context.typo.legendeForte.copyWith(color: couleur)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.libelle, style: context.typo.corpsFort),
                  Text(
                    [if (r.uniteCode != null) r.uniteCode!, Fmt.echeance(r.joursRestants)]
                        .join(' · '),
                    style: context.typo.corpsDiscret.copyWith(color: retard ? couleur : null),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.couleurs.texteDiscret),
          ],
        ),
      ),
    );
  }
}
