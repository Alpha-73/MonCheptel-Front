/// Choix « Apparence » du Profil : Automatique (le reglage du telephone),
/// Clair ou Sombre.
///
/// Le choix est memorise sur l'appareil dans le stockage deja employe pour
/// la session (`flutter_secure_storage`) : aucune dependance de plus. Un
/// stockage illisible (navigateur prive, test) n'empeche rien : le choix
/// vaut alors pour la session en cours, et l'application suit le telephone
/// au demarrage suivant.
library;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum Apparence {
  automatique('Automatique', 'Comme le téléphone'),
  clair('Clair', 'Fond sable'),
  sombre('Sombre', 'Fond vert-noir, repose les yeux le soir');

  const Apparence(this.libelle, this.detail);
  final String libelle;
  final String detail;

  ThemeMode get mode => switch (this) {
        Apparence.automatique => ThemeMode.system,
        Apparence.clair => ThemeMode.light,
        Apparence.sombre => ThemeMode.dark,
      };
}

class ReglageApparence extends ValueNotifier<Apparence> {
  ReglageApparence._() : super(Apparence.automatique);

  /// Pour les tests : un reglage independant de celui de l'application.
  @visibleForTesting
  ReglageApparence.pourTest([super.depart = Apparence.automatique]);

  /// Le reglage de toute l'application, ecoute par `MaterialApp`.
  static final ReglageApparence instance = ReglageApparence._();

  static const _cle = 'apparence';
  static const FlutterSecureStorage _coffre = FlutterSecureStorage();

  /// Relit le choix memorise. Sans effet si le stockage est indisponible.
  Future<void> charger() async {
    try {
      final lu = await _coffre.read(key: _cle);
      value = Apparence.values.firstWhere((a) => a.name == lu,
          orElse: () => Apparence.automatique);
    } catch (_) {
      // Stockage indisponible : on suit le telephone.
    }
  }

  /// Applique tout de suite, puis memorise.
  Future<void> choisir(Apparence a) async {
    value = a;
    try {
      await _coffre.write(key: _cle, value: a.name);
    } catch (_) {
      // Le choix vaut pour cette session.
    }
  }
}
