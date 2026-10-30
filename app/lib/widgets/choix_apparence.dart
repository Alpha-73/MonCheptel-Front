/// « Apparence : Automatique / Clair / Sombre », dans le Profil de
/// l'eleveur et du veterinaire. Le choix s'applique tout de suite et reste
/// memorise sur l'appareil (voir theme/apparence.dart).
library;

import 'package:flutter/material.dart';

import '../theme/apparence.dart';
import '../theme/palette.dart';

class ChoixApparence extends StatelessWidget {
  const ChoixApparence({super.key, this.reglage});

  /// Pour les tests : un reglage a part. Nul : celui de l'application.
  final ReglageApparence? reglage;

  static const _icones = {
    Apparence.automatique: Icons.brightness_auto_outlined,
    Apparence.clair: Icons.light_mode_outlined,
    Apparence.sombre: Icons.dark_mode_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final r = reglage ?? ReglageApparence.instance;
    final c = context.couleurs;
    return ValueListenableBuilder<Apparence>(
      valueListenable: r,
      builder: (context, actuelle, _) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.palette_outlined, color: c.marque),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text('Apparence', style: context.typo.corpsFort),
                ),
              ),
            ]),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Text(actuelle.detail, style: context.typo.legende),
            ),
            const SizedBox(height: 10),
            // Trois cases egales ; le libelle passe sous l'icone quand la
            // place manque (320 px, texte agrandi).
            Row(children: [
              for (final a in Apparence.values) ...[
                if (a != Apparence.values.first) const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: a == actuelle,
                    label: 'Apparence : ${a.libelle}',
                    excludeSemantics: true,
                    child: Material(
                      color: a == actuelle ? c.marque : c.fond,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: a == actuelle ? c.marque : c.filet),
                      ),
                      child: InkWell(
                        key: ValueKey('apparence-${a.name}'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => r.choisir(a),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 56),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_icones[a],
                                    size: 22, color: a == actuelle ? c.surMarque : c.texte),
                                const SizedBox(height: 2),
                                // « Automatique » reste entier sur 320 px :
                                // il se resserre plutot que d'etre coupe.
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    a.libelle,
                                    maxLines: 1,
                                    style: context.typo.legendeForte.copyWith(
                                        color: a == actuelle ? c.surMarque : c.texte),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ]),
          ],
        ),
      ),
    );
  }
}
