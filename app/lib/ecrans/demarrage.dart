/// Premier ecran : relit la session enregistree et oriente selon le role.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/client_api.dart';
import '../config.dart';
import '../theme/barre_etat.dart';
import '../theme/palette.dart';
import '../widgets/boutons.dart';
import '../widgets/marque.dart';
import '../widgets/vivant.dart';
import 'accueil/choix_profil.dart';
import 'auth/mot_de_passe_impose.dart';
import 'commun/espace_a_venir.dart';
import 'eleveur/coquille_eleveur.dart';
import 'veterinaire/coquille_veterinaire.dart';

/// L'ecran d'arrivee d'un utilisateur connecte, selon son role.
///
/// Un mot de passe provisoire (compte veterinaire cree par l'administration,
/// mot de passe reinitialise par elle) doit etre change AVANT tout le reste.
Widget ecranApresConnexion(Session s) {
  if (s.doitChangerMotDePasse) return const EcranMotDePasseImpose();
  return switch (s.role) {
    'ELEVEUR' => const CoquilleEleveur(),
    'VETERINAIRE' => const CoquilleVeterinaire(),
    // L'administration travaille sur sa console web, pas sur le telephone.
    _ => EspaceAVenir(role: s.role),
  };
}

/// Remplace toute la pile par l'ecran d'arrivee : le bouton retour ne doit
/// pas ramener a l'ecran de connexion.
void ouvrirEspace(BuildContext context, Session s) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => ecranApresConnexion(s)),
    (_) => false,
  );
}

/// Maquette « MonCheptel - Splash anime » : le logo apparait, les ondes
/// du signal partent du point orange, et apres 3 s l'application passe au
/// choix du profil (ou directement a l'espace, si une session est
/// enregistree). « Continuer » n'attend pas la fin des 3 s.
class Demarrage extends StatefulWidget {
  const Demarrage({super.key, this.duree = const Duration(seconds: 3)});

  /// Duree du splash. Raccourcie dans les tests.
  final Duration duree;

  @override
  State<Demarrage> createState() => _DemarrageState();
}

class _DemarrageState extends State<Demarrage> with SingleTickerProviderStateMixin {
  late final AnimationController _temps =
      AnimationController(vsync: this, duration: widget.duree);
  late final Future<Session?> _session = ClientApi.instance.restaurerSession();
  bool _parti = false;

  @override
  void initState() {
    super.initState();
    _temps.forward().whenComplete(_suivant);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Le logo est pret des la premiere image du splash, pas une fraction
    // de seconde apres.
    precacheImage(const AssetImage('assets/marque/logo.png'), context);
  }

  @override
  void dispose() {
    _temps.dispose();
    super.dispose();
  }

  Future<void> _suivant() async {
    if (_parti) return;
    _parti = true;
    final session = await _session;
    if (!mounted) return;
    if (session == null) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const ChoixProfil()));
    } else {
      // Le jeton d'acces a peut-etre expire depuis le dernier lancement :
      // pas besoin de le verifier ici, le premier appel le renouvellera.
      ouvrirEspace(context, session);
    }
  }

  @override
  Widget build(BuildContext context) {
    final taille = MediaQuery.sizeOf(context);
    final reduit = mouvementReduit(context);
    // Le logo et ses ondes au centre ; ils se tassent sur un ecran bas
    // (paysage, petit Android) pour que rien ne deborde.
    final largeurLogo = (taille.width - 72).clamp(180.0, taille.height < 640 ? 240.0 : 320.0);
    final ondes = (largeurLogo * 1.45).clamp(240.0, 460.0);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: BarreEtat.pourFond(context.couleurs),
      child: Scaffold(
        body: FondMarque(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: Column(
                    children: [
                      const Spacer(flex: 3),
                      // Les ondes partent de derriere le logo, qui arrive en
                      // fondu en grandissant un peu.
                      SizedBox(
                        height: (ondes * 0.82).clamp(200.0, 380.0),
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: OverflowBox(
                                maxWidth: ondes,
                                maxHeight: ondes,
                                child: Opacity(
                                  opacity: 0.55,
                                  child: OndesSignal(taille: ondes, anime: !reduit, point: false),
                                ),
                              ),
                            ),
                            AnimatedBuilder(
                              animation: _temps,
                              builder: (context, enfant) {
                                final t = reduit
                                    ? 1.0
                                    : Curves.easeOutBack
                                        .transform((_temps.value * 2.5).clamp(0.0, 1.0));
                                return Opacity(
                                  opacity: t.clamp(0.0, 1.0),
                                  child: Transform.scale(scale: 0.86 + 0.14 * t, child: enfant),
                                );
                              },
                              child: LogoMonCheptel(largeur: largeurLogo),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Les quatre filieres apparaissent l'une apres l'autre.
                      AnimatedBuilder(
                        animation: _temps,
                        builder: (context, _) => Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var i = 0; i < _filieres.length; i++)
                              Opacity(
                                opacity: reduit
                                    ? 1.0
                                    : ((_temps.value - 0.30 - i * 0.08) / 0.15).clamp(0.0, 1.0),
                                child: _PuceFiliere(_filieres[i]),
                              ),
                          ],
                        ),
                      ),
                      const Spacer(flex: 4),
                      _Progression(temps: _temps),
                      const SizedBox(height: 16),
                      BoutonPrincipal('Continuer',
                          icone: Icons.arrow_forward,
                          iconeApres: true,
                          grand: true,
                          onPressed: _suivant),
                      const SizedBox(height: 10),
                      Text('MonCheptel · Version ${Config.version}',
                          style: context.typo.legende),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const List<String> _filieres = ['Volaille', 'Bovins', 'Ovins', 'Caprins'];

/// Une filiere sous le logo : pastille claire a filet vert.
class _PuceFiliere extends StatelessWidget {
  const _PuceFiliere(this.libelle);
  final String libelle;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: context.couleurs.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.couleurs.filetLeger),
        ),
        child: Text(libelle,
            style: context.typo.legendeForte.copyWith(color: context.couleurs.marque)),
      );
}

/// Barre de progression du splash, sous le logo.
class _Progression extends StatelessWidget {
  const _Progression({required this.temps});
  final Animation<double> temps;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: temps,
        builder: (context, _) => Semantics(
          label: 'Chargement',
          child: Center(
            child: Container(
              width: 140,
              height: 6,
              decoration: BoxDecoration(
                color: context.couleurs.fondAccueilBas,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: context.couleurs.filet, width: 0.5),
              ),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: temps.value.clamp(0.04, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [context.couleurs.marque, context.couleurs.accent]),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
