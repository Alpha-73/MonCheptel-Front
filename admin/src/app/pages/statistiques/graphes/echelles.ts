// Calculs purs des graphiques de l'écran Statistiques : graduations, hauteurs,
// libellés de dates, étapes du parcours. Sans Angular, testés à part.

import { formaterDateCourte, formaterDateLongue, formaterNombre, lireDate } from '../../../core/format';
import { Entonnoir, PrecisionMoteur } from '../statistiques.api';

/** Une série d'un graphique : son nom (légende, infobulle) et sa couleur (jeton CSS). */
export interface SerieGraphe {
  libelle: string;
  couleur: string;
}

/**
 * Graduations « rondes » d'un axe de comptes, de 0 jusqu'au premier multiple
 * du pas qui couvre le maximum : pas de 1, 2 ou 5 × 10ⁿ (jamais décimal),
 * au plus `cible` intervalles. 7 → [0, 2, 4, 6, 8] ; 0 → [0, 1].
 */
export function graduations(maximum: number, cible = 4): number[] {
  const max = Number.isFinite(maximum) ? Math.max(0, maximum) : 0;
  if (max === 0) {
    return [0, 1];
  }
  const intervalles = Math.max(1, Math.floor(cible));
  let pas = 1;
  for (let puissance = 1; ; puissance *= 10) {
    const trouve = [1, 2, 5].map((m) => m * puissance).find((p) => Math.ceil(max / p) <= intervalles);
    if (trouve) {
      pas = trouve;
      break;
    }
  }
  return Array.from({ length: Math.ceil(max / pas) + 1 }, (_, i) => i * pas);
}

/** Position d'une valeur sur l'axe, en % du sommet (borné à [0, 100]). */
export function proportion(valeur: number, sommet: number): number {
  if (!sommet || sommet <= 0 || !valeur || valeur <= 0) {
    return 0;
  }
  return Math.min(100, (valeur / sommet) * 100);
}

/** Part entière arrondie, en % ; `null` quand le total est nul. */
export function pourcentage(part: number, total: number): number | null {
  if (!total || total <= 0) {
    return null;
  }
  return Math.round((Math.max(0, part) / total) * 100);
}

/** Somme d'une liste de comptes. */
export function somme(valeurs: readonly number[]): number {
  return valeurs.reduce((total, v) => total + (v || 0), 0);
}

// ── Dates ────────────────────────────────────────────────────────────────

/** Libellé court d'une semaine sous l'axe : son lundi, « 20 juil. ». */
export function libelleSemaine(debut: string): string {
  return formaterDateCourte(debut);
}

/** Étendue d'une semaine : « 20 – 26 juil. », « 28 juil. – 3 août ». */
export function plageSemaine(debut: string): string {
  const lundi = lireDate(debut);
  if (!lundi) {
    return '—';
  }
  const dimanche = new Date(lundi.getFullYear(), lundi.getMonth(), lundi.getDate() + 6);
  if (dimanche.getMonth() === lundi.getMonth()) {
    return `${lundi.getDate()} – ${formaterDateCourte(dimanche)}`;
  }
  return `${formaterDateCourte(lundi)} – ${formaterDateCourte(dimanche)}`;
}

function premierDuMois(mois: string): Date | null {
  return /^\d{4}-\d{2}$/.test(mois) ? lireDate(`${mois}-01`) : null;
}

/** « 2025-11 » → « nov. » (sous l'axe). */
export function libelleMois(mois: string): string {
  const date = premierDuMois(mois);
  return date ? formaterDateCourte(date).replace(/^1 /, '') : mois;
}

/** « 2025-11 » → « novembre 2025 » (infobulle, tableau). */
export function moisLong(mois: string): string {
  const date = premierDuMois(mois);
  return date ? formaterDateLongue(date).replace(/^1 /, '') : mois;
}

/** Année affichée sous un mois : sur le premier de la série et sur chaque janvier. */
export function anneeAAfficher(mois: string, index: number): string | null {
  const date = premierDuMois(mois);
  if (!date) {
    return null;
  }
  return index === 0 || date.getMonth() === 0 ? String(date.getFullYear()) : null;
}

/**
 * Sur un axe trop serré pour tous les libellés, on n'en garde qu'un sur deux,
 * en partant du dernier (la période en cours reste toujours nommée).
 */
export function libelleVisible(index: number, nombre: number, maxLibelles = 8): boolean {
  if (nombre <= maxLibelles) {
    return true;
  }
  return (nombre - 1 - index) % 2 === 0;
}

// ── Parcours d'un signalement ────────────────────────────────────────────

export interface EtapeEntonnoir {
  cle: keyof Entonnoir;
  libelle: string;
  nombre: number;
  /** % de l'étape précédente ; `null` pour la première, ou si la précédente est vide. */
  partPrecedente: number | null;
  /** % des signalements de départ. */
  partInitiale: number | null;
}

const ETAPES: [keyof Entonnoir, string][] = [
  ['signales', 'Signalés'],
  ['aOrienter', 'À orienter'],
  ['orientes', 'Orientés'],
  ['prisEnCharge', 'Pris en charge'],
  ['traites', 'Traités'],
];

export function etapesEntonnoir(entonnoir: Entonnoir | null | undefined): EtapeEntonnoir[] {
  const depart = entonnoir?.signales ?? 0;
  return ETAPES.map(([cle, libelle], i) => {
    const nombre = entonnoir?.[cle] ?? 0;
    const precedent = i === 0 ? null : (entonnoir?.[ETAPES[i - 1][0]] ?? 0);
    return {
      cle,
      libelle,
      nombre,
      partPrecedente: precedent === null ? null : pourcentage(nombre, precedent),
      partInitiale: pourcentage(nombre, depart),
    };
  });
}

// ── Moteur de diagnostic ─────────────────────────────────────────────────

/** « Le moteur a vu juste dans 11 cas sur 14 vérifiés. » */
export function phraseMoteur(moteur: PrecisionMoteur | null | undefined): string {
  const verifies = moteur?.verifies ?? 0;
  if (verifies <= 0) {
    return 'Aucun diagnostic vétérinaire encore saisi';
  }
  const justes = Math.min(verifies, Math.max(0, moteur?.concordants ?? 0));
  return `Le moteur a vu juste dans ${formaterNombre(justes)} cas sur ${formaterNombre(verifies)} ${verifies > 1 ? 'vérifiés' : 'vérifié'}`;
}

/**
 * Parcours d'un graphique au clavier (une seule tabulation par graphique,
 * audit A26) : flèches gauche/droite (et haut/bas), Début, Fin. Rend l'index
 * suivant parmi `possibles`, ou null si la touche ne concerne pas le graphique.
 */
export function indexClavier(cle: string, actuel: number | null, possibles: number[]): number | null {
  if (!possibles.length) {
    return null;
  }
  const rang = actuel === null ? -1 : possibles.indexOf(actuel);
  switch (cle) {
    case 'ArrowRight':
    case 'ArrowDown':
      return possibles[rang < 0 ? 0 : Math.min(rang + 1, possibles.length - 1)];
    case 'ArrowLeft':
    case 'ArrowUp':
      return possibles[rang < 0 ? possibles.length - 1 : Math.max(rang - 1, 0)];
    case 'Home':
      return possibles[0];
    case 'End':
      return possibles[possibles.length - 1];
    default:
      return null;
  }
}
