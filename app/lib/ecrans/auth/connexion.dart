/// Maquettes « Espace éleveur » (connexion) et « Veto - Connexion », et la
/// pop-up « Mot de passe incorrect ».
///
/// Un seul ecran pour les deux espaces : le back authentifie de la meme
/// facon et oriente selon le role. Seuls le titre et les liens changent :
/// un veterinaire ne cree pas de compte, l'administration le lui fournit.
library;

import 'package:flutter/material.dart';

import '../../api/client_api.dart';
import '../../api/services.dart';
import '../../theme/palette.dart';
import '../../theme/dimensions.dart';
import '../../widgets/boutons.dart';
import '../../widgets/dialogues.dart';
import '../../widgets/formulaires.dart';
import '../../widgets/marque.dart';
import '../demarrage.dart';
import 'heros_marque.dart';
import '../../widgets/vivant.dart';
import 'inscription.dart';
import 'mot_de_passe_oublie.dart';

enum EspaceConnexion { eleveur, veterinaire }

/// L'espace de connexion d'un role : un veterinaire revient sur « Espace
/// vétérinaire », tout autre role sur l'espace eleveur.
EspaceConnexion espaceDuRole(String? role) =>
    role == 'VETERINAIRE' ? EspaceConnexion.veterinaire : EspaceConnexion.eleveur;

class EcranConnexion extends StatefulWidget {
  const EcranConnexion({
    super.key,
    this.espace = EspaceConnexion.eleveur,
    this.sessionExpiree = false,
    this.emailPrerempli,
  });

  final EspaceConnexion espace;

  /// Arrivee ici parce que la session n'a pas pu etre renouvelee.
  final bool sessionExpiree;
  final String? emailPrerempli;

  @override
  State<EcranConnexion> createState() => _EcranConnexionState();
}

class _EcranConnexionState extends State<EcranConnexion> {
  final _cle = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.emailPrerempli);
  final _motDePasse = TextEditingController();
  bool _envoi = false;

  @override
  void dispose() {
    _email.dispose();
    _motDePasse.dispose();
    super.dispose();
  }

  Future<void> _seConnecter() async {
    if (!_cle.currentState!.validate()) return;
    setState(() => _envoi = true);
    try {
      final session = await AuthApi.connexion(_email.text, _motDePasse.text);
      if (!mounted) return;
      // Audit du 11 octobre : un compte eleveur saisi dans « Espace
      // vétérinaire » (ou l'inverse) ouvrait son propre espace sans un mot.
      // Ce n'etait pas une faille — le back ne donne a ce compte QUE ses
      // droits, et chaque route verifie le role — mais l'utilisateur ne
      // comprenait plus ou il etait. On ferme la session ouverte et on
      // propose le bon espace. L'administrateur garde son ecran dedie.
      final bonEspace = espaceDuRole(session.role);
      final roleMobile = session.role == 'ELEVEUR' || session.role == 'VETERINAIRE';
      if (roleMobile && bonEspace != widget.espace) {
        await ClientApi.instance.deconnecter();
        if (!mounted) return;
        final veto = bonEspace == EspaceConnexion.veterinaire;
        final changer = await confirmer(
          context,
          veto ? 'Compte vétérinaire' : 'Compte éleveur',
          message: veto
              ? "Ce compte est un compte vétérinaire. Connectez-vous depuis l'espace vétérinaire."
              : "Ce compte est un compte éleveur. Connectez-vous depuis l'espace éleveur.",
          confirmer: veto ? "Aller à l'espace vétérinaire" : "Aller à l'espace éleveur",
          annuler: 'Rester ici',
        );
        if (changer && mounted) _changerEspace(bonEspace);
        return;
      }
      ouvrirEspace(context, session);
    } on ApiException catch (e) {
      if (!mounted) return;
      // Le back rend LE MEME message pour une adresse inconnue, un mauvais
      // mot de passe et un compte verrouille : on ne revele rien de plus.
      await afficherErreur(context, e,
          titre: e.horsLigne ? 'Connexion impossible' : 'Connexion refusée');
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  void _changerEspace(EspaceConnexion espace) {
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => EcranConnexion(espace: espace, emailPrerempli: _email.text)));
  }

  @override
  Widget build(BuildContext context) {
    final veto = widget.espace == EspaceConnexion.veterinaire;
    final peutRevenir = Navigator.of(context).canPop();
    final carte = CarteFormulaire(enfants: _champs(context, veto));
    final liens = _liens(context, veto);
    return Scaffold(
      backgroundColor: context.couleurs.fond,
      body: Form(
        key: _cle,
        child: AutofillGroup(
          child: LayoutBuilder(builder: (context, c) {
            // Tablette ou telephone en paysage : panneau de marque a gauche,
            // formulaire a droite, chacun dans sa colonne.
            if (c.maxWidth >= 720) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _PanneauMarque(retour: peutRevenir)),
                  Expanded(
                    child: SafeArea(
                      left: false,
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          child: ColonneFormulaire(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [carte, const SizedBox(height: 20), liens],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
            // Telephone : en-tete de marque, carte qui le chevauche, liens.
            return ListView(
              padding: EdgeInsets.zero,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                HerosMarque(retour: peutRevenir),
                Transform.translate(
                  offset: const Offset(0, -28),
                  child: ColonneFormulaire(child: carte),
                ),
                ColonneFormulaire(child: liens),
              ],
            );
          }),
        ),
      ),
    );
  }

  /// Le contenu de la carte : titre de l'espace, champs, bouton, lien.
  List<Widget> _champs(BuildContext context, bool veto) => [
        Semantics(
          header: true,
          child: Text(veto ? 'ESPACE VÉTÉRINAIRE' : 'ESPACE ÉLEVEUR',
              textAlign: TextAlign.center,
              style: context.typo.titreSection.copyWith(fontSize: 22, letterSpacing: 0.6)),
        ),
        const SizedBox(height: 6),
        const Center(child: TraitMarque()),
        const SizedBox(height: 10),
        Text(
            veto
                ? "Connectez-vous avec les identifiants fournis par l'administrateur."
                : 'Content de vous revoir !',
            textAlign: TextAlign.center,
            style: context.typo.corpsDiscret),
        const SizedBox(height: 18),
        if (widget.sessionExpiree)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.couleurs.fondAttentionPale,
                  borderRadius: BorderRadius.circular(Dim.rayon),
                  border: Border(
                      left: BorderSide(color: context.couleurs.accent, width: Dim.bordureEncart)),
                ),
                child: Text('Votre session a expiré. Reconnectez-vous.', style: context.typo.corps),
              ),
            ),
          ),
        ChampTexte(
          libelle: 'Adresse e-mail',
          controleur: _email,
          indication: 'vous@exemple.ml',
          icone: Icons.mail_outline,
          clavier: TextInputType.emailAddress,
          validateur: Valider.email,
          autofill: const [AutofillHints.email, AutofillHints.username],
          actionClavier: TextInputAction.next,
        ),
        ChampTexte(
          libelle: 'Mot de passe',
          controleur: _motDePasse,
          icone: Icons.lock_outline,
          secret: true,
          validateur: (v) => Valider.requis(v, 'Le mot de passe est obligatoire'),
          autofill: const [AutofillHints.password],
          actionClavier: TextInputAction.done,
          // « Valider » sur le clavier connecte, sans aller chercher le bouton.
          onValider: (_) {
            if (!_envoi) _seConnecter();
          },
        ),
        const SizedBox(height: 4),
        BoutonPrincipal(_envoi ? 'Connexion…' : 'Se connecter',
            icone: _envoi ? null : Icons.arrow_forward_rounded,
            iconeApres: true,
            grand: true,
            onPressed: _envoi ? null : _seConnecter),
        const SizedBox(height: 6),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, Dim.hauteurTactile)),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => EcranDemandeCode(emailPrerempli: _email.text))),
          child: Text('Mot de passe oublié ?',
              style: context.typo.corpsFort.copyWith(color: context.couleurs.marque)),
        ),
      ];

  /// Sous la carte : creer un compte, ou changer d'espace.
  Widget _liens(BuildContext context, bool veto) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: veto
              ? [
                  Text('Vous êtes éleveur ?',
                      textAlign: TextAlign.center, style: context.typo.corpsDiscret),
                  const SizedBox(height: 8),
                  BoutonSecondaire("Accéder à l'espace éleveur",
                      onPressed: () => _changerEspace(EspaceConnexion.eleveur)),
                ]
              : [
                  Text('Pas encore de compte ?',
                      textAlign: TextAlign.center, style: context.typo.corpsDiscret),
                  const SizedBox(height: 8),
                  BoutonSecondaire('Créer un compte',
                      icone: Icons.person_add_alt_1_outlined,
                      grand: true,
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => const EcranInscription()))),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(minimumSize: const Size(48, Dim.hauteurTactile)),
                      onPressed: () => _changerEspace(EspaceConnexion.veterinaire),
                      icon: Icon(Icons.medical_services_outlined,
                          size: 20, color: context.couleurs.texteDiscret),
                      label: Text('Je suis vétérinaire', style: context.typo.corpsFort),
                    ),
                  ),
                ],
        ),
      );
}

/// Grand ecran : le panneau gauche porte la marque (degrade, ondes, logo,
/// slogan), la ou le telephone affiche l'en-tete.
class _PanneauMarque extends StatelessWidget {
  const _PanneauMarque({required this.retour});
  final bool retour;

  @override
  Widget build(BuildContext context) {
    final c = context.couleurs;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.enteteSombreDebut, c.enteteDebut, c.enteteFin],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -120,
            top: -100,
            child: OndesSignal(
                taille: 420, anime: !mouvementReduit(context), couleur: const Color(0xFFFFFFFF)),
          ),
          SafeArea(
            right: false,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LogoMonCheptel(largeur: 260, clair: true),
                    const SizedBox(height: 24),
                    for (final (icone, texte) in const [
                      (Icons.pets_outlined, 'Votre cheptel, lot par lot'),
                      (Icons.health_and_safety_outlined, 'Un vétérinaire de votre zone en un geste'),
                      (Icons.payments_outlined, 'Vos dépenses et vos revenus'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icone, color: c.surEntete, size: 22),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(texte,
                                  style: context.typo.corpsFort.copyWith(color: c.surEntete)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (retour)
            Positioned(
              left: 4,
              top: MediaQuery.paddingOf(context).top + 4,
              child: BackButton(color: c.surEntete),
            ),
        ],
      ),
    );
  }
}
