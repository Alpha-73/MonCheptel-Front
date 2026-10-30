/// Les pop-ups de la maquette : confirmation, information, erreur.
///
/// Construites a la main avec `Dialog` plutot qu'avec `AlertDialog` et un
/// theme : la maquette pose ses boutons pleine largeur, l'un sous l'autre.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/client_api.dart';
import '../theme/palette.dart';
import '../theme/dimensions.dart';
import 'boutons.dart';

/// Ouvre une pop-up comme la maquette : fondu de 0,2 s, centree, sur un
/// voile noir a 35 %.
Future<T?> ouvrirPopup<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x59000000),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, _, __) => builder(context),
    transitionBuilder: (context, animation, _, enfant) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: enfant,
    ),
  );
}

Future<T?> _popup<T>(BuildContext context,
    {required String titre,
    String? message,
    IconData? icone,
    Color? couleurIcone,
    required List<Widget> Function(BuildContext) boutons}) {
  return ouvrirPopup<T>(
    context,
    builder: (context) => Dialog(
      backgroundColor: context.couleurs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dim.rayonPastille)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (icone != null) ...[
              Icon(icone, size: 40, color: couleurIcone ?? context.couleurs.marque),
              const SizedBox(height: 12),
            ],
            Text(titre, style: context.typo.titreSection, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message, style: context.typo.corpsDiscret, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 20),
            ...boutons(context),
          ],
        ),
      ),
    ),
  );
}

/// Information (« Opération enregistrée »). Un seul bouton.
Future<void> afficherInfo(BuildContext context, String titre,
    {String? message, String bouton = 'OK'}) {
  return _popup<void>(context,
      titre: titre,
      message: message,
      icone: Icons.check_circle_outline,
      boutons: (c) => [BoutonPrincipal(bouton, onPressed: () => Navigator.of(c).pop())]);
}

/// Deux issues (« Voir la fiche » / « Ajouter un autre »).
/// Rend `true` pour la premiere, `false` pour la seconde.
Future<bool?> choisirSuite(BuildContext context, String titre,
    {String? message, required String premier, required String second}) {
  return _popup<bool>(context,
      titre: titre,
      message: message,
      icone: Icons.check_circle_outline,
      boutons: (c) => [
            BoutonPrincipal(premier, onPressed: () => Navigator.of(c).pop(true)),
            const SizedBox(height: 10),
            BoutonSecondaire(second, onPressed: () => Navigator.of(c).pop(false)),
          ]);
}

/// Confirmation d'une action. [destructif] : bouton rouge.
Future<bool> confirmer(BuildContext context, String titre,
    {String? message,
    required String confirmer,
    String annuler = 'Annuler',
    bool destructif = false}) async {
  final r = await _popup<bool>(context,
      titre: titre,
      message: message,
      icone: destructif ? Icons.warning_amber_rounded : null,
      couleurIcone: context.couleurs.erreur,
      boutons: (c) => [
            destructif
                ? BoutonDestructif(confirmer, onPressed: () => Navigator.of(c).pop(true))
                : BoutonPrincipal(confirmer, onPressed: () => Navigator.of(c).pop(true)),
            const SizedBox(height: 10),
            BoutonSecondaire(annuler, onPressed: () => Navigator.of(c).pop(false)),
          ]);
  return r ?? false;
}

/// Erreur du back, en pop-up.
Future<void> afficherErreur(BuildContext context, Object erreur, {String? titre}) {
  final message = erreur is ApiException
      ? erreur.texte
      : "Une erreur inattendue s'est produite.";
  return _popup<void>(context,
      titre: titre ?? 'Action impossible',
      message: message,
      icone: Icons.error_outline,
      couleurIcone: context.couleurs.erreur,
      boutons: (c) => [BoutonPrincipal('Compris', onPressed: () => Navigator.of(c).pop())]);
}

/// Ouvre le composeur avec le numero. Le telephone appelle, pas l'application.
Future<void> appeler(BuildContext context, String? numero) async {
  if (numero == null || numero.trim().isEmpty) {
    await afficherErreur(context, const ApiException(0, 'Aucun numéro de téléphone renseigné.'),
        titre: 'Appel impossible');
    return;
  }
  final uri = Uri(scheme: 'tel', path: numero.replaceAll(' ', ''));
  bool ok;
  try {
    ok = await launchUrl(uri);
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) {
    await afficherErreur(
        context, ApiException(0, "Cet appareil ne peut pas passer d'appel. Numéro : $numero"),
        titre: 'Appel impossible');
  }
}

/// Confirmation d'appel (pop-up « Appeler Dr Traoré ? »), puis l'appel.
Future<void> confirmerAppel(BuildContext context, String nom, String? numero) async {
  final ok = await confirmer(context, 'Appeler $nom ?',
      message: numero, confirmer: 'Appeler');
  if (ok && context.mounted) await appeler(context, numero);
}

/// Refus avec motif facultatif (V14 : le veterinaire refuse un cas).
///
/// Rend le motif saisi (eventuellement vide) si l'utilisateur confirme, nul
/// s'il renonce.
Future<String?> demanderMotif(BuildContext context, String titre,
    {String? message,
    required String confirmer,
    String annuler = 'Annuler',
    String indication = 'Motif (facultatif)'}) {
  return ouvrirPopup<String>(
    context,
    builder: (context) => _PopupMotif(
        titre: titre,
        message: message,
        confirmer: confirmer,
        annuler: annuler,
        indication: indication),
  );
}

class _PopupMotif extends StatefulWidget {
  const _PopupMotif(
      {required this.titre,
      required this.message,
      required this.confirmer,
      required this.annuler,
      required this.indication});
  final String titre;
  final String? message;
  final String confirmer;
  final String annuler;
  final String indication;

  @override
  State<_PopupMotif> createState() => _PopupMotifState();
}

class _PopupMotifState extends State<_PopupMotif> {
  final _motif = TextEditingController();

  @override
  void dispose() {
    _motif.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: context.couleurs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dim.rayonPastille)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.titre, style: context.typo.titreSection, textAlign: TextAlign.center),
              if (widget.message != null) ...[
                const SizedBox(height: 8),
                Text(widget.message!,
                    style: context.typo.corpsDiscret, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _motif,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(hintText: widget.indication),
              ),
              const SizedBox(height: 12),
              BoutonDestructif(widget.confirmer,
                  onPressed: () => Navigator.of(context).pop(_motif.text.trim())),
              const SizedBox(height: 10),
              BoutonSecondaire(widget.annuler, onPressed: () => Navigator.of(context).pop()),
            ],
          ),
        ),
      );
}
