/// « Ajouter une maladie » : le veterinaire enrichit le catalogue.
///
/// La maladie est utilisable tout de suite et le veterinaire en devient
/// competent. L'administration peut la corriger ou la retirer ensuite.
///
/// Un symptome absent de la liste se saisit directement (« Nouveau
/// symptôme ») : il est cree puis coche.
///
/// Sources : GET /api/signalements/symptomes, POST /api/signalements/symptomes,
/// POST /api/veterinaires/maladies.
library;

import 'package:flutter/material.dart';

import '../../api/client_api.dart';
import '../../api/modeles.dart';
import '../../api/services.dart';
import '../../libelles.dart';
import '../../theme/dimensions.dart';
import '../../theme/palette.dart';
import '../../widgets/boutons.dart';
import '../../widgets/carte.dart';
import '../../widgets/dialogues.dart';
import '../../widgets/entete.dart';
import '../../widgets/etats.dart';
import '../../widgets/formulaires.dart';
import '../../widgets/mise_en_page.dart';

/// Poids d'un symptome dans le diagnostic, en trois niveaux lisibles.
const List<(double, String)> _niveaux = [
  (0.9, 'Typique'),
  (0.6, 'Fréquent'),
  (0.3, 'Possible'),
];

class EcranNouvelleMaladie extends StatelessWidget {
  const EcranNouvelleMaladie({super.key});

  @override
  Widget build(BuildContext context) => Chargeur<List<Symptome>>(
        titreEcran: 'Ajouter une maladie',
        clair: true,
        charger: SignalementApi.tousLesSymptomes,
        construire: (context, symptomes, _) => _Formulaire(symptomes: symptomes),
      );
}

class _Formulaire extends StatefulWidget {
  const _Formulaire({required this.symptomes});
  final List<Symptome> symptomes;

  @override
  State<_Formulaire> createState() => _FormulaireState();
}

class _FormulaireState extends State<_Formulaire> {
  final _cle = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _traitement = TextEditingController();
  final _nouveau = TextEditingController();
  late final List<Symptome> _symptomes = [...widget.symptomes];
  final Set<String> _filieres = {};
  final Map<int, double> _poids = {};
  String _gravite = 'MOYEN';
  bool _orienter = true;
  bool _envoi = false;
  bool _ajoutSymptome = false;

  @override
  void dispose() {
    _nom.dispose();
    _traitement.dispose();
    _nouveau.dispose();
    super.dispose();
  }

  Future<void> _ajouterSymptome() async {
    final libelle = _nouveau.text.trim();
    if (libelle.isEmpty) return;
    setState(() => _ajoutSymptome = true);
    try {
      final s = await SignalementApi.creerSymptome(libelle);
      if (!mounted) return;
      setState(() {
        if (!_symptomes.any((x) => x.id == s.id)) _symptomes.add(s);
        _poids.putIfAbsent(s.id, () => 0.6);
        _nouveau.clear();
      });
    } on ApiException catch (e) {
      if (mounted) await afficherErreur(context, e);
    } finally {
      if (mounted) setState(() => _ajoutSymptome = false);
    }
  }

  Future<void> _enregistrer() async {
    if (!(_cle.currentState?.validate() ?? false)) return;
    if (_filieres.isEmpty) {
      await afficherErreur(context, const ApiException(0, 'Choisissez au moins une filière.'));
      return;
    }
    if (_poids.isEmpty) {
      await afficherErreur(context, const ApiException(0, 'Cochez au moins un symptôme.'));
      return;
    }
    setState(() => _envoi = true);
    try {
      await VeterinaireApi.creerMaladie(
        nom: _nom.text,
        gravite: _gravite,
        filieres: _filieres,
        traitement: _traitement.text,
        orienteVersVeterinaire: _orienter,
        poidsSymptomes: _poids,
      );
      if (!mounted) return;
      await afficherInfo(context, 'Maladie ajoutée',
          message: 'Elle est dans le catalogue et dans vos compétences.', bouton: 'Terminer');
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) await afficherErreur(context, e);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tries = [..._symptomes]..sort((a, b) => a.libelle.compareTo(b.libelle));
    final coches = tries.where((s) => _poids.containsKey(s.id)).toList();
    return EcranSecondaire(
      titre: 'Ajouter une maladie',
      clair: true,
      corps: Form(
        key: _cle,
        child: ListView(
          padding: lisible(context, const EdgeInsets.fromLTRB(Dim.gouttiere, 8, Dim.gouttiere, 24)),
          children: [
            ChampTexte(
              libelle: 'Nom de la maladie',
              controleur: _nom,
              longueurMax: 120,
              indication: 'Ex. : Variole aviaire',
              validateur: (v) => (v == null || v.trim().isEmpty) ? 'Indiquez le nom' : null,
            ),
            const LibelleChamp('Filières touchées'),
            Puces<String>(
              options: [for (final f in L.filieres) (f, L.filiere(f))],
              choisies: _filieres,
              onChange: (v) => setState(() => _filieres
                ..clear()
                ..addAll(v)),
            ),
            const LibelleChamp('Gravité'),
            Segments<String>(
              options: const [('FAIBLE', 'Faible'), ('MOYEN', 'Moyenne'), ('ELEVE', 'Élevée')],
              valeur: _gravite,
              onChange: (v) => setState(() => _gravite = v),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _orienter,
              onChanged: (v) => setState(() => _orienter = v),
              contentPadding: EdgeInsets.zero,
              activeThumbColor: context.couleurs.surMarque,
              activeTrackColor: context.couleurs.marque,
              title: Text('Demande toujours un vétérinaire', style: context.typo.corpsFort),
              subtitle: Text("Le traitement n'est alors pas montré à l'éleveur.",
                  style: context.typo.legende),
            ),
            ChampTexte(
              libelle: 'Traitement (facultatif)',
              controleur: _traitement,
              lignes: 3,
              longueurMax: 2000,
            ),
            const LibelleChamp('Symptômes'),
            Puces<int>(
              options: [for (final s in tries) (s.id, s.libelle)],
              choisies: _poids.keys.toSet(),
              onChange: (v) => setState(() {
                _poids.removeWhere((id, _) => !v.contains(id));
                for (final id in v) {
                  _poids.putIfAbsent(id, () => 0.6);
                }
              }),
            ),
            const SizedBox(height: 12),
            // Un symptome qui n'est pas dans la liste.
            LayoutBuilder(
              builder: (context, c) {
                final champ = TextField(
                  controller: _nouveau,
                  maxLength: 80,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _ajouterSymptome(),
                  style: context.typo.corps,
                  decoration: const InputDecoration(
                    hintText: 'Nouveau symptôme absent de la liste',
                    counterText: '',
                  ),
                );
                final bouton = BoutonSecondaire(_ajoutSymptome ? 'Ajout…' : 'Ajouter',
                    icone: Icons.add,
                    pleineLargeur: c.maxWidth < 360,
                    onPressed: _ajoutSymptome ? null : _ajouterSymptome);
                if (c.maxWidth < 360) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [champ, const SizedBox(height: 8), bouton],
                  );
                }
                return Row(children: [Expanded(child: champ), const SizedBox(width: 8), bouton]);
              },
            ),
            if (coches.isNotEmpty) ...[
              const LibelleChamp('Importance de chaque symptôme'),
              Carte(
                enfant: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final s in coches) ...[
                      Text(s.libelle, style: context.typo.corpsFort),
                      const SizedBox(height: 6),
                      Segments<double>(
                        options: _niveaux,
                        valeur: _poids[s.id],
                        onChange: (v) => setState(() => _poids[s.id] = v),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ],
            const Note("La maladie est ajoutée tout de suite. L'administration pourra la corriger."),
          ],
        ),
      ),
      pied: BoutonPrincipal(_envoi ? 'Enregistrement…' : 'Ajouter la maladie',
          onPressed: _envoi ? null : _enregistrer),
    );
  }
}
