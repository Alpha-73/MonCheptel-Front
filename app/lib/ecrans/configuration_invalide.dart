/// Ecran affiche a la place de l'application quand la version de
/// publication a ete compilee sans API en HTTPS (audit global G19).
///
/// Volontairement sans appel au reseau ni au coffre : il doit s'afficher
/// meme quand rien d'autre ne marche.
library;

import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/theme_app.dart';

class EcranConfigurationInvalide extends StatelessWidget {
  const EcranConfigurationInvalide({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MonCheptel',
        debugShowCheckedModeBanner: false,
        theme: themeMonCheptel(),
        home: Scaffold(
          backgroundColor: context.couleurs.fond,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline_rounded, size: 48, color: context.couleurs.erreur),
                  const SizedBox(height: 16),
                  Text('Application mal configurée', style: context.typo.titreSection),
                  const SizedBox(height: 12),
                  Text(message, style: context.typo.corps),
                  const SizedBox(height: 12),
                  Text(
                    "Cette version ne peut joindre aucun serveur. Contactez la personne "
                    "qui vous l'a fournie.",
                    style: context.typo.corpsDiscret,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
