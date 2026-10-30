/// Notifications (audit F4 et L13).
///
/// Sources : GET /api/notifications?page=N, puis POST
/// /api/notifications/lecture : ouvrir la liste vaut lecture, ce qui eteint
/// la pastille de la cloche. Les non-lues restent en gras le temps de la
/// visite.
///
/// Toucher une notification ouvre ce qu'elle vise, d'apres
/// `referenceType` / `referenceId` :
///  - SIGNALEMENT : le signalement (reponse du veterinaire) ;
///  - ALERTE : l'alerte si elle est toujours en cours, sinon son texte ;
///  - CONSEIL : le conseil ;
///  - UNITE : le carnet du lot ou de l'animal (rappel de soins).
/// Sans reference (anciennes notifications), on se rabat sur le type : une
/// ORIENTATION ouvre « Mes signalements » ; le reste affiche le message.
library;

import 'package:flutter/material.dart';

import '../../../api/client_api.dart';
import '../../../api/modeles.dart';
import '../../../api/services.dart';
import '../../../theme/palette.dart';
import '../../../theme/dimensions.dart';
import '../../../theme/format.dart';
import '../../../widgets/boutons.dart';
import '../../../widgets/dialogues.dart';
import '../../../widgets/eleveur/ecran_vivant.dart';
import '../../../widgets/etats.dart';
import '../../../widgets/navigation.dart';
import '../../../widgets/vivant.dart';
import '../animaux/carnet.dart';
import '../conseils/conseils.dart';
import '../sante/alerte.dart';
import '../sante/mes_signalements.dart';
import '../../../widgets/mise_en_page.dart';

/// Ce qu'ouvre une notification. Separe de l'ecran pour etre teste.
sealed class CibleNotification {
  const CibleNotification();
}

class CibleSignalement extends CibleNotification {
  const CibleSignalement(this.id);
  final int id;
}

class CibleAlerte extends CibleNotification {
  const CibleAlerte(this.id);
  final int id;
}

class CibleConseil extends CibleNotification {
  const CibleConseil(this.id);
  final int id;
}

/// Le carnet d'une unite : rappel de soins (TypeNotification.RAPPEL).
class CibleUnite extends CibleNotification {
  const CibleUnite(this.id);
  final int id;
}

class CibleMesSignalements extends CibleNotification {
  const CibleMesSignalements();
}

/// Rien a ouvrir : on montre le message entier.
class CibleMessage extends CibleNotification {
  const CibleMessage();
}

CibleNotification cibleDe(NotificationApp n) {
  final id = n.referenceId;
  final ref = n.referenceType?.toUpperCase();
  if (id != null) {
    switch (ref) {
      case 'SIGNALEMENT':
        return CibleSignalement(id);
      case 'ALERTE':
        return CibleAlerte(id);
      case 'CONSEIL':
        return CibleConseil(id);
      case 'UNITE':
        return CibleUnite(id);
    }
  }
  if (n.type == 'ORIENTATION') return const CibleMesSignalements();
  return const CibleMessage();
}

/// Ouvre l'ecran vise par [n].
Future<void> ouvrirNotification(BuildContext context, NotificationApp n) async {
  switch (cibleDe(n)) {
    case CibleSignalement(:final id):
      await ouvrir<void>(context, EcranDetailSignalement(signalementId: id));
    case CibleConseil(:final id):
      await ouvrir<void>(context, EcranConseil(conseilId: id));
    case CibleUnite(:final id):
      await ouvrir<void>(context, EcranCarnet(uniteId: id));
    case CibleMesSignalements():
      await ouvrir<void>(context, const EcranMesSignalements());
    case CibleAlerte(:final id):
      Alerte? alerte;
      try {
        for (final a in await AlerteEleveurApi.enCours()) {
          if (a.id == id) alerte = a;
        }
      } on ApiException {
        alerte = null;
      }
      if (!context.mounted) return;
      if (alerte != null) {
        await ouvrir<void>(context, EcranAlerte(alerte: alerte));
      } else {
        await afficherInfo(context, n.titre,
            message: [
              if (n.corps != null) n.corps!,
              "Cette alerte n'est plus en cours.",
            ].join('\n\n'));
      }
    case CibleMessage():
      await afficherInfo(context, n.titre, message: n.corps);
  }
}

class EcranNotifications extends StatefulWidget {
  const EcranNotifications({super.key, this.charger, this.marquerLu, this.surToucher});

  /// Ce que fait le toucher d'une notification ; par defaut
  /// [ouvrirNotification] (ecrans de l'eleveur). L'espace veterinaire peut
  /// y brancher ses propres ecrans.
  final Future<void> Function(BuildContext context, NotificationApp n)? surToucher;

  /// Source d'une page ; par defaut GET /api/notifications. Remplacable en
  /// test, comme [marquerLu].
  final Future<PageApi<NotificationApp>> Function(int page)? charger;
  final Future<void> Function()? marquerLu;

  @override
  State<EcranNotifications> createState() => _EcranNotificationsState();
}

class _EcranNotificationsState extends State<EcranNotifications> {
  final List<NotificationApp> _liste = [];
  int _page = 0;
  bool _derniere = false;
  bool _chargement = false;
  bool _premiere = true;
  Object? _erreur;

  Future<PageApi<NotificationApp>> Function(int) get _charger =>
      widget.charger ?? ((p) => NotificationApi.lister(page: p));

  @override
  void initState() {
    super.initState();
    _suivante();
  }

  Future<void> _suivante() async {
    if (_chargement || _derniere) return;
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final p = await _charger(_page);
      if (!mounted) return;
      setState(() {
        _liste.addAll(p.elements);
        _derniere = p.derniere;
        _page++;
      });
      // Marque lu APRES lecture : la liste montre encore les nouvelles en
      // gras. Une fois, a la premiere page.
      if (_premiere && p.elements.any((n) => !n.lue)) {
        _premiere = false;
        try {
          await (widget.marquerLu ?? NotificationApi.toutMarquerLu)();
        } catch (_) {
          // Sans gravite : la pastille restera allumee jusqu'au prochain essai.
        }
      }
    } catch (e) {
      if (mounted) setState(() => _erreur = e);
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _toutRecharger() async {
    if (_chargement) return;
    setState(() {
      _liste.clear();
      _page = 0;
      _derniere = false;
    });
    await _suivante();
  }

  /// « Aujourd'hui », « Cette semaine », « Plus ancien ».
  static String _groupe(DateTime? d) {
    if (d == null) return 'Plus ancien';
    final maintenant = DateTime.now();
    final jour = DateTime(maintenant.year, maintenant.month, maintenant.day);
    if (!d.isBefore(jour)) return "Aujourd'hui";
    if (jour.difference(d).inDays < 7) return 'Cette semaine';
    return 'Plus ancien';
  }

  @override
  Widget build(BuildContext context) {
    final Widget corps;
    if (_liste.isEmpty && _erreur != null) {
      corps = EtatErreur(erreur: _erreur!, onReessayer: _suivante);
    } else if (_liste.isEmpty && _chargement) {
      corps = SingleChildScrollView(padding: lisible(context), child: const Padding(
        padding: EdgeInsets.only(top: 16),
        child: ListeSquelette(nombre: 5),
      ));
    } else {
      final enfants = <Widget>[];
      String? groupe;
      for (var i = 0; i < _liste.length; i++) {
        final n = _liste[i];
        final g = _groupe(n.dateCreation);
        if (g != groupe) {
          groupe = g;
          enfants.add(Padding(
            padding: EdgeInsets.fromLTRB(4, enfants.isEmpty ? 0 : 14, 4, 8),
            child: Text(g, style: context.typo.legendeForte),
          ));
        }
        enfants.add(Apparition(
          rang: i % 8,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: LigneNotification(
              notification: n,
              onTap: () => (widget.surToucher ?? ouvrirNotification)(context, n),
            ),
          ),
        ));
      }
      corps = RefreshIndicator(
        onRefresh: _toutRecharger,
        color: context.couleurs.marque,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: lisible(context, const EdgeInsets.fromLTRB(Dim.gouttiere, 16, Dim.gouttiere, 32)),
          children: [
            if (_liste.isEmpty)
              const EtatVide('Aucune notification pour le moment.',
                  icone: Icons.notifications_off_outlined),
            ...enfants,
            if (!_derniere && _liste.isNotEmpty)
              BoutonSecondaire(_chargement ? 'Chargement…' : 'Voir plus',
                  onPressed: _chargement ? null : _suivante),
          ],
        ),
      );
    }
    return EcranVivant(titre: 'Notifications', corps: corps);
  }
}

/// Une notification : pictogramme dans un rond teinte, titre (gras si
/// non lue, point orange), message, heure, chevron si elle ouvre un ecran.
class LigneNotification extends StatelessWidget {
  const LigneNotification({super.key, required this.notification, required this.onTap});
  final NotificationApp notification;
  final VoidCallback onTap;

  static (IconData, Color) _style(BuildContext context, String type) => switch (type) {
        'ALERTE' => (Icons.warning_amber_rounded, context.couleurs.graviteHaute),
        'RAPPEL' => (Icons.event_rounded, context.couleurs.attentionTexte),
        'ORIENTATION' => (Icons.medical_services_rounded, context.couleurs.sante),
        'MODERATION' => (Icons.lightbulb_outline_rounded, context.couleurs.marque),
        _ => (Icons.notifications_none_rounded, context.couleurs.marque),
      };

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final (icone, teinte) = _style(context, n.type);
    final ouvre = cibleDe(n) is! CibleMessage;
    return Pressable(
      onTap: onTap,
      rayon: 16,
      couleur: n.lue
          ? context.couleurs.surface
          : (context.couleurs.sombre ? context.couleurs.fondAccentPale : const Color(0xFFFFFBF5)),
      libelle: [if (!n.lue) 'Nouveau', n.titre, if (n.corps != null) n.corps!].join('. '),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                      color: teinte.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(icone, color: teinte, size: 24),
                ),
                if (!n.lue)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: context.couleurs.accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.couleurs.surface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.titre, style: n.lue ? context.typo.corps : context.typo.corpsFort),
                  if (n.corps != null) ...[
                    const SizedBox(height: 2),
                    Text(n.corps!,
                        style: context.typo.corpsDiscret, maxLines: 3, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 4),
                  Text(Fmt.ilYA(n.dateCreation), style: context.typo.legende),
                ],
              ),
            ),
            if (ouvre)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Icon(Icons.chevron_right_rounded, color: context.couleurs.texteDiscret),
              ),
          ],
        ),
      ),
    );
  }
}
