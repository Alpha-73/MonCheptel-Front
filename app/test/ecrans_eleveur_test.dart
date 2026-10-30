// Accueil et carnet de l'eleveur, rendus avec des donnees factices (aucun
// appel au back) sur un petit telephone : rien ne deborde, les gestes
// attendus sont la (annuler une vente, cloturer un lot).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moncheptel/api/modeles.dart';
import 'package:moncheptel/ecrans/eleveur/animaux/carnet.dart';
import 'package:moncheptel/ecrans/eleveur/tableau_de_bord.dart';
import 'package:moncheptel/theme/theme_app.dart';

String _jour(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

final _ajd = DateTime.now();

TableauDeBord _tableau({bool alerte = true}) => TableauDeBord.json({
      'nomEleveur': 'Awa Traoré',
      'zone': 'Koutiala',
      'filieres': ['VOLAILLE', 'BOVINS'],
      'filiereAffichee': 'VOLAILLE',
      'unitesActives': 3,
      'tetesRestantes': 1320,
      'unitesCloturees': 2,
      'tetesSorties': 410,
      'soldeDuMois': {'revenus': 450000, 'depenses': 1250000, 'solde': -800000},
      'alertes': [
        if (alerte)
          {
            'id': 1,
            'maladie': 'Maladie de Newcastle',
            'zone': 'Koutiala',
            'filiere': 'VOLAILLE',
            'message': 'Vaccinez',
            'portee': 40,
            'statut': 'ACTIVE',
            'dateFin': _jour(_ajd.add(const Duration(days: 12))),
          },
        // Alerte d'une autre filiere : masquee sur l'onglet Volaille (F15).
        {
          'id': 2,
          'maladie': 'Fièvre aphteuse',
          'zone': 'Koutiala',
          'filiere': 'BOVINS',
          'message': '',
          'portee': 3,
          'statut': 'ACTIVE',
        },
      ],
      'rappels': [
        {'id': 1, 'uniteId': 7, 'uniteCode': 'LOT-2026-014', 'libelle': 'Vaccin Gumboro (rappel)',
         'joursRestants': -3, 'statut': 'ECHU'},
        {'id': 2, 'libelle': 'Déparasitage', 'joursRestants': 0, 'statut': 'A_VENIR'},
        {'id': 3, 'uniteId': 8, 'uniteCode': 'LOT-015', 'libelle': 'Vitamines',
         'joursRestants': 5, 'statut': 'A_VENIR'},
      ],
      'notificationsNonLues': 12,
    });

DonneesCarnet _carnet() {
  final entree = _ajd.subtract(const Duration(days: 50));
  final j = {
    'unite': {
      'id': 7,
      'code': 'LOT-2026-014',
      'modeSuivi': 'LOT',
      'filiere': 'VOLAILLE',
      'typeElevage': 'Poulet de chair',
      'statut': 'ACTIF',
      'dateEntree': _jour(entree),
      'dateCloturePrevue': _jour(entree.add(const Duration(days: 45))),
      'joursRestants': -5,
      'effectifInitial': 1850,
      'effectifRestant': 1500,
      'note': 'Bâtiment nord',
    },
    'mouvements': [
      {'id': 30, 'type': 'MISE_EN_PLACE', 'nombreTetes': 1850, 'dateMouvement': _jour(entree)},
      {'id': 31, 'type': 'VENTE', 'nombreTetes': 300, 'dateMouvement': _jour(_ajd),
       'motif': 'Marché de Koutiala'},
      {'id': 32, 'type': 'MORT', 'nombreTetes': 50, 'dateMouvement': _jour(_ajd)},
    ],
    'sorties': [
      {'id': 31, 'date': _jour(_ajd), 'nature': 'VENTE', 'nombre': 300, 'montant': 900000},
    ],
    'evenements': [
      {'id': 1, 'type': 'VACCINATION', 'dateEvenement': _jour(entree.add(const Duration(days: 7))),
       'produitObservation': 'HB1', 'veterinaire': 'Dr Aïssata Traoré'},
      {'id': 2, 'type': 'TRAITEMENT', 'dateEvenement': _jour(entree.add(const Duration(days: 9)))},
    ],
    'rappels': [
      {'id': 1, 'uniteId': 7, 'uniteCode': 'LOT-2026-014', 'libelle': 'Vaccin Gumboro',
       'joursRestants': -3, 'statut': 'ECHU'},
    ],
    'rentabilite': {'revenus': 900000, 'depenses': 1100000, 'solde': -200000},
  };
  return (detail: DetailUnite.json(j), sorties: SortieUnite.depuisDetail(j));
}

Future<void> _monter(WidgetTester t, Widget ecran, {double largeur = 360}) async {
  t.view.physicalSize = Size(largeur, 740);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    theme: themeMonCheptel(),
    home: ecran is EcranCarnet ? ecran : Scaffold(body: ecran),
  ));
  await t.pump();
  await t.pump(const Duration(seconds: 2));
}

/// La liste verticale de l'ecran (les onglets de filiere defilent aussi).
Finder _vertical() => find
    .byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down)
    .first;

Future<void> _montrer(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('Accueil : salutation, jauge, alerte de la filière, à faire, raccourcis', (t) async {
    await _monter(
        t, TableauDeBordEleveur(versOnglet: (_) {}, charger: (_) async => _tableau()));
    expect(t.takeException(), isNull);
    expect(find.text('Awa'), findsOneWidget);
    // 3 lots, 2 avec un soin en retard ? Un seul : 2 sur 3 a jour.
    expect(find.text('67 %'), findsOneWidget);
    expect(find.text('Alerte : Maladie de Newcastle'), findsOneWidget);
    expect(find.text('Alerte : Fièvre aphteuse'), findsNothing);
    // Le compteur porte le nom de l'espece de l'onglet.
    await t.scrollUntilVisible(find.text('Têtes de volaille'), 200, scrollable: _vertical());
    expect(find.text('Têtes en élevage'), findsNothing);
    // « Solde » (ex « Argent du mois ») passe AVANT les raccourcis.
    await t.scrollUntilVisible(find.text('Événement sanitaire'), 200, scrollable: _vertical());
    expect(find.text('Argent du mois'), findsNothing);
    expect(t.getTopLeft(find.text('Solde')).dy,
        lessThan(t.getTopLeft(find.text('Raccourcis')).dy));
    // Quatre raccourcis, une famille chacun ; plus de « Vendre ».
    for (final r in ['+ Opération', 'Changer le statut', 'Ajouter un lot', 'Événement sanitaire']) {
      expect(find.text(r), findsOneWidget, reason: r);
    }
    expect(find.text('Vendre'), findsNothing);
    expect(find.text('Soigner'), findsNothing);
    // « À faire » tout en bas, sous les raccourcis.
    await t.scrollUntilVisible(find.text('Vaccin Gumboro (rappel)'), 200, scrollable: _vertical());
    expect(find.text('Vaccin Gumboro (rappel)'), findsOneWidget);
    expect(t.getTopLeft(find.text('À faire')).dy,
        greaterThan(t.getTopLeft(find.text('Raccourcis')).dy));
    // Sans unite : pas de tiret orphelin (F18).
    await t.scrollUntilVisible(find.text("aujourd'hui"), 200, scrollable: _vertical());
    expect(t.takeException(), isNull);
    await t.pump(const Duration(seconds: 2));
  });

  testWidgets('Accueil tient aussi sur 320 px', (t) async {
    await _monter(t, TableauDeBordEleveur(versOnglet: (_) {}, charger: (_) async => _tableau()),
        largeur: 320);
    expect(t.takeException(), isNull);
    await t.scrollUntilVisible(find.text('Solde du mois · toutes filières'), 200,
        scrollable: _vertical());
    expect(t.takeException(), isNull);
    await t.pump(const Duration(seconds: 2));
  });

  testWidgets('Carnet : cycle dépassé, clôture, annulation d’une vente', (t) async {
    await _monter(t, EcranCarnet(uniteId: 7, charger: () async => _carnet()));
    expect(t.takeException(), isNull);
    expect(find.text('J+50'), findsOneWidget);
    expect(find.text('Cycle terminé depuis 5 jours'), findsOneWidget);
    // Barre du bas : sanitaire, statut et argent sont trois gestes distincts.
    expect(find.text('Événement sanitaire'), findsOneWidget);
    expect(find.text('Opération'), findsOneWidget);
    expect(find.text('Changer le statut'), findsWidgets);
    expect(find.text('Soigner'), findsNothing);

    await t.scrollUntilVisible(find.text('Vente · − 300 têtes'), 200, scrollable: _vertical());
    expect(find.text('+ 900 000 FCFA · Marché de Koutiala'), findsOneWidget);
    await _montrer(t, find.text('Vente · − 300 têtes'));
    await t.tap(find.text('Vente · − 300 têtes'));
    await t.pumpAndSettle();
    expect(find.text('Annuler cette vente ?'), findsOneWidget);
    await t.tap(find.text('Garder'));
    await t.pumpAndSettle();

    await t.scrollUntilVisible(find.text('Clôturer le lot'), 200, scrollable: _vertical());
    await _montrer(t, find.text('Clôturer le lot'));
    await t.tap(find.text('Clôturer le lot'));
    await t.pumpAndSettle();
    // Audit global G5 : des tetes restent, on demande ce qu'elles sont devenues.
    expect(find.textContaining('LOT-2026-014 compte encore'), findsOneWidget);
    expect(find.text('Enregistrer leur sortie'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('Carnet : l’acte d’un vétérinaire est en lecture seule', (t) async {
    await _monter(t, EcranCarnet(uniteId: 7, charger: () async => _carnet()));
    await t.scrollUntilVisible(find.text('Vaccination'), 200, scrollable: _vertical());
    await _montrer(t, find.text('Vaccination'));
    await t.tap(find.text('Vaccination'));
    await t.pumpAndSettle();
    // Aucun ecran de modification ouvert.
    expect(find.text("Modifier l'événement"), findsNothing);
  });
}
