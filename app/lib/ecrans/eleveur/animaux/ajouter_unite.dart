/// Maquette : « AjouterAnimal - Type ouvert / Rempli » et la pop-up
/// « Animal enregistre ».
///
/// Un seul ecran pour un lot et pour un animal : c'est le TYPE d'elevage
/// choisi qui decide du formulaire, comme dans la maquette. Volaille : un
/// lot (effectif, date de mise en place). Autres filieres : un animal
/// (sexe, race, naissance, date d'entree).
///
/// Sources : GET /api/types-elevage, GET /api/auth/moi (filieres
/// pratiquees : le back refuse un type d'une filiere non pratiquee),
/// puis POST /api/cheptel/lots ou /api/cheptel/animaux.
///
/// Ecart avec la maquette : le choix « État » (Actif / Vendu / Mort /
/// Transféré) a la creation est retire. Un elevage nait actif ; il sort du
/// cheptel par une SORTIE, qui met l'effectif et la comptabilite a jour.
/// Creer directement un animal « Vendu » contournerait ce journal.
library;

import 'package:flutter/material.dart';

import '../../../api/client_api.dart';
import '../../../api/modeles.dart';
import '../../../api/services.dart';
import '../../../libelles.dart';
import '../../../widgets/boutons.dart';
import '../../../widgets/dialogues.dart';
import '../../../widgets/entete.dart';
import '../../../widgets/etats.dart';
import '../../../theme/palette.dart';
import '../../../widgets/eleveur/pictos.dart';
import '../../../widgets/formulaires.dart';
import 'carnet.dart';

/// « Volaille — Poulet de chair ».
String libelleType(TypeElevage t) => '${L.filiere(t.filiere)} — ${t.libelle}';

/// Detail d'un type dans une liste de choix : « cycle de 45 jours ».
String? detailType(TypeElevage t) => t.dureeCycleJours == null
    ? 'rentabilité évaluée sur un an'
    : 'cycle de ${t.dureeCycleJours} jours';

typedef _Donnees = ({List<TypeElevage> types, Profil profil});

class EcranAjouterUnite extends StatefulWidget {
  const EcranAjouterUnite(
      {super.key, this.filiere, this.typeElevageId, this.effectifPropose});

  /// Filiere de l'onglet d'ou l'on vient ; nulle = toutes.
  final String? filiere;

  /// Type preselectionne (depuis « Créer ce lot » du simulateur).
  final int? typeElevageId;

  /// Effectif prerempli (les sujets a acheter du simulateur, audit F16).
  final int? effectifPropose;

  @override
  State<EcranAjouterUnite> createState() => _EcranAjouterUniteState();
}

class _EcranAjouterUniteState extends State<EcranAjouterUnite> {
  bool _ajoutFiliere = false;

  Future<_Donnees> _charger() async {
    final reponses = await Future.wait([
      ReferentielApi.typesElevage(filiere: widget.filiere),
      AuthApi.moi(),
    ]);
    return (types: reponses[0] as List<TypeElevage>, profil: reponses[1] as Profil);
  }

  /// Audit F16 : le simulateur propose une filiere que l'eleveur ne
  /// pratique pas encore ; on l'ajoute a son profil en un geste.
  Future<void> _ajouterFiliere(Profil p, String filiere, Future<void> Function() recharger) async {
    final zone = p.zone;
    if (zone == null) {
      await afficherInfo(context, 'Zone manquante',
          message: 'Renseignez votre zone dans Profil > Mes informations.');
      return;
    }
    setState(() => _ajoutFiliere = true);
    try {
      await AuthApi.modifierProfil(
        nom: p.nom,
        email: p.email,
        telephone: p.telephone,
        zoneId: zone.id,
        langue: p.langue,
        filieres: {...p.filieresPratiquees, filiere},
      );
      await recharger();
    } on ApiException catch (e) {
      if (mounted) await afficherErreur(context, e);
    } finally {
      if (mounted) setState(() => _ajoutFiliere = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Chargeur<_Donnees>(
      titreEcran: 'Ajouter',
      charger: _charger,
      construire: (context, d, recharger) {
        final pratiquees = d.profil.filieresPratiquees.toSet();
        final types = d.types.where((t) => pratiquees.contains(t.filiere)).toList();
        final f = widget.filiere;
        if (types.isEmpty && f != null && d.types.isNotEmpty && !pratiquees.contains(f)) {
          return EcranSecondaire(
            titre: 'Ajouter',
            corps: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  VignetteAnimal(filiere: f, taille: 88),
                  const SizedBox(height: 16),
                  Text('La filière ${L.filiere(f).toLowerCase()} '
                      "n'est pas encore dans votre profil.",
                      style: context.typo.corpsFort, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  BoutonPrincipal(
                    _ajoutFiliere ? 'Ajout…' : 'Ajouter ${L.filiere(f).toLowerCase()} à mon profil',
                    icone: Icons.add_rounded,
                    onPressed: _ajoutFiliere
                        ? null
                        : () => _ajouterFiliere(d.profil, f, recharger),
                  ),
                ],
              ),
            ),
          );
        }
        return _Formulaire(
          types: types,
          typeInitial: widget.typeElevageId,
          effectifPropose: widget.effectifPropose,
        );
      },
    );
  }
}

class _Formulaire extends StatefulWidget {
  const _Formulaire({required this.types, this.typeInitial, this.effectifPropose});
  final List<TypeElevage> types;
  final int? typeInitial;
  final int? effectifPropose;

  @override
  State<_Formulaire> createState() => _FormulaireState();
}

class _FormulaireState extends State<_Formulaire> {
  final _cle = GlobalKey<FormState>();
  final _code = TextEditingController();
  late final _effectif =
      TextEditingController(text: widget.effectifPropose?.toString() ?? '');
  final _race = TextEditingController();

  TypeElevage? _type;
  String? _erreurType;
  String? _sexe;
  DateTime _dateEntree = DateTime.now();
  DateTime? _dateNaissance;
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    for (final t in widget.types) {
      if (t.id == widget.typeInitial) _type = t;
    }
    // Un seul type possible : inutile de le faire choisir.
    if (_type == null && widget.types.length == 1) _type = widget.types.first;
  }

  @override
  void dispose() {
    _code.dispose();
    _effectif.dispose();
    _race.dispose();
    super.dispose();
  }

  bool get _lot => _type != null && L.suiviParLot(_type!.filiere);

  void _vider() {
    _code.clear();
    _effectif.clear();
    _race.clear();
    setState(() {
      _sexe = null;
      _dateNaissance = null;
      _dateEntree = DateTime.now();
    });
  }

  Future<void> _enregistrer() async {
    setState(() => _erreurType = _type == null ? "Choisissez le type d'élevage" : null);
    final ok = _cle.currentState!.validate();
    if (!ok || _type == null) return;
    setState(() => _envoi = true);
    try {
      final Unite cree = _lot
          ? await CheptelApi.creerLot(
              code: _code.text,
              typeElevageId: _type!.id,
              effectifInitial: int.parse(_effectif.text.trim()),
              dateMiseEnPlace: _dateEntree,
            )
          : await CheptelApi.creerAnimal(
              code: _code.text,
              typeElevageId: _type!.id,
              dateEntree: _dateEntree,
              race: _race.text,
              sexe: _sexe,
              dateNaissance: _dateNaissance,
            );
      if (!mounted) return;
      final voir = await choisirSuite(
        context,
        _lot ? 'Lot enregistré' : 'Animal enregistré',
        message: '${cree.code} a été ajouté à votre cheptel.',
        premier: 'Voir la fiche',
        second: _lot ? 'Ajouter un autre lot' : 'Ajouter un autre animal',
      );
      if (!mounted) return;
      if (voir == false) {
        _vider();
      } else {
        Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
            builder: (_) => EcranCarnet(uniteId: cree.id)));
      }
    } on ApiException catch (e) {
      if (mounted) await afficherErreur(context, e);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titre = _type == null ? 'Ajouter' : (_lot ? 'Ajouter un lot' : 'Ajouter un animal');
    if (widget.types.isEmpty) {
      return const EcranSecondaire(
        titre: 'Ajouter',
        corps: EtatVide("Aucun type d'élevage n'est disponible pour vos filières. "
            "Vérifiez vos filières dans Profil > Mes informations."),
      );
    }
    return EcranSecondaire(
      titre: titre,
      corps: CorpsFormulaire(cle: _cle, enfants: [
        ChampChoix<int>(
          libelle: "Type d'élevage",
          indication: "Choisir le type d'élevage",
          valeur: _type?.id,
          erreur: _erreurType,
          options: [
            for (final t in widget.types)
              (valeur: t.id, libelle: libelleType(t), detail: detailType(t)),
          ],
          onChange: (id) => setState(() {
            _type = widget.types.firstWhere((t) => t.id == id);
            _erreurType = null;
          }),
        ),
        if (_type != null) ...[
          ChampTexte(
            libelle: _lot ? 'Identifiant du lot (facultatif)' : 'Identifiant (facultatif)',
            controleur: _code,
            indication: _lot ? 'Ex : LOT-015' : 'Ex : BOV-048',
            longueurMax: 20,
          ),
          const Note('Vide : un nom est créé tout seul.'),
          const SizedBox(height: 8),
          if (_lot) ...[
            ChampTexte(
              libelle: 'Effectif mis en place',
              controleur: _effectif,
              indication: 'Ex : 185',
              chiffresSeulement: true,
              longueurMax: 6,
              validateur: (v) => Valider.entierPositif(v, "L'effectif"),
            ),
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
            ChampTexte(
              libelle: 'Race (facultatif)',
              controleur: _race,
              indication: 'Ex : Zébu',
              longueurMax: 60,
            ),
            ChampDate(
              libelle: 'Date de naissance (facultatif)',
              valeur: _dateNaissance,
              derniere: DateTime.now(),
              onChange: (d) => setState(() {
                _dateNaissance = d;
                if (_dateEntree.isBefore(d)) _dateEntree = d;
              }),
            ),
            ChampDate(
              libelle: "Date d'entrée dans le cheptel",
              valeur: _dateEntree,
              // Audit F11 : un animal n'entre pas avant sa naissance.
              premiere: _dateNaissance,
              derniere: DateTime.now(),
              onChange: (d) => setState(() => _dateEntree = d),
            ),
          ],
        ],
      ]),
      pied: Row(
        children: [
          Expanded(
            child: BoutonSecondaire('Annuler',
                onPressed: _envoi ? null : () => Navigator.of(context).pop()),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: BoutonPrincipal(_envoi ? 'Envoi…' : 'Enregistrer',
                onPressed: _envoi ? null : _enregistrer),
          ),
        ],
      ),
    );
  }
}
