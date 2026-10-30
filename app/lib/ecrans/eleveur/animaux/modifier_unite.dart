/// Maquette : « ModifierAnimal - Rempli » et sa pop-up « Supprimer ».
///
/// Sources : GET /api/types-elevage?filiere=X (un elevage ne change pas de
/// filiere : le back le refuse), PUT /api/cheptel/{id}, DELETE
/// /api/cheptel/{id}.
///
/// L'effectif est en LECTURE SEULE (correction de la maquette demandee) :
/// il ne bouge que par les entrees et les sorties, qui laissent une trace.
///
/// Rend `true` a l'ecran appelant quand l'unite a ete supprimee.
library;

import 'package:flutter/material.dart';

import '../../../api/client_api.dart';
import '../../../api/modeles.dart';
import '../../../api/services.dart';
import '../../../theme/format.dart';
import '../../../widgets/boutons.dart';
import '../../../widgets/dialogues.dart';
import '../../../widgets/entete.dart';
import '../../../widgets/etats.dart';
import '../../../widgets/formulaires.dart';
import 'ajouter_unite.dart';

class EcranModifierUnite extends StatelessWidget {
  const EcranModifierUnite({super.key, required this.unite});
  final Unite unite;

  @override
  Widget build(BuildContext context) => Chargeur<List<TypeElevage>>(
        titreEcran: 'Modifier',
        charger: () => ReferentielApi.typesElevage(filiere: unite.filiere),
        construire: (context, types, _) => _Formulaire(unite: unite, types: types),
      );
}

class _Formulaire extends StatefulWidget {
  const _Formulaire({required this.unite, required this.types});
  final Unite unite;
  final List<TypeElevage> types;

  @override
  State<_Formulaire> createState() => _FormulaireState();
}

class _FormulaireState extends State<_Formulaire> {
  final _cle = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.unite.code);
  late final _race = TextEditingController(text: widget.unite.race);
  late final _note = TextEditingController(text: widget.unite.note);
  late int? _typeId = widget.unite.typeElevageId;
  late String? _sexe = widget.unite.sexe;
  late DateTime _dateEntree = widget.unite.dateEntree ?? DateTime.now();
  late DateTime? _dateNaissance = widget.unite.dateNaissance;
  String? _erreurType;
  bool _envoi = false;

  @override
  void dispose() {
    _code.dispose();
    _race.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    setState(() => _erreurType = _typeId == null ? "Choisissez le type d'élevage" : null);
    if (!_cle.currentState!.validate() || _typeId == null) return;
    setState(() => _envoi = true);
    try {
      await CheptelApi.modifier(
        widget.unite.id,
        code: _code.text,
        typeElevageId: _typeId!,
        dateEntree: _dateEntree,
        note: _note.text,
        race: widget.unite.estLot ? null : _race.text,
        sexe: widget.unite.estLot ? null : _sexe,
        dateNaissance: widget.unite.estLot ? null : _dateNaissance,
      );
      if (!mounted) return;
      await afficherInfo(context, 'Modifications enregistrées');
      if (mounted) Navigator.of(context).pop(false);
    } on ApiException catch (e) {
      if (mounted) await afficherErreur(context, e);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Future<void> _supprimer() async {
    final u = widget.unite;
    final ok = await confirmer(
      context,
      'Supprimer ${u.code} ?',
      message: "La suppression n'est possible que pour un élevage saisi par erreur, "
          'sans soin, opération ni sortie enregistrés.',
      confirmer: 'Supprimer',
      destructif: true,
    );
    if (!ok || !mounted) return;
    try {
      await CheptelApi.supprimer(u.id);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      // 422 avec la raison exacte : « Cet elevage porte un carnet
      // sanitaire... Cloturez-le ». On la montre telle quelle.
      if (mounted) await afficherErreur(context, e, titre: 'Suppression refusée');
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.unite;
    return EcranSecondaire(
      titre: u.estLot ? 'Modifier le lot' : "Modifier l'animal",
      corps: CorpsFormulaire(cle: _cle, enfants: [
        ChampTexte(
          libelle: u.estLot ? 'Identifiant du lot' : 'Identifiant',
          controleur: _code,
          longueurMax: 20,
          validateur: (v) => Valider.requis(v, "L'identifiant est obligatoire"),
        ),
        ChampChoix<int>(
          libelle: "Type d'élevage",
          valeur: _typeId,
          erreur: _erreurType,
          options: [
            for (final t in widget.types)
              (valeur: t.id, libelle: libelleType(t), detail: detailType(t)),
          ],
          onChange: (id) => setState(() {
            _typeId = id;
            _erreurType = null;
          }),
        ),
        const Note("Le type d'élevage détermine la fréquence d'évaluation de la "
            'rentabilité. Le modifier recalcule la période en cours.'),
        const SizedBox(height: 8),
        if (u.estLot) ...[
          BlocChamp(
            libelle: 'Effectif',
            champ: Text('${Fmt.tetes(u.effectifRestant)} sur ${Fmt.montant(u.effectifInitial)} mises en place'),
          ),
          const Note("L'effectif change par les sorties (vente, mort, transfert), "
              'pas ici : chaque tête perdue ou vendue reste tracée.'),
          const SizedBox(height: 8),
          ChampDate(
            libelle: 'Date de mise en place',
            valeur: _dateEntree,
            derniere: DateTime.now(),
            onChange: (d) => setState(() => _dateEntree = d),
          ),
        ] else ...[
          const LibelleChamp('Sexe'),
          Segments<String>(
            options: const [('MALE', 'Mâle'), ('FEMELLE', 'Femelle')],
            valeur: _sexe,
            onChange: (s) => setState(() => _sexe = s),
          ),
          const SizedBox(height: 16),
          ChampTexte(libelle: 'Race (facultatif)', controleur: _race, longueurMax: 60),
          ChampDate(
            libelle: 'Date de naissance (facultatif)',
            valeur: _dateNaissance,
            derniere: DateTime.now(),
            onChange: (d) => setState(() => _dateNaissance = d),
          ),
          ChampDate(
            libelle: "Date d'entrée dans le cheptel",
            valeur: _dateEntree,
            derniere: DateTime.now(),
            onChange: (d) => setState(() => _dateEntree = d),
          ),
        ],
        ChampTexte(
          libelle: 'Note (facultatif)',
          controleur: _note,
          lignes: 3,
          longueurMax: 500,
        ),
        const SizedBox(height: 8),
        BoutonDestructif(u.estLot ? 'Supprimer ce lot' : 'Supprimer cet animal',
            onPressed: _envoi ? null : _supprimer),
      ]),
      pied: BoutonPrincipal(_envoi ? 'Enregistrement…' : 'Enregistrer',
          onPressed: _envoi ? null : _enregistrer),
    );
  }
}
