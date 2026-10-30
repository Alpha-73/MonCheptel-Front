// Coquille de l'espace eleveur : touche retour (audit F7), feuille « Agir
// vite », pictogrammes d'elevage, et petits calculs de l'accueil et des lots.
// Les onglets sont remplaces par des ecrans factices : aucun appel au back.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moncheptel/api/modeles.dart';
import 'package:moncheptel/ecrans/eleveur/agir_vite.dart';
import 'package:moncheptel/ecrans/eleveur/animaux/mes_animaux.dart';
import 'package:moncheptel/ecrans/eleveur/coquille_eleveur.dart';
import 'package:moncheptel/ecrans/eleveur/tableau_de_bord.dart';
import 'package:moncheptel/theme/theme_app.dart';
import 'package:moncheptel/widgets/echafaudage.dart';
import 'package:moncheptel/widgets/eleveur/pictos.dart';

Future<void> _ouvrir(WidgetTester t, {ValueChanged<ActionRapide>? surAction}) async {
  t.view.physicalSize = const Size(402, 874);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    theme: themeMonCheptel(),
    home: CoquilleEleveur(
      onglets: (i, _) => Center(child: Text('onglet $i')),
      surAction: surAction,
    ),
  ));
  await t.pump();
}

bool _peutQuitter(WidgetTester t) =>
    t.widget<PopScope<Object?>>(find.byWidgetPredicate((w) => w is PopScope)).canPop;

Rappel _rappel(int id, int? uniteId, int jours) => Rappel.json({
      'id': id,
      'uniteId': uniteId,
      'libelle': 'Vaccin',
      'joursRestants': jours,
      'statut': jours < 0 ? 'ECHU' : 'A_VENIR',
    });

void main() {
  group('Coquille éleveur', () {
    testWidgets('la touche retour ramène à l’Accueil au lieu de quitter', (t) async {
      await _ouvrir(t);
      expect(find.text('onglet 0'), findsOneWidget);

      await t.tap(find.text('Santé'));
      await t.pump();
      expect(find.text('onglet 2'), findsOneWidget);
      expect(_peutQuitter(t), isFalse);

      await t.binding.handlePopRoute();
      await t.pump();
      expect(find.text('onglet 0'), findsOneWidget);
      // Sur l'Accueil, le retour peut de nouveau quitter l'application.
      expect(_peutQuitter(t), isTrue);
    });

    testWidgets('la barre est fixe : le corps s’arrête au-dessus d’elle', (t) async {
      await _ouvrir(t);
      expect(t.widget<Scaffold>(find.byType(Scaffold).first).extendBody, isFalse);
      final barre = t.getRect(find.byType(BarreNavigation));
      // Pleine largeur, collee au bas de l'ecran.
      expect(barre.left, 0);
      expect(barre.width, 402);
      expect(barre.bottom, 874);
      expect(t.getRect(find.text('onglet 0')).bottom, lessThanOrEqualTo(barre.top));
    });

    testWidgets('changer d’onglet ne déplace aucune entrée de la barre', (t) async {
      await _ouvrir(t);
      Map<String, Offset> positions() => {
            for (final l in ['Accueil', 'Animaux', 'Santé', 'Conseils', 'Profil'])
              l: t.getCenter(find.text(l)),
          };
      final avant = positions();
      final boutonAvant = t.getCenter(find.bySemanticsLabel('Agir vite : signaler, ajouter, noter'));
      await t.tap(find.text('Santé'));
      await t.pumpAndSettle();
      expect(positions(), avant);
      expect(t.getCenter(find.bySemanticsLabel('Agir vite : signaler, ajouter, noter')),
          boutonAvant);
      // L'indicateur garde sa taille : seul son remplissage change.
      final indicateurs = find.byWidgetPredicate(
          (w) => w is AnimatedContainer && w.constraints?.maxWidth == 52);
      expect(indicateurs, findsNWidgets(5));
    });

    testWidgets('l’onglet Animaux porte un pictogramme d’élevage, pas une patte', (t) async {
      await _ouvrir(t);
      expect(find.byIcon(Icons.pets), findsNothing);
      expect(find.byIcon(Icons.pets_outlined), findsNothing);
      expect(find.byType(PictoCheptel), findsOneWidget);
    });

    testWidgets('le bouton central ouvre « Agir vite » et ses quatre tuiles', (t) async {
      ActionRapide? choisie;
      await _ouvrir(t, surAction: (a) => choisie = a);

      await t.tap(find.bySemanticsLabel('Agir vite : signaler, ajouter, noter'));
      await t.pumpAndSettle();
      expect(find.text('Agir vite'), findsOneWidget);
      expect(find.text('Événement sanitaire'), findsOneWidget);
      expect(find.text('Ajouter un lot ou un animal'), findsOneWidget);
      expect(find.text('Changer le statut'), findsOneWidget);
      expect(find.text('Dépense ou revenu'), findsOneWidget);
      // Plus de tuile qui melange soins et ventes.
      expect(find.text('Noter un soin, une vente, une perte'), findsNothing);

      await t.tap(find.text('Événement sanitaire'));
      await t.pumpAndSettle();
      expect(choisie, ActionRapide.sanitaire);
      expect(find.text('Agir vite'), findsNothing);
    });

    testWidgets('chaque tuile rend son action', (t) async {
      final attendues = {
        'Ajouter un lot ou un animal': ActionRapide.ajouter,
        'Changer le statut': ActionRapide.statut,
        'Dépense ou revenu': ActionRapide.operation,
      };
      for (final MapEntry(key: libelle, value: action) in attendues.entries) {
        ActionRapide? choisie;
        await _ouvrir(t, surAction: (a) => choisie = a);
        await t.tap(find.bySemanticsLabel('Agir vite : signaler, ajouter, noter'));
        await t.pumpAndSettle();
        await t.tap(find.text(libelle));
        await t.pumpAndSettle();
        expect(choisie, action, reason: libelle);
      }
    });

    testWidgets('la feuille se ferme sans action', (t) async {
      ActionRapide? choisie;
      await _ouvrir(t, surAction: (a) => choisie = a);
      await t.tap(find.bySemanticsLabel('Agir vite : signaler, ajouter, noter'));
      await t.pumpAndSettle();
      await t.tapAt(const Offset(200, 40));
      await t.pumpAndSettle();
      expect(find.text('Agir vite'), findsNothing);
      expect(choisie, isNull);
    });
  });

  group('Petits écrans (320 px)', () {
    testWidgets('carte de lot, carte d’animal et rappel tiennent sans débordement', (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final lot = Unite.json({
        'id': 1, 'code': 'LOT-2026-014', 'modeSuivi': 'LOT', 'filiere': 'VOLAILLE',
        'typeElevage': 'Poulet de chair', 'statut': 'ACTIF',
        'dateEntree': '2026-08-01', 'dateCloturePrevue': '2026-09-15',
        'joursRestants': -22, 'effectifInitial': 1850, 'effectifRestant': 1500,
      });
      final animal = Unite.json({
        'id': 2, 'code': 'BOV-048', 'modeSuivi': 'INDIVIDUEL', 'filiere': 'BOVINS',
        'typeElevage': 'Zébu', 'statut': 'VENDU', 'race': 'Zébu peul', 'sexe': 'FEMELLE',
        'dateNaissance': '2022-01-10',
      });
      await t.pumpWidget(MaterialApp(
        theme: themeMonCheptel(),
        home: Scaffold(
          body: ListView(padding: const EdgeInsets.all(16), children: [
            CarteUnite(unite: lot, onTap: () {}),
            CarteUnite(unite: animal, onTap: () {}),
            CarteRappel(
                rappel: Rappel.json({
                  'id': 1, 'uniteCode': 'LOT-2026-014', 'libelle': 'Vaccin Gumboro (rappel)',
                  'joursRestants': -3, 'statut': 'ECHU',
                }),
                onTap: () {}),
            const FeuilleAgirVite(),
          ]),
        ),
      ));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('J+${DateTime.now().difference(DateTime(2026, 8, 1)).inDays}'), findsOneWidget);
    });
  });

  group('Pictogrammes', () {
    testWidgets('les quatre espèces se dessinent, pleines et en contour', (t) async {
      await t.pumpWidget(MaterialApp(
        home: Row(children: [
          for (final e in Espece.values) ...[
            PictoAnimal(espece: e, taille: 40),
            PictoAnimal(espece: e, taille: 40, plein: false),
          ],
        ]),
      ));
      expect(find.byType(PictoAnimal), findsNWidgets(8));
      expect(t.takeException(), isNull);
    });

    test('filière vers espèce', () {
      expect(especeDeFiliere('VOLAILLE'), Espece.volaille);
      expect(especeDeFiliere('OVINS'), Espece.ovin);
      expect(especeDeFiliere('CAPRINS'), Espece.caprin);
      expect(especeDeFiliere('BOVINS'), Espece.bovin);
    });
  });

  group('Calculs de l’accueil et des lots', () {
    test('prénom tiré du nom', () {
      expect(prenomDe('Awa Traoré'), 'Awa');
      expect(prenomDe('  '), 'Éleveur');
    });

    test('jauge : part des élevages sans soin en retard', () {
      expect(jaugeSante(0, const []), isNull);
      expect(jaugeSante(4, [_rappel(1, 10, 3)]), 1.0);
      // Deux retards sur la meme unite comptent une fois.
      expect(jaugeSante(4, [_rappel(1, 10, -2), _rappel(2, 10, -5), _rappel(3, 11, 0)]), 0.75);
    });

    test('cycle d’un lot : jour, durée, avancement', () {
      final lot = Unite.json({
        'id': 1,
        'code': 'LOT-014',
        'modeSuivi': 'LOT',
        'filiere': 'VOLAILLE',
        'typeElevage': 'Poulet de chair',
        'statut': 'ACTIF',
        'dateEntree': '2026-09-01',
        'dateCloturePrevue': '2026-10-16',
        'effectifInitial': 185,
        'effectifRestant': 150,
      });
      final c = cycleDe(lot, DateTime(2026, 9, 17))!;
      expect(c.jour, 16);
      expect(c.duree, 45);
      expect(c.avancement, closeTo(16 / 45, 1e-9));
      expect(c.joursRestants, 29);

      final animal = Unite.json({
        'id': 2,
        'code': 'BOV-1',
        'modeSuivi': 'INDIVIDUEL',
        'filiere': 'BOVINS',
        'typeElevage': 'Zébu',
        'statut': 'ACTIF',
      });
      expect(cycleDe(animal), isNull);
    });

    test('sorties annulables lues depuis le détail', () {
      final s = SortieUnite.depuisDetail({
        'sorties': [
          {'id': 9, 'date': '2026-10-01', 'nature': 'VENTE', 'nombre': 30, 'montant': 150000},
        ],
      });
      expect(s.single.id, 9);
      expect(s.single.nature, 'VENTE');
      expect(s.single.nombre, 30);
      expect(s.single.montant, 150000);
      expect(SortieUnite.depuisDetail(const {}), isEmpty);
    });
  });
}
