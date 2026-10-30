import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moncheptel/ecrans/accueil/choix_profil.dart';
import 'package:moncheptel/theme/theme_app.dart';
import 'package:moncheptel/widgets/marque.dart';

// Les ondes du choix du profil tournent en boucle : on avance le temps a la
// main (`pump` avec une duree) plutot qu'avec `pumpAndSettle`.
Future<void> _ouvrir(WidgetTester t) async {
  t.view.physicalSize = const Size(402, 874);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(theme: themeMonCheptel(), home: const ChoixProfil()));
  await t.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('le choix du profil porte le logo et les deux profils', (t) async {
    await _ouvrir(t);
    expect(find.byType(LogoMonCheptel), findsOneWidget);
    expect(find.text('Bienvenue sur MonCheptel'), findsOneWidget);
    expect(find.text('Éleveur'), findsOneWidget);
    expect(find.text('Vétérinaire'), findsOneWidget);
  });

  testWidgets('Éleveur ouvre la connexion éleveur, avec la création de compte', (t) async {
    await _ouvrir(t);
    await t.tap(find.text('Éleveur'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('ESPACE ÉLEVEUR'), findsOneWidget);
    expect(find.text('Créer un compte'), findsOneWidget);
  });

  testWidgets('Vétérinaire ouvre sa connexion, sans création de compte', (t) async {
    await _ouvrir(t);
    await t.tap(find.text('Vétérinaire'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('ESPACE VÉTÉRINAIRE'), findsOneWidget);
    expect(find.text('Créer un compte'), findsNothing);
    expect(find.text("Accéder à l'espace éleveur"), findsOneWidget);
  });

  testWidgets('le mot de passe se montre et se masque', (t) async {
    await _ouvrir(t);
    await t.tap(find.text('Éleveur'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    EditableText champ() => t.widget<EditableText>(find.byType(EditableText).at(1));
    expect(champ().obscureText, isTrue);
    await t.tap(find.byTooltip('Afficher le mot de passe'));
    await t.pump();
    expect(champ().obscureText, isFalse);
  });
}
