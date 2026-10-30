// Fonctions de mise en forme « à la française », sans dépendre des données
// ICU du navigateur (qui varient d'un moteur à l'autre : espace fine ou non,
// « sept. » ou « sep »). Les pipes de shared/ ne font que les appeler.

import {
  CategorieConseil,
  Filiere,
  Langue,
  NiveauGravite,
  Role,
  StatutAlerte,
  StatutConseil,
  StatutSignalement,
} from './modeles';

/** Espace insécable utilisée comme séparateur de milliers (« 1 248 »). */
export const SEPARATEUR_MILLIERS = ' ';

const MOIS_COURTS = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
const MOIS_LONGS = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

/** 1248 → « 1 248 » ; 3.5 → « 3,5 ». Rend « — » pour une valeur absente. */
export function formaterNombre(valeur: number | null | undefined, decimales = 0): string {
  if (valeur === null || valeur === undefined || Number.isNaN(valeur)) {
    return '—';
  }
  const negatif = valeur < 0;
  const fixe = Math.abs(valeur).toFixed(decimales);
  const [entier, fraction] = fixe.split('.');
  const groupes = entier.replace(/\B(?=(\d{3})+(?!\d))/g, SEPARATEUR_MILLIERS);
  const fractionPropre = fraction && /[1-9]/.test(fraction) ? ',' + fraction.replace(/0+$/, '') : '';
  return (negatif ? '-' : '') + groupes + fractionPropre;
}

/**
 * Convertit une date de l'API en `Date`.
 * - `LocalDate` (« 2026-08-03 ») : lue comme une date civile locale, pour ne
 *   jamais reculer d'un jour selon le fuseau du navigateur ;
 * - `Instant` ISO-8601 : laissé au parseur du navigateur.
 */
export function lireDate(valeur: string | Date | null | undefined): Date | null {
  if (!valeur) {
    return null;
  }
  if (valeur instanceof Date) {
    return Number.isNaN(valeur.getTime()) ? null : valeur;
  }
  const civile = /^(\d{4})-(\d{2})-(\d{2})$/.exec(valeur);
  const date = civile ? new Date(+civile[1], +civile[2] - 1, +civile[3]) : new Date(valeur);
  return Number.isNaN(date.getTime()) ? null : date;
}

/** « 18 sept. » (format des tableaux de la maquette). */
export function formaterDateCourte(valeur: string | Date | null | undefined): string {
  const date = lireDate(valeur);
  return date ? `${date.getDate()} ${MOIS_COURTS[date.getMonth()]}` : '—';
}

/** « 3 août 2026 » ; sans l'année : « 18 septembre ». */
export function formaterDateLongue(valeur: string | Date | null | undefined, avecAnnee = true): string {
  const date = lireDate(valeur);
  if (!date) {
    return '—';
  }
  const base = `${date.getDate()} ${MOIS_LONGS[date.getMonth()]}`;
  return avecAnnee ? `${base} ${date.getFullYear()}` : base;
}

/** « 1 vétérinaire », « 3 vétérinaires » ; « 0 vétérinaire » en français. */
export function pluriel(n: number, singulier: string, plurielForme = singulier + 's'): string {
  return `${formaterNombre(n)} ${Math.abs(n) >= 2 ? plurielForme : singulier}`;
}

/** Initiales d'un nom : « Mamadou Traoré » → « MT » ; ignore « Dr ». */
export function initiales(nom: string | null | undefined): string {
  if (!nom) {
    return '?';
  }
  const mots = nom
    .split(/\s+/)
    .filter((m) => m && /^\p{L}/u.test(m) && !/^(dr|pr)\.?$/i.test(m));
  if (mots.length === 0) {
    return '?';
  }
  if (mots.length === 1) {
    // Un seul mot (« Administrateur ») : ses deux premières lettres, « AD ».
    return mots[0].slice(0, 2).toUpperCase();
  }
  const lettres = [mots[0], mots[mots.length - 1]];
  return lettres.map((m) => m.charAt(0).toUpperCase()).join('') || '?';
}

// ── Libellés des énumérations ────────────────────────────────────────────

const LIBELLES: Record<string, Record<string, string>> = {
  filiere: { VOLAILLE: 'Volaille', BOVINS: 'Bovins', OVINS: 'Ovins', CAPRINS: 'Caprins' },
  gravite: { FAIBLE: 'Faible', MOYEN: 'Moyen', ELEVE: 'Élevé' },
  statutSignalement: { NOUVEAU: 'Nouveau', ORIENTE: 'En attente de réponse', EN_COURS: 'Accepté', TRAITE: 'Traité' },
  statutConseil: { BROUILLON: 'Brouillon', EN_MODERATION: 'En modération', PUBLIE: 'Publié', RETIRE: 'Retiré' },
  categorie: { SANTE: 'Santé', PRODUCTION: 'Production', HYGIENE: 'Hygiène' },
  statutAlerte: { ACTIVE: 'Active', TERMINEE: 'Terminée' },
  role: { ELEVEUR: 'Éleveur', VETERINAIRE: 'Vétérinaire', ADMINISTRATEUR: 'Administrateur' },
  langue: { FR: 'Français', BM: 'Bambara' },
};

export type FamilleLibelle = keyof typeof LIBELLES;

export function libelle(famille: FamilleLibelle, code: string | null | undefined): string {
  if (!code) {
    return '—';
  }
  return LIBELLES[famille]?.[code] ?? code;
}

export const libelleFiliere = (f: Filiere | null | undefined) => libelle('filiere', f);
export const libelleGravite = (g: NiveauGravite | null | undefined) => libelle('gravite', g);
export const libelleStatutConseil = (s: StatutConseil | null | undefined) => libelle('statutConseil', s);
export const libelleStatutAlerte = (s: StatutAlerte | null | undefined) => libelle('statutAlerte', s);
export const libelleStatutSignalement = (s: StatutSignalement | null | undefined) => libelle('statutSignalement', s);
export const libelleCategorie = (c: CategorieConseil | null | undefined) => libelle('categorie', c);
export const libelleRole = (r: Role | null | undefined) => libelle('role', r);
export const libelleLangue = (l: Langue | null | undefined) => libelle('langue', l);

/** « Volaille, Bovins » dans l'ordre canonique des filières. */
export function libellesFilieres(filieres: Filiere[] | null | undefined): string {
  if (!filieres || filieres.length === 0) {
    return '—';
  }
  const ordre: Filiere[] = ['VOLAILLE', 'BOVINS', 'OVINS', 'CAPRINS'];
  return [...filieres]
    .sort((a, b) => ordre.indexOf(a) - ordre.indexOf(b))
    .map(libelleFiliere)
    .join(', ');
}

/**
 * Le serveur renvoie certains libellés de statistiques sans accents
 * (« Eleveurs », « Veterinaires ») : on les rétablit pour l'affichage.
 */
export function accentuer(texte: string): string {
  const corrections: Record<string, string> = {
    Eleveurs: 'Éleveurs',
    Eleveur: 'Éleveur',
    Veterinaires: 'Vétérinaires',
    Veterinaire: 'Vétérinaire',
  };
  return corrections[texte] ?? texte;
}

// ── Couleur des pastilles ────────────────────────────────────────────────

export type CouleurBadge = 'vert' | 'rouge' | 'orange' | 'gris';

/** Élevé en rouge, Moyen en orange, Faible en vert (comme la maquette). */
export function couleurGravite(g: NiveauGravite | null | undefined): CouleurBadge {
  return g === 'ELEVE' ? 'rouge' : g === 'MOYEN' ? 'orange' : g === 'FAIBLE' ? 'vert' : 'gris';
}

export function couleurStatutConseil(s: StatutConseil | null | undefined): CouleurBadge {
  return s === 'PUBLIE' ? 'vert' : s === 'EN_MODERATION' ? 'orange' : s === 'RETIRE' ? 'rouge' : 'gris';
}

export function couleurStatutAlerte(s: StatutAlerte | null | undefined): CouleurBadge {
  return s === 'ACTIVE' ? 'rouge' : 'gris';
}

/** Largeur d'une barre de répartition, en % du maximum de la série. */
export function largeurBarre(valeur: number, maximum: number): number {
  if (!maximum || maximum <= 0 || !valeur || valeur <= 0) {
    return 0;
  }
  return Math.max(1.5, Math.min(100, (valeur / maximum) * 100));
}

/** « des 742 éleveurs concernés » ; « de l'éleveur concerné » ; « d'aucun éleveur ». */
export function desEleveursConcernes(n: number): string {
  if (n <= 0) {
    return "d'aucun éleveur";
  }
  return n === 1 ? "de l'éleveur concerné" : `des ${formaterNombre(n)} éleveurs concernés`;
}

const JOURS = ['dimanche', 'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi'];

/** « Mardi 7 octobre 2026 ». */
export function formaterJour(date: Date): string {
  const jour = JOURS[date.getDay()];
  return `${jour.charAt(0).toUpperCase()}${jour.slice(1)} ${date.getDate()} ${MOIS_LONGS[date.getMonth()]} ${date.getFullYear()}`;
}

/** Date du jour au format des champs date, « 2026-10-07 », à l'heure locale. */
export function jourIso(date: Date = new Date()): string {
  const deux = (n: number) => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${deux(date.getMonth() + 1)}-${deux(date.getDate())}`;
}

/** Ancienneté lisible : « à l'instant », « il y a 12 min », « il y a 3 h », « il y a 2 j », puis « 18 sept. ». */
export function depuis(valeur: string | Date | null | undefined, maintenant: Date = new Date()): string {
  const date = lireDate(valeur);
  if (!date) return '—';
  const minutes = Math.floor((maintenant.getTime() - date.getTime()) / 60000);
  if (minutes < 1) return 'à l’instant';
  if (minutes < 60) return `il y a ${minutes} min`;
  const heures = Math.floor(minutes / 60);
  if (heures < 24) return `il y a ${heures} h`;
  const jours = Math.floor(heures / 24);
  if (jours < 7) return `il y a ${jours} j`;
  return formaterDateCourte(date);
}
