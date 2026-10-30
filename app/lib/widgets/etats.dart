/// Chargement, erreur, liste vide : les trois etats que tout ecran connecte
/// au back doit savoir afficher.
library;

import 'package:flutter/material.dart';

import '../api/client_api.dart';
import '../theme/palette.dart';
import '../theme/dimensions.dart';
import 'boutons.dart';
import 'entete.dart';

/// Charge une donnee depuis le back et construit l'ecran avec.
///
/// Remplace le trio « variable future + FutureBuilder + bouton reessayer »
/// que chaque ecran ecrirait sinon a la main. [construire] recoit aussi
/// [recharger], a appeler apres une modification (retour d'un formulaire,
/// tirer pour actualiser).
class Chargeur<T> extends StatefulWidget {
  const Chargeur(
      {super.key,
      required this.charger,
      required this.construire,
      this.titreEcran,
      this.clair = false});

  final Future<T> Function() charger;

  /// Renseigne quand [construire] rend un ECRAN entier (avec son propre
  /// Scaffold) : pendant le chargement et en cas d'erreur, le Chargeur
  /// affiche alors lui-meme un en-tete avec ce titre et un bouton retour.
  /// Sans cela, l'utilisateur resterait sur un ecran blanc sans issue.
  final String? titreEcran;

  /// En-tete clair pour [titreEcran] (parcours veterinaire).
  final bool clair;
  final Widget Function(BuildContext context, T donnee, Future<void> Function() recharger)
      construire;

  @override
  State<Chargeur<T>> createState() => _ChargeurState<T>();
}

class _ChargeurState<T> extends State<Chargeur<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.charger();
  }

  Future<void> _recharger() async {
    final f = widget.charger();
    if (!mounted) return;
    // Accolades obligatoires : `() => _future = f` RENVOIE f, et setState
    // refuse un callback qui renvoie un Future (exception en mode debug).
    setState(() {
      _future = f;
    });
    // On attend la fin pour que l'indicateur « tirer pour actualiser »
    // reste affiche le temps du chargement. Une erreur est deja montree par
    // le FutureBuilder : inutile de la relancer ici.
    try {
      await f;
    } catch (_) {}
  }

  Widget _habiller(Widget etat) {
    final titre = widget.titreEcran;
    if (titre == null) return etat;
    return Scaffold(
      backgroundColor: context.couleurs.fond,
      appBar: barreSecondaire(context, titre: titre, clair: widget.clair),
      body: etat,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, instantane) {
        if (instantane.hasError) {
          return _habiller(
              EtatErreur(erreur: instantane.error!, onReessayer: _recharger));
        }
        if (!instantane.hasData) {
          // `hasData` et non `connectionState` : une donnee nulle legitime
          // (T nullable) n'existe pas dans cette application.
          return _habiller(const EtatChargement());
        }
        return widget.construire(context, instantane.data as T, _recharger);
      },
    );
  }
}

class EtatChargement extends StatelessWidget {
  const EtatChargement({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: CircularProgressIndicator(color: context.couleurs.marque),
        ),
      );
}

/// Message d'erreur et bouton « Réessayer ».
class EtatErreur extends StatelessWidget {
  const EtatErreur({super.key, required this.erreur, required this.onReessayer});

  final Object erreur;
  final VoidCallback onReessayer;

  @override
  Widget build(BuildContext context) {
    final message = erreur is ApiException
        ? (erreur as ApiException).texte
        : "Une erreur inattendue s'est produite.";
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Dim.gouttiere * 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 40, color: context.couleurs.texteDiscret),
            const SizedBox(height: 12),
            Text(message, style: context.typo.corps, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            BoutonSecondaire('Réessayer', onPressed: onReessayer, pleineLargeur: false),
          ],
        ),
      ),
    );
  }
}

/// Liste vide : une phrase qui dit quoi faire, pas seulement « rien ».
class EtatVide extends StatelessWidget {
  const EtatVide(this.message, {super.key, this.icone = Icons.inbox_outlined});

  final String message;
  final IconData icone;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          children: [
            Icon(icone, size: 36, color: context.couleurs.texteIndicatif),
            const SizedBox(height: 10),
            Text(message, style: context.typo.corpsDiscret, textAlign: TextAlign.center),
          ],
        ),
      );
}
