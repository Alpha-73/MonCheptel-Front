/// Maquette : « Profil - Accueil », sa pop-up « Deconnexion » et « Langue -
/// Francais ».
///
/// Source : GET /api/auth/moi.
library;

import 'package:flutter/material.dart';

import '../../../api/client_api.dart';
import '../../../api/modeles.dart';
import '../../../api/services.dart';
import '../../../libelles.dart';
import '../../../theme/palette.dart';
import '../../../theme/dimensions.dart';
import '../../../theme/format.dart';
import '../../../theme/typographie.dart';
import '../../../widgets/boutons.dart';
import '../../../widgets/carte.dart';
import '../../../widgets/choix_apparence.dart';
import '../../../widgets/dialogues.dart';
import '../../../widgets/eleveur/ecran_vivant.dart';
import '../../../widgets/navigation.dart';
import '../../../widgets/pastille.dart';
import '../../../widgets/vivant.dart';
import '../sante/mes_signalements.dart';
import '../sante/vocabulaire_sante.dart';
import '../../auth/connexion.dart';
import '../../auth/mot_de_passe_impose.dart';
import '../finances/operations.dart';
import '../finances/rapports.dart';
import '../investir/investir.dart';
import '../sante/veterinaires.dart';
import 'mes_informations.dart';
import 'notifications.dart';
import '../../../widgets/mise_en_page.dart';

class ProfilAccueil extends StatelessWidget {
  const ProfilAccueil({super.key});

  Future<void> _deconnecter(BuildContext context) async {
    final ok = await confirmer(context, 'Se déconnecter ?',
        message: 'Vous devrez saisir à nouveau votre adresse et votre mot de passe.',
        confirmer: 'Se déconnecter');
    if (!ok) return;
    await ClientApi.instance.deconnecter();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const EcranConnexion()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const EnteteVivant(titre: 'Profil', sousTitre: 'Vos informations et réglages'),
        Expanded(
          child: ChargeurVivant<Profil>(
            charger: AuthApi.moi,
            construire: (context, p, recharger) {
              Future<void> puisRecharger(Widget ecran) async {
                await ouvrir<void>(context, ecran);
                await recharger();
              }

              return ListView(
                padding: lisible(context, const EdgeInsets.fromLTRB(Dim.gouttiere, 8, Dim.gouttiere, 24)),
                children: [
                  Apparition(
                    child: _CarteIdentite(
                        profil: p, onTap: () => puisRecharger(EcranMesInformations(profil: p))),
                  ),
                  const _Rubrique('Mon argent'),
                  Apparition(
                    rang: 1,
                    child: _Groupe(entrees: [
                      _Entree(
                        icone: Icons.account_balance_wallet_outlined,
                        titre: 'Dépenses & revenus',
                        detail: 'Ce que j’ai gagné et dépensé',
                        onTap: () => ouvrir<void>(context, const EcranOperations()),
                      ),
                      _Entree(
                        icone: Icons.bar_chart_rounded,
                        titre: 'Graphiques',
                        detail: 'Mois, trimestre, année',
                        onTap: () => ouvrir<void>(context, const EcranRapports()),
                      ),
                      _Entree(
                        icone: Icons.savings_outlined,
                        titre: 'Où investir ?',
                        detail: 'Démarrer selon mon budget',
                        onTap: () => ouvrir<void>(context, const EcranInvestir()),
                      ),
                    ]),
                  ),
                  const _Rubrique('Santé'),
                  Apparition(
                    rang: 2,
                    child: _Groupe(entrees: [
                      _Entree(
                        icone: Icons.assignment_outlined,
                        titre: 'Mes signalements',
                        detail: 'Les réponses des vétérinaires',
                        onTap: () => ouvrir<void>(context, const EcranMesSignalements()),
                      ),
                      _Entree(
                        icone: Icons.medical_services_outlined,
                        titre: 'Vétérinaires',
                        detail: 'De votre zone',
                        onTap: () => ouvrir<void>(context, const EcranVeterinaires()),
                      ),
                    ]),
                  ),
                  const _Rubrique('Réglages'),
                  Apparition(
                    rang: 3,
                    child: _Groupe(entrees: [
                      _Entree(
                        icone: Icons.notifications_none_rounded,
                        titre: 'Notifications',
                        detail: 'Alertes, rappels, réponses',
                        onTap: () => ouvrir<void>(context, const EcranNotifications()),
                      ),
                      _Entree(
                        icone: Icons.translate_rounded,
                        titre: 'Langue',
                        detail: p.langue == 'BM' ? 'Bambara' : 'Français',
                        onTap: () => ouvrir<void>(context, const EcranLangue()),
                      ),
                      _Entree(
                        icone: Icons.lock_outline_rounded,
                        titre: 'Changer mon mot de passe',
                        onTap: () => ouvrir<void>(context, const EcranChangerMotDePasse()),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  const Apparition(rang: 4, child: ChoixApparence()),
                  const SizedBox(height: 20),
                  BoutonDestructif('Se déconnecter', onPressed: () => _deconnecter(context)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// L'eleveur : grand avatar a anneau orange, nom, contact, filieres.
class _CarteIdentite extends StatelessWidget {
  const _CarteIdentite({required this.profil, required this.onTap});
  final Profil profil;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = profil;
    return Pressable(
      onTap: onTap,
      rayon: 20,
      libelle: 'Mes informations : ${p.nom}',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: context.couleurs.accent, shape: BoxShape.circle),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration:
                        BoxDecoration(color: context.couleurs.surface, shape: BoxShape.circle),
                    child: Avatar(Fmt.initiales(p.nom), taille: 60),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.nom, style: context.typo.titreSection),
                      if (p.zone != null)
                        Row(children: [
                          Icon(Icons.place_outlined, size: 18, color: context.couleurs.texteDiscret),
                          const SizedBox(width: 4),
                          Flexible(child: Text(p.zone!.nom, style: context.typo.corpsDiscret)),
                        ]),
                      if (p.telephone != null && p.telephone!.isNotEmpty)
                        Row(children: [
                          Icon(Icons.phone_outlined, size: 18, color: context.couleurs.texteDiscret),
                          const SizedBox(width: 4),
                          Flexible(child: Text(p.telephone!, style: context.typo.corpsDiscret)),
                        ]),
                    ],
                  ),
                ),
                Icon(Icons.edit_outlined, color: context.couleurs.marque),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final f in L.trierFilieres(p.filieresPratiquees))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.couleurs.fondMarquePale,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(iconeFiliere(f), size: 18, color: context.couleurs.marque),
                    const SizedBox(width: 6),
                    Text(L.filiere(f), style: Typo.pastille.copyWith(color: context.couleurs.marque)),
                  ]),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Rubrique extends StatelessWidget {
  const _Rubrique(this.texte);
  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
        child: Semantics(header: true, child: Text(texte, style: context.typo.titreSection)),
      );
}

/// Plusieurs entrees dans un seul panneau blanc, separees d'un filet.
class _Groupe extends StatelessWidget {
  const _Groupe({required this.entrees});
  final List<Widget> entrees;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: context.couleurs.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color(0x0F193B39), blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              for (var i = 0; i < entrees.length; i++) ...[
                if (i > 0) Divider(height: 1, indent: 68, color: context.couleurs.filetLeger),
                entrees[i],
              ],
            ],
          ),
        ),
      );
}

class _Entree extends StatelessWidget {
  const _Entree({required this.icone, required this.titre, this.detail, required this.onTap});
  final IconData icone;
  final String titre;
  final String? detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: context.couleurs.fondMarquePale, shape: BoxShape.circle),
                  child: Icon(icone, color: context.couleurs.marque, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titre, style: context.typo.corpsFort),
                      if (detail != null) Text(detail!, style: context.typo.corpsDiscret),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: context.couleurs.texteDiscret),
              ],
            ),
          ),
        ),
      );
}

/// Maquette : « Langue - Francais ». Le bambara n'est pas encore traduit :
/// l'option est visible mais desactivee, comme dans la maquette.
class EcranLangue extends StatelessWidget {
  const EcranLangue({super.key});

  @override
  Widget build(BuildContext context) => EcranVivant(
        titre: 'Langue',
        corps: ListView(
          padding: lisible(context, const EdgeInsets.all(Dim.gouttiere)),
          children: [
            Carte(
              enfant: Row(children: [
                Expanded(child: Text('Français', style: context.typo.corpsFort)),
                Icon(Icons.check_circle, color: context.couleurs.marque),
              ]),
            ),
            const SizedBox(height: 8),
            Opacity(
              opacity: 0.5,
              child: Carte(
                enfant: Row(children: [
                  Expanded(child: Text('Bambara', style: context.typo.corpsFort)),
                  Text('Bientôt disponible', style: context.typo.legende),
                ]),
              ),
            ),
          ],
        ),
      );
}
