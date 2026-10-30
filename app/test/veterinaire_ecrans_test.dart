// Tests des ecrans du poste de garde : cloture d'un cas (choix de la
// maladie, compte rendu obligatoire, erreurs du back) et interrupteur de
// disponibilite. Les appels au back sont remplaces par des fonctions.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moncheptel/api/client_api.dart';
import 'package:moncheptel/api/modeles.dart';
import 'package:moncheptel/ecrans/veterinaire/cloture.dart';
import 'package:moncheptel/ecrans/veterinaire/accueil_veterinaire.dart';
import 'package:moncheptel/ecrans/veterinaire/commun_veterinaire.dart';
import 'package:moncheptel/ecrans/veterinaire/demandes.dart';
import 'package:moncheptel/ecrans/veterinaire/disponibilite.dart';
import 'package:moncheptel/theme/theme_app.dart';

Map<String, dynamic> _maladie(int id, String nom, {String gravite = 'ELEVE'}) => {
      'id': id,
      'nom': nom,
      'gravite': gravite,
      'filieres': ['VOLAILLE'],
      'orienteVersVeterinaire': true,
    };

Signalement _cas({bool probable = true, String? telephone = '76123456', int effectif = 850}) =>
    Signalement.json({
      'id': 41,
      'uniteCode': 'LOT #024',
      'eleveurNom': 'Mamadou Traoré',
      if (telephone != null) 'eleveurTelephone': telephone,
      'trancheEffectif': 'MOINS_DE_10',
      'dateSignalement': '2026-10-07T08:30:00Z',
      'diagnostic': {
        if (probable) 'probable': _maladie(3, 'Maladie de Newcastle'),
        if (probable) 'alternative': _maladie(5, 'Bronchite infectieuse', gravite: 'MOYEN'),
        'gravite': 'ELEVE',
        'orientationRequise': true,
      },
      'statut': 'EN_COURS',
      'uniteEffectif': effectif,
    });

Signalement _clos(String? maladie) => Signalement.json({
      'id': 41,
      'eleveurNom': 'Mamadou Traoré',
      'trancheEffectif': 'MOINS_DE_10',
      'statut': 'TRAITE',
      'compteRendu': 'ok',
      if (maladie != null) 'maladieConfirmee': maladie,
    });

/// Un ecran d'accueil qui ouvre la cloture et garde son resultat.
class _Hote extends StatefulWidget {
  const _Hote(this.ecran);
  final Widget ecran;
  @override
  State<_Hote> createState() => _HoteState();
}

ResultatCloture? _resultat;
bool _revenu = false;

class _HoteState extends State<_Hote> {
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async {
              _resultat = await Navigator.of(context)
                  .push<ResultatCloture>(MaterialPageRoute(builder: (_) => widget.ecran));
              _revenu = true;
            },
            child: const Text('ouvrir'),
          ),
        ),
      );
}

Future<void> _monter(WidgetTester t, Widget ecran) async {
  t.view.physicalSize = const Size(402, 874);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  _resultat = null;
  _revenu = false;
  await t.pumpWidget(MaterialApp(
    theme: themeMonCheptel(),
    builder: (context, enfant) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: enfant!,
    ),
    home: _Hote(ecran),
  ));
  await t.tap(find.text('ouvrir'));
  await t.pumpAndSettle();
}

Future<void> _toucher(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
}

Future<void> _cloturer(WidgetTester t) async {
  await t.tap(find.text('Clôturer le cas'));
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  group('Écran de clôture', () {
    testWidgets('la maladie probable est présélectionnée, le compte rendu est exigé',
        (t) async {
      var appels = 0;
      await _monter(
        t,
        EcranCloture(
          signalement: _cas(),
          envoyer: (id, cr, m) async {
            appels++;
            return _clos('Maladie de Newcastle');
          },
        ),
      );
      expect(find.text('Maladie de Newcastle'), findsOneWidget);
      expect(find.text("Proposée par l'outil"), findsOneWidget);
      expect(find.text('Bronchite infectieuse'), findsOneWidget);
      expect(find.text('Diagnostic non posé'), findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('maladie-3')),
              matching: find.byIcon(Icons.radio_button_checked_rounded)),
          findsOneWidget);

      await _cloturer(t);
      await t.pumpAndSettle();
      expect(appels, 0);
      expect(find.textContaining('le compte rendu est obligatoire'), findsOneWidget);
    });

    testWidgets("l'autre hypothèse et une phrase toute faite partent au back", (t) async {
      int? maladieEnvoyee = -1;
      String? compteRendu;
      await _monter(
        t,
        EcranCloture(
          signalement: _cas(),
          envoyer: (id, cr, m) async {
            maladieEnvoyee = m;
            compteRendu = cr;
            return _clos('Bronchite infectieuse');
          },
        ),
      );
      await _toucher(t, find.text('Bronchite infectieuse'));
      await t.pump();
      await _toucher(t, find.text('Vaccination faite'));
      await t.pump();
      await t.ensureVisible(find.byKey(const ValueKey('complement')));
      await t.enterText(find.byKey(const ValueKey('complement')), 'Rappel dans 21 jours');
      await t.pump();
      await _cloturer(t);
      expect(maladieEnvoyee, 5);
      expect(compteRendu, 'Vaccination faite. Rappel dans 21 jours');
      expect(find.text('Cas clôturé'), findsWidgets);
      expect(find.textContaining('Diagnostic : Bronchite infectieuse'), findsOneWidget);

      await t.tap(find.text('Voir les demandes restantes'));
      await t.pumpAndSettle();
      expect(_revenu, isTrue);
      expect(_resultat?.onglet, OngletVeto.eleveurs);
      expect(_resultat?.signalement?.maladieConfirmee, 'Bronchite infectieuse');
    });

    testWidgets('« Diagnostic non posé » envoie une maladie nulle', (t) async {
      int? maladieEnvoyee = -1;
      await _monter(
        t,
        EcranCloture(
          signalement: _cas(),
          envoyer: (id, cr, m) async {
            maladieEnvoyee = m;
            return _clos(null);
          },
        ),
      );
      await _toucher(t, find.text('Diagnostic non posé'));
      await t.pump();
      await _toucher(t, find.text('Visite prévue'));
      await t.pump();
      await _cloturer(t);
      expect(maladieEnvoyee, isNull);
    });

    testWidgets('sans hypothèse de l’outil, il faut choisir une maladie', (t) async {
      var appels = 0;
      await _monter(
        t,
        EcranCloture(
          signalement: _cas(probable: false),
          envoyer: (id, cr, m) async {
            appels++;
            return _clos(null);
          },
        ),
      );
      await _toucher(t, find.text('Lot isolé'));
      await t.pump();
      await _cloturer(t);
      expect(appels, 0);
      expect(find.textContaining('Choisissez la maladie retenue'), findsOneWidget);
    });

    testWidgets('« Autre maladie… » cherche dans le catalogue filtré', (t) async {
      int? maladieEnvoyee;
      await _monter(
        t,
        EcranCloture(
          signalement: _cas(),
          catalogue: () async => [
            Maladie.json(_maladie(8, 'Variole aviaire', gravite: 'MOYEN')),
            Maladie.json({
              'id': 9,
              'nom': 'Fièvre aphteuse',
              'gravite': 'ELEVE',
              'filieres': ['BOVINS'],
            }),
          ],
          envoyer: (id, cr, m) async {
            maladieEnvoyee = m;
            return _clos('Variole aviaire');
          },
        ),
      );
      await t.tap(find.text('Autre maladie…'));
      await t.pumpAndSettle();
      expect(find.text('Variole aviaire'), findsOneWidget);
      expect(find.text('Fièvre aphteuse'), findsNothing); // autre filiere
      await t.tap(find.text('Variole aviaire'));
      await t.pumpAndSettle();
      await _toucher(t, find.text('Traitement prescrit'));
      await t.pump();
      await _cloturer(t);
      expect(maladieEnvoyee, 8);
    });

    testWidgets('422 : « déjà clôturé », puis retour à la liste rechargée', (t) async {
      await _monter(
        t,
        EcranCloture(
          signalement: _cas(),
          envoyer: (id, cr, m) async =>
              throw const ApiException(422, 'Ce signalement est déjà traité'),
        ),
      );
      await _toucher(t, find.text('Lot isolé'));
      await t.pump();
      await _cloturer(t);
      await t.pumpAndSettle();
      expect(find.text('Ce cas est déjà clôturé'), findsOneWidget);
      await t.tap(find.text('Compris'));
      await t.pumpAndSettle();
      expect(_revenu, isTrue);
      expect(_resultat?.recharger, isTrue);
    });

    testWidgets('un compte rendu commencé ne se perd pas par un retour', (t) async {
      await _monter(t, EcranCloture(signalement: _cas(), envoyer: (a, b, c) async => _clos(null)));
      await _toucher(t, find.text('Lot isolé'));
      await t.pump();
      await t.tap(find.byTooltip('Retour'));
      await t.pumpAndSettle();
      expect(find.text('Abandonner la clôture ?'), findsOneWidget);
      // Toucher hors de la pop-up, ou « Continuer » : on reste.
      await t.tap(find.text('Continuer la saisie'));
      await t.pumpAndSettle();
      expect(_revenu, isFalse);
      expect(find.text('Clôturer le cas'), findsOneWidget);
    });
  });

  group('Interrupteur de disponibilité', () {
    Future<void> monter(WidgetTester t, Widget w) => t.pumpWidget(MaterialApp(
          theme: themeMonCheptel(),
          home: Scaffold(body: Center(child: SizedBox(width: 360, child: w))),
        ));

    testWidgets('bascule et enregistre', (t) async {
      final envois = <bool>[];
      await monter(
        t,
        InterrupteurDisponibilite(
          disponible: true,
          surFond: false,
          enregistrer: (v) async {
            envois.add(v);
            return v;
          },
        ),
      );
      expect(find.text('Disponible'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('interrupteur-disponibilite')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(envois, [false]);
      expect(find.text('Indisponible'), findsOneWidget);
      expect(find.textContaining('aucun nouveau cas'), findsOneWidget); // SnackBar
    });

    testWidgets('revient en arrière si le back refuse', (t) async {
      await monter(
        t,
        InterrupteurDisponibilite(
          disponible: true,
          surFond: false,
          enregistrer: (v) async => throw const ApiException(0, 'Pas de réseau'),
        ),
      );
      await t.tap(find.byKey(const ValueKey('interrupteur-disponibilite')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Disponible'), findsOneWidget);
      expect(find.textContaining('Pas de réseau'), findsOneWidget);
    });
  });

  group('Fiche de cas', () {
    testWidgets('avec numéro : « Appeler » en grand, « Clôturer » à côté', (t) async {
      await _monter(t, EcranDemande(signalement: _cas()));
      expect(find.text('Appeler'), findsOneWidget);
      expect(find.text('Clôturer'), findsOneWidget);
      expect(find.text('Maladie probable'), findsOneWidget);
      expect(find.text('Autre hypothèse'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('sans numéro : appel désactivé, la clôture devient principale', (t) async {
      await _monter(t, EcranDemande(signalement: _cas(telephone: null, effectif: 1)));
      expect(find.text('Numéro non renseigné'), findsWidgets);
      expect(find.text('Clôturer le cas'), findsOneWidget);
      expect(find.text('Sujets touchés'), findsNothing);
      await t.tap(find.text('Clôturer le cas'));
      await t.pumpAndSettle();
      expect(find.text('Clôture du cas'), findsOneWidget);
    });

    testWidgets('la carte de tri et une carte de cas se dessinent', (t) async {
      await _monter(
          t,
          Scaffold(
            body: ListView(children: [
              CarteTri(enAttente: 4, cas: [_cas(), _cas()], onTap: () {}),
              CarteCas(signalement: _cas(), onTap: () {}),
              CarteCas(signalement: _cas(telephone: null), onTap: () {}),
            ]),
          ));
      expect(find.text('éleveurs vous attendent'), findsOneWidget);
      expect(find.byTooltip('Numéro non renseigné'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('Petites règles du poste de garde', () {
    Profil profil(String nom, String? titre) =>
        Profil.json({'id': 1, 'nom': nom, 'email': 'x@y.ml', 'role': 'VETERINAIRE', if (titre != null) 'titre': titre});

    test('nomVeto ne double jamais le titre', () {
      expect(nomVeto(profil('Dr Aminata Sow', 'Docteur vétérinaire')), 'Dr Aminata Sow');
      expect(nomVeto(profil('Aminata Sow', 'Docteur vétérinaire')), 'Dr Aminata Sow');
      expect(nomVeto(profil('Aissata Traore', 'Dr')), 'Dr Aissata Traore');
      expect(nomVeto(profil('Aissata Traore', null)), 'Aissata Traore');
    });

    test('« Sujets touchés » masqué pour un animal seul', () {
      expect(afficherSujetsTouches(_cas(effectif: 1)), isFalse);
      expect(afficherSujetsTouches(_cas(effectif: 850)), isTrue);
    });

    test('compte rendu composé à partir des phrases', () {
      expect(composerCompteRendu({'Lot isolé', 'Vaccination faite'}, ''),
          'Vaccination faite. Lot isolé.');
      expect(composerCompteRendu({}, '  '), '');
    });

    test('ancienneté courte', () {
      final m = DateTime(2026, 10, 7, 12);
      expect(ancienneteCourte(DateTime(2026, 10, 7, 11, 25), m), '35 min');
      expect(ancienneteCourte(DateTime(2026, 10, 7, 9), m), '3 h');
      expect(ancienneteCourte(DateTime(2026, 10, 5, 9), m), '2 j');
    });
  });
}
