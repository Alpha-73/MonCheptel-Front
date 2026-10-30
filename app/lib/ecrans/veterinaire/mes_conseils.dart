/// Maquettes : « Veto - Mes conseils », « Veto - Conseil rediger » et sa
/// pop-up « Publie », « Veto - Conseil modifier » et sa pop-up « Supprimer ».
///
/// Sources : GET /api/conseils/mes-conseils, POST /api/conseils puis POST
/// /api/conseils/{id}/soumission, PUT et DELETE /api/conseils/{id},
/// GET /api/veterinaires/competences (filieres proposees).
///
/// Un veterinaire ne se publie pas lui-meme : « Publier » cree un brouillon
/// et l'envoie aussitot en moderation. C'est l'administration qui publie.
library;

import 'package:flutter/material.dart';

import '../../api/client_api.dart';
import '../../api/modeles.dart';
import '../../api/services.dart';
import '../../libelles.dart';
import '../../theme/palette.dart';
import '../../theme/dimensions.dart';
import '../../theme/format.dart';
import '../../widgets/boutons.dart';
import '../../widgets/carte.dart';
import '../../widgets/dialogues.dart';
import '../../widgets/echafaudage.dart';
import '../../widgets/entete.dart';
import '../../widgets/etats.dart';
import '../../widgets/formulaires.dart';
import '../../widgets/navigation.dart';
import '../../widgets/pastille.dart';
import 'commun_veterinaire.dart';
import '../../widgets/mise_en_page.dart';

// ── liste ─────────────────────────────────────────────────────────────────

class MesConseils extends StatelessWidget {
  const MesConseils({super.key});

  /// « 2 conseils publiés · 1 en modération ».
  static String _resume(List<ConseilDetail> cs) {
    int nb(String statut) => cs.where((c) => c.statut == statut).length;
    String n(int x, String un, String plusieurs) => '$x ${x > 1 ? plusieurs : un}';
    final publies = nb('PUBLIE');
    return [
      n(publies, 'conseil publié', 'conseils publiés'),
      if (nb('EN_MODERATION') > 0) '${nb('EN_MODERATION')} en modération',
      if (nb('BROUILLON') > 0) n(nb('BROUILLON'), 'brouillon', 'brouillons'),
      if (nb('RETIRE') > 0) n(nb('RETIRE'), 'retiré', 'retirés'),
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Chargeur<List<ConseilDetail>>(
      charger: ConseilApi.mesConseils,
      construire: (context, conseils, recharger) {
        Future<void> puisRecharger(Widget ecran) async {
          await ouvrir<void>(context, ecran);
          await recharger();
        }

        return Column(
          children: [
            const EnteteClair(titre: 'Mes conseils'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: recharger,
                color: context.couleurs.marque,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: lisible(context, const EdgeInsets.fromLTRB(Dim.gouttiere, 8, Dim.gouttiere, 16)),
                  children: [
                    Text(_resume(conseils), style: context.typo.legende),
                    const SizedBox(height: 10),
                    if (conseils.isEmpty)
                      const EtatVide(
                        "Vous n'avez encore rédigé aucun conseil. Un conseil validé "
                        "par l'administration est lu par tous les éleveurs de sa filière.",
                        icone: Icons.menu_book_outlined,
                      ),
                    for (final c in conseils)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Dim.ecart),
                        child: _CarteConseil(
                          c,
                          onTap: () => puisRecharger(EcranConseilVeto(conseil: c)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Juste au-dessus de la barre fixe de la coquille.
            Padding(
              padding: const EdgeInsets.fromLTRB(Dim.gouttiere, 4, Dim.gouttiere, 12),
              child: BoutonPrincipal('Rédiger un conseil',
                  icone: Icons.add, onPressed: () => puisRecharger(const EcranConseilVeto())),
            ),
          ],
        );
      },
    );
  }
}

class _CarteConseil extends StatelessWidget {
  const _CarteConseil(this.c, {required this.onTap});
  final ConseilDetail c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Carte(
        onTap: onTap,
        enfant: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(c.titre, style: context.typo.corpsFort)),
                const SizedBox(width: 8),
                Pastille(L.statutConseil(c.statut), ton: L.tonStatutConseil(c.statut)),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${L.filiere(c.filiere)} · ${Fmt.dateLongue(c.dateReference)}',
                    style: context.typo.legende,
                  ),
                ),
                // Decoratif : toute la carte ouvre la modification.
                ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.edit_outlined, color: context.couleurs.marque, size: 22),
                  ),
                ),
              ],
            ),
            if (c.statut == 'RETIRE' && c.motifRetrait != null)
              Text('Retiré : ${c.motifRetrait}',
                  style: context.typo.legende.copyWith(color: context.couleurs.erreur)),
          ],
        ),
      );
}

// ── rediger / modifier ────────────────────────────────────────────────────

/// Rediger un conseil ([conseil] nul) ou modifier l'un des siens.
class EcranConseilVeto extends StatelessWidget {
  const EcranConseilVeto({super.key, this.conseil});
  final ConseilDetail? conseil;

  String get _titre => conseil == null
      ? 'Rédiger un conseil'
      : conseil!.statut == 'EN_MODERATION'
          ? 'Conseil en relecture'
          : 'Modifier le conseil';

  @override
  Widget build(BuildContext context) => Chargeur<List<Maladie>>(
        titreEcran: _titre,
        clair: true,
        charger: VeterinaireApi.competences,
        construire: (context, competences, _) {
          // Filieres proposees : celles du veterinaire (deduites de ses
          // competences), plus celle du conseil modifie. Sans competence
          // declaree, les quatre.
          final siennes = filieresDesCompetences(competences);
          final filieres = L.trierFilieres({
            ...(siennes.isEmpty ? L.filieres : siennes),
            if (conseil != null) conseil!.filiere,
          });
          return _FormulaireConseil(titre: _titre, conseil: conseil, filieres: filieres);
        },
      );
}

class _FormulaireConseil extends StatefulWidget {
  const _FormulaireConseil({required this.titre, required this.conseil, required this.filieres});
  final String titre;
  final ConseilDetail? conseil;
  final List<String> filieres;

  @override
  State<_FormulaireConseil> createState() => _FormulaireConseilState();
}

class _FormulaireConseilState extends State<_FormulaireConseil> {
  final _cle = GlobalKey<FormState>();
  late final _titre = TextEditingController(text: widget.conseil?.titre);
  late final _contenu = TextEditingController(text: widget.conseil?.contenu);
  late String _filiere = widget.conseil?.filiere ?? widget.filieres.first;
  late String _categorie = widget.conseil?.categorie ?? L.categoriesConseil.first;
  bool _envoi = false;

  /// En modération, le back refuse toute modification (422) : le
  /// formulaire est en lecture seule jusqu'à la décision.
  bool get _lectureSeule => widget.conseil?.statut == 'EN_MODERATION';

  @override
  void dispose() {
    _titre.dispose();
    _contenu.dispose();
    super.dispose();
  }

  Future<void> _publier() async {
    if (!_cle.currentState!.validate()) return;
    setState(() => _envoi = true);
    try {
      final brouillon = await ConseilApi.rediger(
          titre: _titre.text, contenu: _contenu.text, filiere: _filiere, categorie: _categorie);
      try {
        await ConseilApi.soumettre(brouillon.id);
      } on ApiException catch (e) {
        // Le brouillon existe : on le dit, et on renvoie a la liste ou il
        // attend. L'ouvrir et l'enregistrer le renverra en moderation.
        if (!mounted) return;
        await afficherErreur(
            context,
            ApiException(e.statut,
                "Votre conseil est enregistré en brouillon, mais n'a pas pu être envoyé "
                'en modération : ${e.texte}\nRetrouvez-le dans Mes conseils pour le renvoyer.'),
            titre: 'Envoi incomplet');
        if (mounted) Navigator.of(context).pop();
        return;
      }
      if (!mounted) return;
      final voirListe = await choisirSuite(
        context,
        'Conseil envoyé en modération',
        message: 'Il sera visible par les éleveurs de la filière '
            "${L.filiere(_filiere).toLowerCase()} dès validation par l'administrateur.",
        premier: 'Voir mes conseils',
        second: 'Rédiger un autre',
      );
      if (!mounted) return;
      if (voirListe == false) {
        _titre.clear();
        _contenu.clear();
      } else {
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (mounted) await afficherErreur(context, e);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Future<void> _enregistrer() async {
    if (!_cle.currentState!.validate()) return;
    setState(() => _envoi = true);
    try {
      final c = await ConseilApi.modifier(widget.conseil!.id,
          titre: _titre.text, contenu: _contenu.text, filiere: _filiere, categorie: _categorie);
      // Un conseil publie modifie repasse seul en moderation (back). Un
      // brouillon ou un conseil retire, lui, doit y etre renvoye.
      if (c.statut == 'BROUILLON' || c.statut == 'RETIRE') {
        await ConseilApi.soumettre(c.id);
      }
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) await afficherErreur(context, e);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Future<void> _supprimer() async {
    final c = widget.conseil!;
    final ok = await confirmer(context, 'Supprimer ce conseil ?',
        message: '« ${c.titre} » ne sera plus visible par les éleveurs. '
            'Cette action est définitive.',
        confirmer: 'Oui, supprimer',
        destructif: true);
    if (!ok || !mounted) return;
    setState(() => _envoi = true);
    try {
      await ConseilApi.supprimer(c.id);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) await afficherErreur(context, e);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  /// La ligne d'etat en tete de « Modifier le conseil ».
  Widget _etat(ConseilDetail c) {
    final texte = switch (c.statut) {
      'PUBLIE' => 'Publié le ${Fmt.dateLongue(c.datePublication)}',
      'EN_MODERATION' => 'En modération depuis le ${Fmt.dateLongue(c.dateSoumission)}',
      'RETIRE' => "Retiré par l'administration",
      _ => 'Brouillon non envoyé',
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Pastille(texte, ton: L.tonStatutConseil(c.statut)),
    );
  }

  /// L'encart orange sous le contenu.
  String _avertissement() {
    final c = widget.conseil;
    return switch (c?.statut) {
      null => 'Votre conseil sera visible par les éleveurs de la filière choisie. '
          "L'administrateur peut le retirer s'il ne respecte pas la charte.",
      'PUBLIE' => 'Après modification, le conseil repasse en modération avant '
          "d'être à nouveau visible par les éleveurs.",
      'EN_MODERATION' => "En relecture par l'administrateur : modification possible "
          'après sa décision. Vous pouvez encore le supprimer.',
      'RETIRE' => [
          if (c!.motifRetrait != null) 'Motif du retrait : ${c.motifRetrait}.',
          'Une fois corrigé, le conseil repart en modération.',
        ].join(' '),
      _ => "Enregistrer envoie ce brouillon en modération.",
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.conseil;
    return EcranSecondaire(
      titre: widget.titre,
      clair: true,
      corps: CorpsFormulaire(cle: _cle, enfants: [
        if (c != null) ...[_etat(c), const SizedBox(height: 16)],
        LibelleChamp(c == null ? 'Filière concernée' : 'Filière'),
        ChoixPilules<String>(
          options: [for (final f in widget.filieres) (f, L.filiere(f))],
          valeur: _filiere,
          onChange: (f) {
            if (!_lectureSeule) setState(() => _filiere = f);
          },
        ),
        const SizedBox(height: 16),
        const LibelleChamp('Catégorie'),
        ChoixPilules<String>(
          options: [for (final k in L.categoriesConseil) (k, L.categorieConseil(k))],
          valeur: _categorie,
          onChange: (k) {
            if (!_lectureSeule) setState(() => _categorie = k);
          },
        ),
        const SizedBox(height: 16),
        ChampTexte(
          libelle: 'Titre',
          controleur: _titre,
          lectureSeule: _lectureSeule,
          longueurMax: 160,
          indication: 'Ex. : Réduire les risques de Newcastle',
          validateur: (v) => Valider.requis(v, 'Le titre est obligatoire'),
        ),
        ChampTexte(
          libelle: 'Contenu',
          controleur: _contenu,
          lectureSeule: _lectureSeule,
          lignes: 7,
          longueurMax: 10000,
          clavier: TextInputType.multiline,
          indication: "Expliquez simplement, en vous adressant directement à l'éleveur.",
          validateur: (v) => Valider.requis(v, 'Le contenu est obligatoire'),
        ),
        Encart(
            titre: _avertissement(),
            ton: _lectureSeule ? TonEncart.marque : TonEncart.attention,
            fort: false),
      ]),
      pied: c == null
          ? BoutonPrincipal(_envoi ? 'Envoi…' : 'Publier', onPressed: _envoi ? null : _publier)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_lectureSeule) ...[
                  BoutonPrincipal(_envoi ? 'Enregistrement…' : 'Enregistrer les modifications',
                      onPressed: _envoi ? null : _enregistrer),
                  const SizedBox(height: 10),
                ],
                BoutonDestructif('Supprimer ce conseil', onPressed: _envoi ? null : _supprimer),
              ],
            ),
    );
  }
}
