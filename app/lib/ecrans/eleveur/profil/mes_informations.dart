/// Maquette : « Mes informations - Rempli » et sa pop-up « Enregistre ».
///
/// Sources : GET /api/zones, PUT /api/auth/moi.
///
/// Changer d'adresse e-mail change l'IDENTIFIANT de connexion. Le back
/// previent l'ANCIENNE adresse (pour qu'un vol de compte ne passe pas
/// inapercu) ; l'ecran le rappelle avant d'enregistrer. Depuis le
/// 10 octobre, il exige aussi le mot de passe actuel : le champ apparait
/// des que l'adresse est modifiee.
library;

import 'package:flutter/material.dart';

import '../../../api/client_api.dart';
import '../../../api/modeles.dart';
import '../../../api/services.dart';
import '../../../libelles.dart';
import '../../../theme/palette.dart';
import '../../../widgets/boutons.dart';
import '../../../widgets/dialogues.dart';
import '../../../widgets/eleveur/ecran_vivant.dart';
import '../../../widgets/entete.dart';
import '../../../widgets/etats.dart';
import '../../../widgets/formulaires.dart';

class EcranMesInformations extends StatelessWidget {
  const EcranMesInformations({super.key, required this.profil});
  final Profil profil;

  @override
  Widget build(BuildContext context) => Chargeur<List<ZoneGeo>>(
        titreEcran: 'Mes informations',
        charger: ReferentielApi.zones,
        construire: (context, zones, _) => _Formulaire(profil: profil, zones: zones),
      );
}

class _Formulaire extends StatefulWidget {
  const _Formulaire({required this.profil, required this.zones});
  final Profil profil;
  final List<ZoneGeo> zones;

  @override
  State<_Formulaire> createState() => _FormulaireState();
}

class _FormulaireState extends State<_Formulaire> {
  final _cle = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: widget.profil.nom);
  late final _email = TextEditingController(text: widget.profil.email);
  late final _telephone = TextEditingController(text: widget.profil.telephone);
  final _motDePasse = TextEditingController();

  bool get _emailChange =>
      _email.text.trim().toLowerCase() != widget.profil.email.toLowerCase();

  @override
  void initState() {
    super.initState();
    // Fait apparaitre (ou disparaitre) le champ « mot de passe actuel ».
    _email.addListener(_surEmail);
  }

  bool _emailChangeAffiche = false;
  void _surEmail() {
    if (_emailChange != _emailChangeAffiche) {
      setState(() => _emailChangeAffiche = _emailChange);
    }
  }
  late int? _zoneId = widget.profil.zone?.id;
  late Set<String> _filieres = widget.profil.filieresPratiquees.toSet();
  String? _erreurZone;
  String? _erreurFilieres;
  bool _envoi = false;

  @override
  void dispose() {
    _nom.dispose();
    _email.removeListener(_surEmail);
    _email.dispose();
    _telephone.dispose();
    _motDePasse.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    setState(() {
      _erreurZone = _zoneId == null ? 'Choisissez votre zone' : null;
      _erreurFilieres = _filieres.isEmpty ? 'Gardez au moins une filière' : null;
    });
    if (!_cle.currentState!.validate() || _zoneId == null || _filieres.isEmpty) return;

    final emailChange = _emailChange;
    if (emailChange) {
      final ok = await confirmer(context, "Changer d'adresse de connexion ?",
          message: 'Vous vous connecterez désormais avec ${_email.text.trim()}. '
              'Un message d’avertissement est envoyé à votre ancienne adresse.',
          confirmer: 'Changer');
      if (!ok || !mounted) return;
    }

    setState(() => _envoi = true);
    try {
      await AuthApi.modifierProfil(
        nom: _nom.text,
        email: _email.text,
        telephone: _telephone.text,
        zoneId: _zoneId!,
        langue: widget.profil.langue,
        filieres: _filieres,
        motDePasseActuel: emailChange ? _motDePasse.text : null,
      );
      if (!mounted) return;
      await afficherInfo(context, 'Informations enregistrées');
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      // 409 : adresse deja utilisee ; 422 : filiere retiree alors qu'un
      // elevage actif y est rattache, par exemple. Le message le dit.
      if (mounted) await afficherErreur(context, e);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) => EcranVivant(
        titre: 'Mes informations',
        corps: CorpsFormulaire(cle: _cle, enfants: [
          ChampTexte(
            libelle: 'Nom complet',
            controleur: _nom,
            longueurMax: 120,
            validateur: (v) => Valider.requis(v, 'Le nom est obligatoire'),
          ),
          ChampTexte(
            libelle: 'Adresse e-mail (pour vous connecter)',
            controleur: _email,
            clavier: TextInputType.emailAddress,
            longueurMax: 160,
            validateur: Valider.email,
          ),
          if (_emailChangeAffiche)
            ChampTexte(
              libelle: 'Mot de passe actuel (pour changer d’adresse)',
              controleur: _motDePasse,
              secret: true,
              validateur: (v) => Valider.requis(
                  v, "Confirmez votre mot de passe pour changer d'adresse"),
            ),
          ChampTexte(
            libelle: 'Téléphone (facultatif)',
            controleur: _telephone,
            clavier: TextInputType.phone,
            longueurMax: 20,
          ),
          ChampChoix<int>(
            libelle: 'Zone',
            valeur: _zoneId,
            erreur: _erreurZone,
            options: [
              for (final z in widget.zones)
                (valeur: z.id, libelle: z.nom, detail: z.region),
            ],
            onChange: (z) => setState(() {
              _zoneId = z;
              _erreurZone = null;
            }),
          ),
          const LibelleChamp('Filières pratiquées'),
          Puces<String>(
            options: [for (final f in L.filieres) (f, L.filiere(f))],
            choisies: _filieres,
            onChange: (v) => setState(() {
              _filieres = v;
              _erreurFilieres = null;
            }),
          ),
          if (_erreurFilieres != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_erreurFilieres!,
                  style: context.typo.legende.copyWith(color: context.couleurs.erreur)),
            ),
        ]),
        pied: BoutonPrincipal(_envoi ? 'Enregistrement…' : 'Enregistrer',
            onPressed: _envoi ? null : _enregistrer),
      );
}
