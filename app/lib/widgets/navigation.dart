/// Raccourci de navigation : tous les ecrans secondaires s'ouvrent ainsi.
library;

import 'package:flutter/material.dart';

/// Ouvre [ecran] par-dessus l'ecran courant. Le `Future` se termine quand
/// l'utilisateur revient : l'appelant en profite pour recharger ses donnees.
Future<T?> ouvrir<T>(BuildContext context, Widget ecran) =>
    Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: (_) => ecran));
