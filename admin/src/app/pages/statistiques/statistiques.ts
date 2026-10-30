import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { ApiService } from '../../core/api.service';
import { chargement } from '../../core/chargement';
import { accentuer, formaterNombre, pluriel } from '../../core/format';
import { LigneStatistique, NiveauGravite } from '../../core/modeles';
import { Compteur } from '../../shared/compteur';
import { Icone } from '../../shared/icone';
import { NombrePipe } from '../../shared/pipes';
import { EnTete, Etat } from '../../shared/ui';
import { Barres, LigneBarre } from './graphes/barres';
import { CarteGraphe } from './graphes/carte-graphe';
import { CategorieColonne, Colonnes } from './graphes/colonnes';
import {
  SerieGraphe,
  anneeAAfficher,
  etapesEntonnoir,
  libelleMois,
  libelleSemaine,
  moisLong,
  phraseMoteur,
  plageSemaine,
  somme,
} from './graphes/echelles';
import { PartRepartition, Repartition } from './graphes/repartition';
import { StatistiquesApi } from './statistiques.api';

/** Nombre de zones détaillées avant de regrouper le reste en « Autres ». */
export const ZONES_DETAILLEES = 5;

/** Garde les n premières lignes et somme les suivantes dans « Autres ». */
export function regrouperAutres(lignes: LigneStatistique[], n = ZONES_DETAILLEES): LigneStatistique[] {
  const triees = [...lignes].sort((a, b) => b.valeur - a.valeur);
  if (triees.length <= n + 1) {
    return triees;
  }
  const autres = triees.slice(n).reduce((total, l) => total + l.valeur, 0);
  return [...triees.slice(0, n), { libelle: 'Autres', valeur: autres }];
}

/** « 6 h », « 1,5 h », « 45 min » ; « — » sans donnée. */
export function formaterDelai(heures: number | null | undefined): string {
  if (heures === null || heures === undefined || Number.isNaN(heures)) {
    return '—';
  }
  if (heures < 1) {
    return `${Math.round(heures * 60)} min`;
  }
  return `${formaterNombre(heures, heures < 10 ? 1 : 0)} h`;
}

// Couleurs des graphiques : jetons définis dans statistiques.scss (palette
// validée, voir l'en-tête de ce fichier de styles).
const C = {
  serie1: 'var(--g-serie-1)',
  serie2: 'var(--g-serie-2)',
  attenue: 'var(--g-attenue)',
  propose: 'var(--g-propose)',
  gravite: { FAIBLE: 'var(--g-gravite-1)', MOYEN: 'var(--g-gravite-2)', ELEVE: 'var(--g-gravite-3)' } as Record<NiveauGravite, string>,
  etapes: [1, 2, 3, 4, 5].map((i) => `var(--g-etape-${i})`),
  delais: [1, 2, 3, 4, 5].map((i) => `var(--g-delai-${i})`),
};

const GRAVITE_FEMININ: Record<NiveauGravite, string> = { FAIBLE: 'faible', MOYEN: 'moyenne', ELEVE: 'élevée' };

/**
 * Écran « Admin - Statistiques ».
 * - GET /api/admin/statistiques : chiffres clés, éleveurs par zone, comptes par rôle ;
 * - GET /api/admin/statistiques/series : séries des graphiques. Son échec
 *   n'empêche pas d'afficher le reste de l'écran.
 */
@Component({
  selector: 'app-statistiques',
  imports: [EnTete, Etat, Icone, NombrePipe, Compteur, CarteGraphe, Colonnes, Barres, Repartition],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './statistiques.html',
  styleUrl: './statistiques.scss',
})
export class Statistiques {
  private readonly api = inject(ApiService);
  private readonly apiStats = inject(StatistiquesApi);

  protected readonly stats = chargement(() => this.api.statistiques());
  protected readonly series = chargement(() => this.apiStats.series());
  protected readonly formaterDelai = formaterDelai;
  protected readonly accentuer = accentuer;

  // ── Signalements par semaine, empilés par gravité ───────────────────────

  /** De bas en haut : le plus grave contre la ligne de base. */
  protected readonly seriesGravite: SerieGraphe[] = [
    { libelle: 'Élevée', couleur: C.gravite.ELEVE },
    { libelle: 'Moyenne', couleur: C.gravite.MOYEN },
    { libelle: 'Faible', couleur: C.gravite.FAIBLE },
  ];
  private readonly semaines = computed(() => this.series.donnees()?.semaines ?? []);
  protected readonly categoriesSemaines = computed<CategorieColonne[]>(() =>
    this.semaines().map((s) => ({ libelle: libelleSemaine(s.debut), titre: `Semaine du ${plageSemaine(s.debut)}` })),
  );
  protected readonly valeursSemaines = computed(() => this.semaines().map((s) => [s.eleve, s.moyen, s.faible]));
  protected readonly totalSemaines = computed(() => somme(this.valeursSemaines().flat()));
  protected readonly resumeSemaines = computed(() => {
    const s = this.semaines();
    if (!s.length) {
      return '';
    }
    const totaux = this.valeursSemaines().map(somme);
    const pic = totaux.indexOf(Math.max(...totaux));
    const graves = somme(s.map((x) => x.eleve));
    return (
      `Signalements par semaine sur ${s.length} semaines : ${pluriel(this.totalSemaines(), 'signalement')}, ` +
      `dont ${formaterNombre(graves)} de gravité élevée. Semaine la plus chargée : ${plageSemaine(s[pic].debut)}, ` +
      `${formaterNombre(totaux[pic])}. Dernière semaine : ${formaterNombre(totaux[totaux.length - 1])}.`
    );
  });

  // ── Inscriptions par mois ──────────────────────────────────────────────

  protected readonly seriesInscriptions: SerieGraphe[] = [
    { libelle: 'Éleveurs', couleur: C.serie1 },
    { libelle: 'Vétérinaires', couleur: C.serie2 },
  ];
  private readonly inscriptions = computed(() => this.series.donnees()?.inscriptions ?? []);
  protected readonly categoriesMois = computed<CategorieColonne[]>(() =>
    this.inscriptions().map((m, i) => ({ libelle: libelleMois(m.mois), sousLibelle: anneeAAfficher(m.mois, i), titre: moisLong(m.mois) })),
  );
  protected readonly valeursMois = computed(() => this.inscriptions().map((m) => [m.eleveurs, m.veterinaires]));
  protected readonly totalInscriptions = computed(() => somme(this.valeursMois().flat()));
  protected readonly resumeInscriptions = computed(() => {
    const m = this.inscriptions();
    if (!m.length) {
      return '';
    }
    const eleveurs = somme(m.map((x) => x.eleveurs));
    const veterinaires = somme(m.map((x) => x.veterinaires));
    const dernier = m[m.length - 1];
    return (
      `Inscriptions par mois sur ${m.length} mois : ${pluriel(eleveurs, 'éleveur')} et ${pluriel(veterinaires, 'vétérinaire')}. ` +
      `${moisLong(dernier.mois)} : ${formaterNombre(dernier.eleveurs + dernier.veterinaires)}.`
    );
  });

  // ── Parcours d'un signalement (30 j) ───────────────────────────────────

  protected readonly etapes = computed(() => etapesEntonnoir(this.series.donnees()?.entonnoir));
  protected readonly lignesEntonnoir = computed<LigneBarre[]>(() =>
    this.etapes().map((e, i) => ({
      libelle: e.libelle,
      valeurs: [e.nombre],
      couleur: C.etapes[i],
      detail: e.partPrecedente === null ? null : `${e.partPrecedente} %`,
      explication:
        e.partPrecedente === null
          ? 'Point de départ'
          : `${e.partPrecedente} % de l'étape précédente · ${e.partInitiale ?? 0} % des signalés`,
    })),
  );
  protected readonly seriesEntonnoir: SerieGraphe[] = [{ libelle: 'Signalements', couleur: C.etapes[0] }];
  protected readonly resumeEntonnoir = computed(() => {
    const e = this.etapes();
    return (
      `Parcours des signalements des 30 derniers jours : ` +
      e.map((x) => `${x.libelle.toLowerCase()} ${formaterNombre(x.nombre)}${x.partPrecedente === null ? '' : ` (${x.partPrecedente} %)`}`).join(', ') +
      '.'
    );
  });

  // ── Délai de prise en charge (90 j) ────────────────────────────────────

  private readonly delais = computed(() => this.series.donnees()?.delais ?? []);
  protected readonly categoriesDelais = computed<CategorieColonne[]>(() =>
    this.delais().map((d) => ({ libelle: d.tranche, titre: `Pris en charge en ${d.tranche}` })),
  );
  protected readonly valeursDelais = computed(() => this.delais().map((d) => [d.nombre]));
  protected readonly couleursDelais = computed(() => this.delais().map((_, i) => C.delais[Math.min(i, C.delais.length - 1)]));
  protected readonly seriesDelais: SerieGraphe[] = [{ libelle: 'Signalements', couleur: C.delais[0] }];
  protected readonly totalDelais = computed(() => somme(this.delais().map((d) => d.nombre)));
  protected readonly sousTitreDelais = computed(() => {
    const moyenne = this.stats.donnees()?.delaiMoyenPriseEnChargeHeures;
    const base = 'Du signalement à la prise en charge · 90 j';
    return moyenne === null || moyenne === undefined ? base : `${base} · moyenne sur 30 j : ${formaterDelai(moyenne)}`;
  });
  protected readonly resumeDelais = computed(
    () =>
      `Délai de prise en charge, ${pluriel(this.totalDelais(), 'signalement')} sur 90 jours : ` +
      this.delais().map((d) => `${d.tranche} : ${formaterNombre(d.nombre)}`).join(', ') +
      '.',
  );

  // ── Maladies les plus signalées (90 j) ─────────────────────────────────

  protected readonly seriesMaladies: SerieGraphe[] = [
    { libelle: 'Confirmé par un vétérinaire', couleur: C.serie1 },
    { libelle: 'Proposé par le moteur', couleur: C.propose },
  ];
  protected readonly lignesMaladies = computed<LigneBarre[]>(() =>
    (this.series.donnees()?.maladies ?? [])
      .filter((m) => m.confirmes + m.proposes > 0)
      .map((m) => ({
        libelle: m.maladie,
        repere: { couleur: C.gravite[m.gravite] ?? C.attenue, texte: `Gravité ${GRAVITE_FEMININ[m.gravite] ?? '—'}` },
        valeurs: [m.confirmes, m.proposes],
      })),
  );
  protected readonly phraseMoteur = computed(() => phraseMoteur(this.series.donnees()?.moteur));
  protected readonly moteurVerifie = computed(() => (this.series.donnees()?.moteur?.verifies ?? 0) > 0);
  protected readonly resumeMaladies = computed(
    () =>
      `Maladies les plus signalées sur 90 jours : ` +
      this.lignesMaladies()
        .map((l) => `${l.libelle} ${formaterNombre(somme(l.valeurs))} (${formaterNombre(l.valeurs[0])} confirmés)`)
        .join(', ') +
      `. ${this.phraseMoteur()}.`,
  );

  // ── Rôles et zones (GET /statistiques) ─────────────────────────────────

  protected readonly parts = computed<PartRepartition[]>(() =>
    (this.stats.donnees()?.parRole ?? []).map((l) => {
      const libelle = accentuer(l.libelle);
      const couleur = /^[ÉE]leveur/i.test(libelle) ? C.serie1 : /^V[ée]t[ée]rinaire/i.test(libelle) ? C.serie2 : C.attenue;
      return { libelle, valeur: l.valeur, couleur };
    }),
  );
  protected readonly totalRoles = computed(() => somme(this.parts().map((p) => p.valeur)));
  protected readonly resumeRoles = computed(
    () => `Comptes par rôle : ${this.parts().map((p) => `${p.libelle} ${formaterNombre(p.valeur)}`).join(', ')}.`,
  );

  protected readonly seriesZones: SerieGraphe[] = [{ libelle: 'Éleveurs', couleur: C.serie1 }];
  protected readonly lignesZones = computed<LigneBarre[]>(() =>
    regrouperAutres(this.stats.donnees()?.parZone ?? []).map((l) => ({
      libelle: l.libelle,
      valeurs: [l.valeur],
      couleur: l.libelle === 'Autres' ? C.attenue : null,
    })),
  );
  protected readonly resumeZones = computed(
    () => `Éleveurs par zone : ${this.lignesZones().map((l) => `${l.libelle} ${formaterNombre(l.valeurs[0])}`).join(', ')}.`,
  );

  constructor() {
    this.stats.charger();
    this.series.charger();
  }

  protected recharger(): void {
    this.stats.charger();
    this.series.charger();
  }
}
