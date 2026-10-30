/// Maquette : « MotDePasse oublie - Demande / Code / Nouveau / Contact ».
///
/// Le back n'a que DEUX routes pour ce parcours :
///   POST /api/auth/mot-de-passe/oublie         envoie le code par e-mail
///   POST /api/auth/mot-de-passe/reinitialiser  code + nouveau mot de passe
///
/// L'ecran « Code » ne verifie donc rien : il garde le code et passe a la
/// suite. C'est a l'envoi du nouveau mot de passe que le back juge le code.
/// S'il est faux, on revient a l'ecran du code avec le message du back.
///
/// Pourquoi pas une route « verifier le code » ? Elle permettrait de tester
/// des codes sans rien changer : un oracle gratuit pour deviner. Le back
/// compte cinq essais par code, quelle que soit la route ; une seule route
/// est plus simple a proteger.
library;

import 'package:flutter/material.dart';

import '../../api/client_api.dart';
import '../../api/services.dart';
import '../../config.dart';
import '../../theme/palette.dart';
import '../../widgets/boutons.dart';
import '../../widgets/carte.dart';
import '../../widgets/dialogues.dart';
import '../../widgets/eleveur/ecran_vivant.dart';
import '../../widgets/entete.dart';
import '../../widgets/formulaires.dart';
import 'connexion.dart';
import '../../widgets/mise_en_page.dart';

// ── 1. Demande ────────────────────────────────────────────────────────────

class EcranDemandeCode extends StatefulWidget {
  const EcranDemandeCode({super.key, this.emailPrerempli});
  final String? emailPrerempli;

  @override
  State<EcranDemandeCode> createState() => _EcranDemandeCodeState();
}

class _EcranDemandeCodeState extends State<EcranDemandeCode> {
  final _cle = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.emailPrerempli);
  bool _envoi = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _demander() async {
    if (!_cle.currentState!.validate()) return;
    setState(() => _envoi = true);
    try {
      await AuthApi.demanderCode(_email.text);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => EcranSaisieCode(email: _email.text.trim())));
    } on ApiException catch (e) {
      if (mounted) await afficherErreur(context, e);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) => EcranVivant(
        titre: 'Mot de passe oublié',
        corps: CorpsFormulaire(cle: _cle, enfants: [
          Text(
              "Saisissez l'adresse e-mail de votre compte. "
              'Nous vous enverrons un code à six chiffres.',
              style: context.typo.corps),
          const SizedBox(height: 20),
          ChampTexte(
            libelle: 'Adresse e-mail',
            controleur: _email,
            indication: 'vous@exemple.ml',
            clavier: TextInputType.emailAddress,
            validateur: Valider.email,
          ),
          const Note('Le code est valable 15 minutes. '
              'Vous pouvez en demander trois par heure.'),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const EcranContactAdministration())),
            child: Text("Je n'ai pas accès à cette adresse",
                style: context.typo.legendeForte.copyWith(color: context.couleurs.marque)),
          ),
        ]),
        pied: BoutonPrincipal(_envoi ? 'Envoi…' : 'Recevoir un code',
            onPressed: _envoi ? null : _demander),
      );
}

// ── 2. Code ───────────────────────────────────────────────────────────────

class EcranSaisieCode extends StatefulWidget {
  const EcranSaisieCode({super.key, required this.email, this.erreurPrecedente});
  final String email;

  /// Message du back quand le code saisi a ete refuse a l'etape suivante.
  final String? erreurPrecedente;

  @override
  State<EcranSaisieCode> createState() => _EcranSaisieCodeState();
}

class _EcranSaisieCodeState extends State<EcranSaisieCode> {
  final _cle = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _renvoi = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _valider() {
    if (!_cle.currentState!.validate()) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) =>
            EcranNouveauMotDePasse(email: widget.email, code: _code.text.trim())));
  }

  Future<void> _renvoyer() async {
    setState(() => _renvoi = true);
    try {
      await AuthApi.demanderCode(widget.email);
      if (mounted) {
        await afficherInfo(context, 'Code renvoyé',
            message: 'Si cette adresse correspond à un compte, '
                'un nouveau code vient d\'y être envoyé. '
                "L'ancien n'est plus valable.");
      }
    } on ApiException catch (e) {
      if (mounted) await afficherErreur(context, e);
    } finally {
      if (mounted) setState(() => _renvoi = false);
    }
  }

  @override
  Widget build(BuildContext context) => EcranVivant(
        titre: 'Mot de passe oublié',
        corps: CorpsFormulaire(cle: _cle, enfants: [
          if (widget.erreurPrecedente != null) ...[
            Encart(
                titre: 'Code refusé',
                detail: widget.erreurPrecedente,
                ton: TonEncart.erreur),
            const SizedBox(height: 16),
          ],
          // Le back repond 202 que l'adresse existe ou non : l'ecran ne peut
          // donc pas affirmer qu'un code est parti.
          Text("Si cette adresse correspond à un compte, un code vient d'y être envoyé.",
              style: context.typo.corps),
          const SizedBox(height: 6),
          Text(widget.email, style: context.typo.corpsFort),
          const SizedBox(height: 20),
          ChampTexte(
            libelle: 'Code reçu par e-mail',
            controleur: _code,
            indication: '482 913',
            clavier: TextInputType.number,
            longueurMax: 7,
            validateur: (v) {
              final chiffres = (v ?? '').replaceAll(' ', '');
              return RegExp(r'^\d{6}$').hasMatch(chiffres)
                  ? null
                  : 'Le code compte six chiffres';
            },
          ),
          const Note('Vous disposez de cinq essais. '
              'Passé ce nombre, il faut demander un nouveau code.'),
          TextButton(
            onPressed: _renvoi ? null : _renvoyer,
            child: Text(_renvoi ? 'Envoi…' : 'Renvoyer un code',
                style: context.typo.legendeForte.copyWith(color: context.couleurs.marque)),
          ),
        ]),
        pied: BoutonPrincipal('Valider le code', onPressed: _valider),
      );
}

// ── 3. Nouveau mot de passe ───────────────────────────────────────────────

class EcranNouveauMotDePasse extends StatefulWidget {
  const EcranNouveauMotDePasse({super.key, required this.email, required this.code});
  final String email;
  final String code;

  @override
  State<EcranNouveauMotDePasse> createState() => _EcranNouveauMotDePasseState();
}

class _EcranNouveauMotDePasseState extends State<EcranNouveauMotDePasse> {
  final _cle = GlobalKey<FormState>();
  final _mdp = TextEditingController();
  final _confirmation = TextEditingController();
  bool _envoi = false;

  @override
  void dispose() {
    _mdp.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_cle.currentState!.validate()) return;
    setState(() => _envoi = true);
    try {
      await AuthApi.reinitialiser(widget.email, widget.code, _mdp.text);
      if (!mounted) return;
      await afficherInfo(context, 'Mot de passe modifié',
          message: 'Connectez-vous avec votre nouveau mot de passe.',
          bouton: 'Se connecter');
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
            builder: (_) => EcranConnexion(emailPrerempli: widget.email)),
        (_) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statut == 422) {
        // Code faux ou expire : retour a la saisie du code, avec la raison.
        Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
            builder: (_) =>
                EcranSaisieCode(email: widget.email, erreurPrecedente: e.texte)));
      } else {
        await afficherErreur(context, e);
      }
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) => EcranVivant(
        titre: 'Nouveau mot de passe',
        corps: CorpsFormulaire(cle: _cle, enfants: [
          Text("Choisissez un mot de passe d'au moins 8 caractères.",
              style: context.typo.corps),
          const SizedBox(height: 20),
          ChampTexte(
            libelle: 'Nouveau mot de passe',
            controleur: _mdp,
            secret: true,
            validateur: Valider.motDePasse,
          ),
          ChampTexte(
            libelle: 'Confirmer',
            controleur: _confirmation,
            secret: true,
            validateur: (v) => v != _mdp.text ? 'Les deux mots de passe diffèrent' : null,
          ),
          const Note('Vos sessions ouvertes seront fermées. '
              'Vous vous reconnecterez avec ce mot de passe.'),
        ]),
        pied: BoutonPrincipal(_envoi ? 'Enregistrement…' : 'Enregistrer',
            onPressed: _envoi ? null : _enregistrer),
      );
}

// ── Pas d'acces a l'adresse ───────────────────────────────────────────────

class EcranContactAdministration extends StatelessWidget {
  const EcranContactAdministration({super.key});

  @override
  Widget build(BuildContext context) => EcranVivant(
        titre: "Pas d'accès à votre e-mail ?",
        corps: ListView(
          padding: lisible(context, const EdgeInsets.all(16)),
          children: [
            Text(
                "L'administration peut réinitialiser votre mot de passe après "
                'vérification de votre identité, et corriger votre adresse.',
                style: context.typo.corps),
            const SizedBox(height: 20),
            Carte(
              enfant: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Administration MonCheptel', style: context.typo.corpsFort),
                  const SizedBox(height: 6),
                  Text(Config.telephoneAdministration,
                      style: context.typo.chiffre.copyWith(fontSize: 20)),
                  const SizedBox(height: 6),
                  Text('Du lundi au samedi, 8 h — 18 h', style: context.typo.legende),
                ],
              ),
            ),
          ],
        ),
        pied: BoutonPrincipal("Appeler l'administration",
            icone: Icons.call,
            onPressed: () => appeler(context, Config.telephoneAdministration)),
      );
}
