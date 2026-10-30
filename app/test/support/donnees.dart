// Donnees factices communes aux tests d'ecrans (aucun appel au vrai back).
import 'dart:convert';
import 'dart:io' show File, Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moncheptel/api/modeles.dart';
import 'package:moncheptel/ecrans/eleveur/animaux/carnet.dart';
import 'package:moncheptel/theme/theme_app.dart';

String jour(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

final DateTime aujourdhui = DateTime.now();

TableauDeBord tableauFactice({String filiere = 'VOLAILLE'}) =>
    TableauDeBord.json(tableauJson(filiere: filiere));

Map<String, dynamic> tableauJson({String filiere = 'VOLAILLE'}) => {
      'nomEleveur': 'Awa Traoré',
      'zone': 'Koutiala',
      'filieres': ['VOLAILLE', 'BOVINS', 'OVINS'],
      'filiereAffichee': filiere,
      'unitesActives': 3,
      'tetesRestantes': 1320,
      'unitesCloturees': 2,
      'tetesSorties': 410,
      'soldeDuMois': {'revenus': 450000, 'depenses': 1250000, 'solde': -800000},
      'alertes': [
        {
          'id': 1,
          'maladie': 'Maladie de Newcastle',
          'zone': 'Koutiala',
          'filiere': 'VOLAILLE',
          'message': 'Vaccinez',
          'portee': 40,
          'statut': 'ACTIVE',
          'dateFin': jour(aujourdhui.add(const Duration(days: 12))),
        },
      ],
      'rappels': [
        {'id': 1, 'uniteId': 7, 'uniteCode': 'LOT-2026-014', 'libelle': 'Vaccin Gumboro (rappel)',
         'joursRestants': -3, 'statut': 'ECHU'},
        {'id': 2, 'libelle': 'Déparasitage', 'joursRestants': 0, 'statut': 'A_VENIR'},
      ],
      'notificationsNonLues': 12,
    };

Map<String, dynamic> uniteLotJson({int restant = 1500}) {
  final entree = aujourdhui.subtract(const Duration(days: 50));
  return {
    'id': 7,
    'code': 'LOT-2026-014',
    'modeSuivi': 'LOT',
    'filiere': 'VOLAILLE',
    'typeElevage': 'Poulet de chair',
    'statut': 'ACTIF',
    'dateEntree': jour(entree),
    'dateCloturePrevue': jour(entree.add(const Duration(days: 45))),
    'joursRestants': -5,
    'effectifInitial': 1850,
    'effectifRestant': restant,
    'note': 'Bâtiment nord',
  };
}

Unite lotFactice() => Unite.json(uniteLotJson());

Unite animalFactice() => Unite.json(animalJson);

final Map<String, dynamic> animalJson = {
      'id': 9,
      'code': 'BOV-048',
      'modeSuivi': 'INDIVIDUEL',
      'filiere': 'BOVINS',
      'typeElevage': 'Zébu',
      'statut': 'ACTIF',
      'dateEntree': jour(aujourdhui.subtract(const Duration(days: 400))),
      'effectifInitial': 1,
      'effectifRestant': 1,
    };

DonneesCarnet carnetFactice() {
  final entree = aujourdhui.subtract(const Duration(days: 50));
  final j = {
    'unite': uniteLotJson(),
    'mouvements': [
      {'id': 30, 'type': 'MISE_EN_PLACE', 'nombreTetes': 1850, 'dateMouvement': jour(entree)},
      {'id': 31, 'type': 'VENTE', 'nombreTetes': 300, 'dateMouvement': jour(aujourdhui),
       'motif': 'Marché de Koutiala'},
    ],
    'sorties': [
      {'id': 31, 'date': jour(aujourdhui), 'nature': 'VENTE', 'nombre': 300, 'montant': 900000},
    ],
    'evenements': [
      {'id': 1, 'type': 'VACCINATION', 'dateEvenement': jour(entree.add(const Duration(days: 7))),
       'produitObservation': 'HB1', 'veterinaire': 'Dr Aïssata Traoré'},
    ],
    'rappels': [
      {'id': 1, 'uniteId': 7, 'uniteCode': 'LOT-2026-014', 'libelle': 'Vaccin Gumboro',
       'joursRestants': -3, 'statut': 'ECHU'},
    ],
    'rentabilite': {'revenus': 900000, 'depenses': 1100000, 'solde': -200000},
  };
  return (detail: DetailUnite.json(j), sorties: SortieUnite.depuisDetail(j));
}

Map<String, dynamic> _maladie(int id, String nom, {String gravite = 'ELEVE'}) => {
      'id': id,
      'nom': nom,
      'gravite': gravite,
      'filieres': ['VOLAILLE'],
      'orienteVersVeterinaire': true,
    };

Map<String, dynamic> _cas(int id, String gravite, String statut) => {
      'id': id,
      'uniteCode': 'LOT #0$id',
      'eleveurNom': 'Mamadou Traoré',
      'eleveurTelephone': '76123456',
      'trancheEffectif': 'DE_10_A_50',
      'dateSignalement': aujourdhui.subtract(Duration(hours: id * 3)).toUtc().toIso8601String(),
      'diagnostic': {
        'probable': _maladie(3, 'Maladie de Newcastle', gravite: gravite),
        'gravite': gravite,
        'orientationRequise': true,
      },
      'gravite': gravite,
      'statut': statut,
      'uniteEffectif': 850,
      'filiere': 'VOLAILLE',
    };

/// Faux back de l'espace veterinaire : accueil, profil, competences, files.
http.Client backVeterinaire() => MockClient((r) async {
      Object? corps;
      final p = r.url.path;
      if (p.endsWith('/api/veterinaires/accueil')) {
        corps = {
          'enAttente': 4, 'enAttenteGraves': 2, 'traitesCeMois': 11,
          'conseilsPublies': 3, 'conseilsEnModeration': 1, 'disponible': true,
        };
      } else if (p.endsWith('/api/auth/moi')) {
        corps = {
          'id': 2, 'nom': 'Aïssata Traoré', 'email': 'veto@example.ml', 'role': 'VETERINAIRE',
          'titre': 'Docteur', 'zone': {'id': 1, 'nom': 'Koutiala'}, 'disponible': true,
        };
      } else if (p.endsWith('/api/veterinaires/competences')) {
        corps = [_maladie(3, 'Maladie de Newcastle'), _maladie(5, 'Bronchite infectieuse')];
      } else if (p.endsWith('/api/signalements/file')) {
        final statut = r.url.queryParameters['statut'];
        final elements = switch (statut) {
          'ORIENTE' => [_cas(1, 'ELEVE', 'ORIENTE'), _cas(2, 'MOYEN', 'ORIENTE')],
          'EN_COURS' => [_cas(3, 'FAIBLE', 'EN_COURS')],
          _ => <Map<String, dynamic>>[],
        };
        corps = {'elements': elements, 'page': 0, 'total': statut == 'TRAITE' ? 11 : elements.length,
          'derniere': true};
      } else if (p.endsWith('/api/notifications/non-lues')) {
        corps = 3;
      } else {
        return http.Response('{"message":"inconnu"}', 404);
      }
      return http.Response.bytes(utf8.encode(jsonEncode(corps)), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

/// Monte [ecran] a la taille et au grossissement du texte donnes, dans le
/// theme clair ou sombre.
Future<void> monterEcran(
  WidgetTester t,
  Widget ecran, {
  Size taille = const Size(360, 740),
  double texte = 1.0,
  bool sombre = false,
}) async {
  t.view.physicalSize = taille;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = texte;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  await t.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: themeMonCheptel(),
    darkTheme: themeMonCheptel(luminosite: Brightness.dark),
    themeMode: sombre ? ThemeMode.dark : ThemeMode.light,
    home: ecran,
  ));
  await t.pump();
  await t.pump(const Duration(seconds: 2));
}

/// Fait defiler la liste verticale principale jusqu'en bas, en verifiant a
/// chaque pas qu'aucun debordement n'a ete signale.
Future<void> parcourirJusquEnBas(WidgetTester t) async {
  final listes = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down);
  if (listes.evaluate().isEmpty) return;
  for (var i = 0; i < 25; i++) {
    final etat = t.state<ScrollableState>(listes.first);
    final pos = etat.position;
    if (pos.pixels >= pos.maxScrollExtent) break;
    pos.jumpTo((pos.pixels + 300).clamp(0, pos.maxScrollExtent));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    sansErreur(t);
  }
}

/// Aucun debordement ni erreur de rendu signale. Avec DETAILS_DEBORDEMENT=1
/// dans l'environnement, l'erreur est laissee au framework de test, qui
/// l'imprime en entier (widget fautif compris).
void sansErreur(WidgetTester t) {
  if (Platform.environment['DETAILS_DEBORDEMENT'] == '1') return;
  expect(t.takeException(), isNull);
}

/// Charge les vraies polices (Nunito, Baloo 2, icones Material) : sans
/// elles, le moteur de test dessine chaque lettre comme un carre d'un
/// cadratin (« Ahem »), deux fois plus large que Nunito, et les mesures de
/// debordement ne voudraient rien dire.
Future<void> chargerPolices() async {
  Future<void> famille(String nom, List<String> fichiers) async {
    final l = FontLoader(nom);
    for (final f in fichiers) {
      l.addFont(File(f).readAsBytes().then((o) => ByteData.sublistView(o)));
    }
    await l.load();
  }

  await famille('Nunito', [
    for (final g in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) 'assets/polices/Nunito-$g.ttf',
  ]);
  await famille('Baloo2', [
    for (final g in ['SemiBold', 'Bold', 'ExtraBold']) 'assets/polices/Baloo2-$g.ttf',
  ]);
  final flutter = Platform.environment['FLUTTER_ROOT'];
  final icones = File('${flutter ?? ''}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icones.existsSync()) await famille('MaterialIcons', [icones.path]);
}

http.Response _json(Object? corps) => http.Response.bytes(utf8.encode(jsonEncode(corps)), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});

/// Faux back de l'espace eleveur : cheptel, profil, rappels, signalements,
/// conseils, tableau de bord.
http.Client backEleveur() => MockClient((r) async {
      final p = r.url.path;
      if (p.endsWith('/api/cheptel')) return _json([uniteLotJson(), animalJson]);
      if (p.endsWith('/api/auth/moi')) {
        return _json({
          'id': 1, 'nom': 'Awa Traoré', 'email': 'awa@example.ml', 'role': 'ELEVEUR',
          'telephone': '76000000', 'zone': {'id': 1, 'nom': 'Koutiala'}, 'langue': 'FR',
          'filieresPratiquees': ['VOLAILLE', 'BOVINS'],
        });
      }
      if (p.endsWith('/api/sanitaire/rappels')) return _json(tableauJson()['rappels']);
      if (p.endsWith('/api/signalements/mes')) {
        return _json([
          {
            'id': 4, 'uniteCode': 'LOT-2026-014', 'statut': 'ORIENTE',
            'dateSignalement': aujourdhui.toUtc().toIso8601String(),
            'trancheEffectif': 'DE_10_A_50',
            'diagnostic': {'gravite': 'ELEVE', 'probable': _maladie(3, 'Maladie de Newcastle')},
            'veterinaireNom': 'Dr Aïssata Traoré', 'veterinaireTelephone': '76123456',
          },
        ]);
      }
      if (p.endsWith('/api/conseils')) {
        return _json({
          'elements': [
            for (final (i, c) in [('SANTE', 'Vacciner contre Newcastle'), ('HYGIENE', 'Nettoyer les abreuvoirs')].indexed)
              {
                'id': i + 1, 'titre': c.$2, 'categorie': c.$1, 'filiere': 'VOLAILLE',
                'extrait': 'Un geste simple qui protège tout le lot.',
                'veterinaireNom': 'Dr Aïssata Traoré',
                'datePublication': aujourdhui.toUtc().toIso8601String(),
              },
          ],
          'page': 0, 'total': 2, 'derniere': true,
        });
      }
      if (p.endsWith('/api/tableau-de-bord')) return _json(tableauJson());
      if (p.endsWith('/api/notifications/non-lues')) return _json(3);
      return http.Response('{"message":"inconnu"}', 404);
    });
