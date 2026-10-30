/// Ecran d'un role qui n'a pas d'espace dans l'application mobile :
/// l'administrateur, dont la console est une application web.
///
/// Mieux qu'un ecran vide ou un plantage : la personne voit qu'elle est
/// bien connectee, sous quel role, ou aller, et peut se deconnecter.
library;

import 'package:flutter/material.dart';

import '../../api/client_api.dart';
import '../../libelles.dart';
import '../../theme/dimensions.dart';
import '../../theme/palette.dart';
import '../../widgets/boutons.dart';
import '../../widgets/echafaudage.dart';
import '../auth/connexion.dart';

class EspaceAVenir extends StatelessWidget {
  const EspaceAVenir({super.key, required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final nom = ClientApi.instance.session?.nom ?? '';
    return Scaffold(
      body: Column(
        children: [
          EnteteMarque(titre: 'MonCheptel', sousTitre: '$nom — ${L.role(role)}'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(Dim.gouttiere * 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Espace ${L.role(role).toLowerCase()}',
                      style: context.typo.titreSection, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text(
                    role == 'ADMINISTRATEUR'
                        ? "L'administration de MonCheptel se fait depuis la console web, "
                            "sur un ordinateur. Votre compte fonctionne : ouvrez la console "
                            'avec les mêmes identifiants.'
                        : "Cet espace n'est pas disponible dans l'application mobile. "
                            'Votre compte fonctionne.',
                    style: context.typo.corpsDiscret,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  BoutonSecondaire('Se déconnecter', onPressed: () async {
                    await ClientApi.instance.deconnecter();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute<void>(builder: (_) => const EcranConnexion()),
                        (_) => false);
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
