/// Maquette : « MotDePasse - Modifier » et sa pop-up « Confirme ».
///
/// Sert dans deux cas :
///  - depuis le profil, quand l'utilisateur le choisit ;
///  - IMPOSE juste apres la connexion, quand le back renvoie
///    `doitChangerMotDePasse` : mot de passe provisoire donne par
///    l'administration. Dans ce cas, pas de retour possible.
///
/// Apres le changement, le back invalide TOUTES les sessions, y compris
/// celle de ce telephone : on renvoie a la connexion.
library;

import 'package:flutter/material.dart';

import '../../api/client_api.dart';
import '../../api/services.dart';
import '../../theme/palette.dart';
import '../../widgets/boutons.dart';
import '../../widgets/carte.dart';
import '../../widgets/dialogues.dart';
import '../../widgets/entete.dart';
import '../../widgets/formulaires.dart';
import 'connexion.dart';

class EcranMotDePasseImpose extends StatelessWidget {
  const EcranMotDePasseImpose({super.key});

  @override
  Widget build(BuildContext context) => const EcranChangerMotDePasse(impose: true);
}

class EcranChangerMotDePasse extends StatefulWidget {
  const EcranChangerMotDePasse({super.key, this.impose = false});
  final bool impose;

  @override
  State<EcranChangerMotDePasse> createState() => _EcranChangerMotDePasseState();
}

class _EcranChangerMotDePasseState extends State<EcranChangerMotDePasse> {
  final _cle = GlobalKey<FormState>();
  final _ancien = TextEditingController();
  final _nouveau = TextEditingController();
  final _confirmation = TextEditingController();
  bool _envoi = false;

  @override
  void dispose() {
    _ancien.dispose();
    _nouveau.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_cle.currentState!.validate()) return;
    setState(() => _envoi = true);
    try {
      await AuthApi.changerMotDePasse(_ancien.text, _nouveau.text);
      // Les jetons de ce telephone viennent d'etre revoques par le back.
      await ClientApi.instance.fermerSession();
      if (!mounted) return;
      await afficherInfo(context, 'Mot de passe modifié',
          message: 'Par sécurité, toutes vos sessions ont été fermées. '
              'Reconnectez-vous avec le nouveau mot de passe.',
          bouton: 'Se connecter');
      if (!mounted) return;
      final espace = espaceDuRole(ClientApi.instance.dernierRole);
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => EcranConnexion(espace: espace)),
          (_) => false);
    } on ApiException catch (e) {
      if (mounted) await afficherErreur(context, e);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Future<void> _seDeconnecter() async {
    await ClientApi.instance.deconnecter();
    if (!mounted) return;
    final espace = espaceDuRole(ClientApi.instance.dernierRole);
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => EcranConnexion(espace: espace)),
        (_) => false);
  }

  @override
  Widget build(BuildContext context) => EcranSecondaire(
        titre: 'Mot de passe',
        actions: [
          if (widget.impose)
            IconButton(
              tooltip: 'Se déconnecter',
              icon: const Icon(Icons.logout),
              onPressed: _seDeconnecter,
            ),
        ],
        corps: CorpsFormulaire(cle: _cle, enfants: [
          if (widget.impose) ...[
            const Encart(
              titre: 'Mot de passe provisoire',
              detail: "Votre mot de passe a été fourni par l'administration. "
                  'Choisissez-en un personnel pour continuer.',
              ton: TonEncart.attention,
            ),
            const SizedBox(height: 20),
          ],
          ChampTexte(
            libelle: widget.impose ? 'Mot de passe provisoire' : 'Mot de passe actuel',
            controleur: _ancien,
            secret: true,
            validateur: (v) => Valider.requis(v),
          ),
          ChampTexte(
            libelle: 'Nouveau mot de passe',
            controleur: _nouveau,
            secret: true,
            indication: 'Au moins 8 caractères',
            validateur: (v) {
              final e = Valider.motDePasse(v);
              if (e != null) return e;
              return v == _ancien.text ? "Choisissez un mot de passe différent de l'actuel" : null;
            },
          ),
          ChampTexte(
            libelle: 'Confirmer',
            controleur: _confirmation,
            secret: true,
            validateur: (v) => v != _nouveau.text ? 'Les deux mots de passe diffèrent' : null,
          ),
          Text('Toutes vos sessions seront fermées après le changement.',
              style: context.typo.legende),
        ]),
        pied: BoutonPrincipal(_envoi ? 'Enregistrement…' : 'Enregistrer',
            onPressed: _envoi ? null : _enregistrer),
      );
}
