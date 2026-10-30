/// Maquettes : « Veto - Profil », « Veto - Competences » et sa pop-up
/// « Enregistre ».
///
/// Sources : GET /api/auth/moi, GET /api/veterinaires/competences,
/// GET /api/signalements/maladies-catalogue, POST et DELETE
/// /api/veterinaires/competences/{maladieId}.
library;

import 'package:flutter/material.dart';

import '../../api/client_api.dart';
import '../../api/modeles.dart';
import '../../api/services.dart';
import '../../libelles.dart';
import '../../theme/palette.dart';
import '../../theme/dimensions.dart';
import '../../theme/format.dart';
import '../../widgets/choix_apparence.dart';
import '../../widgets/boutons.dart';
import '../../widgets/carte.dart';
import '../../widgets/dialogues.dart';
import '../../widgets/echafaudage.dart';
import '../../widgets/entete.dart';
import '../../widgets/etats.dart';
import '../../widgets/formulaires.dart';
import '../../widgets/navigation.dart';
import '../../widgets/pastille.dart';
import '../auth/connexion.dart';
import '../auth/mot_de_passe_impose.dart';
import 'commun_veterinaire.dart';
import 'disponibilite.dart';
import 'notifications_veterinaire.dart';
import 'nouvelle_maladie.dart';
import '../../widgets/mise_en_page.dart';

/// « +223 76 11 22 33 · Koutiala » : telephone et zone d'intervention.
String _coordonnees(Profil p) => [
      if (p.telephone != null) p.telephone!,
      if ((p.zoneIntervention ?? p.zone) != null) (p.zoneIntervention ?? p.zone)!.nom,
    ].join(' · ');

// ── profil ────────────────────────────────────────────────────────────────

class ProfilVeterinaire extends StatelessWidget {
  const ProfilVeterinaire({super.key});

  static Future<(Profil, List<Maladie>)> _charger() async {
    final r = await Future.wait<Object>([AuthApi.moi(), VeterinaireApi.competences()]);
    return (r[0] as Profil, r[1] as List<Maladie>);
  }

  Future<void> _deconnecter(BuildContext context) async {
    await ClientApi.instance.deconnecter();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
            builder: (_) => const EcranConnexion(espace: EspaceConnexion.veterinaire)),
        (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    const entete = EnteteClair(titre: 'Profil');
    return ChargeurVeto<(Profil, List<Maladie>)>(
      entete: entete,
      charger: _charger,
      construire: (context, d, recharger) {
        final (p, competences) = d;
        final filieres = filieresDesCompetences(competences);
        final n = competences.length;
        return Column(children: [
          entete,
          Expanded(
              child: ListView(
            padding: lisible(context, const EdgeInsets.only(top: 8, bottom: 24)),
            children: [
              Gouttiere(
                enfant: Carte(
                  enfant: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Avatar(Fmt.initiales(p.nom), taille: 52, pale: true),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(nomVeto(p), style: context.typo.titreSection),
                                Text(_coordonnees(p), style: context.typo.legende),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (filieres.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, runSpacing: 6, children: [
                          for (final f in filieres) Pastille(L.filiere(f), ton: TonPastille.marque),
                        ]),
                      ],
                    ],
                  ),
                ),
              ),
              const RubriqueVeto('GARDE'),
              Gouttiere(
                enfant: InterrupteurDisponibilite(disponible: p.disponible ?? true, surFond: false),
              ),
              const RubriqueVeto('EXERCICE'),
              _Groupe(entrees: [
                _Entree(
                  icone: Icons.health_and_safety_outlined,
                  titre: 'Maladies que je traite',
                  detail: '$n compétence${n > 1 ? 's' : ''}',
                  onTap: () async {
                    await ouvrir<void>(context, const EcranCompetences());
                    await recharger();
                  },
                ),
                // Fixee par l'administration : affichee, pas modifiable.
                _Entree(
                  icone: Icons.place_outlined,
                  titre: "Zone d'intervention",
                  detail: (p.zoneIntervention ?? p.zone)?.nom ?? 'Non renseignée',
                ),
              ]),
              const RubriqueVeto('PARAMÈTRES'),
              _Groupe(entrees: [
                _Entree(
                  icone: Icons.notifications_none,
                  titre: 'Notifications',
                  detail: 'Nouveaux cas, conseils relus',
                  onTap: () => ouvrir<void>(context, const EcranNotificationsVeto()),
                ),
                _Entree(
                  icone: Icons.lock_outline,
                  titre: 'Changer mon mot de passe',
                  onTap: () => ouvrir<void>(context, const EcranChangerMotDePasse()),
                ),
              ]),
              const SizedBox(height: 12),
              const Gouttiere(enfant: ChoixApparence()),
              const SizedBox(height: 24),
              Gouttiere(
                enfant: BoutonDestructif('Se déconnecter', onPressed: () => _deconnecter(context)),
              ),
            ],
          )),
        ]);
      },
    );
  }
}

/// Plusieurs entrees dans une seule carte, comme la maquette.
class _Groupe extends StatelessWidget {
  const _Groupe({required this.entrees});
  final List<_Entree> entrees;

  @override
  Widget build(BuildContext context) => Gouttiere(
        enfant: Carte(
          padding: const EdgeInsets.symmetric(vertical: 4),
          enfant: Column(children: entrees),
        ),
      );
}

class _Entree extends StatelessWidget {
  const _Entree({required this.icone, required this.titre, this.detail, this.onTap});
  final IconData icone;
  final String titre;
  final String? detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ligne = Padding(
      padding: const EdgeInsets.fromLTRB(Dim.padCarte + 2, 10, 10, 10),
      child: Row(
        children: [
          Icon(icone, color: context.couleurs.marque, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre, style: context.typo.corpsFort),
                if (detail != null) Text(detail!, style: context.typo.legende),
              ],
            ),
          ),
          if (onTap != null) Icon(Icons.chevron_right, color: context.couleurs.texteDiscret),
        ],
      ),
    );
    final haute = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: Dim.hauteurTactile),
      child: ligne,
    );
    if (onTap == null) return haute;
    return InkWell(onTap: onTap, child: haute);
  }
}

// ── competences ───────────────────────────────────────────────────────────

class EcranCompetences extends StatelessWidget {
  const EcranCompetences({super.key});

  static Future<(Profil, List<Maladie>, List<Maladie>)> _charger() async {
    final r = await Future.wait<Object>([
      AuthApi.moi(),
      SignalementApi.catalogueComplet(),
      VeterinaireApi.competences(),
    ]);
    return (r[0] as Profil, r[1] as List<Maladie>, r[2] as List<Maladie>);
  }

  @override
  Widget build(BuildContext context) => Chargeur<(Profil, List<Maladie>, List<Maladie>)>(
        titreEcran: 'Mes compétences',
        clair: true,
        charger: _charger,
        construire: (context, d, recharger) {
          final (profil, catalogue, competences) = d;
          return _FormulaireCompetences(
            // Nouvelle cle apres l'ajout d'une maladie : l'etat repart des
            // competences rechargees (la nouvelle maladie y est cochee).
            key: ValueKey('${catalogue.length}-${competences.length}'),
            profil: profil,
            catalogue: catalogue,
            initiales: {for (final m in competences) m.id},
            recharger: recharger,
          );
        },
      );
}

class _FormulaireCompetences extends StatefulWidget {
  const _FormulaireCompetences(
      {super.key,
      required this.profil,
      required this.catalogue,
      required this.initiales,
      required this.recharger});
  final Profil profil;
  final Future<void> Function() recharger;
  final List<Maladie> catalogue;

  /// Identifiants des maladies deja declarees au chargement.
  final Set<int> initiales;

  @override
  State<_FormulaireCompetences> createState() => _FormulaireCompetencesState();
}

class _FormulaireCompetencesState extends State<_FormulaireCompetences> {
  late final Set<int> _cochees = {...widget.initiales};
  bool _envoi = false;

  bool get _modifie =>
      _cochees.length != widget.initiales.length || !_cochees.containsAll(widget.initiales);

  /// Une requete par maladie ajoutee ou retiree : le back ne prend pas la
  /// liste entiere (voir VeterinaireControleur), pour qu'une declaration
  /// faite ailleurs entre-temps ne soit pas ecrasee.
  Future<void> _enregistrer() async {
    setState(() => _envoi = true);
    try {
      for (final id in _cochees.difference(widget.initiales)) {
        try {
          await VeterinaireApi.declarerCompetence(id);
        } on ApiException catch (e) {
          // 409 : deja declaree (double envoi, autre appareil). C'est l'etat
          // voulu.
          if (e.statut != 409) rethrow;
        }
      }
      for (final id in widget.initiales.difference(_cochees)) {
        await VeterinaireApi.retirerCompetence(id);
      }
      if (!mounted) return;
      await afficherInfo(context, 'Compétences mises à jour',
          message: 'Les éleveurs de votre zone signalant une de vos maladies pourront vous choisir.',
          bouton: 'Terminer');
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) await afficherErreur(context, e);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profil;
    return EcranSecondaire(
      titre: 'Mes compétences',
      clair: true,
      corps: ListView(
        padding: lisible(context, const EdgeInsets.fromLTRB(Dim.gouttiere, 8, Dim.gouttiere, 24)),
        children: [
          Carte(
            enfant: Row(
              children: [
                Avatar(Fmt.initiales(p.nom), taille: 60, pale: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nomVeto(p), style: context.typo.corpsFort.copyWith(fontSize: 18)),
                      if (p.telephone != null) Text(p.telephone!, style: context.typo.corpsDiscret),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Lecture seule : la zone d'intervention est fixee par
          // l'administration.
          BlocChamp(
            libelle: "Zone d'intervention",
            champ: Container(
              constraints: const BoxConstraints(minHeight: Dim.hauteurTactile),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: context.couleurs.surface,
                borderRadius: BorderRadius.circular(Dim.rayon),
                border: Border.all(color: context.couleurs.filet, width: Dim.filet),
              ),
              child:
                  Text((p.zoneIntervention ?? p.zone)?.nom ?? 'Non renseignée', style: context.typo.corps),
            ),
          ),
          const LibelleChamp('Maladies que vous traitez'),
          Carte(
            padding: const EdgeInsets.symmetric(vertical: 4),
            enfant: Column(
              children: [
                if (widget.catalogue.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(Dim.padCarte),
                    child: Text('Le catalogue des maladies est vide.', style: context.typo.corpsDiscret),
                  ),
                for (final m in widget.catalogue)
                  CheckboxListTile(
                    value: _cochees.contains(m.id),
                    onChanged: _envoi
                        ? null
                        : (v) => setState(() {
                              if (v == true) {
                                _cochees.add(m.id);
                              } else {
                                _cochees.remove(m.id);
                              }
                            }),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: context.couleurs.marque,
                    side: BorderSide(color: context.couleurs.marque, width: 1.5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                    title: Text(m.nom, style: context.typo.corpsFort),
                    subtitle: Text(L.trierFilieres(m.filieres).map(L.filiere).join(' · '),
                        style: context.typo.legende),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          BoutonSecondaire('Ajouter une maladie au catalogue',
              icone: Icons.add,
              onPressed: _envoi
                  ? null
                  : () async {
                      final ajoutee = await ouvrir<bool>(context, const EcranNouvelleMaladie());
                      if (ajoutee == true) await widget.recharger();
                    }),
          const Note('Les éleveurs de votre zone signalant ces maladies pourront vous choisir.'),
        ],
      ),
      pied: BoutonPrincipal(_envoi ? 'Enregistrement…' : 'Enregistrer',
          onPressed: (_envoi || !_modifie) ? null : _enregistrer),
    );
  }
}
