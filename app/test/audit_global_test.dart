// Regles de l'app ajoutees par l'audit global : configuration de
// publication (G19), cloture du veterinaire filtree par filiere (G6),
// cloture d'un lot qui a encore des tetes (G5), notification RAPPEL vers le
// carnet, prise en charge explicite (relecture, point 6).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moncheptel/api/modeles.dart';
import 'package:moncheptel/config.dart';
import 'package:moncheptel/ecrans/eleveur/animaux/carnet.dart';
import 'package:moncheptel/ecrans/eleveur/profil/notifications.dart';
import 'package:moncheptel/ecrans/veterinaire/cloture.dart';
import 'package:moncheptel/ecrans/veterinaire/demandes.dart';
import 'package:moncheptel/theme/theme_app.dart';

Map<String, dynamic> _maladie(int id, String nom, List<String> filieres) => {
      'id': id,
      'nom': nom,
      'gravite': 'ELEVE',
      'filieres': filieres,
      'orienteVersVeterinaire': true,
    };

Signalement _cas({String statut = 'ORIENTE', String? filiere}) => Signalement.json({
      'id': 41,
      'uniteCode': 'BOV-007',
      'eleveurNom': 'Mamadou Traoré',
      'eleveurTelephone': '76123456',
      'trancheEffectif': 'MOINS_DE_10',
      'dateSignalement': '2026-10-07T08:30:00Z',
      'diagnostic': {
        'probable': _maladie(3, 'Maladie de Newcastle', ['VOLAILLE']),
        'alternative': _maladie(8, 'Fièvre aphteuse', ['BOVINS']),
        'gravite': 'ELEVE',
        'orientationRequise': true,
      },
      'statut': statut,
      'uniteEffectif': 1,
      if (filiere != null) 'uniteFiliere': filiere,
    });

Future<void> _monter(WidgetTester t, Widget ecran) async {
  t.view.physicalSize = const Size(402, 874);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    theme: themeMonCheptel(),
    builder: (context, enfant) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: enfant!,
    ),
    home: ecran,
  ));
  await t.pumpAndSettle();
}

void main() {
  group('Configuration de publication (G19)', () {
    test('en debug, aucune exigence', () {
      expect(Config.erreurConfiguration(release: false, url: 'http://10.0.2.2:8080'), isNull);
    });
    test('en publication, une adresse HTTP est refusée avec un message clair', () {
      final e = Config.erreurConfiguration(release: true, url: 'http://10.0.2.2:8080');
      expect(e, contains('HTTPS'));
      expect(e, contains('--dart-define=API_URL=https://'));
    });
    test('en publication, une adresse HTTPS passe', () {
      expect(Config.erreurConfiguration(release: true, url: 'https://api.moncheptel.ml'), isNull);
    });
  });

  group('Clôture vétérinaire filtrée par filière (G6)', () {
    testWidgets("une hypothèse d'une autre filière n'est ni proposée ni présélectionnée", (t) async {
      await _monter(t, EcranCloture(signalement: _cas(statut: 'EN_COURS', filiere: 'BOVINS')));
      expect(find.text('Maladie de Newcastle'), findsNothing);
      expect(find.text('Fièvre aphteuse'), findsOneWidget);
      expect(find.text("Proposée par l'outil"), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('sans filière connue, rien n’est filtré', (t) async {
      await _monter(t, EcranCloture(signalement: _cas(statut: 'EN_COURS')));
      expect(find.text('Maladie de Newcastle'), findsOneWidget);
      expect(find.text("Proposée par l'outil"), findsOneWidget);
    });
  });

  group('Accepter ou refuser un cas confié (point 6, V14)', () {
    testWidgets("ouvrir un cas confié ne l'accepte pas ; le bouton, si", (t) async {
      var appels = 0;
      await _monter(
          t,
          EcranDemande(
            signalement: _cas(),
            prendreEnCharge: (id) async {
              appels++;
              return _cas(statut: 'EN_COURS');
            },
          ));
      expect(appels, 0);
      expect(find.text('Refuser'), findsOneWidget);
      final bouton = find.text('Accepter le cas');
      expect(bouton, findsOneWidget);
      await t.ensureVisible(bouton);
      await t.tap(bouton);
      await t.pumpAndSettle();
      expect(appels, 1);
      expect(find.text('Accepter le cas'), findsNothing);
    });

    testWidgets('refuser demande un motif facultatif puis envoie le refus', (t) async {
      String? motifRecu;
      var refus = 0;
      await _monter(
          t,
          EcranDemande(
            signalement: _cas(),
            prendreEnCharge: (id) async => fail('accepter ne doit pas être appelé'),
            refuser: (id, {motif}) async {
              refus++;
              motifRecu = motif;
              return _cas(statut: 'NOUVEAU');
            },
          ));
      final bouton = find.text('Refuser');
      await t.ensureVisible(bouton);
      await t.tap(bouton);
      await t.pumpAndSettle();
      expect(find.text('Refuser ce cas ?'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'En déplacement');
      await t.tap(find.text('Refuser le cas'));
      await t.pumpAndSettle();
      expect(refus, 1);
      expect(motifRecu, 'En déplacement');
    });

    testWidgets('un cas déjà accepté n’affiche ni « Accepter » ni « Refuser »', (t) async {
      await _monter(t, EcranDemande(signalement: _cas(statut: 'EN_COURS'),
          prendreEnCharge: (id) async => fail('ne doit pas être appelé')));
      expect(find.text('Accepter le cas'), findsNothing);
      expect(find.text('Refuser'), findsNothing);
    });
  });

  group('Clôture d’un lot qui a encore des têtes (G5)', () {
    test('le message dit combien il en reste et quoi faire', () {
      final lot = Unite.json({
        'id': 1, 'code': 'LOT-014', 'modeSuivi': 'LOT', 'filiere': 'VOLAILLE',
        'typeElevage': 'Poulet de chair', 'statut': 'ACTIF',
        'dateEntree': '2026-08-01', 'effectifInitial': 50, 'effectifRestant': 40,
      });
      final (titre, message) = messageClotureAvecTetes(lot);
      expect(titre, startsWith('LOT-014 compte encore 40'));
      expect(message, contains('vendues, mortes ou transférées'));

      final animal = Unite.json({
        'id': 2, 'code': 'BOV-048', 'modeSuivi': 'INDIVIDUEL', 'filiere': 'BOVINS',
        'typeElevage': 'Zébu', 'statut': 'ACTIF', 'dateEntree': '2026-08-01',
        'effectifInitial': 1, 'effectifRestant': 1,
      });
      expect(messageClotureAvecTetes(animal).$1, 'Clôturer la fiche de BOV-048 ?');
    });
  });

  test('une notification RAPPEL liée à une unité ouvre son carnet', () {
    final n = NotificationApp.json({
      'id': 1,
      'type': 'RAPPEL',
      'titre': 'Soins à faire demain',
      'corps': 'Newcastle (LOT-014).',
      'lue': false,
      'referenceType': 'UNITE',
      'referenceId': 14,
      'dateCreation': '2026-10-08T06:00:00Z',
    });
    expect(cibleDe(n), isA<CibleUnite>().having((c) => c.id, 'id', 14));
  });
}
