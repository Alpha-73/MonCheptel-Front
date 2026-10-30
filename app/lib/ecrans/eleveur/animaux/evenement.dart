/// Les deux formulaires de la vie d'un elevage, desormais SEPARES (demande
/// du proprietaire, 8 octobre) :
///
///  - [EcranAjouterEvenement] : un EVENEMENT SANITAIRE et rien d'autre
///    (vaccination, traitement, consultation ; « Signaler une maladie »
///    ouvre le parcours de signalement)
///       → POST /api/sanitaire/unites/{id}/evenements
///  - [EcranChangerStatut] : le CHANGEMENT DE STATUT, c'est-a-dire une
///    sortie (vente, mort, transfert) qui retire des tetes
///       → POST /api/cheptel/{id}/sorties
///
/// Les depenses et revenus restent dans « + Opération » (finances). La vente
/// reste une sortie AVEC montant : son revenu est ajoute aux comptes par le
/// back, d'ou l'avertissement de double comptage du formulaire. Une sortie
/// s'annule depuis l'historique du carnet.
///
/// Vente : l'eleveur saisit le PRIX PAR TETE, l'application calcule le total
/// (prix x nombre de sujets) et c'est ce total qui part au back. Un prix a
/// zero est refuse (audit F8) ; les dates ne peuvent preceder l'entree de
/// l'unite (audit F11, cote app).
library;

import 'package:flutter/material.dart';

import '../../../api/client_api.dart';
import '../../../api/modeles.dart';
import '../../../api/services.dart';
import '../../../libelles.dart';
import '../../../theme/format.dart';
import '../../../theme/palette.dart';
import '../../../widgets/boutons.dart';
import '../../../widgets/carte.dart';
import '../../../widgets/dialogues.dart';
import '../../../widgets/entete.dart';
import '../../../widgets/formulaires.dart';
import '../sante/signalement.dart';

/// Total d'une vente : prix par tete x nombre de sujets vendus. Nul tant
/// que l'un des deux manque ou n'est pas strictement positif.
int? totalVente({required int? prixUnitaire, required int? nombre}) {
  if (prixUnitaire == null || nombre == null || prixUnitaire <= 0 || nombre <= 0) return null;
  return prixUnitaire * nombre;
}

/// Code du choix « Signaler une maladie » dans les tuiles sanitaires : il
/// ouvre le parcours de signalement au lieu d'un formulaire de soin.
const String codeSignaler = 'SIGNALER';

/// Un type a choisir : code, libelle, icone, encre et fond de la pastille.
typedef TypeTuile = (String code, String libelle, IconData icone, Color encre, Color fond);

/// Les quatre gestes sanitaires, dans l'ordre de l'accueil.
List<TypeTuile> typesSanitaires(PaletteMonCheptel c) => [
      (codeSignaler, 'Signaler une maladie', Icons.sick_outlined, c.erreur, c.fondErreurPale),
      ('TRAITEMENT', 'Traitement', Icons.medication_outlined, c.sante, c.fondMarquePale),
      ('CONSULTATION', 'Consultation', Icons.medical_services_outlined, c.sante, c.fondMarquePale),
      ('VACCINATION', 'Vaccination', Icons.vaccines_outlined, c.sante, c.fondMarquePale),
    ];

/// Les trois changements de statut (sorties).
List<TypeTuile> typesStatut(PaletteMonCheptel c) => [
      ('VENTE', 'Vente', Icons.sell_outlined, c.marque, c.fondMarquePale),
      ('MORT', 'Mort', Icons.heart_broken_outlined, c.texteDiscret, c.sable),
      ('TRANSFERT', 'Don, transfert', Icons.swap_horiz_rounded, c.attentionTexte, c.fondAccentPale),
    ];

// ════════════════════════════════════════════════════════════════════════
// Evenement sanitaire
// ════════════════════════════════════════════════════════════════════════

class EcranAjouterEvenement extends StatefulWidget {
  const EcranAjouterEvenement({super.key, required this.unite, this.type});
  final Unite unite;

  /// Type preselectionne (« Vaccination » choisi sur l'accueil).
  final String? type;

  @override
  State<EcranAjouterEvenement> createState() => _EcranAjouterEvenementState();
}

class _EcranAjouterEvenementState extends State<EcranAjouterEvenement> {
  final _cle = GlobalKey<FormState>();
  final _observation = TextEditingController();
  final _rappel = TextEditingController();
  late String? _type = widget.type == codeSignaler ? null : widget.type;
  DateTime _date = DateTime.now();
  String? _erreurType;
  bool _envoi = false;

  @override
  void dispose() {
    _observation.dispose();
    _rappel.dispose();
    super.dispose();
  }

  void _choisir(String t) {
    if (t == codeSignaler) {
      // Une maladie se signale par ses symptomes : le parcours dedie
      // remplace ce formulaire.
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
          builder: (_) => EcranSignalementSymptomes(unite: widget.unite)));
      return;
    }
    setState(() {
      _type = t;
      _erreurType = null;
    });
  }

  Future<void> _enregistrer() async {
    setState(() => _erreurType = _type == null ? 'Choisissez le soin' : null);
    if (!_cle.currentState!.validate() || _type == null) return;
    setState(() => _envoi = true);
    try {
      await SanitaireApi.ajouterEvenement(
        widget.unite.id,
        type: _type!,
        date: _date,
        produitObservation: _observation.text,
        rappelDansJours: int.tryParse(_rappel.text.trim()),
      );
      if (!mounted) return;
      // Confirmation non bloquante : un appui de moins qu'une pop-up.
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${L.typeEvenement(_type!)} : c’est noté.')));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) await afficherErreur(context, e);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.unite;
    return EcranSecondaire(
      titre: 'Événement sanitaire',
      sousTitre: u.code,
      corps: CorpsFormulaire(cle: _cle, enfants: [
        const LibelleChamp('Que s’est-il passé ?'),
        GrilleTypes(types: typesSanitaires(context.couleurs), actif: _type, onChoix: _choisir),
        if (_erreurType != null) _MessageErreur(_erreurType!),
        const SizedBox(height: 16),
        if (_type != null) ...[
          ChampDate(
            libelle: 'Date du soin',
            valeur: _date,
            premiere: u.dateEntree,
            derniere: DateTime.now(),
            onChange: (d) => setState(() => _date = d),
          ),
          ChampTexte(
            libelle: 'Produit, remarque (facultatif)',
            controleur: _observation,
            indication: 'Ex : vaccin Newcastle HB1, dose de rappel',
            lignes: 3,
            longueurMax: 255,
          ),
          ChampTexte(
            libelle: 'Prochain soin dans combien de jours ? (facultatif)',
            controleur: _rappel,
            indication: 'Ex : 21',
            chiffresSeulement: true,
            longueurMax: 4,
          ),
        ],
      ]),
      pied: _PiedFormulaire(envoi: _envoi, onEnregistrer: _enregistrer),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// Changement de statut (sortie)
// ════════════════════════════════════════════════════════════════════════

class EcranChangerStatut extends StatefulWidget {
  const EcranChangerStatut(
      {super.key, required this.unite, this.type, this.toutesLesTetes = false});
  final Unite unite;

  /// `VENTE`, `MORT` ou `TRANSFERT` choisi d'avance (« Vendre » du carnet).
  final String? type;

  /// Ouvert depuis « Clôturer » d'un lot qui a encore des tetes (audit
  /// global G5) : toutes les tetes restantes sont preremplies, leur sortie
  /// clot le lot.
  final bool toutesLesTetes;

  @override
  State<EcranChangerStatut> createState() => _EcranChangerStatutState();
}

class _EcranChangerStatutState extends State<EcranChangerStatut> {
  final _cle = GlobalKey<FormState>();
  final _observation = TextEditingController();
  final _tetes = TextEditingController();
  final _prix = TextEditingController();
  late String? _type = widget.type;
  DateTime _date = DateTime.now();
  String? _erreurType;
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    // L'encart « LOT-014 passera de 180 a 150 tetes » et le total de la
    // vente suivent la saisie.
    if (widget.toutesLesTetes && widget.unite.estLot) {
      _tetes.text = '${widget.unite.effectifRestant}';
    }
    _tetes.addListener(_rafraichir);
    _prix.addListener(_rafraichir);
  }

  void _rafraichir() => setState(() {});

  @override
  void dispose() {
    for (final c in [_observation, _tetes, _prix]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Nombre de tetes qui sortent : saisi pour un lot, toujours 1 pour un
  /// animal.
  int? get _nombreTetes => widget.unite.estLot ? int.tryParse(_tetes.text.trim()) : 1;

  int? get _total =>
      totalVente(prixUnitaire: int.tryParse(_prix.text.trim()), nombre: _nombreTetes);

  Future<void> _enregistrer() async {
    setState(() => _erreurType = _type == null ? 'Choisissez le nouveau statut' : null);
    if (!_cle.currentState!.validate() || _type == null) return;
    setState(() => _envoi = true);
    final u = widget.unite;
    final total = _type == 'VENTE' ? _total : null;
    try {
      await CheptelApi.sortie(
        u.id,
        type: _type!,
        nombreTetes: _nombreTetes!,
        date: _date,
        montant: total,
        motif: _observation.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(switch (_type) {
          'VENTE' => 'Vente de ${Fmt.fcfa(total ?? 0)} enregistrée et ajoutée à vos revenus. '
              'Pour l’annuler : historique du carnet.',
          'MORT' => 'Perte enregistrée. Pour l’annuler : historique du carnet.',
          _ => 'Transfert enregistré. Pour l’annuler : historique du carnet.',
        }),
      ));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) await afficherErreur(context, e);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.unite;
    return EcranSecondaire(
      titre: 'Changer le statut',
      sousTitre: u.code,
      corps: CorpsFormulaire(cle: _cle, enfants: [
        LibelleChamp(u.estLot ? 'Des animaux sortent du lot' : '${u.code} sort du cheptel'),
        GrilleTypes(
          types: typesStatut(context.couleurs),
          actif: _type,
          onChoix: (t) => setState(() {
            _type = t;
            _erreurType = null;
          }),
        ),
        if (_erreurType != null) _MessageErreur(_erreurType!),
        const SizedBox(height: 16),
        if (_type != null) ..._champs(u),
      ]),
      pied: _PiedFormulaire(envoi: _envoi, onEnregistrer: _enregistrer),
    );
  }

  List<Widget> _champs(Unite u) {
    final n = _nombreTetes;
    final reste = n == null ? null : u.effectifRestant - n;
    final vente = _type == 'VENTE';
    final total = _total;
    return [
      if (u.estLot)
        ChampTexte(
          libelle: switch (_type) {
            'VENTE' => 'Nombre de têtes vendues',
            'MORT' => 'Nombre de têtes mortes',
            _ => 'Nombre de têtes transférées',
          },
          controleur: _tetes,
          chiffresSeulement: true,
          longueurMax: 6,
          validateur: (v) {
            final e = Valider.entierPositif(v, 'Le nombre de têtes');
            if (e != null) return e;
            return int.parse(v!.trim()) > u.effectifRestant
                ? 'Le lot ne compte que ${Fmt.tetes(u.effectifRestant)}'
                : null;
          },
        ),
      ChampDate(
        libelle: 'Date',
        valeur: _date,
        premiere: u.dateEntree,
        derniere: DateTime.now(),
        onChange: (d) => setState(() => _date = d),
      ),
      if (vente) ...[
        ChampTexte(
          libelle: u.estLot ? 'Prix par tête (FCFA)' : 'Prix de vente (FCFA)',
          controleur: _prix,
          chiffresSeulement: true,
          longueurMax: 9,
          indication: u.estLot ? 'Ex : 2 500' : 'Ex : 350 000',
          // Audit F8 : 0 FCFA n'est pas une vente (le back le refuse).
          validateur: (v) => Valider.entierPositif(v, 'Le prix'),
        ),
        if (u.estLot) _TotalVente(total: total, prix: int.tryParse(_prix.text.trim()), nombre: n),
        // Le revenu de la vente est cree par le back : le noter aussi dans
        // « + Opération » le compterait deux fois.
        const Encart(
          titre: 'Le revenu est ajouté à vos comptes automatiquement.',
          detail: 'Ne notez pas cette vente une deuxième fois dans « + Opération ».',
          ton: TonEncart.attention,
        ),
        const SizedBox(height: 12),
      ],
      ChampTexte(
        libelle: 'Remarque (facultatif)',
        controleur: _observation,
        indication: vente ? 'Ex : vendu au marché de Koutiala' : 'Ex : chaleur, transport',
        longueurMax: 255,
      ),
      if (u.estLot && reste != null && reste >= 0)
        Encart(
          titre: '${u.code} : ${Fmt.tetes(u.effectifRestant)} → ${Fmt.tetes(reste)}',
          detail: reste == 0 ? 'Le lot sera clôturé.' : null,
        ),
      if (!u.estLot)
        Encart(
          titre: '${u.code} sortira du cheptel.',
          detail: 'Son carnet reste consultable.',
        ),
    ];
  }
}

/// « 2 500 × 30 têtes = 75 000 FCFA », mis a jour a chaque chiffre tape.
class _TotalVente extends StatelessWidget {
  const _TotalVente({required this.total, required this.prix, required this.nombre});
  final int? total;
  final int? prix;
  final int? nombre;

  @override
  Widget build(BuildContext context) {
    final c = context.couleurs;
    final calcul = prix != null && nombre != null && total != null
        ? '${Fmt.montant(prix!)} × ${Fmt.tetes(nombre!)}'
        : 'Prix par tête × nombre de têtes';
    return Semantics(
      liveRegion: true,
      label: total == null ? 'Total de la vente : à calculer' : 'Total de la vente : ${Fmt.fcfa(total!)}',
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.fondMarquePale,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Icon(Icons.calculate_outlined, color: c.marque, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total de la vente', style: context.typo.legendeForte),
              Text(total == null ? '—' : Fmt.fcfa(total!),
                  style: context.typo.chiffre.copyWith(color: c.marque)),
              Text(calcul, style: context.typo.legende),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _MessageErreur extends StatelessWidget {
  const _MessageErreur(this.texte);
  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(texte,
            style: context.typo.legendeForte.copyWith(color: context.couleurs.erreur)),
      );
}

class _PiedFormulaire extends StatelessWidget {
  const _PiedFormulaire({required this.envoi, required this.onEnregistrer});
  final bool envoi;
  final VoidCallback onEnregistrer;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: BoutonSecondaire('Annuler',
                onPressed: envoi ? null : () => Navigator.of(context).pop()),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: BoutonPrincipal(envoi ? 'Envoi…' : 'Enregistrer',
                onPressed: envoi ? null : onEnregistrer),
          ),
        ],
      );
}

/// Grandes tuiles de type : 64 px de haut au moins, l'actif en vert plein
/// avec une coche. Deux colonnes sur telephone, trois ou quatre au-dela.
class GrilleTypes extends StatelessWidget {
  const GrilleTypes({super.key, required this.types, required this.actif, required this.onChoix});
  final List<TypeTuile> types;
  final String? actif;
  final ValueChanged<String> onChoix;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, contraintes) {
        final c = context.couleurs;
        final colonnes = contraintes.maxWidth >= 720 ? 4 : contraintes.maxWidth >= 520 ? 3 : 2;
        final largeur = (contraintes.maxWidth - 10 * (colonnes - 1)) / colonnes;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          for (final (code, libelle, icone, encre, fond) in types)
            SizedBox(
              width: largeur,
              child: Semantics(
                button: true,
                selected: code == actif,
                label: libelle,
                excludeSemantics: true,
                child: Material(
                  color: code == actif ? c.marque : c.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: code == actif ? c.marque : c.filetLeger),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onChoix(code),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 64),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Row(children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: code == actif ? c.surMarque.withAlpha(0x26) : fond,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(code == actif ? Icons.check_rounded : icone,
                                color: code == actif ? c.surMarque : encre),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(libelle,
                                style: context.typo.corpsFort.copyWith(
                                    color: code == actif ? c.surMarque : c.texte, height: 1.2)),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ]);
      });
}

// ── Modification d'un soin ────────────────────────────────────────────────

class EcranModifierEvenement extends StatefulWidget {
  const EcranModifierEvenement({super.key, required this.evenement});
  final Evenement evenement;

  @override
  State<EcranModifierEvenement> createState() => _EcranModifierEvenementState();
}

class _EcranModifierEvenementState extends State<EcranModifierEvenement> {
  final _cle = GlobalKey<FormState>();
  late final _observation =
      TextEditingController(text: widget.evenement.produitObservation);
  late String _type = widget.evenement.type;
  late DateTime _date = widget.evenement.dateEvenement ?? DateTime.now();
  bool _envoi = false;

  @override
  void dispose() {
    _observation.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    setState(() => _envoi = true);
    try {
      await SanitaireApi.modifierEvenement(widget.evenement.id,
          type: _type, date: _date, produitObservation: _observation.text);
      if (!mounted) return;
      await afficherInfo(context, 'Événement modifié');
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) await afficherErreur(context, e);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Future<void> _supprimer() async {
    final ok = await confirmer(context, 'Supprimer cet événement ?',
        message: 'Il disparaîtra du carnet sanitaire.',
        confirmer: 'Supprimer',
        destructif: true);
    if (!ok || !mounted) return;
    try {
      await SanitaireApi.supprimerEvenement(widget.evenement.id);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) await afficherErreur(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => EcranSecondaire(
        titre: "Modifier l'événement",
        corps: CorpsFormulaire(cle: _cle, enfants: [
          ChampChoix<String>(
            libelle: "Type d'événement",
            valeur: _type,
            options: [
              for (final t in L.typesEvenement)
                (valeur: t, libelle: L.typeEvenement(t), detail: null),
            ],
            onChange: (t) => setState(() => _type = t),
          ),
          ChampDate(
            libelle: 'Date',
            valeur: _date,
            derniere: DateTime.now(),
            onChange: (d) => setState(() => _date = d),
          ),
          ChampTexte(
            libelle: 'Produit et observation',
            controleur: _observation,
            lignes: 3,
            longueurMax: 255,
          ),
          const SizedBox(height: 8),
          BoutonDestructif('Supprimer cet événement', onPressed: _envoi ? null : _supprimer),
        ]),
        pied: BoutonPrincipal(_envoi ? 'Enregistrement…' : 'Enregistrer',
            onPressed: _envoi ? null : _enregistrer),
      );
}
