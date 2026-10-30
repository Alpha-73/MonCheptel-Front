// Captures de controle (PNG), seulement avec CAPTURES=<dossier> :
//   CAPTURES=/chemin flutter test test/captures_test.dart
// Sans la variable, le test est saute et rien n'est ecrit.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:moncheptel/ecrans/eleveur/coquille_eleveur.dart';
import 'package:moncheptel/ecrans/eleveur/tableau_de_bord.dart';
import 'package:moncheptel/ecrans/veterinaire/coquille_veterinaire.dart';

import 'support/donnees.dart';

final _dossier = Platform.environment['CAPTURES'];

Future<void> _capturer(WidgetTester t, String nom) async {
  await t.runAsync(() async {
    final vue = t.binding.renderViews.first;
    final calque = vue.debugLayer! as OffsetLayer;
    final image = await calque.toImage(Offset.zero & vue.size, pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_dossier/$nom.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(chargerPolices);
  const taille = Size(402, 874);

  for (final sombre in [false, true]) {
    testWidgets('accueil éleveur ${sombre ? 'sombre' : 'clair'}', (t) async {
      await monterEcran(
          t,
          CoquilleEleveur(
            onglets: (i, aller) => TableauDeBordEleveur(
                versOnglet: aller, charger: (_) async => tableauFactice()),
          ),
          taille: taille,
          sombre: sombre);
      await t.pump(const Duration(seconds: 2));
      await _capturer(t, 'accueil-eleveur-${sombre ? 'sombre' : 'clair'}');
    }, skip: _dossier == null);
  }

  testWidgets('accueil vétérinaire sombre', (t) async {
    await http.runWithClient(() async {
      await monterEcran(t, const CoquilleVeterinaire(), taille: taille, sombre: true);
      await t.pump(const Duration(seconds: 2));
      await _capturer(t, 'accueil-veterinaire-sombre');
    }, backVeterinaire);
  }, skip: _dossier == null);
}
