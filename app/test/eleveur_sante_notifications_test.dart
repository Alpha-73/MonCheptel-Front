// Espace eleveur : « Mes signalements » (audit F3) et notifications
// cliquables (audit F4). Les sources de donnees sont remplacees par des
// fonctions : aucun appel reseau.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moncheptel/api/modeles.dart';
import 'package:moncheptel/ecrans/eleveur/profil/notifications.dart';
import 'package:moncheptel/ecrans/eleveur/sante/mes_signalements.dart';
import 'package:moncheptel/theme/theme_app.dart';

Map<String, dynamic> _signalement({
  int id = 12,
  String statut = 'TRAITE',
  String? confirmee = 'Coccidiose',
  bool veterinaireRacine = true,
}) =>
    {
      'id': id,
      'uniteId': 3,
      'uniteCode': 'LOT-014',
      'symptomes': [
        {'id': 3, 'libelle': 'Diarrhée avec sang'},
        {'id': 5, 'libelle': 'Abattement'},
      ],
      'trancheEffectif': 'DE_10_A_50',
      'dateSignalement': '2026-10-05T08:30:00Z',
      'diagnostic': {
        'probable': {
          'id': 2,
          'nom': 'Coccidiose',
          'gravite': 'MOYEN',
          'filieres': ['VOLAILLE'],
          'orienteVersVeterinaire': false,
        },
        'gravite': 'MOYEN',
        'orientationRequise': true,
      },
      'statut': statut,
      if (statut == 'TRAITE') 'dateTraitement': '2026-10-06T10:00:00Z',
      if (statut == 'TRAITE') 'compteRendu': 'Anticoccidien 5 jours, eau changée chaque jour.',
      if (confirmee != null) 'maladieConfirmee': confirmee,
      if (veterinaireRacine)
        'veterinaire': {
          'id': 7,
          'nom': 'Dr Aïssata Traoré',
          'telephone': '+223 76 00 00 01',
          'disponible': true,
        },
    };

Future<void> _monter(WidgetTester t, Widget ecran) async {
  t.view.physicalSize = const Size(402, 874);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(theme: themeMonCheptel(), home: ecran));
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
}

NotificationApp _notification({
  int id = 1,
  String type = 'ORIENTATION',
  String titre = 'Réponse du vétérinaire',
  String? corps = 'Dr Traoré a répondu à votre signalement sur LOT-014',
  String? referenceType,
  int? referenceId,
}) =>
    NotificationApp.json({
      'id': id,
      'type': type,
      'titre': titre,
      if (corps != null) 'corps': corps,
      'lue': false,
      if (referenceType != null) 'referenceType': referenceType,
      if (referenceId != null) 'referenceId': referenceId,
      'dateCreation': DateTime.now().toUtc().toIso8601String(),
    });

PageApi<NotificationApp> _page(List<NotificationApp> l) =>
    PageApi<NotificationApp>.json({'elements': const [], 'page': 0, 'total': 0, 'derniere': true},
        NotificationApp.json)
      ..elements.addAll(l);

void main() {
  group('SuiviSignalement', () {
    test('lit le vétérinaire à la racine, sinon dans le diagnostic', () {
      final racine = SuiviSignalement.json(_signalement());
      expect(racine.veterinaire?.nom, 'Dr Aïssata Traoré');
      expect(racine.signalement.maladieConfirmee, 'Coccidiose');

      final j = _signalement(veterinaireRacine: false);
      (j['diagnostic'] as Map<String, dynamic>)['veterinaire'] = {
        'id': 8,
        'nom': 'Dr Diallo',
        'disponible': true,
      };
      expect(SuiviSignalement.json(j).veterinaire?.nom, 'Dr Diallo');

      final sansVeto = SuiviSignalement.json(_signalement(veterinaireRacine: false));
      expect(sansVeto.veterinaire, isNull);
    });
  });

  group('Mes signalements', () {
    testWidgets('statut, vétérinaire à appeler, maladie confirmée et réponse', (t) async {
      await _monter(
        t,
        EcranMesSignalements(
          charger: () async => [
            SuiviSignalement.json(_signalement()),
            SuiviSignalement.json(
                _signalement(id: 13, statut: 'ORIENTE', confirmee: null)),
          ],
        ),
      );
      expect(find.text('Mes signalements'), findsOneWidget);
      // Cas traité : maladie confirmée, réponse et statut lisible.
      expect(find.text('Réponse reçue'), findsOneWidget);
      expect(find.text('Confirmée par le vétérinaire'), findsOneWidget);
      expect(find.textContaining('Anticoccidien'), findsOneWidget);
      // Cas confié : pas encore de réponse, maladie probable.
      expect(find.text('En attente de réponse'), findsOneWidget);
      expect(find.text('Maladie probable'), findsOneWidget);
      // Le vétérinaire est nommé, avec un bouton Appeler par carte.
      expect(find.text('Dr Aïssata Traoré'), findsNWidgets(2));
      expect(find.text('Appeler'), findsNWidgets(2));
    });

    testWidgets('liste vide : invite à signaler', (t) async {
      await _monter(t, EcranMesSignalements(charger: () async => const []));
      expect(find.textContaining('Aucun signalement'), findsOneWidget);
      expect(find.text('Signaler un animal malade'), findsOneWidget);
    });

    testWidgets('le détail montre la réponse du vétérinaire et le suivi', (t) async {
      await _monter(
        t,
        EcranDetailSignalement(
          signalementId: 12,
          charger: (id) async => SuiviSignalement.json(_signalement(id: id)),
        ),
      );
      expect(find.text('Réponse du vétérinaire'), findsOneWidget);
      expect(find.text('Maladie confirmée'), findsOneWidget);
      expect(find.text('Coccidiose'), findsWidgets);
      expect(find.text('Appeler Dr Aïssata Traoré'), findsOneWidget);
      await t.scrollUntilVisible(find.text('Diarrhée avec sang'), 300,
          scrollable: find.byType(Scrollable).last);
      expect(find.text('Diarrhée avec sang'), findsOneWidget);
    });
  });

  group('Notifications', () {
    test('la référence désigne l’écran ; sans elle, le type décide', () {
      expect(cibleDe(_notification(referenceType: 'SIGNALEMENT', referenceId: 12)),
          isA<CibleSignalement>().having((c) => c.id, 'id', 12));
      expect(cibleDe(_notification(type: 'ALERTE', referenceType: 'ALERTE', referenceId: 4)),
          isA<CibleAlerte>());
      expect(cibleDe(_notification(type: 'MODERATION', referenceType: 'CONSEIL', referenceId: 9)),
          isA<CibleConseil>());
      expect(cibleDe(_notification()), isA<CibleMesSignalements>());
      expect(cibleDe(_notification(type: 'SYSTEME')), isA<CibleMessage>());
    });

    testWidgets('toucher une notification de signalement ouvre le signalement', (t) async {
      var marque = false;
      await _monter(
        t,
        EcranNotifications(
          charger: (_) async =>
              _page([_notification(referenceType: 'SIGNALEMENT', referenceId: 12)]),
          marquerLu: () async => marque = true,
        ),
      );
      expect(marque, isTrue);
      expect(find.text("Aujourd'hui"), findsOneWidget);
      await t.tap(find.text('Réponse du vétérinaire'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byType(EcranDetailSignalement), findsOneWidget);
      final ecran = t.widget<EcranDetailSignalement>(find.byType(EcranDetailSignalement));
      expect(ecran.signalementId, 12);
      // Le chargement reel echoue sans serveur : on laisse retomber.
      await t.pump(const Duration(seconds: 1));
    });

    testWidgets('sans référence, la notification affiche son message', (t) async {
      await _monter(
        t,
        EcranNotifications(
          charger: (_) async => _page([
            _notification(
                type: 'SYSTEME', titre: 'Bienvenue', corps: 'Votre compte est prêt.'),
          ]),
          marquerLu: () async {},
        ),
      );
      await t.tap(find.text('Bienvenue'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Votre compte est prêt.'), findsNWidgets(2));
      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('le toucher peut être remplacé (espace vétérinaire)', (t) async {
      NotificationApp? touchee;
      await _monter(
        t,
        EcranNotifications(
          charger: (_) async => _page([_notification(referenceType: 'SIGNALEMENT', referenceId: 3)]),
          marquerLu: () async {},
          surToucher: (_, n) async => touchee = n,
        ),
      );
      await t.tap(find.text('Réponse du vétérinaire'));
      await t.pump();
      expect(touchee?.referenceId, 3);
    });
  });
}
