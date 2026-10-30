/// Le seul endroit de l'application qui parle HTTP.
///
/// Trois responsabilites, et aucune autre :
///
///  1. joindre le jeton d'acces a chaque requete ;
///  2. le renouveler quand il expire, sans que l'ecran s'en apercoive ;
///  3. transformer toute reponse d'erreur en une [ApiException] lisible.
///
/// Les ecrans n'appellent jamais `http` directement : ils passent par les
/// fonctions de `services.dart`, qui passent par ici.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

/// Erreur rendue par le back, ou absence de reponse.
///
/// [statut] reprend la convention du back : 400 saisie invalide, 401 session
/// absente ou expiree, 403 refuse,
/// 404 introuvable, 409 conflit, 422 regle metier. 0 = pas de reponse
/// (reseau coupe, serveur arrete, delai depasse).
class ApiException implements Exception {
  const ApiException(this.statut, this.message, {this.champs = const {}});

  final int statut;
  final String message;

  /// Pour un 400 de validation : champ -> raison. Vide sinon.
  final Map<String, String> champs;

  bool get horsLigne => statut == 0;

  /// Le texte a montrer a l'utilisateur.
  ///
  /// Pour une erreur de validation, le message general du back
  /// (« Requete invalide ») n'aide personne : on montre la raison du champ.
  String get texte {
    if (champs.isEmpty) return message;
    return champs.values.join('\n');
  }

  @override
  String toString() => 'ApiException($statut, $message)';
}

/// Ce que le back a rendu a la connexion, conserve entre deux lancements.
class Session {
  const Session({
    required this.jetonAcces,
    required this.jetonRafraichissement,
    required this.expireA,
    required this.utilisateurId,
    required this.nom,
    required this.role,
    required this.doitChangerMotDePasse,
  });

  final String jetonAcces;
  final String jetonRafraichissement;
  final DateTime expireA;
  final int utilisateurId;
  final String nom;

  /// `ELEVEUR`, `VETERINAIRE` ou `ADMINISTRATEUR`.
  final String role;
  final bool doitChangerMotDePasse;

  /// Construit depuis `JetonReponse`.
  factory Session.depuisJeton(Map<String, dynamic> j) => Session(
        jetonAcces: j['jetonAcces'] as String,
        jetonRafraichissement: j['jetonRafraichissement'] as String,
        expireA: DateTime.now()
            .add(Duration(seconds: (j['expireDansSecondes'] as num).toInt())),
        utilisateurId: (j['utilisateurId'] as num).toInt(),
        nom: j['nom'] as String? ?? '',
        role: j['role'] as String? ?? '',
        doitChangerMotDePasse: j['doitChangerMotDePasse'] as bool? ?? false,
      );

  Map<String, dynamic> versJson() => {
        'jetonAcces': jetonAcces,
        'jetonRafraichissement': jetonRafraichissement,
        'expireA': expireA.toIso8601String(),
        'utilisateurId': utilisateurId,
        'nom': nom,
        'role': role,
        'doitChangerMotDePasse': doitChangerMotDePasse,
      };

  factory Session.depuisJson(Map<String, dynamic> j) => Session(
        jetonAcces: j['jetonAcces'] as String,
        jetonRafraichissement: j['jetonRafraichissement'] as String,
        expireA: DateTime.parse(j['expireA'] as String),
        utilisateurId: (j['utilisateurId'] as num).toInt(),
        nom: j['nom'] as String? ?? '',
        role: j['role'] as String? ?? '',
        doitChangerMotDePasse: j['doitChangerMotDePasse'] as bool? ?? false,
      );
}

class ClientApi {
  ClientApi._();

  /// Instance unique : la session est un etat global de l'application.
  static final ClientApi instance = ClientApi._();

  static const String _cleSession = 'moncheptel.session';
  final FlutterSecureStorage _coffre = const FlutterSecureStorage();

  Session? _session;
  Session? get session => _session;

  /// Rafraichissement en cours, partage entre toutes les requetes.
  ///
  /// Le back fait tourner les jetons : un jeton de rafraichissement ne sert
  /// QU'UNE fois. Si l'ecran d'accueil lance trois requetes en parallele et
  /// que chacune rafraichissait de son cote, la deuxieme et la troisieme
  /// presenteraient un jeton deja consomme — refus, et deconnexion. Toutes
  /// attendent donc le meme rafraichissement.
  Future<bool>? _rafraichissement;

  /// Appele quand la session ne peut plus etre renouvelee. `main.dart` y
  /// branche le retour a l'ecran de connexion.
  void Function()? surSessionExpiree;

  /// Appele au debut de [deconnecter], session encore valide. `main.dart`
  /// y branche le retrait du telephone des notifications poussees
  /// (pousse/pousse.dart) : la route du back exige d'etre connecte.
  Future<void> Function()? avantDeconnexion;

  // ── session ─────────────────────────────────────────────────────────────

  /// Relit la session du lancement precedent. Sans session : `null`.
  Future<Session?> restaurerSession() async {
    try {
      final brut = await _coffre.read(key: _cleSession);
      if (brut == null) return null;
      _session = Session.depuisJson(jsonDecode(brut) as Map<String, dynamic>);
    } catch (_) {
      // Coffre illisible (application reinstallee, format change) :
      // on repart d'une connexion plutot que de planter au demarrage.
      _session = null;
      try {
        await _coffre.delete(key: _cleSession);
      } catch (_) {
        // Coffre inutilisable : on continue sans session plutot que de
        // bloquer l'application sur l'ecran de demarrage.
      }
    }
    return _session;
  }

  Future<Session> ouvrirSession(Map<String, dynamic> jetonReponse) async {
    final s = Session.depuisJeton(jetonReponse);
    await _enregistrer(s);
    return s;
  }

  Future<void> _enregistrer(Session s) async {
    _session = s;
    await _coffre.write(key: _cleSession, value: jsonEncode(s.versJson()));
  }

  /// Role de la derniere session fermee : l'ecran de connexion qui suit
  /// rouvre le BON espace (veterinaire ou eleveur), sans quoi un
  /// veterinaire se retrouvait sur « Espace éleveur » (audit du 10 octobre).
  String? get dernierRole => _dernierRole;
  String? _dernierRole;

  Future<void> fermerSession() async {
    _dernierRole = _session?.role ?? _dernierRole;
    _session = null;
    await _coffre.delete(key: _cleSession);
  }

  /// Deconnexion : le back revoque le jeton de rafraichissement, puis on
  /// oublie la session localement.
  ///
  /// Si le back ne repond pas, on deconnecte QUAND MEME localement :
  /// l'utilisateur qui appuie sur « Se deconnecter » doit l'etre, reseau ou
  /// pas. Le jeton non revoque expirera seul.
  Future<void> deconnecter() async {
    final s = _session;
    if (s != null) {
      try {
        await avantDeconnexion?.call();
      } catch (_) {
        // Jamais bloquant : la deconnexion doit aboutir.
      }
      try {
        // authentifie: false (audit du 10 octobre). La route est ouverte : le
        // jeton de rafraichissement suffit. Avec authentification, un jeton
        // d'acces proche de l'expiration etait d'abord RENOUVELE — le back
        // revoquait l'ancien jeton et en creait un neuf — puis la
        // deconnexion partait avec l'ancien : le neuf restait valable trente
        // jours.
        await post('/api/auth/deconnexion',
            entetes: {'X-Refresh-Token': s.jetonRafraichissement},
            authentifie: false);
      } catch (_) {
        // Voir ci-dessus : sans consequence pour l'utilisateur.
      }
    }
    await fermerSession();
  }

  // ── verbes ──────────────────────────────────────────────────────────────

  Future<dynamic> get(String chemin, {Map<String, Object?>? requete}) =>
      _envoyer('GET', chemin, requete: requete);

  Future<dynamic> post(String chemin,
          {Object? corps, Map<String, String>? entetes, bool authentifie = true}) =>
      _envoyer('POST', chemin,
          corps: corps, entetes: entetes, authentifie: authentifie);

  Future<dynamic> put(String chemin, {Object? corps}) =>
      _envoyer('PUT', chemin, corps: corps);

  Future<dynamic> delete(String chemin, {Map<String, Object?>? requete}) =>
      _envoyer('DELETE', chemin, requete: requete);

  // ── coeur ───────────────────────────────────────────────────────────────

  Future<dynamic> _envoyer(
    String methode,
    String chemin, {
    Map<String, Object?>? requete,
    Object? corps,
    Map<String, String>? entetes,
    bool authentifie = true,
    bool reessai = true,
  }) async {
    // Renouvellement PREVENTIF : le jeton expire dans moins d'une minute.
    // Evite un aller-retour voue a l'echec.
    if (authentifie && _session != null &&
        DateTime.now().isAfter(_session!.expireA.subtract(const Duration(minutes: 1)))) {
      final ok = await _rafraichir();
      if (!ok) throw _sessionPerdue();
    }

    final reponse = await _http(methode, chemin,
        requete: requete, corps: corps, entetes: entetes, authentifie: authentifie);

    // Le back rend 401 pour un jeton absent, invalide OU expire, et 403 pour
    // un vrai refus (role, proprietaire, mot de passe provisoire) qu'un
    // renouvellement ne changerait pas. Le jeton a pu expirer entre la
    // verification ci-dessus et l'arrivee au serveur, ou avoir ete revoque :
    // sur 401 seulement, on tente UN renouvellement, puis une seule reprise.
    if (reponse.statusCode == 401 && authentifie && reessai && _session != null) {
      final ok = await _rafraichir();
      if (!ok) throw _sessionPerdue();
      return _envoyer(methode, chemin,
          requete: requete, corps: corps, entetes: entetes, reessai: false);
    }

    return _decoder(reponse);
  }

  Future<http.Response> _http(
    String methode,
    String chemin, {
    Map<String, Object?>? requete,
    Object? corps,
    Map<String, String>? entetes,
    required bool authentifie,
  }) async {
    final parametres = <String, String>{
      for (final e in (requete ?? const <String, Object?>{}).entries)
        if (e.value != null) e.key: e.value.toString(),
    };
    final uri = Uri.parse('${Config.urlApi}$chemin')
        .replace(queryParameters: parametres.isEmpty ? null : parametres);

    final enTetes = <String, String>{
      'Accept': 'application/json',
      if (corps != null) 'Content-Type': 'application/json; charset=utf-8',
      if (authentifie && _session != null)
        'Authorization': 'Bearer ${_session!.jetonAcces}',
      ...?entetes,
    };
    final texteCorps = corps == null ? null : jsonEncode(corps);

    try {
      final Future<http.Response> appel = switch (methode) {
        'GET' => http.get(uri, headers: enTetes),
        'POST' => http.post(uri, headers: enTetes, body: texteCorps),
        'PUT' => http.put(uri, headers: enTetes, body: texteCorps),
        'DELETE' => http.delete(uri, headers: enTetes),
        _ => throw ArgumentError('Methode non geree : $methode'),
      };
      return await appel.timeout(Config.delaiRequete);
    } on TimeoutException {
      throw const ApiException(0,
          'Le serveur ne répond pas. Vérifiez votre connexion et réessayez.');
    } on ArgumentError {
      rethrow;
    } catch (_) {
      // SocketException, ClientException, HandshakeException... Pour
      // l'utilisateur, une seule chose compte : la requete n'est pas partie.
      throw const ApiException(0,
          'Impossible de joindre le serveur. Vérifiez votre connexion.');
    }
  }

  dynamic _decoder(http.Response r) {
    // TOUJOURS decoder les octets en UTF-8. `r.body` suit le charset annonce
    // par l'en-tete, et retombe sur latin-1 quand il n'y en a pas : « Élevé »
    // s'afficherait « Ã‰levÃ© ».
    final texte = r.bodyBytes.isEmpty ? '' : utf8.decode(r.bodyBytes);
    final json = texte.isEmpty ? null : _jsonOuNull(texte);

    if (r.statusCode >= 200 && r.statusCode < 300) return json;

    String message = 'Erreur ${r.statusCode}';
    var champs = const <String, String>{};
    if (json is Map<String, dynamic>) {
      message = (json['message'] as String?) ?? message;
      final c = json['champs'];
      if (c is Map) {
        champs = c.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } else if (r.statusCode == 403) {
      message = 'Accès refusé.';
    } else if (r.statusCode == 401) {
      message = 'Session expirée. Reconnectez-vous.';
    }
    throw ApiException(r.statusCode, message, champs: champs);
  }

  static Object? _jsonOuNull(String texte) {
    try {
      return jsonDecode(texte);
    } catch (_) {
      return null;
    }
  }

  // ── renouvellement ──────────────────────────────────────────────────────

  Future<bool> _rafraichir() {
    // `??=` : si un renouvellement est deja en cours, on attend le meme.
    return _rafraichissement ??=
        _faireRafraichir().whenComplete(() => _rafraichissement = null);
  }

  Future<bool> _faireRafraichir() async {
    final s = _session;
    if (s == null) return false;
    final http.Response r;
    try {
      r = await _http('POST', '/api/auth/rafraichir',
          corps: {'jetonRafraichissement': s.jetonRafraichissement},
          authentifie: false);
    } on ApiException {
      // Reseau coupe : on ne deconnecte PAS. La session est peut-etre
      // encore valide ; l'erreur reseau remonte a l'ecran, qui proposera de
      // reessayer.
      rethrow;
    }
    if (r.statusCode != 200) {
      // 422 « Session expiree » : jeton de 30 jours echu, deja consomme,
      // ou revoque par un changement de mot de passe.
      return false;
    }
    final json = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    // Les DEUX jetons sont remplaces : l'ancien jeton de rafraichissement
    // vient d'etre invalide par le back.
    await _enregistrer(Session.depuisJeton(json));
    return true;
  }

  ApiException _sessionPerdue() {
    // Plusieurs requetes paralleles echouent ensemble : seule la PREMIERE
    // renvoie a l'ecran de connexion. `fermerSession` remet la session a
    // nul avant tout `await`, donc les suivantes trouvent deja nul.
    final avaitUneSession = _session != null;
    // Non attendu (la session est remise a nul avant tout await), mais une
    // erreur du coffre ne doit pas devenir une erreur asynchrone non geree.
    fermerSession().catchError((Object _) {});
    if (avaitUneSession) surSessionExpiree?.call();
    return const ApiException(401, 'Session expirée. Reconnectez-vous.');
  }
}
