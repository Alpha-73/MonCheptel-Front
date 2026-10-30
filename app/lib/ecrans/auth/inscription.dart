/// Maquette : « CreerCompte - Zone ouverte » (etape 1), « CreerCompte -
/// Etape 2 » et la pop-up « Compte cree ».
///
/// Ecarts assumes avec la maquette, tous dictes par le contrat du back :
///  - Nom et Prenom sont deux champs a l'ecran, mais le back n'a qu'un
///    `nom` : on envoie « Prénom Nom ».
///  - Le choix de langue de l'etape 1 est retire : `InscriptionRequete` n'a
///    pas de champ langue, et le bambara n'est pas encore traduit (« Bientôt
///    disponible » sur l'ecran Langue). Le garder serait un bouton qui ne
///    fait rien.
///  - Un champ Telephone (facultatif) est ajoute : le veterinaire oriente
///    vers l'eleveur l'appelle a ce numero (`eleveurTelephone` du
///    signalement). Sans lui, il n'a aucun moyen de le joindre.
library;

import 'package:flutter/material.dart';

import '../../api/client_api.dart';
import '../../api/modeles.dart';
import '../../api/services.dart';
import '../../libelles.dart';
import '../../theme/palette.dart';
import '../../theme/dimensions.dart';
import '../../widgets/boutons.dart';
import '../../widgets/dialogues.dart';
import '../../widgets/etats.dart';
import '../../widgets/formulaires.dart';
import '../../widgets/vivant.dart';
import '../demarrage.dart';
import '../eleveur/sante/vocabulaire_sante.dart';
import 'heros_marque.dart';
import '../../widgets/mise_en_page.dart';

class EcranInscription extends StatefulWidget {
  const EcranInscription({super.key});

  @override
  State<EcranInscription> createState() => _EcranInscriptionState();
}

class _EcranInscriptionState extends State<EcranInscription> {
  final _cle1 = GlobalKey<FormState>();
  final _cle2 = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _prenom = TextEditingController();
  final _email = TextEditingController();
  final _telephone = TextEditingController();
  final _motDePasse = TextEditingController();
  final _confirmation = TextEditingController();

  int _etape = 1;
  int? _zoneId;
  String? _erreurZone;
  Set<String> _filieres = {};
  String? _erreurFilieres;
  bool _cgu = false;
  bool _envoi = false;

  late Future<List<ZoneGeo>> _zones = ReferentielApi.zones();

  @override
  void dispose() {
    for (final c in [_nom, _prenom, _email, _telephone, _motDePasse, _confirmation]) {
      c.dispose();
    }
    super.dispose();
  }

  void _continuer() {
    final champsOk = _cle1.currentState!.validate();
    setState(() => _erreurZone = _zoneId == null ? 'Choisissez votre zone' : null);
    if (champsOk && _zoneId != null) setState(() => _etape = 2);
  }

  Future<void> _creer() async {
    final champsOk = _cle2.currentState!.validate();
    setState(() => _erreurFilieres =
        _filieres.isEmpty ? 'Choisissez au moins une filière' : null);
    if (!champsOk || _filieres.isEmpty) return;
    if (!_cgu) {
      await afficherErreur(
          context,
          const ApiException(0,
              "Vous devez accepter les conditions d'utilisation pour créer un compte."),
          titre: 'Conditions non acceptées');
      return;
    }
    setState(() => _envoi = true);
    try {
      final session = await AuthApi.inscription(
        nom: '${_prenom.text.trim()} ${_nom.text.trim()}'.trim(),
        email: _email.text,
        telephone: _telephone.text,
        zoneId: _zoneId!,
        filieres: _filieres,
        motDePasse: _motDePasse.text,
      );
      if (!mounted) return;
      await afficherInfo(context, 'Compte créé',
          message: 'Bienvenue sur MonCheptel.', bouton: 'Commencer');
      if (!mounted) return;
      ouvrirEspace(context, session);
    } on ApiException catch (e) {
      if (!mounted) return;
      // 409 : adresse deja prise. On renvoie a l'etape 1 pour la corriger.
      if (e.statut == 409) setState(() => _etape = 1);
      await afficherErreur(context, e, titre: 'Inscription impossible');
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pied = _etape == 1
        ? BoutonPrincipal('Continuer',
            icone: Icons.arrow_forward_rounded, iconeApres: true, onPressed: _continuer)
        : Row(
            children: [
              Expanded(
                child: BoutonSecondaire('Retour',
                    onPressed: _envoi ? null : () => setState(() => _etape = 1)),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: BoutonPrincipal(_envoi ? 'Création…' : 'Créer mon compte',
                    onPressed: _envoi ? null : _creer),
              ),
            ],
          );
    return Scaffold(
      backgroundColor: context.couleurs.fond,
      body: Form(
        key: _etape == 1 ? _cle1 : _cle2,
        child: ListView(
          // Heros pleine largeur ; formulaire centre dans une colonne
          // lisible, du petit Android a la tablette.
          padding: EdgeInsets.zero,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            const HerosMarque(compact: true, titre: 'Créer un compte', retour: true),
            ColonneFormulaire(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Dim.gouttiere, 4, Dim.gouttiere, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Avancement(etape: _etape),
                    const SizedBox(height: 18),
                    ...(_etape == 1 ? _etape1() : _etape2()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Dim.gouttiere, 8, Dim.gouttiere, 12),
            child: ColonneFormulaire(
                child: Material(type: MaterialType.transparency, child: pied)),
          ),
        ),
      ),
    );
  }

  List<Widget> _etape1() => [
        // Prenom et Nom cote a cote quand la place le permet, l'un sous
        // l'autre sur un petit ecran ou avec un texte agrandi.
        LayoutBuilder(builder: (context, c) {
          final prenom = ChampTexte(
              libelle: 'Prénom',
              controleur: _prenom,
              longueurMax: 59,
              validateur: (v) => Valider.requis(v, 'Obligatoire'));
          final nom = ChampTexte(
              libelle: 'Nom',
              controleur: _nom,
              longueurMax: 60,
              validateur: (v) => Valider.requis(v, 'Obligatoire'));
          final etroit = c.maxWidth < 360 || MediaQuery.textScalerOf(context).scale(1) > 1.3;
          if (etroit) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, children: [prenom, nom]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: prenom),
              const SizedBox(width: 12),
              Expanded(child: nom),
            ],
          );
        }),
        ChampTexte(
          libelle: 'Téléphone (facultatif)',
          controleur: _telephone,
          indication: '+223 70 00 00 00',
          icone: Icons.phone_outlined,
          clavier: TextInputType.phone,
          longueurMax: 20,
        ),
        // Le back exige l'adresse (InscriptionRequete : @NotBlank @Email) :
        // c'est l'identifiant de connexion. On dit a quoi elle sert.
        ChampTexte(
          libelle: 'Adresse e-mail',
          controleur: _email,
          indication: 'vous@exemple.ml',
          icone: Icons.mail_outline,
          clavier: TextInputType.emailAddress,
          longueurMax: 160,
          validateur: Valider.email,
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
              'Elle sert à vous connecter et à recevoir un code si vous oubliez votre mot de passe.',
              style: context.typo.corpsDiscret),
        ),
        const SizedBox(height: 8),
        FutureBuilder<List<ZoneGeo>>(
          future: _zones,
          builder: (context, s) {
            if (s.hasError) {
              return EtatErreur(
                  erreur: s.error!,
                  onReessayer: () => setState(() {
                        _zones = ReferentielApi.zones();
                      }));
            }
            final zones = s.data ?? const <ZoneGeo>[];
            return ChampChoix<int>(
              libelle: 'Où se trouve votre élevage ?',
              indication: s.hasData ? 'Choisir votre zone' : 'Chargement des zones…',
              valeur: _zoneId,
              erreur: _erreurZone,
              options: [
                for (final z in zones)
                  (valeur: z.id, libelle: z.nom, detail: z.region),
              ],
              onChange: (v) => setState(() {
                _zoneId = v;
                _erreurZone = null;
              }),
            );
          },
        ),
      ];

  List<Widget> _etape2() => [
        Text('Quels animaux élevez-vous ?', style: context.typo.titreSection),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, c) {
          final n = colonnesGrille(c.maxWidth, L.filieres.length, ecart: 10);
          final largeur = (c.maxWidth - 10 * (n - 1)) / n;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final f in L.filieres)
                SizedBox(
                  width: largeur,
                  child: _TuileFiliere(
                    filiere: f,
                    choisie: _filieres.contains(f),
                    onTap: () => setState(() {
                      final copie = {..._filieres};
                      if (!copie.remove(f)) copie.add(f);
                      _filieres = copie;
                      _erreurFilieres = null;
                    }),
                  ),
                ),
            ],
          );
        }),
        if (_erreurFilieres != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_erreurFilieres!, style: context.typo.corps.copyWith(color: context.couleurs.erreur)),
          ),
        const SizedBox(height: 20),
        ChampTexte(
          libelle: 'Mot de passe',
          controleur: _motDePasse,
          secret: true,
          icone: Icons.lock_outline,
          indication: 'Au moins 8 caractères',
          validateur: Valider.motDePasse,
        ),
        ChampTexte(
          libelle: 'Encore une fois',
          controleur: _confirmation,
          secret: true,
          icone: Icons.lock_outline,
          validateur: (v) =>
              v != _motDePasse.text ? 'Les deux mots de passe diffèrent' : null,
        ),
        Semantics(
          checked: _cgu,
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(Dim.rayon),
            onTap: () => setState(() => _cgu = !_cgu),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _cgu ? context.couleurs.marque : context.couleurs.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _cgu ? context.couleurs.marque : context.couleurs.filet, width: 2),
                    ),
                    child: _cgu
                        ? Icon(Icons.check_rounded, size: 22, color: context.couleurs.surMarque)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text("J'accepte les conditions d'utilisation de MonCheptel.",
                        style: context.typo.corps),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
}

/// Avancement : deux traits, le courant en orange, et ce que contient
/// l'etape.
class _Avancement extends StatelessWidget {
  const _Avancement({required this.etape});
  final int etape;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Étape $etape sur 2',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (var i = 1; i <= 2; i++) ...[
                  if (i > 1) const SizedBox(width: 8),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == etape
                            ? context.couleurs.accent
                            : (i < etape ? context.couleurs.marque : context.couleurs.sable),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
                'Étape $etape sur 2 · '
                '${etape == 1 ? 'Qui êtes-vous ?' : 'Vos animaux et votre mot de passe'}',
                style: context.typo.corpsFort),
          ],
        ),
      );
}

class _TuileFiliere extends StatelessWidget {
  const _TuileFiliere({required this.filiere, required this.choisie, required this.onTap});
  final String filiere;
  final bool choisie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: choisie,
        button: true,
        label: L.filiere(filiere),
        excludeSemantics: true,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: choisie ? context.couleurs.marque : context.couleurs.filetLeger, width: choisie ? 2.5 : 1),
          ),
          child: Pressable(
            onTap: onTap,
            rayon: 14,
            ombre: false,
            couleur: choisie ? context.couleurs.fondMarquePale : context.couleurs.surface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(iconeFiliere(filiere), size: 30, color: context.couleurs.marque),
                  const SizedBox(width: 10),
                  Expanded(child: Text(L.filiere(filiere), style: context.typo.corpsFort)),
                  Icon(choisie ? Icons.check_circle_rounded : Icons.circle_outlined,
                      color: choisie ? context.couleurs.marque : context.couleurs.filet),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
        ),
      );
}
