// Notifications poussees (audit du 11 octobre) : le message Firebase est
// relu comme une notification de l'ecran Notifications, donc ouvre le meme
// ecran. Aucun appel a Firebase ici.
import 'package:flutter_test/flutter_test.dart';
import 'package:moncheptel/ecrans/eleveur/profil/notifications.dart';
import 'package:moncheptel/pousse/pousse.dart';

void main() {
  test('un cas confie ouvre le signalement', () {
    final n = notificationDepuisDonnees(
      titre: 'Nouveau signalement — Newcastle',
      corps: 'Balla Koné a signalé des symptômes sur LOT-014',
      donnees: {'type': 'ORIENTATION', 'referenceType': 'SIGNALEMENT', 'referenceId': '42'},
    );
    expect(n.titre, 'Nouveau signalement — Newcastle');
    expect(n.referenceType, 'SIGNALEMENT');
    expect(n.referenceId, 42);
    expect(cibleDe(n), isA<CibleSignalement>().having((c) => c.id, 'id', 42));
  });

  test('un rappel de soins ouvre le carnet de l’unité', () {
    final n = notificationDepuisDonnees(
      titre: 'Soins à faire demain',
      donnees: {'type': 'RAPPEL', 'referenceType': 'UNITE', 'referenceId': '14'},
    );
    expect(cibleDe(n), isA<CibleUnite>().having((c) => c.id, 'id', 14));
  });

  test('sans référence (le back envoie des chaînes vides), le type décide', () {
    final n = notificationDepuisDonnees(
      titre: 'Choisissez un autre vétérinaire',
      donnees: {'type': 'ORIENTATION', 'referenceType': '', 'referenceId': ''},
    );
    expect(n.referenceType, isNull);
    expect(n.referenceId, isNull);
    expect(cibleDe(n), isA<CibleMesSignalements>());
  });

  test('message incomplet : titre par défaut, aucun plantage', () {
    final n = notificationDepuisDonnees(donnees: const {});
    expect(n.titre, 'MonCheptel');
    expect(n.type, 'SYSTEME');
    expect(cibleDe(n), isA<CibleMessage>());
  });
}
