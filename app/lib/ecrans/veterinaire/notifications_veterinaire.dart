/// Les notifications du vétérinaire, groupées par jour ; chaque ligne
/// ouvre le cas ou le conseil concerné.
///
/// Sources : GET /api/notifications, POST /api/notifications/lecture,
/// GET /api/signalements/{id} (au toucher d'un cas), GET /api/conseils/{id}.
library;

import 'package:flutter/material.dart';

import '../../api/client_api.dart';
import '../../api/modeles.dart';
import '../../api/services.dart';
import '../../theme/palette.dart';
import '../../theme/dimensions.dart';
import '../../theme/format.dart';
import '../../widgets/dialogues.dart';
import '../../widgets/etats.dart';
import '../../widgets/navigation.dart';
import '../../widgets/vivant.dart';
import 'commun_veterinaire.dart';
import 'demandes.dart';
import 'mes_conseils.dart';
import '../../widgets/mise_en_page.dart';

/// « Aujourd'hui », « Hier », sinon la date.
String jourNotification(DateTime? d, [DateTime? maintenant]) {
  if (d == null) return 'Plus ancien';
  final m = maintenant ?? DateTime.now();
  final jour = DateTime(d.year, d.month, d.day);
  final ecart = DateTime(m.year, m.month, m.day).difference(jour).inDays;
  if (ecart == 0) return "Aujourd'hui";
  if (ecart == 1) return 'Hier';
  return Fmt.dateLongue(d);
}

class EcranNotificationsVeto extends StatelessWidget {
  const EcranNotificationsVeto({super.key});

  static Future<PageApi<NotificationApp>> _charger() async {
    final page = await NotificationApi.lister();
    // Marquees lues APRES lecture : la liste montre encore les nouvelles.
    if (page.elements.any((n) => !n.lue)) {
      try {
        await NotificationApi.toutMarquerLu();
      } catch (_) {}
    }
    return page;
  }

  static bool ouvrable(NotificationApp n) =>
      n.referenceId != null && (n.referenceType == 'SIGNALEMENT' || n.referenceType == 'CONSEIL');

  static Future<void> ouvrirNotification(BuildContext context, NotificationApp n) async {
    final id = n.referenceId;
    if (id == null) return;
    switch (n.referenceType) {
      case 'SIGNALEMENT':
        await ouvrir<int>(context, EcranDemandeParId(id: id));
      case 'CONSEIL':
        // Ses propres conseils, tous statuts : GET /api/conseils/{id} ne rend
        // que les conseils PUBLIES (404 sur un conseil retire ou refuse, celui
        // justement dont parle la notification de moderation) et compte une
        // lecture (relecture, point 7).
        try {
          final mes = await ConseilApi.mesConseils();
          final c = mes.where((c) => c.id == id).firstOrNull;
          if (!context.mounted) return;
          if (c == null) {
            await afficherErreur(
                context, const ApiException(404, "Ce conseil n'existe plus."));
            return;
          }
          await ouvrir<void>(context, EcranConseilVeto(conseil: c));
        } on ApiException catch (e) {
          if (context.mounted) await afficherErreur(context, e);
        }
    }
  }

  static IconData _icone(String type) => switch (type) {
        'ORIENTATION' => Icons.medical_services_outlined,
        'MODERATION' => Icons.menu_book_outlined,
        'ALERTE' => Icons.warning_amber_rounded,
        _ => Icons.notifications_none_rounded,
      };

  @override
  Widget build(BuildContext context) {
    const entete = EnteteVivant(sombre: true, retour: true, titre: 'Notifications');
    return Scaffold(
      backgroundColor: context.couleurs.fond,
      body: ChargeurVeto<PageApi<NotificationApp>>(
        entete: entete,
        charger: _charger,
        construire: (context, page, recharger) {
          final lignes = <Widget>[];
          String? jourCourant;
          var rang = 0;
          for (final n in page.elements) {
            final jour = jourNotification(n.dateCreation);
            if (jour != jourCourant) {
              jourCourant = jour;
              lignes.add(Padding(
                padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                child: Semantics(
                  header: true,
                  child: Text(jour.toUpperCase(),
                      style: context.typo.legende
                          .copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                ),
              ));
            }
            lignes.add(Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Apparition(
                rang: rang++,
                child: _LigneNotification(
                  n,
                  icone: _icone(n.type),
                  onTap: ouvrable(n)
                      ? () async {
                          await ouvrirNotification(context, n);
                          await recharger();
                        }
                      : null,
                ),
              ),
            ));
          }
          return Column(
            children: [
              entete,
              Expanded(
                child: RefreshIndicator(
                  onRefresh: recharger,
                  color: context.couleurs.marque,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: lisible(context, const EdgeInsets.fromLTRB(Dim.gouttiere, 0, Dim.gouttiere, 24)),
                    children: [
                      if (page.elements.isEmpty)
                        const EtatVide('Aucune notification pour le moment.',
                            icone: Icons.notifications_off_outlined),
                      ...lignes,
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LigneNotification extends StatelessWidget {
  const _LigneNotification(this.n, {required this.icone, this.onTap});
  final NotificationApp n;
  final IconData icone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        ombre: !n.lue,
        couleur: n.lue ? context.couleurs.surface : context.couleurs.fondAccentPale,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: context.couleurs.fondMarquePale, shape: BoxShape.circle),
                  child: Icon(icone, color: context.couleurs.marque, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.titre,
                          style: n.lue ? context.typo.corps : context.typo.corpsFort),
                      if (n.corps != null) Text(n.corps!, style: context.typo.legende),
                      const SizedBox(height: 2),
                      Text(Fmt.ilYA(n.dateCreation),
                          style: context.typo.legende.copyWith(fontSize: 12.5)),
                    ],
                  ),
                ),
                if (onTap != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Icon(Icons.chevron_right, color: context.couleurs.marque),
                  ),
              ],
            ),
          ),
        ),
      );
}
