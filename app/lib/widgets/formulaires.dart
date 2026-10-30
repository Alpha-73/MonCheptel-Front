/// Champs de formulaire de la maquette : libelle AU-DESSUS du champ, champ
/// blanc a filet gris, 48 px de haut.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/palette.dart';
import '../theme/dimensions.dart';
import '../theme/format.dart';
import '../theme/typographie.dart';
import 'mise_en_page.dart';

/// Libelle de champ : 14/600, au-dessus du champ.
class LibelleChamp extends StatelessWidget {
  const LibelleChamp(this.texte, {super.key});
  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(texte, style: context.typo.legendeForte.copyWith(color: context.couleurs.texte)),
      );
}

/// Bloc « libelle + champ » avec l'espacement standard sous lui.
class BlocChamp extends StatelessWidget {
  const BlocChamp({super.key, required this.libelle, required this.champ});
  final String libelle;
  final Widget champ;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [LibelleChamp(libelle), champ],
        ),
      );
}

/// Champ texte. [validateur] : renvoie le message d'erreur, ou null.
///
/// [icone] : pictogramme a gauche (enveloppe, cadenas), comme sur la
/// maquette « Espace éleveur ». Un champ [secret] porte un oeil qui
/// affiche ou masque le mot de passe.
class ChampTexte extends StatefulWidget {
  const ChampTexte({
    super.key,
    required this.libelle,
    required this.controleur,
    this.indication,
    this.validateur,
    this.clavier,
    this.secret = false,
    this.lignes = 1,
    this.longueurMax,
    this.chiffresSeulement = false,
    this.lectureSeule = false,
    this.autofill,
    this.icone,
    this.actionClavier,
    this.onValider,
  });

  final String libelle;
  final TextEditingController controleur;
  final String? indication;
  final String? Function(String?)? validateur;
  final TextInputType? clavier;
  final bool secret;
  final int lignes;
  final int? longueurMax;
  final bool chiffresSeulement;
  final bool lectureSeule;
  final Iterable<String>? autofill;
  final IconData? icone;

  /// Touche d'action du clavier (Suivant, Valider…).
  final TextInputAction? actionClavier;

  /// Appele quand l'utilisateur valide depuis le clavier.
  final ValueChanged<String>? onValider;

  @override
  State<ChampTexte> createState() => _ChampTexteState();
}

class _ChampTexteState extends State<ChampTexte> {
  late bool _masque = widget.secret;

  @override
  Widget build(BuildContext context) => BlocChamp(
        libelle: widget.libelle,
        champ: TextFormField(
          controller: widget.controleur,
          validator: widget.validateur,
          keyboardType: widget.chiffresSeulement ? TextInputType.number : widget.clavier,
          obscureText: _masque,
          readOnly: widget.lectureSeule,
          enabled: !widget.lectureSeule,
          minLines: widget.lignes,
          maxLines: widget.secret ? 1 : widget.lignes,
          maxLength: widget.longueurMax,
          autofillHints: widget.autofill,
          textInputAction: widget.actionClavier,
          onFieldSubmitted: widget.onValider,
          style: context.typo.corps,
          inputFormatters: [
            if (widget.chiffresSeulement) FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            hintText: widget.indication,
            counterText: '',
            fillColor: widget.lectureSeule ? context.couleurs.fond : context.couleurs.surface,
            prefixIcon: widget.icone == null
                ? null
                : Icon(widget.icone, size: 20, color: context.couleurs.texteDiscret),
            suffixIcon: !widget.secret
                ? null
                : IconButton(
                    tooltip: _masque ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                    icon: Icon(
                        _masque ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 20,
                        color: context.couleurs.texteDiscret),
                    onPressed: () => setState(() => _masque = !_masque),
                  ),
          ),
        ),
      );
}

/// Faux champ cliquable : affiche une valeur, ouvre un selecteur au toucher.
///
/// Base commune de [ChampChoix] et [ChampDate]. Pas de `DropdownButton` :
/// son parametre de valeur a change de nom selon les versions de Flutter,
/// et la maquette ouvre de toute facon une liste, pas un menu.
class _FauxChamp extends StatelessWidget {
  const _FauxChamp({
    required this.texte,
    required this.indicatif,
    required this.icone,
    required this.onTap,
    this.erreur,
  });

  final String texte;
  final bool indicatif;
  final IconData icone;
  final VoidCallback? onTap;
  final String? erreur;

  @override
  Widget build(BuildContext context) {
    final bord = erreur != null ? context.couleurs.erreur : context.couleurs.filet;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: onTap == null ? context.couleurs.fond : context.couleurs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Dim.rayon),
            side: BorderSide(color: bord, width: Dim.filet),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Dim.rayon),
            child: Container(
              constraints: const BoxConstraints(minHeight: Dim.hauteurTactile),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      texte,
                      style: indicatif
                          ? context.typo.corps.copyWith(color: context.couleurs.texteIndicatif)
                          : context.typo.corps,
                    ),
                  ),
                  if (onTap != null) Icon(icone, color: context.couleurs.texteDiscret),
                ],
              ),
            ),
          ),
        ),
        if (erreur != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(erreur!,
                style: context.typo.legende.copyWith(color: context.couleurs.erreur)),
          ),
      ],
    );
  }
}

/// Une option de [ChampChoix] : la valeur et ce qu'on en affiche.
typedef OptionChoix<T> = ({T valeur, String libelle, String? detail});

/// Liste deroulante a la maniere de la maquette : un champ qui ouvre une
/// liste par le bas de l'ecran.
class ChampChoix<T> extends StatelessWidget {
  const ChampChoix({
    super.key,
    required this.libelle,
    required this.options,
    required this.valeur,
    required this.onChange,
    this.indication = 'Choisir',
    this.erreur,
    this.actif = true,
  });

  final String libelle;
  final List<OptionChoix<T>> options;
  final T? valeur;
  final ValueChanged<T> onChange;
  final String indication;
  final String? erreur;
  final bool actif;

  Future<void> _ouvrir(BuildContext context) async {
    final choisi = await showModalBottomSheet<OptionChoix<T>>(
      context: context,
      backgroundColor: context.couleurs.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Dim.rayonPastille)),
      ),
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Text(libelle, style: context.typo.titreSection),
              ),
              Flexible(
                child: ListView(padding: lisible(context), 
                  shrinkWrap: true,
                  children: [
                    for (final o in options)
                      ListTile(
                        title: Text(o.libelle, style: context.typo.corps),
                        subtitle: o.detail == null
                            ? null
                            : Text(o.detail!, style: context.typo.legende),
                        trailing: o.valeur == valeur
                            ? Icon(Icons.check, color: context.couleurs.marque)
                            : null,
                        onTap: () => Navigator.of(context).pop(o),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (choisi != null) onChange(choisi.valeur);
  }

  @override
  Widget build(BuildContext context) {
    OptionChoix<T>? courant;
    for (final o in options) {
      if (o.valeur == valeur) courant = o;
    }
    return BlocChamp(
      libelle: libelle,
      champ: _FauxChamp(
        texte: courant?.libelle ?? indication,
        indicatif: courant == null,
        icone: Icons.expand_more,
        erreur: erreur,
        onTap: (actif && options.isNotEmpty) ? () => _ouvrir(context) : null,
      ),
    );
  }
}

/// Champ de date : ouvre le calendrier du systeme, en francais.
class ChampDate extends StatelessWidget {
  const ChampDate({
    super.key,
    required this.libelle,
    required this.valeur,
    required this.onChange,
    this.premiere,
    this.derniere,
    this.erreur,
  });

  final String libelle;
  final DateTime? valeur;
  final ValueChanged<DateTime> onChange;
  final DateTime? premiere;
  final DateTime? derniere;
  final String? erreur;

  @override
  Widget build(BuildContext context) => BlocChamp(
        libelle: libelle,
        champ: _FauxChamp(
          texte: valeur == null ? 'JJ/MM/AAAA' : Fmt.dateChamp(valeur!),
          indicatif: valeur == null,
          icone: Icons.calendar_today_outlined,
          erreur: erreur,
          onTap: () async {
            final maintenant = DateTime.now();
            final dernier = derniere ?? DateTime(maintenant.year + 1, 12, 31);
            final premier = premiere ?? DateTime(2000);
            var initial = valeur ?? maintenant;
            if (initial.isAfter(dernier)) initial = dernier;
            if (initial.isBefore(premier)) initial = premier;
            final d = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: premier,
              lastDate: dernier,
              locale: const Locale('fr'),
            );
            if (d != null) onChange(d);
          },
        ),
      );
}

/// Choix exclusif en segments : « Dépense | Revenu », « Mâle | Femelle ».
class Segments<T> extends StatelessWidget {
  const Segments({
    super.key,
    required this.options,
    required this.valeur,
    required this.onChange,
  });

  final List<(T, String)> options;
  final T? valeur;
  final ValueChanged<T>? onChange;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _Segment(
              libelle: options[i].$2,
              actif: options[i].$1 == valeur,
              onTap: onChange == null ? null : () => onChange!(options[i].$1),
            ),
          ),
        ],
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.libelle, required this.actif, this.onTap});
  final String libelle;
  final bool actif;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: actif ? context.couleurs.marque : context.couleurs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dim.rayon),
          side: actif
              ? BorderSide.none
              : BorderSide(color: context.couleurs.filet, width: Dim.filet),
        ),
        child: InkWell(
          onTap: actif ? null : onTap,
          borderRadius: BorderRadius.circular(Dim.rayon),
          child: Container(
            height: Dim.hauteurTactile,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              libelle,
              textAlign: TextAlign.center,
              style: Typo.bouton
                  .copyWith(color: actif ? context.couleurs.surMarque : context.couleurs.texte),
            ),
          ),
        ),
      );
}

/// Choix exclusif en pilules qui passent a la ligne : la filiere et la
/// categorie d'un conseil. Pilule choisie pleine et verte, les autres
/// blanches a filet gris, 44 px de haut (maquette « Veto - Conseil
/// rediger »).
class ChoixPilules<T> extends StatelessWidget {
  const ChoixPilules({
    super.key,
    required this.options,
    required this.valeur,
    required this.onChange,
  });

  final List<(T, String)> options;
  final T? valeur;
  final ValueChanged<T> onChange;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (v, libelle) in options)
          Semantics(
            selected: v == valeur,
            button: true,
            child: Material(
              color: v == valeur ? context.couleurs.marque : context.couleurs.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Dim.rayonPastille),
                side: v == valeur
                    ? BorderSide.none
                    : BorderSide(color: context.couleurs.filet, width: Dim.filet),
              ),
              child: InkWell(
                onTap: v == valeur ? null : () => onChange(v),
                borderRadius: BorderRadius.circular(Dim.rayonPastille),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  // `widthFactor: 1` : la pilule epouse son texte au lieu de
                  // prendre toute la largeur que lui offre le Wrap.
                  child: SizedBox(
                    height: 44,
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                    libelle,
                    style: v == valeur
                        ? Typo.bouton.copyWith(color: context.couleurs.surMarque)
                        : Typo.bouton.copyWith(
                            color: context.couleurs.texteDiscret, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Puces a choix multiple : les filieres pratiquees, les symptomes.
class Puces<T> extends StatelessWidget {
  const Puces({
    super.key,
    required this.options,
    required this.choisies,
    required this.onChange,
  });

  final List<(T, String)> options;
  final Set<T> choisies;
  final ValueChanged<Set<T>> onChange;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (valeur, libelle) in options)
          _Puce(
            libelle: libelle,
            actif: choisies.contains(valeur),
            onTap: () {
              final copie = {...choisies};
              if (!copie.remove(valeur)) copie.add(valeur);
              onChange(copie);
            },
          ),
      ],
    );
  }
}

class _Puce extends StatelessWidget {
  const _Puce({required this.libelle, required this.actif, required this.onTap});
  final String libelle;
  final bool actif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: actif ? context.couleurs.fondMarquePale : context.couleurs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dim.rayonPastille),
          side: BorderSide(
              color: actif ? context.couleurs.marque : context.couleurs.filet,
              width: actif ? 1.5 : Dim.filet),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Dim.rayonPastille),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (actif) ...[
                  Icon(Icons.check, size: 16, color: context.couleurs.marque),
                  const SizedBox(width: 6),
                ],
                Text(libelle,
                    style: context.typo.legendeForte.copyWith(
                        color: actif ? context.couleurs.marque : context.couleurs.texte)),
              ],
            ),
          ),
        ),
      );
}

// ── validateurs ────────────────────────────────────────────────────────────

abstract final class Valider {
  static String? requis(String? v, [String message = 'Ce champ est obligatoire']) =>
      (v == null || v.trim().isEmpty) ? message : null;

  /// Meme regle large que le back (`@Email`) : un @ et un point apres.
  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return "L'adresse e-mail est obligatoire";
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
    return ok ? null : 'Adresse e-mail invalide';
  }

  /// 8 a 72 caracteres, comme `@Size(min = 8, max = 72)` cote back. 72 est
  /// la limite de BCrypt : au-dela, les caracteres seraient ignores.
  static String? motDePasse(String? v) {
    if (v == null || v.isEmpty) return 'Le mot de passe est obligatoire';
    if (v.length < 8) return 'Au moins 8 caractères';
    if (v.length > 72) return '72 caractères au maximum';
    return null;
  }

  static String? entierPositif(String? v, [String quoi = 'La valeur']) {
    final n = int.tryParse((v ?? '').trim());
    if (n == null) return '$quoi est obligatoire';
    if (n <= 0) return '$quoi doit être supérieur à zéro';
    return null;
  }
}
