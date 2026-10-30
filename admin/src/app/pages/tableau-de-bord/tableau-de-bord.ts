import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { RouterLink } from '@angular/router';
import { catchError, map, of } from 'rxjs';
import { ApiService } from '../../core/api.service';
import { couleurGravite, depuis, formaterJour, lireDate, libelleGravite, pluriel } from '../../core/format';
import { TableauDeBordAdmin } from '../../core/modeles';
import { PoulsService } from '../../core/pouls.service';
import { SessionService } from '../../core/session.service';
import { Compteur } from '../../shared/compteur';
import { Icone } from '../../shared/icone';
import { NombrePipe } from '../../shared/pipes';
import { EnTete, Etat } from '../../shared/ui';
import { StatistiquesApi } from '../statistiques/statistiques.api';

/** Une ligne de la colonne « À traiter » : une phrase et son action directe. */
export interface Tache {
  nombre: number;
  texte: string;
  detail: string;
  action: string;
  lien: string;
  params?: Record<string, string>;
  icone: string;
  urgent: boolean;
  ton: 'rouge' | 'orange' | 'vert';
}

/** Une entrée du fil « En direct ». */
export interface Evenement {
  cle: string;
  date: Date;
  titre: string;
  detail: string;
  ton: string;
  etiquette: string;
  lien: unknown[];
  params?: Record<string, string>;
}

/** Ce qui attend l'administration, du plus urgent au moins urgent (A2, A4). */
export function tachesDuJour(d: TableauDeBordAdmin): Tache[] {
  const t: Tache[] = [];
  if (d.casSansVeterinaire > 0) {
    t.push({
      nombre: d.casSansVeterinaire, texte: d.casSansVeterinaire > 1 ? 'cas graves sans vétérinaire' : 'cas grave sans vétérinaire',
      detail: 'Personne ne couvre leur zone', action: 'Attribuer', lien: '/signalements', params: { vue: 'A_ATTRIBUER' },
      icone: 'triangle', urgent: true, ton: 'rouge',
    });
  }
  if (d.alertesActives > 0) {
    t.push({
      nombre: d.alertesActives, texte: d.alertesActives > 1 ? 'alertes actives' : 'alerte active',
      detail: d.zonesSousAlerte.join(', ') || 'Zones sous surveillance', action: 'Suivre', lien: '/alertes',
      icone: 'diffusion', urgent: false, ton: 'orange',
    });
  }
  if (d.orientesEnAttente > 0) {
    t.push({
      nombre: d.orientesEnAttente, texte: 'cas sans réponse',
      detail: 'Confiés, le vétérinaire n’a pas encore répondu', action: 'Voir', lien: '/signalements', params: { vue: 'ORIENTES' },
      icone: 'orientation', urgent: false, ton: 'orange',
    });
  }
  if (d.conseilsEnModeration > 0) {
    t.push({
      nombre: d.conseilsEnModeration, texte: d.conseilsEnModeration > 1 ? 'conseils à modérer' : 'conseil à modérer',
      detail: 'Rédigés par les vétérinaires', action: 'Relire', lien: '/conseils', params: { statut: 'EN_MODERATION' },
      icone: 'document', urgent: false, ton: 'vert',
    });
  }
  return t;
}

/** Bandeau : le nombre de SUJETS, pas la somme d'alertes, de cas et de conseils (A3). */
export function resumeTaches(t: Tache[]): string {
  if (!t.length) return 'Tout est calme sur la plateforme';
  const urgents = t.filter((x) => x.urgent).length;
  const sujets = t.length > 1 ? `${t.length} sujets à traiter` : '1 sujet à traiter';
  return urgents ? `${sujets}, dont ${urgents} urgent${urgents > 1 ? 's' : ''}` : sujets;
}

/** « Aujourd'hui », « Hier », « Cette semaine », « Plus tôt ». */
export function groupeDate(date: Date, maintenant = new Date()): string {
  const jour = (x: Date) => new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime();
  const ecart = Math.round((jour(maintenant) - jour(date)) / 86_400_000);
  return ecart <= 0 ? "Aujourd'hui" : ecart === 1 ? 'Hier' : ecart < 7 ? 'Cette semaine' : 'Plus tôt';
}

/**
 * Écran « Tableau de bord ». Se lit en trois secondes : l'en-tête dit s'il y a
 * quelque chose à faire et porte les trois chiffres qui bougent ; dessous, à
 * gauche ce qui attend une action, à droite ce qui vient de se passer.
 * Les compteurs statiques (éleveurs, têtes, conseils publiés) sont dans
 * Statistiques.
 */
@Component({
  selector: 'app-tableau-de-bord',
  imports: [RouterLink, EnTete, Etat, Icone, Compteur, NombrePipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './tableau-de-bord.html',
  styleUrl: './tableau-de-bord.scss',
})
export class TableauDeBord {
  private readonly api = inject(ApiService);
  private readonly session = inject(SessionService);
  protected readonly pouls = inject(PoulsService);
  protected readonly depuis = depuis;
  protected readonly pluriel = pluriel;

  protected readonly surtitre = computed(
    () => `Bonjour ${(this.session.session()?.nom || 'Administrateur').split(' ')[0]} · ${formaterJour(new Date())}`,
  );

  private readonly semaines = toSignal(
    inject(StatistiquesApi).series().pipe(map((s) => s.semaines.map((x) => x.faible + x.moyen + x.eleve)), catchError(() => of(null))),
    { initialValue: null },
  );
  private readonly alertes = toSignal(this.api.alertes().pipe(catchError(() => of([]))), { initialValue: [] });

  protected readonly taches = computed(() => {
    const d = this.pouls.donnees();
    return d ? tachesDuJour(d) : [];
  });
  protected readonly resume = computed(() => (this.pouls.donnees() ? resumeTaches(this.taches()) : 'Tableau de bord'));

  /** Signalements de la semaine en cours, et la courbe des 12 dernières. */
  protected readonly semaine = computed(() => {
    const s = this.semaines();
    return s && s.length ? s[s.length - 1] : null;
  });
  protected readonly courbe = computed(() => {
    const s = this.semaines();
    if (!s || s.length < 2) return null;
    const max = Math.max(1, ...s);
    const pts = s.map((v, i) => [(i / (s.length - 1)) * 100, 30 - (v / max) * 26 - 2]);
    const ligne = pts.map(([x, y], i) => `${i ? 'L' : 'M'}${x.toFixed(1)} ${y.toFixed(1)}`).join(' ');
    return { ligne, aire: `${ligne} L100 32 L0 32 Z`, dernier: pts[pts.length - 1] };
  });

  /** Fil « En direct » : signalements et alertes, groupés par jour. */
  protected readonly fil = computed(() => {
    const d = this.pouls.donnees();
    const ev: Evenement[] = [];
    for (const s of d?.derniersSignalements ?? []) {
      const date = lireDate(s.dateSignalement);
      if (!date) continue;
      ev.push({
        cle: 's' + s.id, date, titre: s.maladie ?? 'Maladie non identifiée', detail: `${s.eleveurNom} · ${s.zone ?? 'zone inconnue'}`,
        ton: couleurGravite(s.gravite), etiquette: s.gravite ? libelleGravite(s.gravite) : 'Signalement',
        lien: ['/signalements'],
      });
    }
    // Les alertes actives, et les autres seulement si elles ont moins de deux jours.
    const recent = Date.now() - 2 * 86_400_000;
    for (const a of this.alertes().filter((x) => x.statut === 'ACTIVE' || (lireDate(x.dateDeclenchement)?.getTime() ?? 0) > recent).slice(0, 4)) {
      const date = lireDate(a.dateDeclenchement);
      if (!date) continue;
      ev.push({
        cle: 'a' + a.id, date, titre: `Alerte ${a.maladie}`, detail: `${a.zone} · ${pluriel(a.portee, 'éleveur prévenu', 'éleveurs prévenus')}`,
        ton: a.statut === 'ACTIVE' ? 'alerte' : 'gris', etiquette: a.statut === 'ACTIVE' ? 'Alerte active' : 'Alerte terminée',
        lien: ['/alertes', a.id],
      });
    }
    ev.sort((x, y) => y.date.getTime() - x.date.getTime());
    const groupes: { titre: string; evenements: Evenement[] }[] = [];
    for (const e of ev.slice(0, 9)) {
      const titre = groupeDate(e.date);
      const g = groupes.find((x) => x.titre === titre);
      if (g) g.evenements.push(e);
      else groupes.push({ titre, evenements: [e] });
    }
    return groupes;
  });

  constructor() {
    if (!this.pouls.donnees()) this.pouls.charger();
  }
}
