/// Noter une depense ou un revenu, en gestes simples :
///   1. « J'ai dépensé » ou « J'ai gagné » ;
///   2. pour quoi : une grille de pictogrammes (aliment, soins, transport…) ;
///   3. combien : le montant, avec les milliers separes pendant la saisie ;
///   4. pour quel elevage (facultatif : « Toute la ferme ») ;
///   5. quand.
///
/// Sources : GET /api/auth/moi (filieres pratiquees), GET /api/cheptel,
/// puis POST, PUT ou DELETE /api/finances/operations.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
import '../../../widgets/formulaires.dart';
import '../../../widgets/vivant.dart';
import '../animaux/carnet.dart';
import 'vocabulaire_argent.dart';
import '../../../widgets/mise_en_page.dart';

typedef _Contexte = ({List<String> filieres, List<Unite> unites});

class EcranOperation extends StatelessWidget {
  const EcranOperation({super.key, this.existante, this.filiere, this.type});

  /// Renseignee : modification. Nulle : creation.
  final Operation? existante;

  /// Filiere proposee par defaut a la creation.
  final String? filiere;

  /// `DEPENSE` ou `REVENU`, choisi d'avance (« J'ai dépensé »).
  final String? type;

  static Future<_Contexte> _charger() async {
    final reponses = await Future.wait([AuthApi.moi(), CheptelApi.lister()]);
    return (
      filieres: L.trierFilieres((reponses[0] as Profil).filieresPratiquees),
      unites: reponses[1] as List<Unite>,
    );
  }

  @override
  Widget build(BuildContext context) => ChargeurVivant<_Contexte>(
        titreEcran: existante == null ? 'Noter de l’argent' : 'Modifier',
        charger: _charger,
        construire: (context, c, _) => _Formulaire(
            contexte: c, existante: existante, filiereProposee: filiere, typePropose: type),
      );
}

class _Formulaire extends StatefulWidget {
  const _Formulaire(
      {required this.contexte, this.existante, this.filiereProposee, this.typePropose});
  final _Contexte contexte;
  final Operation? existante;
  final String? filiereProposee;
  final String? typePropose;

  @override
  State<_Formulaire> createState() => _FormulaireState();
}

class _FormulaireState extends State<_Formulaire> {
  final _cle = GlobalKey<FormState>();
  late final Operation? _o = widget.existante;
  late String _type = _o?.type ?? widget.typePropose ?? 'DEPENSE';
  late String? _filiere = _o?.filiere ??
      (widget.contexte.filieres.contains(widget.filiereProposee)
          ? widget.filiereProposee
          : (widget.contexte.filieres.isEmpty ? null : widget.contexte.filieres.first));
  late int? _uniteId = _o?.uniteId;
  late String? _categorie = _o?.categorie;
  late DateTime _date = _o?.dateOperation ?? DateTime.now();
  late final _montant = TextEditingController(
      text: _o == null ? '' : Fmt.montant(_o.montant));
  late final _libelle = TextEditingController(text: _o?.libelle);
  String? _erreurCategorie;
  String? _erreurFiliere;
  bool _envoi = false;

  @override
  void dispose() {
    _montant.dispose();
    _libelle.dispose();
    super.dispose();
  }

  bool get _plusieursFilieres => widget.contexte.filieres.length > 1;

  /// Un revenu se rattache aussi a un lot deja vendu : on garde donc les
  /// unites sorties, mais seulement celle deja choisie si elle n'est plus
  /// active (modification d'une ancienne operation).
  List<Unite> get _unitesProposees => widget.contexte.unites
      .where((u) =>
          widget.contexte.filieres.contains(u.filiere) && (u.estActif || u.id == _uniteId))
      .toList();

  Unite? get _unite {
    for (final u in widget.contexte.unites) {
      if (u.id == _uniteId) return u;
    }
    return null;
  }

  int? get _valeurMontant => int.tryParse(_montant.text.replaceAll(RegExp(r'\D'), ''));

  Future<void> _enregistrer() async {
    final filiere = _unite?.filiere ?? _filiere;
    setState(() {
      _erreurCategorie = _categorie == null ? 'Touchez une catégorie' : null;
      _erreurFiliere = filiere == null ? 'Choisissez la filière' : null;
    });
    if (!_cle.currentState!.validate() || _categorie == null || filiere == null) return;
    setState(() => _envoi = true);
    final montant = _valeurMontant!;
    try {
      if (_o == null) {
        await FinanceApi.creer(
            type: _type, categorie: _categorie!, montant: montant, date: _date,
            filiere: filiere, uniteId: _uniteId, libelle: _libelle.text);
      } else {
        await FinanceApi.modifier(_o.id,
            type: _type, categorie: _categorie!, montant: montant, date: _date,
            filiere: filiere, uniteId: _uniteId, libelle: _libelle.text);
      }
      if (!mounted) return;
      // Confirmation non bloquante : pas de pop-up a fermer.
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        backgroundColor: context.couleurs.fondFonce,
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: context.couleurs.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  '${_type == 'DEPENSE' ? 'Dépense' : 'Revenu'} de ${Fmt.fcfa(montant)} noté.',
                  style: context.typo.corpsFort.copyWith(color: context.couleurs.surEntete)),
            ),
          ],
        ),
      ));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) await afficherErreur(context, e);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Future<void> _supprimer() async {
    final ok = await confirmer(context, 'Supprimer cette ligne ?',
        message: 'Le solde du mois sera recalculé.', confirmer: 'Supprimer', destructif: true);
    if (!ok || !mounted) return;
    try {
      await FinanceApi.supprimer(_o!.id);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) await afficherErreur(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = L.categoriesParType[_type]!;
    final depense = _type == 'DEPENSE';
    final venteDUnLot = _categorie == 'VENTE_ANIMAUX' && _unite != null && _o == null;
    return EcranVivant(
      titre: _o == null ? (depense ? "J'ai dépensé" : "J'ai gagné") : 'Modifier',
      sousTitre: 'Dépenses & revenus',
      corps: Form(
        key: _cle,
        child: ListView(
          padding: lisible(context, const EdgeInsets.fromLTRB(Dim.gouttiere, 16, Dim.gouttiere, 32)),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Row(
              children: [
                Expanded(
                  child: _TuileType(
                    libelle: "J'ai dépensé",
                    icone: Icons.remove_rounded,
                    type: 'DEPENSE',
                    actif: depense,
                    onTap: () => _changerType('DEPENSE'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TuileType(
                    libelle: "J'ai gagné",
                    icone: Icons.add_rounded,
                    type: 'REVENU',
                    actif: !depense,
                    onTap: () => _changerType('REVENU'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(depense ? 'Pour quoi ?' : 'Grâce à quoi ?', style: context.typo.titreSection),
            const SizedBox(height: 8),
            LayoutBuilder(builder: (context, c) {
              final colonnes = c.maxWidth > 360 ? 3 : 2;
              final largeur = (c.maxWidth - 10 * (colonnes - 1)) / colonnes;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final cat in categories)
                    SizedBox(
                      width: largeur,
                      child: _TuileCategorie(
                        categorie: cat,
                        type: _type,
                        actif: _categorie == cat,
                        onTap: () => setState(() {
                          _categorie = cat;
                          _erreurCategorie = null;
                        }),
                      ),
                    ),
                ],
              );
            }),
            if (_erreurCategorie != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_erreurCategorie!, style: context.typo.corps.copyWith(color: context.couleurs.erreur)),
              ),
            const SizedBox(height: 20),
            Text('Combien ?', style: context.typo.titreSection),
            const SizedBox(height: 8),
            TextFormField(
              controller: _montant,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, _Milliers()],
              style: context.typo.chiffre,
              decoration: InputDecoration(
                hintText: '0',
                suffixText: 'FCFA',
                suffixStyle: context.typo.corpsFort.copyWith(color: context.couleurs.texteDiscret),
              ),
              validator: (_) {
                final v = _valeurMontant;
                if (v == null) return 'Indiquez le montant';
                if (v <= 0) return 'Le montant doit être plus grand que zéro';
                if (v > 9999999999) return 'Montant trop grand';
                return null;
              },
            ),
            const SizedBox(height: 20),
            ChampChoix<int>(
              libelle: depense ? 'Pour quel élevage ? (facultatif)' : 'Quel élevage ? (facultatif)',
              valeur: _uniteId ?? -1,
              options: [
                (
                  valeur: -1,
                  libelle: 'Toute la ferme',
                  detail: 'Pour plusieurs lots ou animaux à la fois',
                ),
                for (final u in _unitesProposees)
                  (
                    valeur: u.id,
                    libelle: u.estLot ? '${u.code} — ${Fmt.tetes(u.effectifRestant)}' : u.code,
                    detail: '${L.filiere(u.filiere)} · ${u.typeElevage}',
                  ),
              ],
              onChange: (id) => setState(() {
                _uniteId = id == -1 ? null : id;
                if (_unite != null) _filiere = _unite!.filiere;
              }),
            ),
            if (venteDUnLot) ...[
              _AvertissementVente(unite: _unite!),
              const SizedBox(height: 16),
            ],
            if (_plusieursFilieres && _unite == null) ...[
              const LibelleChamp('Quelle filière ?'),
              ChoixPilules<String>(
                options: [for (final f in widget.contexte.filieres) (f, L.filiere(f))],
                valeur: _filiere,
                onChange: (f) => setState(() {
                  _filiere = f;
                  _erreurFiliere = null;
                }),
              ),
              if (_erreurFiliere != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_erreurFiliere!, style: context.typo.corps.copyWith(color: context.couleurs.erreur)),
                ),
              const SizedBox(height: 16),
            ],
            ChampDate(
              libelle: 'Quand ?',
              valeur: _date,
              derniere: DateTime.now(),
              onChange: (d) => setState(() => _date = d),
            ),
            ChampTexte(
              libelle: 'Une précision ? (facultatif)',
              controleur: _libelle,
              indication: depense ? 'Ex : 2 sacs de 50 kg' : 'Ex : 30 plateaux d’œufs',
              longueurMax: 255,
            ),
            if (_o != null) ...[
              const SizedBox(height: 8),
              BoutonDestructif('Supprimer cette ligne', onPressed: _envoi ? null : _supprimer),
            ],
          ],
        ),
      ),
      pied: BoutonPrincipal(
        _envoi ? 'Enregistrement…' : 'Enregistrer',
        icone: _envoi ? null : Icons.check_rounded,
        onPressed: _envoi ? null : _enregistrer,
      ),
    );
  }

  void _changerType(String t) => setState(() {
        _type = t;
        // Une categorie de depense n'a pas de sens sur un revenu : le back
        // la refuserait. On l'efface au changement de type.
        if (_categorie != null && !L.categoriesParType[t]!.contains(_categorie)) {
          _categorie = null;
        }
      });
}

/// L7 : une vente d'animaux notee ici ne retire aucune tete du lot, et
/// s'ajouterait a une vente deja notee dans le carnet.
class _AvertissementVente extends StatelessWidget {
  const _AvertissementVente({required this.unite});
  final Unite unite;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.couleurs.fondAttentionPale,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: context.couleurs.accent, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vous vendez des animaux de ce lot ?', style: context.typo.corpsFort),
            const SizedBox(height: 4),
            Text('Notez la vente dans son carnet : le nombre de têtes baissera et '
                "l'argent sera compté une seule fois.",
                style: context.typo.corps),
            const SizedBox(height: 10),
            BoutonSecondaire('Ouvrir le carnet de ${unite.code}',
                onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
                    builder: (_) => EcranCarnet(uniteId: unite.id)))),
          ],
        ),
      );
}

class _TuileType extends StatelessWidget {
  const _TuileType({
    required this.libelle,
    required this.icone,
    required this.type,
    required this.actif,
    required this.onTap,
  });
  final String libelle;
  final IconData icone;
  final String type;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: actif,
        button: true,
        label: libelle,
        excludeSemantics: true,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: actif ? context.couleurs.marque : context.couleurs.filetLeger, width: actif ? 2.5 : 1),
          ),
          child: Pressable(
            onTap: actif ? null : onTap,
            rayon: 14,
            ombre: false,
            couleur: actif ? context.couleurs.fondMarquePale : context.couleurs.surface,
            child: SizedBox(
              height: 64,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icone, size: 28, color: couleurType(context, type)),
                  const SizedBox(width: 6),
                  Flexible(child: Text(libelle, style: context.typo.corpsFort)),
                ],
              ),
            ),
          ),
        ),
      );
}

class _TuileCategorie extends StatelessWidget {
  const _TuileCategorie(
      {required this.categorie, required this.type, required this.actif, required this.onTap});
  final String categorie;
  final String type;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: actif,
        button: true,
        label: L.categorieOperation(categorie),
        excludeSemantics: true,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: actif ? context.couleurs.accent : context.couleurs.filetLeger, width: actif ? 2.5 : 1),
          ),
          child: Pressable(
            onTap: onTap,
            rayon: 14,
            ombre: false,
            couleur: actif ? context.couleurs.fondAccentPale : context.couleurs.surface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 88),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(iconeCategorie(categorie), size: 32, color: couleurType(context, type)),
                    const SizedBox(height: 6),
                    Text(libelleCategorieCourt(categorie),
                        textAlign: TextAlign.center, style: context.typo.corpsFort),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

/// « 1500000 » devient « 1 500 000 » pendant la saisie.
class _Milliers extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue ancien, TextEditingValue nouveau) {
    final chiffres = nouveau.text.replaceAll(RegExp(r'\D'), '');
    if (chiffres.isEmpty) return const TextEditingValue();
    final texte = Fmt.montant(int.parse(chiffres.length > 12 ? chiffres.substring(0, 12) : chiffres));
    return TextEditingValue(
        text: texte, selection: TextSelection.collapsed(offset: texte.length));
  }
}
