/// « Agir vite » : la feuille ouverte par le bouton orange du milieu de la
/// barre du bas. Les quatre familles de gestes, les memes que les
/// raccourcis de l'accueil, chacune dans son propre ecran :
///   - Événement sanitaire → Signaler une maladie, Traitement, Consultation,
///                           Vaccination ;
///   - Ajouter un lot ou un animal ;
///   - Changer le statut   → vente, mort, transfert (les sorties) ;
///   - Dépense ou revenu   → une opération financière.
library;

import 'package:flutter/material.dart';

import '../../api/client_api.dart';
import '../../api/modeles.dart';
import '../../api/services.dart';
import '../../libelles.dart';
import '../../theme/dimensions.dart';
import '../../theme/format.dart';
import '../../theme/palette.dart';
import '../../widgets/dialogues.dart';
import '../../widgets/eleveur/pictos.dart';
import '../../widgets/mise_en_page.dart';
import '../../widgets/navigation.dart';
import '../../widgets/vivant.dart';
import 'animaux/ajouter_unite.dart';
import 'animaux/evenement.dart';
import 'finances/operation_form.dart';
import 'sante/signalement.dart';

enum ActionRapide { sanitaire, ajouter, statut, operation }

/// Feuille du bas aux couleurs du theme.
Future<T?> _feuille<T>(BuildContext context, Widget contenu) => showModalBottomSheet<T>(
      context: context,
      backgroundColor: context.couleurs.fond,
      showDragHandle: true,
      isScrollControlled: true,
      // Sur tablette ou en paysage, la feuille ne s'etale pas d'un bord a
      // l'autre.
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Dim.rayonPanneau))),
      builder: (_) => contenu,
    );

/// Ouvre la feuille et rend l'action choisie (nulle si fermee).
Future<ActionRapide?> montrerAgirVite(BuildContext context) =>
    _feuille<ActionRapide>(context, const FeuilleAgirVite());

/// Ouvre l'ecran de l'action. [filiere] : celle de l'onglet en cours.
Future<void> executerAction(BuildContext context, ActionRapide action, {String? filiere}) async {
  switch (action) {
    case ActionRapide.sanitaire:
      await noterEvenementSanitaire(context, filiere: filiere);
    case ActionRapide.ajouter:
      await ouvrir<void>(context, EcranAjouterUnite(filiere: filiere));
    case ActionRapide.statut:
      await changerStatut(context, filiere: filiere);
    case ActionRapide.operation:
      await noterOperation(context, filiere: filiere);
  }
}

/// « Événement sanitaire » : Signaler une maladie, Traitement, Consultation
/// ou Vaccination, puis l'elevage concerne.
Future<void> noterEvenementSanitaire(BuildContext context, {String? filiere}) async {
  final types = typesSanitaires(context.couleurs);
  final code = await _feuille<String>(
    context,
    FeuilleChoix<String>(
      titre: 'Événement sanitaire',
      question: 'Que s’est-il passé ?',
      choix: [for (final (code, libelle, icone, encre, fond) in types) (code, libelle, icone, fond, encre)],
    ),
  );
  if (code == null || !context.mounted) return;
  if (code == codeSignaler) {
    await ouvrir<void>(context, const EcranSignalementChoix());
    return;
  }
  final unite = await choisirUnite(context, question: 'Pour quel élevage ?', filiere: filiere);
  if (unite == null || !context.mounted) return;
  await ouvrir<void>(context, EcranAjouterEvenement(unite: unite, type: code));
}

/// « Changer le statut » : choix de l'elevage s'il y en a plusieurs, puis
/// vente, mort ou transfert.
Future<void> changerStatut(BuildContext context, {String? filiere}) async {
  final unite =
      await choisirUnite(context, question: 'Quel élevage change de statut ?', filiere: filiere);
  if (unite == null || !context.mounted) return;
  await ouvrir<void>(context, EcranChangerStatut(unite: unite));
}

/// « + Opération » : Dépense ou Revenu, puis le formulaire d'argent.
Future<void> noterOperation(BuildContext context, {String? filiere}) async {
  final c = context.couleurs;
  final type = await _feuille<String>(
    context,
    FeuilleChoix<String>(
      titre: 'Opération',
      question: 'De l’argent sort ou rentre ?',
      choix: [
        ('DEPENSE', 'Dépense', Icons.north_east_rounded, c.fondAccentPale, c.attentionTexte),
        ('REVENU', 'Revenu', Icons.south_west_rounded, c.fondMarquePale, c.marque),
      ],
    ),
  );
  if (type == null || !context.mounted) return;
  await ouvrir<void>(context, EcranOperation(filiere: filiere, type: type));
}

/// L'elevage actif concerne : directement s'il n'y en a qu'un, sinon au
/// choix dans une feuille. Avec [filiere], ceux de la filiere d'abord (tous
/// si elle n'en a aucun).
Future<Unite?> choisirUnite(BuildContext context,
    {required String question, String? filiere}) async {
  List<Unite> actives;
  try {
    actives = await CheptelApi.lister(statut: 'ACTIF');
  } on ApiException catch (e) {
    if (context.mounted) await afficherErreur(context, e);
    return null;
  }
  if (!context.mounted) return null;
  if (actives.isEmpty) {
    await afficherInfo(context, 'Aucun élevage actif',
        message: "Ajoutez d'abord un lot ou un animal.");
    return null;
  }
  final memeFiliere = [for (final u in actives) if (u.filiere == filiere) u];
  final liste = memeFiliere.isEmpty ? actives : memeFiliere;
  if (liste.length == 1) return liste.first;
  return _feuille<Unite>(context, _ChoixUnite(unites: liste, question: question));
}

class FeuilleAgirVite extends StatelessWidget {
  const FeuilleAgirVite({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.couleurs;
    final tuiles = <(ActionRapide, String, IconData?, Color, Color)>[
      (ActionRapide.sanitaire, 'Événement sanitaire', Icons.health_and_safety_outlined,
          c.fondErreurPale, c.erreur),
      (ActionRapide.ajouter, 'Ajouter un lot ou un animal', null, c.fondMarquePale, c.marque),
      (ActionRapide.statut, 'Changer le statut', Icons.sync_alt_rounded, c.sable, c.encreFonce),
      (ActionRapide.operation, 'Dépense ou revenu', Icons.payments_outlined, c.fondAccentPale,
          c.attentionTexte),
    ];
    return _CorpsFeuille(
      titre: 'Agir vite',
      question: 'Que voulez-vous faire ?',
      tuiles: [
        for (var i = 0; i < tuiles.length; i++)
          Apparition(
            rang: i,
            child: TuileAction(
              libelle: tuiles[i].$2,
              icone: tuiles[i].$3,
              fond: tuiles[i].$4,
              encre: tuiles[i].$5,
              onTap: () => Navigator.of(context).pop(tuiles[i].$1),
            ),
          ),
      ],
    );
  }
}

/// Feuille de choix a grandes tuiles : rend la valeur touchee.
class FeuilleChoix<T> extends StatelessWidget {
  const FeuilleChoix({super.key, required this.titre, required this.question, required this.choix});
  final String titre;
  final String question;

  /// (valeur, libelle, icone, fond, encre).
  final List<(T, String, IconData, Color, Color)> choix;

  @override
  Widget build(BuildContext context) => _CorpsFeuille(
        titre: titre,
        question: question,
        tuiles: [
          for (var i = 0; i < choix.length; i++)
            Apparition(
              rang: i,
              child: TuileAction(
                libelle: choix[i].$2,
                icone: choix[i].$3,
                fond: choix[i].$4,
                encre: choix[i].$5,
                onTap: () => Navigator.of(context).pop(choix[i].$1),
              ),
            ),
        ],
      );
}

class _CorpsFeuille extends StatelessWidget {
  const _CorpsFeuille({required this.titre, required this.question, required this.tuiles});
  final String titre;
  final String question;
  final List<Widget> tuiles;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        // En paysage, la feuille peut etre plus haute que l'ecran.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Dim.gouttiere, 0, Dim.gouttiere, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(header: true, child: Text(titre, style: context.typo.titreSection)),
              const SizedBox(height: 2),
              Text(question, style: context.typo.corpsDiscret),
              const SizedBox(height: 16),
              GrilleTuiles(children: tuiles),
            ],
          ),
        ),
      );
}

/// Grande tuile illustree : un rond teinte avec le pictogramme, et un
/// libelle court sur deux lignes au plus. Toute la tuile se touche.
class TuileAction extends StatelessWidget {
  const TuileAction({
    super.key,
    required this.libelle,
    required this.onTap,
    this.icone,
    this.picto,
    this.fond,
    this.encre,
    this.compact = false,
  });
  final String libelle;
  final VoidCallback onTap;

  /// [icone] Material, ou [picto] dessine ; aucun des deux = un animal et un +.
  final IconData? icone;
  final Widget? picto;
  final Color? fond;
  final Color? encre;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final rond = compact ? 46.0 : 58.0;
    final dessin = picto ??
        (icone != null
            ? Icon(icone, size: rond * 0.5, color: encre ?? context.couleurs.marque)
            : Stack(clipBehavior: Clip.none, children: [
                PictoAnimal(taille: rond * 0.52, couleur: encre ?? context.couleurs.marque),
                Positioned(
                  right: -8,
                  bottom: -6,
                  child: Container(
                    decoration: BoxDecoration(
                        color: context.couleurs.accent, shape: BoxShape.circle),
                    child: Icon(Icons.add_rounded, size: 16, color: context.couleurs.surAccent),
                  ),
                ),
              ]));
    return Pressable(
      onTap: onTap,
      rayon: 20,
      libelle: libelle,
      child: ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: rond,
                height: rond,
                decoration: BoxDecoration(
                    color: fond ?? context.couleurs.fondMarquePale, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: dessin,
              ),
              SizedBox(height: compact ? 8 : 10),
              Text(libelle, style: context.typo.corpsFort.copyWith(height: 1.2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoixUnite extends StatelessWidget {
  const _ChoixUnite({required this.unites, required this.question});
  final List<Unite> unites;
  final String question;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(Dim.gouttiere, 0, Dim.gouttiere, 20),
            children: [
              Text(question, style: context.typo.titreSection),
              const SizedBox(height: 12),
              for (final u in unites)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Pressable(
                    onTap: () => Navigator.of(context).pop(u),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 64),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(children: [
                          VignetteAnimal(filiere: u.filiere, taille: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(u.code, style: context.typo.corpsFort),
                                Text(
                                  u.estLot
                                      ? '${u.typeElevage} · ${Fmt.tetes(u.effectifRestant)}'
                                      : '${L.filiere(u.filiere)} · ${u.typeElevage}',
                                  style: context.typo.legende,
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: context.couleurs.texteDiscret),
                        ]),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}
