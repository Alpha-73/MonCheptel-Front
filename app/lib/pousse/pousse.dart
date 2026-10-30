/// Notifications poussees par Firebase (audit des notifications, 11 octobre).
///
/// Le back cree deja une notification pour chaque evenement (cas confie a un
/// veterinaire, reponse a l'eleveur, alerte de zone, soins du jour...) et
/// l'envoie a Firebase pour chaque telephone ENREGISTRE. Ce fichier est le
/// maillon qui manquait : il enregistre le telephone.
///
/// Cycle de vie du jeton Firebase :
///  - espace eleveur ou veterinaire ouvert ([activer]) : permission
///    demandee (Android 13 et plus), jeton envoye au back
///    (POST /api/notifications/appareils) ;
///  - jeton renouvele par Firebase : renvoye aussitot ;
///  - deconnexion ([oublier]) : jeton retire au back
///    (DELETE /api/notifications/appareils) PUIS supprime sur le telephone,
///    pour que la personne suivante sur ce telephone ne recoive pas les
///    notifications de la precedente.
///
/// Reception :
///  - application fermee ou en arriere-plan : Android affiche la
///    notification lui-meme ; la toucher ouvre l'ecran concerne ;
///  - application ouverte : Android n'affiche RIEN (regle de Firebase). On
///    montre un bandeau en bas de l'ecran, avec « Voir ».
///
/// SANS Firebase (fichier android/app/google-services.json absent, version
/// web, tests) : tout est ignore en silence. L'application marche comme
/// avant, les notifications restent lisibles dans l'ecran Notifications.
library;

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../api/modeles.dart';
import '../ecrans/eleveur/profil/notifications.dart' as eleveur;
import '../ecrans/veterinaire/notifications_veterinaire.dart';

class Pousse {
  Pousse._();

  static final Pousse instance = Pousse._();

  /// Navigateur racine (main.dart) : ouvrir un ecran depuis une notification
  /// arrivee n'importe quand, sans `BuildContext` sous la main.
  GlobalKey<NavigatorState>? navigateur;

  /// Pour le bandeau « application ouverte ».
  GlobalKey<ScaffoldMessengerState>? messager;

  /// Incremente a chaque notification recue application ouverte : l'accueil
  /// se recharge (pastille de la cloche, liste des cas).
  final ValueNotifier<int> recues = ValueNotifier<int>(0);

  /// Firebase initialise et utilisable sur cet appareil.
  bool _pret = false;

  /// Role de l'espace ouvert : decide quel ecran ouvre une notification.
  String? _role;

  /// Dernier jeton envoye au back : celui a retirer a la deconnexion.
  String? _jeton;

  final List<StreamSubscription<Object?>> _abonnements = [];
  bool _ecouteurs = false;

  /// Notification touchee alors que l'application etait FERMEE : on
  /// l'ouvre une fois l'espace affiche (le splash dure 3 s).
  bool _initialeTraitee = false;

  /// Appele par l'espace eleveur ou veterinaire a son ouverture (apres une
  /// connexion comme a la reprise d'une session).
  ///
  /// Ne leve jamais : un probleme de notifications ne doit pas empecher
  /// d'utiliser l'application.
  Future<void> activer({required String role}) async {
    // Sans session (tests d'ecran, captures), rien a enregistrer : le back
    // refuserait le jeton (401).
    if (ClientApi.instance.session == null) return;
    _role = role;
    try {
      if (!await _initialiser()) return;
      final messaging = FirebaseMessaging.instance;

      // Android 13 et plus : sans cette autorisation, Android n'affiche
      // aucune notification. La boite de dialogue n'apparait qu'une fois ;
      // ensuite le choix se change dans les reglages du telephone.
      final reglages = await messaging.requestPermission();
      if (reglages.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Notifications refusees par l\'utilisateur');
        // Le jeton est quand meme enregistre : si l'utilisateur les autorise
        // plus tard dans les reglages, elles arriveront sans reconnexion.
      }

      _ecouter();

      final jeton = await messaging.getToken();
      if (jeton != null) await _enregistrer(jeton);

      if (!_initialeTraitee) {
        _initialeTraitee = true;
        final initiale = await messaging.getInitialMessage();
        if (initiale != null) _ouvrirApresAffichage(initiale);
      }
    } catch (e) {
      debugPrint('Notifications poussees indisponibles : $e');
    }
  }

  /// A la deconnexion, AVANT la revocation de la session : la route du back
  /// exige d'etre connecte. Ne leve jamais, et ne fait jamais attendre plus
  /// de quelques secondes : la deconnexion doit aboutir, reseau ou pas.
  Future<void> oublier() async {
    final jeton = _jeton;
    _jeton = null;
    _role = null;
    if (!_pret) return;
    try {
      if (jeton != null) {
        await ClientApi.instance
            .delete('/api/notifications/appareils', requete: {'jeton': jeton})
            .timeout(const Duration(seconds: 5));
      }
    } catch (_) {
      // Le back n'a pas ete prevenu : la suppression du jeton ci-dessous
      // suffit, Firebase signalera ce jeton comme perime au prochain envoi
      // et le back le desactivera.
    }
    try {
      await FirebaseMessaging.instance.deleteToken().timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  // ── interne ─────────────────────────────────────────────────────────────

  Future<bool> _initialiser() async {
    if (_pret) return true;
    // Version web : les notifications poussees y demandent une autre
    // configuration (service worker, cle VAPID). Hors perimetre.
    if (kIsWeb) return false;
    if (Firebase.apps.isEmpty) {
      // Lit android/app/google-services.json, integre a la compilation.
      // Absent : exception, attrapee par l'appelant.
      await Firebase.initializeApp();
    }
    _pret = true;
    return true;
  }

  void _ecouter() {
    if (_ecouteurs) return;
    _ecouteurs = true;
    final messaging = FirebaseMessaging.instance;
    _abonnements
      ..add(messaging.onTokenRefresh.listen((jeton) {
        // Renouvellement decide par Firebase, a tout moment : sans ce renvoi
        // le telephone cesserait de recevoir les notifications sans le dire.
        if (_role != null) _enregistrer(jeton);
      }))
      ..add(FirebaseMessaging.onMessage.listen(_surPremierPlan))
      ..add(FirebaseMessaging.onMessageOpenedApp.listen(_ouvrir));
  }

  Future<void> _enregistrer(String jeton) async {
    try {
      await ClientApi.instance.post('/api/notifications/appareils',
          corps: {'jeton': jeton, 'plateforme': defaultTargetPlatform.name});
      _jeton = jeton;
    } catch (e) {
      // Reseau coupe : nouvel essai a la prochaine ouverture de l'espace.
      debugPrint('Enregistrement du telephone impossible : $e');
    }
  }

  /// Application ouverte : Android n'affiche rien, on montre un bandeau.
  void _surPremierPlan(RemoteMessage m) {
    recues.value++;
    final titre = m.notification?.title;
    if (titre == null) return;
    messager?.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(titre, maxLines: 2, overflow: TextOverflow.ellipsis),
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'Voir', onPressed: () => _ouvrir(m)),
      ));
  }

  void _ouvrirApresAffichage(RemoteMessage m) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _ouvrir(m));
  }

  /// Ouvre l'ecran vise, avec la meme logique que l'ecran Notifications.
  Future<void> _ouvrir(RemoteMessage m) async {
    final context = navigateur?.currentState?.overlay?.context;
    if (context == null || _role == null) return;
    final n = notificationDepuis(m);
    try {
      switch (_role) {
        case 'ELEVEUR':
          await eleveur.ouvrirNotification(context, n);
        case 'VETERINAIRE':
          await EcranNotificationsVeto.ouvrirNotification(context, n);
      }
    } catch (e) {
      debugPrint('Ouverture de la notification impossible : $e');
    }
  }
}

/// Reconstruit une [NotificationApp] depuis le message Firebase : le back y
/// joint `type`, `referenceType` et `referenceId` (PasserelleFirebase).
@visibleForTesting
NotificationApp notificationDepuis(RemoteMessage m) => notificationDepuisDonnees(
      titre: m.notification?.title,
      corps: m.notification?.body,
      donnees: m.data,
    );

/// Separe de [RemoteMessage] pour etre teste sans Firebase.
NotificationApp notificationDepuisDonnees({
  String? titre,
  String? corps,
  required Map<String, dynamic> donnees,
}) {
  String? texte(Object? v) => v == null || v.toString().isEmpty ? null : v.toString();
  return NotificationApp.json({
    'id': 0,
    'type': texte(donnees['type']) ?? 'SYSTEME',
    'titre': titre ?? 'MonCheptel',
    'corps': corps,
    'lue': true,
    'referenceType': texte(donnees['referenceType']),
    'referenceId': int.tryParse(donnees['referenceId']?.toString() ?? ''),
  });
}
