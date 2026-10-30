// Responsive et theme sombre : les ecrans principaux tiennent de 320 px a
// la tablette en paysage, avec un texte agrandi a 1,3, dans les deux
// themes ; la palette sombre passe le contraste AA ; le choix « Apparence »
// bascule le theme ; la separation sanitaire / statut / operation.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:moncheptel/ecrans/accueil/choix_profil.dart';
import 'package:moncheptel/ecrans/auth/connexion.dart';
import 'package:moncheptel/ecrans/eleveur/agir_vite.dart';
import 'package:moncheptel/ecrans/eleveur/animaux/carnet.dart';
import 'package:moncheptel/ecrans/eleveur/animaux/evenement.dart';
import 'package:moncheptel/ecrans/eleveur/coquille_eleveur.dart';
import 'package:moncheptel/ecrans/eleveur/tableau_de_bord.dart';
import 'package:moncheptel/ecrans/veterinaire/accueil_veterinaire.dart';
import 'package:moncheptel/ecrans/veterinaire/coquille_veterinaire.dart';
import 'package:moncheptel/libelles.dart';
import 'package:moncheptel/theme/apparence.dart';
import 'package:moncheptel/theme/palette.dart';
import 'package:moncheptel/theme/theme_app.dart';
import 'package:moncheptel/widgets/choix_apparence.dart';
import 'package:moncheptel/widgets/echafaudage.dart';
import 'package:moncheptel/widgets/mise_en_page.dart';

import 'support/donnees.dart';

const _tailles = {
  '320 px': Size(320, 640),
  '1024 px paysage': Size(1024, 700),
};

double _luminance(Color c) {
  double f(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

double contraste(Color a, Color b) {
  final x = _luminance(a), y = _luminance(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

Widget _accueilEleveur(String filiere) => CoquilleEleveur(
      onglets: (i, aller) => TableauDeBordEleveur(
          versOnglet: aller, charger: (_) async => tableauFactice(filiere: filiere)),
    );

void main() {
  setUpAll(chargerPolices);

  group('Aucun débordement', () {
    for (final MapEntry(key: nom, value: taille) in _tailles.entries) {
      for (final texte in [1.0, 1.3]) {
        for (final sombre in [false, true]) {
          final cas = '$nom, texte $texte, ${sombre ? 'sombre' : 'clair'}';

          testWidgets('accueil éleveur ($cas)', (t) async {
            await monterEcran(t, _accueilEleveur('VOLAILLE'),
                taille: taille, texte: texte, sombre: sombre);
            sansErreur(t);
            await parcourirJusquEnBas(t);
          });

          testWidgets('carnet ($cas)', (t) async {
            await monterEcran(t, EcranCarnet(uniteId: 7, charger: () async => carnetFactice()),
                taille: taille, texte: texte, sombre: sombre);
            sansErreur(t);
            await parcourirJusquEnBas(t);
          });

          testWidgets('changer le statut et événement sanitaire ($cas)', (t) async {
            await monterEcran(t, EcranChangerStatut(unite: lotFactice(), type: 'VENTE'),
                taille: taille, texte: texte, sombre: sombre);
            sansErreur(t);
            await parcourirJusquEnBas(t);
            await monterEcran(t, EcranAjouterEvenement(unite: lotFactice(), type: 'VACCINATION'),
                taille: taille, texte: texte, sombre: sombre);
            sansErreur(t);
          });

          testWidgets('accueil vétérinaire ($cas)', (t) async {
            await http.runWithClient(() async {
              await monterEcran(t, TableauDeBordVeterinaire(versOnglet: (_) {}),
                  taille: taille, texte: texte, sombre: sombre);
              await t.pump(const Duration(seconds: 1));
              expect(find.text('Dr Aïssata Traoré'), findsOneWidget);
              sansErreur(t);
              await parcourirJusquEnBas(t);
            }, backVeterinaire);
          });

          for (final (nom, onglet) in [
            ('Animaux', 1),
            ('Santé', 2),
            ('Conseils', 3),
            ('Profil', 4),
          ]) {
            testWidgets('onglet $nom de l’éleveur ($cas)', (t) async {
              await http.runWithClient(() async {
                await monterEcran(t, const CoquilleEleveur(),
                    taille: taille, texte: texte, sombre: sombre);
                await t.tap(find.text(nom).last);
                await t.pump();
                await t.pump(const Duration(seconds: 2));
                expect(onglet, greaterThan(0));
                sansErreur(t);
                await parcourirJusquEnBas(t);
              }, backEleveur);
            });
          }

          for (final nom in ['Éleveurs', 'Conseils', 'Profil']) {
            testWidgets('onglet $nom du vétérinaire ($cas)', (t) async {
              await http.runWithClient(() async {
                await monterEcran(t, const CoquilleVeterinaire(),
                    taille: taille, texte: texte, sombre: sombre);
                await t.tap(find.text(nom).last);
                await t.pump();
                await t.pump(const Duration(seconds: 2));
                sansErreur(t);
                await parcourirJusquEnBas(t);
              }, backVeterinaire);
            });
          }

          testWidgets('choix du profil et connexion ($cas)', (t) async {
            await monterEcran(t, const ChoixProfil(), taille: taille, texte: texte, sombre: sombre);
            sansErreur(t);
            await monterEcran(t, const EcranConnexion(),
                taille: taille, texte: texte, sombre: sombre);
            sansErreur(t);
            await parcourirJusquEnBas(t);
          });
        }
      }
    }

    testWidgets('« Agir vite » et le choix d’Apparence à 320 px, texte 1,3', (t) async {
      await monterEcran(
          t, const Scaffold(body: SingleChildScrollView(child: FeuilleAgirVite())),
          taille: const Size(320, 640), texte: 1.3);
      sansErreur(t);
      await monterEcran(t, Scaffold(body: ChoixApparence(reglage: ReglageApparence.pourTest())),
          taille: const Size(320, 640), texte: 1.3, sombre: true);
      sansErreur(t);
    });
  });

  group('Grands écrans', () {
    test('les tuiles passent de 2 à 4 colonnes, sans rangée orpheline', () {
      expect(colonnesGrille(288, 4), 2); // 320 px moins les gouttieres
      expect(colonnesGrille(400, 4), 2); // 3 colonnes laisseraient une tuile seule
      expect(colonnesGrille(688, 4), 4); // colonne lisible d'une tablette
      expect(colonnesGrille(500, 6), 3);
      expect(colonnesGrille(250, 4), 2);
    });

    test('le contenu se centre dans une colonne lisible', () {
      expect(margeCentrage(360), 0);
      expect(margeCentrage(1024), (1024 - largeurLisible) / 2);
    });

    testWidgets('à 1024 px, l’accueil centre son contenu et ses 4 raccourcis sur une ligne',
        (t) async {
      await monterEcran(t, _accueilEleveur('VOLAILLE'), taille: const Size(1024, 700));
      await t.scrollUntilVisible(find.text('Événement sanitaire'), 200,
          scrollable: find
              .byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down)
              .first);
      final ys = [
        for (final r in ['+ Opération', 'Changer le statut', 'Ajouter un lot', 'Événement sanitaire'])
          t.getTopLeft(find.text(r)).dy,
      ];
      expect(ys.every((y) => (y - ys.first).abs() < 1), isTrue, reason: '$ys');
      final x = t.getTopLeft(find.text('+ Opération')).dx;
      expect(x, greaterThan((1024 - largeurLisible) / 2));
      // La barre fixe couvre toute la largeur ; ses entrees restent groupees
      // au centre, a portee de pouce.
      expect(t.getSize(find.byType(BarreNavigation)).width, 1024);
      expect(t.getCenter(find.text('Accueil')).dx, greaterThan((1024 - 600) / 2));
    });
  });

  group('Mode sombre', () {
    test('palette sombre : contraste AA des textes', () {
      for (final c in [PaletteMonCheptel.clair, PaletteMonCheptel.nuit]) {
        final nom = c.sombre ? 'sombre' : 'clair';
        for (final fond in [c.fond, c.surface]) {
          for (final (n, encre) in [
            ('titre', c.titre),
            ('texte', c.texte),
            ('texteDiscret', c.texteDiscret),
            ('marque', c.marque),
            ('erreur', c.erreur),
            ('attentionTexte', c.attentionTexte),
          ]) {
            expect(contraste(encre, fond), greaterThanOrEqualTo(4.5), reason: '$nom : $n');
          }
        }
        expect(contraste(c.surMarque, c.marque), greaterThanOrEqualTo(4.5), reason: nom);
        expect(contraste(c.surEntete, c.enteteDebut), greaterThanOrEqualTo(4.5), reason: nom);
        expect(contraste(c.surEntete, c.enteteFin), greaterThanOrEqualTo(4.5), reason: nom);
        expect(contraste(c.surEntete, c.fondFonce), greaterThanOrEqualTo(4.5), reason: nom);
        expect(contraste(c.surEntete, c.graviteHaute), greaterThanOrEqualTo(4.5), reason: nom);
        expect(contraste(c.surAccent, c.accent), greaterThanOrEqualTo(4.5), reason: nom);
        expect(contraste(c.encreFonce, c.sable), greaterThanOrEqualTo(4.5), reason: nom);
        expect(contraste(c.texte, c.fondMarquePale), greaterThanOrEqualTo(4.5), reason: nom);
        // Marques graphiques : 3:1 sur la surface.
        expect(contraste(c.graphiqueRevenus, c.surface), greaterThanOrEqualTo(3), reason: nom);
        expect(contraste(c.graphiqueDepenses, c.surface), greaterThanOrEqualTo(3), reason: nom);
      }
      // Fond vert-noir profond, surfaces un peu plus claires.
      const n = PaletteMonCheptel.nuit;
      expect(_luminance(n.fond), lessThan(_luminance(n.surface)));
      expect(_luminance(n.surface), lessThan(_luminance(n.sable)));
      expect(n.accent, const Color(0xFFEF9429));
    });

    test('le thème sombre porte sa palette et des icônes de barre d’état claires', () {
      final theme = themeMonCheptel(luminosite: Brightness.dark);
      expect(theme.brightness, Brightness.dark);
      expect(theme.extension<PaletteMonCheptel>(), same(PaletteMonCheptel.nuit));
      expect(theme.scaffoldBackgroundColor, PaletteMonCheptel.nuit.fond);
      expect(theme.appBarTheme.systemOverlayStyle?.statusBarIconBrightness, Brightness.light);
    });

    testWidgets('« Apparence » bascule l’application en sombre, puis en clair', (t) async {
      final reglage = ReglageApparence.pourTest();
      await t.pumpWidget(ValueListenableBuilder<Apparence>(
        valueListenable: reglage,
        builder: (_, a, __) => MaterialApp(
          theme: themeMonCheptel(),
          darkTheme: themeMonCheptel(luminosite: Brightness.dark),
          themeMode: a.mode,
          home: Scaffold(body: ChoixApparence(reglage: reglage)),
        ),
      ));
      Brightness luminosite() =>
          Theme.of(t.element(find.byType(ChoixApparence))).brightness;
      expect(reglage.value, Apparence.automatique);
      await t.tap(find.bySemanticsLabel('Apparence : Sombre'));
      await t.pumpAndSettle();
      expect(reglage.value, Apparence.sombre);
      expect(luminosite(), Brightness.dark);
      await t.tap(find.bySemanticsLabel('Apparence : Clair'));
      await t.pumpAndSettle();
      expect(luminosite(), Brightness.light);
    });

    testWidgets('en sombre, l’accueil ne laisse aucun fond blanc', (t) async {
      await monterEcran(t, _accueilEleveur('VOLAILLE'), sombre: true);
      final blancs = find.byWidgetPredicate((w) {
        final c = switch (w) {
          Container(:final color) => color,
          Material(:final color) => color,
          ColoredBox(:final color) => color,
          DecoratedBox(:final decoration) when decoration is BoxDecoration => decoration.color,
          _ => null,
        };
        return c != null && c.a > 0.9 && _luminance(c) > 0.8;
      });
      expect(blancs, findsNothing);
    });
  });

  group('Sanitaire, statut et opérations séparés', () {
    testWidgets('l’écran sanitaire ne propose que du sanitaire', (t) async {
      await monterEcran(t, EcranAjouterEvenement(unite: lotFactice()));
      for (final s in ['Signaler une maladie', 'Traitement', 'Consultation', 'Vaccination']) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      for (final s in ['Vente', 'Mort', 'Don, transfert']) {
        expect(find.text(s), findsNothing, reason: s);
      }
    });

    testWidgets('l’écran de statut ne propose que des sorties', (t) async {
      await monterEcran(t, EcranChangerStatut(unite: lotFactice()));
      expect(find.text('Changer le statut'), findsOneWidget);
      for (final s in ['Vente', 'Mort', 'Don, transfert']) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      expect(find.text('Vaccination'), findsNothing);
    });

    testWidgets('« Têtes de bovins » sur l’onglet Bovins', (t) async {
      await monterEcran(t, _accueilEleveur('BOVINS'));
      await t.scrollUntilVisible(find.text('Têtes de bovins'), 200,
          scrollable: find
              .byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down)
              .first);
      expect(find.text('Têtes de volaille'), findsNothing);
    });

    test('libellés des têtes par filière', () {
      expect(L.tetesDe('VOLAILLE'), 'Têtes de volaille');
      expect(L.tetesDe('BOVINS'), 'Têtes de bovins');
      expect(L.tetesDe('OVINS'), 'Têtes d’ovins');
      expect(L.tetesDe('CAPRINS'), 'Têtes de caprins');
    });
  });

  group('Vente au prix unitaire', () {
    test('total = prix par tête × nombre de sujets', () {
      expect(totalVente(prixUnitaire: 2500, nombre: 30), 75000);
      expect(totalVente(prixUnitaire: 350000, nombre: 1), 350000);
      expect(totalVente(prixUnitaire: 0, nombre: 30), isNull);
      expect(totalVente(prixUnitaire: 2500, nombre: 0), isNull);
      expect(totalVente(prixUnitaire: null, nombre: 3), isNull);
    });

    testWidgets('le total se calcule en direct, avec les milliers séparés', (t) async {
      await monterEcran(t, EcranChangerStatut(unite: lotFactice(), type: 'VENTE'));
      expect(find.text('Prix par tête (FCFA)'), findsOneWidget);
      final champs = find.byType(EditableText);
      await t.enterText(champs.at(0), '30');
      await t.enterText(champs.at(1), '2500');
      await t.pump();
      expect(find.text('Total de la vente'), findsOneWidget);
      expect(find.textContaining('75'), findsWidgets);
      final total = t.widget<Text>(find.byWidgetPredicate(
          (w) => w is Text && (w.data ?? '').endsWith('FCFA') && (w.data ?? '').startsWith('75')));
      expect(total.data!.replaceAll(RegExp(r'\s'), ' '), '75 000 FCFA');
      expect(find.textContaining('Ne notez pas cette vente une deuxième fois'), findsOneWidget);
    });

    testWidgets('un prix à zéro est refusé', (t) async {
      await monterEcran(t, EcranChangerStatut(unite: lotFactice(), type: 'VENTE'));
      final champs = find.byType(EditableText);
      await t.enterText(champs.at(0), '30');
      await t.enterText(champs.at(1), '0');
      await t.tap(find.text('Enregistrer'));
      await t.pump();
      expect(find.textContaining('Le prix'), findsWidgets);
      expect(find.text('Total de la vente'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('pour un animal seul, le prix saisi est le total', (t) async {
      await monterEcran(t, EcranChangerStatut(unite: animalFactice(), type: 'VENTE'));
      expect(find.text('Prix de vente (FCFA)'), findsOneWidget);
      expect(find.text('Total de la vente'), findsNothing);
    });
  });
}
