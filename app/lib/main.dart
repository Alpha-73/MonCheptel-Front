import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api/client_api.dart';
import 'config.dart';
import 'ecrans/configuration_invalide.dart';
import 'ecrans/auth/connexion.dart';
import 'ecrans/demarrage.dart';
import 'pousse/pousse.dart';
import 'theme/apparence.dart';
import 'theme/barre_etat.dart';
import 'theme/palette.dart';
import 'theme/theme_app.dart';

/// Navigateur racine : permet de revenir a la connexion depuis n'importe ou
/// quand la session expire, sans avoir de `BuildContext` sous la main.
final GlobalKey<NavigatorState> navigateurRacine = GlobalKey<NavigatorState>();

/// Bandeaux d'information hors de tout ecran : notification recue pendant
/// que l'application est ouverte (pousse/pousse.dart).
final GlobalKey<ScaffoldMessengerState> messagerRacine = GlobalKey<ScaffoldMessengerState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Audit global G19 : une version de publication sans API en HTTPS ne peut
  // joindre aucun serveur. On le dit tout de suite, en clair.
  final erreur = Config.erreurConfiguration();
  if (erreur != null) {
    runApp(EcranConfigurationInvalide(message: erreur));
    return;
  }

  ClientApi.instance.surSessionExpiree = () {
    navigateurRacine.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(
          builder: (_) => EcranConnexion(
              sessionExpiree: true,
              espace: espaceDuRole(ClientApi.instance.dernierRole))),
      (_) => false,
    );
  };

  // Notifications poussees : ouverture de l'ecran vise, bandeau application
  // ouverte, et retrait du telephone a la deconnexion.
  Pousse.instance
    ..navigateur = navigateurRacine
    ..messager = messagerRacine;
  ClientApi.instance.avantDeconnexion = Pousse.instance.oublier;

  // Style applique des le premier affichage, avant qu'aucun ecran n'ait
  // declare le sien (ecran de demarrage, splash natif qui s'efface).
  SystemChrome.setSystemUIOverlayStyle(BarreEtat.surClair);

  // Le choix « Apparence » est relu en tache de fond : l'application suit
  // le telephone jusqu'a ce qu'il soit connu (quelques millisecondes).
  ReglageApparence.instance.charger();

  runApp(const AppMonCheptel());
}

/// Defilement commun a toute l'application.
///
/// La souris et le pave tactile peuvent faire glisser une liste comme un
/// doigt : sans cela, sur la version web, « tirer pour actualiser » et le
/// glissement des onglets de filiere etaient impossibles.
class _Defilement extends MaterialScrollBehavior {
  const _Defilement();

  // On AJOUTE la souris aux peripheriques par defaut, sans rien retirer :
  // le defaut contient `unknown`, qu'emploie VoiceAccess (pilotage vocal
  // d'Android) pour faire defiler.
  @override
  Set<PointerDeviceKind> get dragDevices =>
      {...super.dragDevices, PointerDeviceKind.mouse};
}

class AppMonCheptel extends StatelessWidget {
  const AppMonCheptel({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Apparence>(
      valueListenable: ReglageApparence.instance,
      builder: (context, apparence, _) => MaterialApp(
      title: 'MonCheptel',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigateurRacine,
      scaffoldMessengerKey: messagerRacine,
      theme: themeMonCheptel(),
      // Theme sombre complet (palette verifiee AA, voir theme/palette.dart).
      // Par defaut l'application suit le reglage du telephone ; le Profil
      // permet de forcer Clair ou Sombre.
      darkTheme: themeMonCheptel(luminosite: Brightness.dark),
      themeMode: apparence.mode,
      scrollBehavior: const _Defilement(),
      // Defaut de la barre d'etat pour TOUTE l'application, selon le fond
      // du theme. Les en-tetes verts le remplacent localement.
      builder: (context, enfant) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: BarreEtat.pourFond(context.couleurs),
        child: enfant ?? const SizedBox.shrink(),
      ),
      // Francais partout, y compris dans ce que Flutter dessine lui-meme :
      // calendrier du selecteur de date, « Coller » dans un champ...
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Demarrage(),
      ),
    );
  }
}
