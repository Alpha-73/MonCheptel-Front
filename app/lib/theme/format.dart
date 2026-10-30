/// Mise en forme des montants et des dates.
library;

abstract final class Fmt {
  /// « 74000 » → « 74 000 ». Espace ORDINAIRE, volontairement.
  ///
  /// `intl` en locale fr utilise l'espace fine insecable U+202F. Ce caractere
  /// n'est pas garanti dans toutes les polices Android : il s'affiche alors
  /// en carre. La maquette a eu le probleme, on ne le refait pas.
  static String montant(num valeur, {bool signe = false}) {
    final n = valeur.abs().round();
    final chiffres = n.toString();
    final tampon = StringBuffer();
    for (var i = 0; i < chiffres.length; i++) {
      if (i > 0 && (chiffres.length - i) % 3 == 0) tampon.write(' ');
      tampon.write(chiffres[i]);
    }
    final corps = tampon.toString();
    // « − » (signe moins U+2212) comme la maquette, pas le tiret.
    if (!signe) return valeur < 0 ? '− $corps' : corps;
    if (valeur == 0) return corps;
    return valeur < 0 ? '− $corps' : '+ $corps';
  }

  /// « 74 000 FCFA », signe compris.
  static String fcfa(num valeur, {bool signe = false}) =>
      '${montant(valeur, signe: signe)} FCFA';

  static const List<String> _mois = [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
  ];

  static const List<String> _moisLongs = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];

  static const List<String> _moisCourts = [
    'Janv', 'Févr', 'Mars', 'Avr', 'Mai', 'Juin',
    'Juil', 'Août', 'Sept', 'Oct', 'Nov', 'Déc',
  ];

  /// « 3 sept. 2026 ». Tiret long si la date est absente.
  static String date(DateTime? d) =>
      d == null ? '—' : '${d.day} ${_mois[d.month - 1]} ${d.year}';

  /// « 3 sept. » — sans l'annee, quand le contexte la donne.
  static String dateCourte(DateTime? d) =>
      d == null ? '—' : '${d.day} ${_mois[d.month - 1]}';

  /// « 12 septembre 2026 ».
  static String dateLongue(DateTime? d) =>
      d == null ? '—' : '${d.day} ${_moisLongs[d.month - 1]} ${d.year}';

  /// « 03/09/2026 », dans les champs de saisie de date.
  static String dateChamp(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// « septembre » pour un mois donne (1-12).
  static String moisLong(int mois) => _moisLongs[mois - 1];

  /// « 2026-09 » (format du rapport) → « Sept ».
  static String moisAxe(String aaaaMm) {
    final parties = aaaaMm.split('-');
    if (parties.length < 2) return aaaaMm;
    final m = int.tryParse(parties[1]);
    return (m == null || m < 1 || m > 12) ? aaaaMm : _moisCourts[m - 1];
  }

  /// « 2026-09 » → « septembre 2026 ».
  static String moisAnnee(String aaaaMm) {
    final parties = aaaaMm.split('-');
    final a = parties.isNotEmpty ? int.tryParse(parties[0]) : null;
    final m = parties.length > 1 ? int.tryParse(parties[1]) : null;
    if (a == null || m == null || m < 1 || m > 12) return aaaaMm;
    return '${_moisLongs[m - 1]} $a';
  }

  /// Graduation d'axe : « 0 », « 25 k », « 1,5 M ». Jamais de devise : le
  /// titre du graphique la donne.
  static String compact(num valeur) {
    final v = valeur.abs();
    final signe = valeur < 0 ? '− ' : '';
    String decimal(double x) {
      final arrondi = (x * 10).round() / 10;
      final texte = arrondi == arrondi.roundToDouble()
          ? arrondi.round().toString()
          : arrondi.toStringAsFixed(1).replaceAll('.', ',');
      return texte;
    }
    if (v >= 1000000) return '$signe${decimal(v / 1000000)} M';
    if (v >= 1000) return '$signe${decimal(v / 1000)} k';
    return '$signe${v.round()}';
  }

  /// « Il y a 2 h », « Hier », « Il y a 3 jours », puis la date.
  static String ilYA(DateTime? d) {
    if (d == null) return '';
    final ecart = DateTime.now().difference(d);
    if (ecart.inMinutes < 1) return "À l'instant";
    if (ecart.inMinutes < 60) return 'Il y a ${ecart.inMinutes} min';
    if (ecart.inHours < 24) return 'Il y a ${ecart.inHours} h';
    if (ecart.inDays == 1) return 'Hier';
    if (ecart.inDays < 7) return 'Il y a ${ecart.inDays} jours';
    return date(d);
  }

  /// « Signalé il y a 2 h », « Signalé hier », puis « Signalé le 3 sept.
  /// 2026 ». [feminin] : « Signalée » (une maladie, une demande).
  static String signale(DateTime? d, {bool feminin = false}) {
    if (d == null) return '';
    final mot = feminin ? 'Signalée' : 'Signalé';
    if (DateTime.now().difference(d).inDays >= 7) return '$mot le ${date(d)}';
    final ilya = ilYA(d);
    return '$mot ${ilya[0].toLowerCase()}${ilya.substring(1)}';
  }

  /// « dans 3 jours », « aujourd'hui », « en retard de 2 jours ».
  static String echeance(int joursRestants) {
    if (joursRestants == 0) return "aujourd'hui";
    if (joursRestants == 1) return 'demain';
    if (joursRestants > 1) return 'dans $joursRestants jours';
    final n = -joursRestants;
    return 'en retard de $n jour${n > 1 ? 's' : ''}';
  }

  /// « 1 tête », « 180 têtes ».
  static String tetes(int n) => '${montant(n)} tête${n > 1 ? 's' : ''}';

  /// Initiales d'un nom, pour une pastille d'avatar. « Balla Koné » → « BK ».
  /// Le titre « Dr » est saute : « Dr Aïssata Traoré » → « AT ».
  static String initiales(String nom) {
    final mots = nom
        .trim()
        .split(RegExp(r'\s+'))
        .where((m) => m.isNotEmpty && m.toLowerCase() != 'dr' && m.toLowerCase() != 'dr.')
        .toList();
    if (mots.isEmpty) return '?';
    if (mots.length == 1) return mots.first[0].toUpperCase();
    return (mots.first[0] + mots.last[0]).toUpperCase();
  }
}
