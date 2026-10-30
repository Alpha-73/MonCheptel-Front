// Lecture des reponses du back propres a l'espace veterinaire, et petits
// calculs des ecrans. Le JSON est celui que rend le back (Jackson, champs
// nuls omis), recopie des DTO Java et du contrat d'API du 7 octobre.
import 'package:flutter_test/flutter_test.dart';
import 'package:moncheptel/api/modeles.dart';
import 'package:moncheptel/ecrans/veterinaire/commun_veterinaire.dart';
import 'package:moncheptel/libelles.dart';
import 'package:moncheptel/theme/format.dart';

Map<String, dynamic> _signalement({
  String statut = 'ORIENTE',
  String? gravite = 'ELEVE',
  int? effectif = 850,
  String? type = 'Poulets de chair',
}) =>
    {
      'id': 41,
      'uniteId': 7,
      'uniteCode': 'LOT #024',
      'eleveurNom': 'Mamadou Traoré',
      'eleveurTelephone': '+223 76 12 34 56',
      'eleveurZone': 'Bamako',
      'symptomes': [
        {'id': 1, 'libelle': 'Toux'},
        {'id': 2, 'libelle': 'Diarrhée verdâtre'},
      ],
      'trancheEffectif': 'PLUS_DE_50',
      'precision': 'Propagation rapide',
      'dateSignalement': '2026-10-07T08:30:00Z',
      'diagnostic': {
        'probable': {
          'id': 3,
          'nom': 'Maladie de Newcastle',
          'gravite': 'ELEVE',
          'filieres': ['VOLAILLE'],
          'orienteVersVeterinaire': true,
        },
        if (gravite != null) 'gravite': gravite,
        'orientationRequise': true,
      },
      'statut': statut,
      if (statut == 'TRAITE') 'dateTraitement': '2026-10-07T10:00:00Z',
      if (statut == 'TRAITE') 'compteRendu': 'Vaccination de rappel faite.',
      if (type != null) 'uniteType': type,
      if (effectif != null) 'uniteEffectif': effectif,
    };

void main() {
  group('Signalement (vue veterinaire)', () {
    test('lit tous les champs de SignalementReponse', () {
      final s = Signalement.json(_signalement());
      expect(s.id, 41);
      expect(s.uniteId, 7);
      expect(s.uniteCode, 'LOT #024');
      expect(s.eleveurNom, 'Mamadou Traoré');
      expect(s.eleveurTelephone, '+223 76 12 34 56');
      expect(s.eleveurZone, 'Bamako');
      expect(s.symptomes.map((x) => x.libelle), ['Toux', 'Diarrhée verdâtre']);
      expect(s.trancheEffectif, 'PLUS_DE_50');
      expect(s.precision, 'Propagation rapide');
      expect(s.dateSignalement, DateTime.utc(2026, 10, 7, 8, 30).toLocal());
      expect(s.maladie, 'Maladie de Newcastle');
      expect(s.gravite, 'ELEVE');
      expect(s.uniteType, 'Poulets de chair');
      expect(s.uniteEffectif, 850);
      expect(s.enAttente, isTrue);
      expect(s.traite, isFalse);
      expect(s.compteRendu, isNull);
    });

    test('un cas traite porte sa date et son compte rendu', () {
      final s = Signalement.json(_signalement(statut: 'TRAITE'));
      expect(s.traite, isTrue);
      expect(s.enAttente, isFalse);
      expect(s.compteRendu, 'Vaccination de rappel faite.');
      expect(s.dateTraitement, isNotNull);
    });

    test('la vue eleveur, sans telephone ni nouveaux champs, se lit aussi', () {
      final s = Signalement.json({
        'id': 1,
        'trancheEffectif': 'MOINS_DE_10',
        'statut': 'NOUVEAU',
      });
      expect(s.eleveurTelephone, isNull);
      expect(s.uniteEffectif, isNull);
      expect(s.maladie, isNull);
      expect(s.gravite, isNull);
      expect(s.symptomes, isEmpty);
    });

    test('PageReponse<SignalementReponse>', () {
      final p = PageApi<Signalement>.json({
        'elements': [_signalement(), _signalement(statut: 'EN_COURS')],
        'page': 0,
        'taille': 20,
        'total': 2,
        'nombrePages': 1,
        'derniere': true,
      }, Signalement.json);
      expect(p.elements, hasLength(2));
      expect(p.total, 2);
      expect(p.derniere, isTrue);
    });
  });

  group('ligneUnite', () {
    test('un lot : code, effectif, zone', () {
      expect(ligneUnite(Signalement.json(_signalement())), 'LOT #024 · 850 sujets · Bamako');
    });

    test('un animal seul : code, type, zone', () {
      final s = Signalement.json(_signalement(effectif: 1, type: 'Zébu'));
      expect(ligneUnite(s), 'LOT #024 · Zébu · Bamako');
    });
  });

  group('ConseilDetail (auteur)', () {
    test('lit statut, motif, dates et date de reference', () {
      final c = ConseilDetail.json({
        'id': 9,
        'titre': 'Réduire les risques de Newcastle',
        'contenu': 'Vaccinez dès 7 jours.',
        'filiere': 'VOLAILLE',
        'categorie': 'SANTE',
        'nombreLectures': 12,
        'statut': 'EN_MODERATION',
        'dateCreation': '2026-09-17T09:00:00Z',
        'dateSoumission': '2026-09-17T09:05:00Z',
      });
      expect(c.statut, 'EN_MODERATION');
      expect(c.auteur, isNull); // absent : publie par l'administration
      expect(c.nombreLectures, 12);
      expect(c.datePublication, isNull);
      expect(c.dateReference, DateTime.utc(2026, 9, 17, 9, 5).toLocal());
      expect(L.statutConseil(c.statut), 'En modération');
    });

    test('un conseil publie prend sa date de publication', () {
      final c = ConseilDetail.json({
        'id': 1,
        'titre': 't',
        'contenu': 'c',
        'filiere': 'BOVINS',
        'categorie': 'HYGIENE',
        'datePublication': '2026-09-12T08:00:00Z',
        'dateCreation': '2026-09-01T08:00:00Z',
        'statut': 'PUBLIE',
        'auteur': {'id': 2, 'nom': 'Aissata Traore', 'titre': 'Dr', 'disponible': true},
      });
      expect(c.dateReference, DateTime.utc(2026, 9, 12, 8).toLocal());
      expect(c.auteur!.nom, 'Aissata Traore');
    });
  });

  group('AccueilVeterinaire', () {
    test('lit les cinq compteurs', () {
      final a = AccueilVeterinaire.json({
        'enAttente': 3,
        'enAttenteGraves': 2,
        'traitesCeMois': 12,
        'conseilsPublies': 7,
        'conseilsEnModeration': 1,
      });
      expect(
          [a.enAttente, a.enAttenteGraves, a.traitesCeMois, a.conseilsPublies,
              a.conseilsEnModeration],
          [3, 2, 12, 7, 1]);
    });

    test('un compteur absent vaut zero', () {
      expect(AccueilVeterinaire.json({}).enAttente, 0);
    });
  });

  group('Profil (veterinaire)', () {
    final json = {
      'id': 5,
      'nom': 'Aissata Traore',
      'telephone': '76000000',
      'email': 'aissata.traore@example.ml',
      'role': 'VETERINAIRE',
      'zone': {'id': 1, 'nom': 'Koutiala', 'region': 'Sikasso'},
      'langue': 'FR',
      'dateInscription': '2026-03-21',
      'filieresPratiquees': <String>[],
      'titre': 'Dr',
      'specialite': 'Aviculture',
      'zoneIntervention': {'id': 1, 'nom': 'Koutiala', 'region': 'Sikasso'},
      'disponible': true,
    };

    test('lit titre, specialite, zone d intervention, disponibilite', () {
      final p = Profil.json(json);
      expect(p.titre, 'Dr');
      expect(p.specialite, 'Aviculture');
      expect(p.zoneIntervention!.nom, 'Koutiala');
      expect(p.disponible, isTrue);
      expect(p.dateInscription, DateTime(2026, 3, 21));
      expect(p.nomAffiche, 'Dr Aissata Traore');
    });

    test('ne double pas le titre deja saisi dans le nom', () {
      final p = Profil.json({...json, 'nom': 'Dr Aissata Traore'});
      expect(p.nomAffiche, 'Dr Aissata Traore');
    });

    test('un eleveur n a pas de titre', () {
      final p = Profil.json({'id': 1, 'nom': 'Mamadou Traoré', 'email': 'm@x.ml', 'role': 'ELEVEUR'});
      expect(p.titre, isNull);
      expect(p.nomAffiche, 'Mamadou Traoré');
    });
  });

  test('filieresDesCompetences : union triee des filieres des maladies', () {
    Maladie m(List<String> f) =>
        Maladie.json({'id': 1, 'nom': 'x', 'gravite': 'MOYEN', 'filieres': f});
    expect(
      filieresDesCompetences([
        m(['CAPRINS', 'OVINS']),
        m(['VOLAILLE']),
        m(['VOLAILLE']),
      ]),
      ['VOLAILLE', 'OVINS', 'CAPRINS'],
    );
    expect(filieresDesCompetences([]), isEmpty);
  });

  group('Fmt', () {
    test('dateLongue', () {
      expect(Fmt.dateLongue(DateTime(2026, 9, 12)), '12 septembre 2026');
      expect(Fmt.dateLongue(null), '—');
    });

    test('signale : recent, puis date', () {
      final maintenant = DateTime.now();
      expect(Fmt.signale(maintenant.subtract(const Duration(hours: 2))), 'Signalé il y a 2 h');
      expect(Fmt.signale(maintenant.subtract(const Duration(hours: 30)), feminin: true),
          'Signalée hier');
      final ancien = DateTime(2026, 9, 3);
      expect(Fmt.signale(ancien), 'Signalé le ${Fmt.date(ancien)}');
    });
  });
}
