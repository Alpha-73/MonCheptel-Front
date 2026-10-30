/// Simulateur « Où investir ? » : budget, options par type d'elevage,
/// detail poste par poste.
///
/// Sources : POST /api/investissement/simulation (une option par type
/// d'elevage) et POST /api/investissement/simulation/{typeElevageId} (le
/// detail poste par poste). Tous les montants sont calcules par le back a
/// partir du referentiel tenu par l'administration ; l'ecran n'additionne
/// rien lui-meme.
///
/// Refonte (audit L10, F16, F18) :
///  - l'eleveur peut partir d'un objectif (« 100 poulets ») : `sujetsVises` ;
///  - chaque option dit pour combien de sujets elle est dimensionnee, et
///    combien en acheter (mortalite comprise) ;
///  - hors budget, on montre le budget minimum au lieu d'un « 1 sujet » ;
///  - « Créer ce lot » preremplit l'effectif.
library;

import 'package:flutter/material.dart';

import '../../../api/modeles.dart';
import '../../../api/services.dart';
import '../../../libelles.dart';
import '../../../theme/palette.dart';
import '../../../theme/dimensions.dart';
import '../../../theme/format.dart';
import '../../../widgets/boutons.dart';
import '../../../widgets/carte.dart';
import '../../../widgets/eleveur/pictos.dart';
import '../../../widgets/entete.dart';
import '../../../widgets/etats.dart';
import '../../../widgets/formulaires.dart';
import '../../../widgets/navigation.dart';
import '../../../widgets/pastille.dart';
import '../../../widgets/vivant.dart';
import '../animaux/ajouter_unite.dart';
import 'logistique.dart';
import '../../../widgets/mise_en_page.dart';

/// « 1 sujet », « 33 sujets ».
String sujets(int n) => '${Fmt.montant(n)} sujet${n > 1 ? 's' : ''}';

// ── 1. Budget ─────────────────────────────────────────────────────────────

class EcranInvestir extends StatefulWidget {
  const EcranInvestir({super.key});

  @override
  State<EcranInvestir> createState() => _EcranInvestirState();
}

class _EcranInvestirState extends State<EcranInvestir> {
  static const _rapides = [25000, 50000, 100000, 250000, 500000, 1000000];
  final _cle = GlobalKey<FormState>();
  final _budget = TextEditingController(text: '50000');
  final _objectif = TextEditingController();
  bool _installation = false;

  @override
  void initState() {
    super.initState();
    _budget.addListener(_rafraichir);
  }

  void _rafraichir() => setState(() {});

  @override
  void dispose() {
    _budget.dispose();
    _objectif.dispose();
    super.dispose();
  }

  void _voir() {
    if (!_cle.currentState!.validate()) return;
    ouvrir<void>(
      context,
      EcranOptions(
        budget: int.parse(_budget.text.trim()),
        installation: _installation,
        sujetsVises: int.tryParse(_objectif.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => EcranSecondaire(
        titre: 'Où investir ?',
        corps: CorpsFormulaire(cle: _cle, enfants: [
          Text('Combien pouvez-vous investir ?', style: context.typo.titreSection),
          const SizedBox(height: 12),
          ChampTexte(
            libelle: 'Votre budget (FCFA)',
            controleur: _budget,
            chiffresSeulement: true,
            longueurMax: 10,
            validateur: (v) {
              final n = int.tryParse((v ?? '').trim());
              if (n == null) return 'Indiquez un montant';
              // `@Min(1000)` cote back.
              if (n < 1000) return 'Au moins 1 000 FCFA';
              return null;
            },
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in _rapides)
                _PuceMontant(
                  texte: Fmt.montant(m),
                  libelle: Fmt.fcfa(m),
                  actif: _budget.text.trim() == '$m',
                  onTap: () => _budget.text = '$m',
                ),
            ],
          ),
          const SizedBox(height: 20),
          ChampTexte(
            libelle: "Combien d'animaux voulez-vous ? (facultatif)",
            controleur: _objectif,
            indication: 'Ex : 100',
            chiffresSeulement: true,
            longueurMax: 6,
            validateur: (v) {
              if (v == null || v.trim().isEmpty) return null;
              return Valider.entierPositif(v, 'Le nombre');
            },
          ),
          const SizedBox(height: 4),
          _Bascule(
            valeur: _installation,
            titre: 'Compter le bâtiment et le matériel',
            detail: 'Laissez éteint si vous les avez déjà.',
            onChange: (v) => setState(() => _installation = v),
          ),
          const Note('Animaux, aliment et soins du premier cycle. Prix indicatifs.'),
        ]),
        pied: BoutonPrincipal('Voir mes options', icone: Icons.arrow_forward_rounded,
            iconeApres: true, onPressed: _voir),
      );
}

class _PuceMontant extends StatelessWidget {
  const _PuceMontant(
      {required this.texte, required this.libelle, required this.actif, required this.onTap});
  final String texte;
  final String libelle;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: actif,
        label: libelle,
        excludeSemantics: true,
        child: Material(
          color: actif ? context.couleurs.marque : context.couleurs.surface,
          shape: StadiumBorder(
              side: BorderSide(color: actif ? context.couleurs.marque : context.couleurs.filetLeger)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              child: Text(texte,
                  style: context.typo.corpsFort
                      .copyWith(color: actif ? context.couleurs.surMarque : context.couleurs.encreFonce)),
            ),
          ),
        ),
      );
}

class _Bascule extends StatelessWidget {
  const _Bascule(
      {required this.valeur, required this.titre, required this.detail, required this.onChange});
  final bool valeur;
  final String titre;
  final String detail;
  final ValueChanged<bool> onChange;

  @override
  Widget build(BuildContext context) => Material(
        color: context.couleurs.surface,
        borderRadius: BorderRadius.circular(16),
        child: SwitchListTile(
          value: valeur,
          onChanged: onChange,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          activeThumbColor: context.couleurs.surMarque,
          activeTrackColor: context.couleurs.marque,
          secondary: Icon(Icons.warehouse_outlined, color: context.couleurs.marque),
          title: Text(titre, style: context.typo.corpsFort),
          subtitle: Text(detail, style: context.typo.legende),
        ),
      );
}

// ── 2. Options ────────────────────────────────────────────────────────────

class EcranOptions extends StatelessWidget {
  const EcranOptions(
      {super.key, required this.budget, required this.installation, this.sujetsVises});
  final int budget;
  final bool installation;
  final int? sujetsVises;

  @override
  Widget build(BuildContext context) => Chargeur<SimulationInvestissement>(
        titreEcran: 'Mes options',
        charger: () => SimulateurApi.simuler(budget,
            inclureInstallation: installation, sujetsVises: sujetsVises),
        construire: (context, s, _) {
          final accessibles = s.options.where((o) => o.realisable).length;
          return EcranSecondaire(
            titre: 'Mes options',
            sousTitre: [
              'Budget : ${Fmt.fcfa(s.budget)}',
              if (sujetsVises != null) 'objectif : ${sujets(sujetsVises!)}',
            ].join(' · '),
            corps: ListView(
              padding: lisible(context, const EdgeInsets.fromLTRB(Dim.gouttiere, Dim.gouttiere, Dim.gouttiere, 32)),
              children: [
                Text(
                  accessibles == 0
                      ? 'Aucune option dans votre budget'
                      : '$accessibles option${accessibles > 1 ? 's' : ''} dans votre budget',
                  style: context.typo.titreSection,
                ),
                Text(
                  s.installationIncluse ? 'Bâtiment et matériel compris' : 'Sans bâtiment ni matériel',
                  style: context.typo.corpsDiscret,
                ),
                const SizedBox(height: 12),
                if (s.options.isEmpty)
                  const EtatVide("Aucun type d'élevage n'est renseigné pour le moment."),
                for (var i = 0; i < s.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Apparition(
                      rang: i,
                      child: _CarteOption(
                        option: s.options[i],
                        installation: s.installationIncluse,
                        onTap: () => ouvrir<void>(
                            context,
                            EcranDetailInvestissement(
                                option: s.options[i],
                                budget: budget,
                                installation: installation,
                                sujetsVises: sujetsVises)),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
}

class _CarteOption extends StatelessWidget {
  const _CarteOption({required this.option, required this.installation, required this.onTap});
  final OptionInvestissement option;
  final bool installation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final o = option;
    final cout = installation ? o.coutTotal : o.coutCycle;
    final ecart = o.ecartBudget;
    return Pressable(
      onTap: onTap,
      rayon: 18,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VignetteAnimal(filiere: o.filiere, taille: 52, actif: o.realisable),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(o.libelle, style: context.typo.corpsFort),
                  const SizedBox(height: 2),
                  // Le dimensionnement : pour combien d'animaux, combien a acheter.
                  Text(
                    [
                      'Pour ${sujets(o.sujetsVises)}',
                      if (o.sujetsAAcheter > o.sujetsVises) '${Fmt.montant(o.sujetsAAcheter)} à acheter',
                    ].join(' · '),
                    style: context.typo.legende,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${Fmt.fcfa(cout)} ${installation ? 'au total' : 'par cycle'}',
                    style: context.typo.chiffre.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    Pastille(L.difficulte(o.difficulte), ton: L.tonDifficulte(o.difficulte)),
                    Pastille(
                      ecart >= 0 ? 'Il reste ${Fmt.fcfa(ecart)}' : 'Il manque ${Fmt.fcfa(-ecart)}',
                      ton: ecart >= 0 ? TonPastille.marque : TonPastille.erreur,
                    ),
                  ]),
                  if (!o.realisable) ...[
                    const SizedBox(height: 6),
                    Text('Budget minimum : ${Fmt.fcfa(cout)}', style: context.typo.legendeForte),
                  ],
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

// ── 3. Detail ─────────────────────────────────────────────────────────────

class EcranDetailInvestissement extends StatelessWidget {
  const EcranDetailInvestissement({
    super.key,
    required this.option,
    required this.budget,
    required this.installation,
    this.sujetsVises,
  });
  final OptionInvestissement option;
  final int budget;
  final bool installation;
  final int? sujetsVises;

  @override
  Widget build(BuildContext context) => Chargeur<DetailSimulation>(
        titreEcran: 'Détail',
        charger: () => SimulateurApi.detail(option.typeElevageId, budget,
            inclureInstallation: installation, sujetsVises: sujetsVises),
        construire: (context, d, _) {
          final o = d.option;
          final lot = L.suiviParLot(o.filiere);
          return EcranSecondaire(
            titre: 'Démarrer en ${L.filiere(o.filiere).toLowerCase()}',
            sousTitre: 'Ce que ça coûte vraiment',
            corps: ListView(
              padding: lisible(context, const EdgeInsets.fromLTRB(Dim.gouttiere, Dim.gouttiere, Dim.gouttiere, 32)),
              children: [
                Row(children: [
                  VignetteAnimal(filiere: o.filiere, taille: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(o.libelle, style: context.typo.titreSection),
                      Text(
                        [
                          L.difficulte(o.difficulte),
                          if (o.dureeCycleJours != null) 'cycle de ${o.dureeCycleJours} jours',
                        ].join(' · '),
                        style: context.typo.corpsDiscret,
                      ),
                    ]),
                  ),
                ]),
                const SizedBox(height: 16),
                // Dimensionnement, en tete : tout le reste en decoule.
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: context.couleurs.fondMarquePale, borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    Icon(Icons.straighten_rounded, color: context.couleurs.marque),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        o.sujetsAAcheter > o.sujetsVises
                            ? 'Prévu pour ${sujets(o.sujetsVises)}. Achetez-en '
                                '${Fmt.montant(o.sujetsAAcheter)} : '
                                '${Fmt.montant(o.sujetsAAcheter - o.sujetsVises)} de plus '
                                'pour les pertes habituelles.'
                            : 'Prévu pour ${sujets(o.sujetsVises)}.',
                        style: context.typo.corpsFort,
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                Text('À chaque cycle', style: context.typo.titreSection),
                const SizedBox(height: 6),
                Carte(
                  enfant: Column(children: [
                    for (final p in d.postesCycle) _LignePoste(poste: p),
                    const Divider(),
                    LigneValeur('Total du cycle', Fmt.fcfa(o.coutCycle), fort: true),
                  ]),
                ),
                if (d.postesInstallation.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Installation, une seule fois', style: context.typo.titreSection),
                  const SizedBox(height: 6),
                  Carte(
                    enfant: Column(children: [
                      for (final p in d.postesInstallation) _LignePoste(poste: p),
                      const Divider(),
                      LigneValeur("Total de l'installation", Fmt.fcfa(o.coutInstallation),
                          fort: true),
                    ]),
                  ),
                ],
                const SizedBox(height: 12),
                Encart(
                  titre: 'En partant de zéro : ${Fmt.fcfa(o.coutCycle + o.coutInstallation)}',
                  detail: 'Déjà équipé : ${Fmt.fcfa(o.coutCycle)} suffisent.',
                ),
              ],
            ),
            pied: Row(
              children: [
                Expanded(
                  child: BoutonSecondaire('Logistique',
                      onPressed: () =>
                          ouvrir<void>(context, EcranLogistique(filiere: o.filiere))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: BoutonPrincipal(lot ? 'Créer ce lot' : 'Ajouter cet animal',
                      onPressed: () => ouvrir<void>(
                          context,
                          EcranAjouterUnite(
                            filiere: o.filiere,
                            typeElevageId: o.typeElevageId,
                            // Audit F16 : l'effectif achete, mortalite comprise.
                            effectifPropose: lot ? o.sujetsAAcheter : null,
                          ))),
                ),
              ],
            ),
          );
        },
      );
}

class _LignePoste extends StatelessWidget {
  const _LignePoste({required this.poste});
  final LignePoste poste;

  /// « 59,4 kg », « 33 », « 1 ».
  static String _quantite(double q, String? unite) {
    final texte = q == q.roundToDouble()
        ? q.toStringAsFixed(0)
        : q.toStringAsFixed(1).replaceAll('.', ',');
    return unite == null || unite.isEmpty ? texte : '$texte $unite';
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(poste.libelle, style: context.typo.corps),
                  Text(
                      '${_quantite(poste.quantite, poste.unite)} × '
                      '${Fmt.fcfa(poste.montantUnitaire)}',
                      style: context.typo.legende),
                ],
              ),
            ),
            Text(Fmt.fcfa(poste.montant), style: context.typo.corpsFort),
          ],
        ),
      );
}
