/// Reglages de l'application, fixes a la compilation.
library;

import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

abstract final class Config {
  /// Adresse du back.
  ///
  /// Par defaut `10.0.2.2:8080` : c'est l'adresse a laquelle l'EMULATEUR
  /// Android voit le `localhost` du PC. Sur un vrai telephone, branche au
  /// meme Wi-Fi que le PC, passer l'adresse IP du PC au lancement :
  ///
  ///     flutter run --dart-define=API_URL=http://192.168.1.20:8080
  ///
  /// `String.fromEnvironment` est evalue a la compilation : changer
  /// d'adresse demande de relancer `flutter run`, pas un simple rechargement.
  static const String urlApi =
      String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8080');

  /// Au-dela, une requete est consideree comme perdue. Le back coupe
  /// lui-meme ses appels SMTP a 10 s : 15 s laisse passer une demande de
  /// code de reinitialisation lente sans faire attendre indefiniment.
  static const Duration delaiRequete = Duration(seconds: 15);

  /// Numero de l'administration, ecran « Pas d'acces a votre e-mail ? ».
  /// Le meme que dans le modele de courriel changement-adresse.txt.
  static const String telephoneAdministration = '+223 73 53 87 94';

  /// Version affichee sous le splash et le choix du profil (maquettes).
  /// A garder alignee sur `version:` dans pubspec.yaml.
  static const String version = '1.0';

  /// Pourquoi cette version ne peut pas fonctionner, ou nul si tout va bien
  /// (audit global G19).
  ///
  /// En publication, Android interdit le trafic en clair : une API en
  /// `http://` (ou l'adresse de l'emulateur par defaut) ferait echouer
  /// TOUTES les requetes avec « Impossible de joindre le serveur ». On le
  /// dit des le demarrage, en clair, au lieu de laisser croire a une panne
  /// de reseau.
  ///
  /// La version web n'est pas concernee : le navigateur accepte une API en
  /// `http://localhost` (demonstrations, captures de la maquette).
  static String? erreurConfiguration(
      {bool release = kReleaseMode, bool web = kIsWeb, String url = urlApi}) {
    if (!release || web) return null;
    if (!url.startsWith('https://')) {
      return "Cette version de publication a été compilée sans adresse d'API en HTTPS "
          '(reçu : $url). Recompilez avec --dart-define=API_URL=https://votre-domaine.';
    }
    return null;
  }
}
