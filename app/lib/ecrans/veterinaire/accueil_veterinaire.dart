/// Maquette : « Veto - Accueil », refondue en « poste de garde » : les cas
/// urgents d'emblée, la disponibilité à portée de pouce, la cloche.
///
/// Sources, en parallèle : GET /api/veterinaires/accueil (compteurs),
/// GET /api/auth/moi (nom, disponibilité), GET /api/veterinaires/competences
/// (filières), GET /api/signalements/file (première page des cas en attente
/// et total des traités), GET /api/notifications/non-lues (badge).
library;

import 'package:flutter/material.dart';

import '../../api/modeles.dart';
import '../../api/services.dart';
import '../../libelles.dart';
import '../../theme/palette.dart';
import '../../theme/dimensions.dart';
import '../../widgets/navigation.dart';
import '../../widgets/pastille.dart';
import '../../widgets/vivant.dart';
import 'commun_veterinaire.dart';
import 'demandes.dart';
import 'disponibilite.dart';
import 'notifications_veterinaire.dart';
import '../../widgets/mise_en_page.dart';

/// Cas montrés sous « Cas urgents ». La file complète est dans Éleveurs.
const int _casMontres = 3;

typedef _Donnees = ({
  AccueilVeterinaire compteurs,
  Profil profil,
  List<Maladie> competences,
  Demandes attente,
  int traitesTotal,
  int nonLues,
});

class TableauDeBordVeterinaire extends StatelessWidget {
  const TableauDeBordVeterinaire({super.key, required this.versOnglet, this.versTraites});
  final ValueChanged<int> versOnglet;

  /// Ouvre l'onglet Éleveurs sur « Traités ».
  final VoidCallback? versTraites;

  static Future<int> _nonLues() async {
    try {
      return await VeterinaireGardeApi.notificationsNonLues();
    } catch (_) {
      return 0; // le badge n'empeche pas l'accueil de s'afficher
    }
  }

  static Future<_Donnees> _charger() async {
    // Future.wait et non `(a, b).wait` : ce dernier enveloppe l'erreur dans
    // une ParallelWaitError, et l'ecran perdrait le message du back.
    final r = await Future.wait<Object>([
      VeterinaireApi.accueil(),
      AuthApi.moi(),
      VeterinaireApi.competences(),
      chargerEnAttenteRapide(),
      SignalementApi.file(statut: 'TRAITE'),
      _nonLues(),
    ]);
    return (
      compteurs: r[0] as AccueilVeterinaire,
      profil: r[1] as Profil,
      competences: r[2] as List<Maladie>,
      attente: r[3] as Demandes,
      traitesTotal: (r[4] as PageApi<Signalement>).total,
      nonLues: r[5] as int,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChargeurVeto<_Donnees>(
      entete: EnteteVivant(
        sombre: true,
        grand: true,
        surtitre: '${salutation()},',
        titre: 'Poste de garde',
      ),
      charger: _charger,
      construire: (context, d, recharger) {
        final c = d.compteurs;
        final p = d.profil;
        final filieres = filieresDesCompetences(d.competences);
        final urgents = d.attente.liste.take(_casMontres).toList();
        Future<void> ouvrirNotifications() async {
          await ouvrir<void>(context, const EcranNotificationsVeto());
          await recharger();
        }

        return Column(
          children: [
            EnteteVivant(
              sombre: true,
              grand: true,
              surtitre: '${salutation()},',
              titre: nomVeto(p),
              sousTitre: (p.zoneIntervention ?? p.zone)?.nom,
              aDroite: BoutonEntete(
                icone: Icons.notifications_none_rounded,
                libelle: 'Notifications',
                badge: d.nonLues,
                onTap: ouvrirNotifications,
              ),
              bas: InterrupteurDisponibilite(disponible: p.disponible ?? true),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: recharger,
                color: context.couleurs.marque,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: lisible(context, const EdgeInsets.only(top: 4, bottom: 24)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Dim.gouttiere),
                      child: Apparition(
                        child: CarteTri(
                          enAttente: c.enAttente,
                          cas: d.attente.liste,
                          onTap: () => versOnglet(OngletVeto.eleveurs),
                        ),
                      ),
                    ),
                    TitreSectionVivant(
                      urgents.isEmpty ? 'Cas urgents' : 'À traiter en premier',
                      action: d.attente.total > _casMontres ? 'Tout voir' : null,
                      onAction: () => versOnglet(OngletVeto.eleveurs),
                    ),
                    if (urgents.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: Dim.gouttiere),
                        child: _Calme(),
                      ),
                    for (var i = 0; i < urgents.length; i++)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            Dim.gouttiere, 0, Dim.gouttiere, Dim.ecart),
                        child: Apparition(
                          rang: i + 1,
                          child: CarteCas(
                            signalement: urgents[i],
                            onTap: () => ouvrirDemande(context, urgents[i],
                                recharger: recharger, versOnglet: versOnglet),
                          ),
                        ),
                      ),
                    const TitreSectionVivant('Votre activité'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Dim.gouttiere),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _Tuile(
                              icone: Icons.task_alt_rounded,
                              valeur: c.traitesCeMois,
                              libelle: 'traité${c.traitesCeMois > 1 ? 's' : ''} ce mois',
                              detail: '${d.traitesTotal} au total',
                              onTap: versTraites ?? () => versOnglet(OngletVeto.eleveurs),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _Tuile(
                              icone: Icons.menu_book_rounded,
                              valeur: c.conseilsPublies,
                              libelle: c.conseilsPublies > 1 ? 'conseils publiés' : 'conseil publié',
                              detail: c.conseilsEnModeration > 0
                                  ? '${c.conseilsEnModeration} en modération'
                                  : 'Partagez votre savoir',
                              onTap: () => versOnglet(OngletVeto.conseils),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const TitreSectionVivant('Vos filières'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Dim.gouttiere),
                      child: filieres.isEmpty
                          ? Text(
                              'Déclarez les maladies que vous traitez depuis Profil : '
                              'vos filières en découlent.',
                              style: context.typo.corpsDiscret)
                          : Wrap(spacing: 10, runSpacing: 8, children: [
                              for (final f in filieres)
                                Pastille(L.filiere(f), ton: TonPastille.marque),
                            ]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// La carte de tri : le nombre en attente, et une barre empilée
/// Élevé / Moyen / Faible.
class CarteTri extends StatelessWidget {
  const CarteTri({super.key, required this.enAttente, required this.cas, required this.onTap});
  final int enAttente;
  final List<Signalement> cas;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    int nb(String g) => cas.where((s) => (s.gravite ?? 'FAIBLE') == g).length;
    final parts = [
      ('ELEVE', nb('ELEVE')),
      ('MOYEN', nb('MOYEN')),
      ('FAIBLE', nb('FAIBLE')),
    ];
    final total = parts.fold<int>(0, (a, p) => a + p.$2);
    return Pressable(
      onTap: onTap,
      libelle: '$enAttente cas en attente. '
          '${parts.map((p) => '${p.$2} ${L.gravite(p.$1).toLowerCase()}').join(', ')}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CompteurAnime(valeur: enAttente, style: context.typo.chiffreHeros),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        enAttente > 1 ? 'éleveurs vous attendent' : 'éleveur vous attend',
                        style: context.typo.corpsFort,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: context.couleurs.marque),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 12,
                  child: total == 0
                      ? Container(color: context.couleurs.sable)
                      : Row(children: [
                          for (final (g, n) in parts)
                            if (n > 0)
                              Expanded(flex: n, child: Container(color: couleurGravite(context, g))),
                        ]),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  for (final (g, n) in parts)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration:
                            BoxDecoration(color: couleurGravite(context, g), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      Text('$n ${L.gravite(g).toLowerCase()}',
                          style: context.typo.legendeForte.copyWith(color: context.couleurs.texte)),
                    ]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aucun cas en attente.
class _Calme extends StatelessWidget {
  const _Calme();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: context.couleurs.fondMarquePale, borderRadius: BorderRadius.circular(Dim.rayon)),
        child: Row(children: [
          Icon(Icons.spa_outlined, color: context.couleurs.marque),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Aucun cas en attente. Les nouveaux signalements arrivent ici.',
                style: context.typo.corps),
          ),
        ]),
      );
}

/// Tuile : pictogramme, chiffre anime, ce qu'il compte, une precision.
class _Tuile extends StatelessWidget {
  const _Tuile({
    required this.icone,
    required this.valeur,
    required this.libelle,
    required this.detail,
    required this.onTap,
  });
  final IconData icone;
  final int valeur;
  final String libelle;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        libelle: '$valeur $libelle, $detail',
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icone, color: context.couleurs.marque, size: 22),
                const SizedBox(height: 6),
                CompteurAnime(valeur: valeur, style: context.typo.chiffre),
                Text(libelle, style: context.typo.corpsFort.copyWith(fontSize: 15)),
                Text(detail, style: context.typo.legende),
              ],
            ),
          ),
        ),
      );
}
