import { Injectable, inject, signal } from '@angular/core';
import { Subscription } from 'rxjs';
import { ApiService } from './api.service';
import { messageErreur } from './erreurs';
import { TableauDeBordAdmin } from './modeles';

/** Actualisation du pouls de la plateforme, en millisecondes. */
export const PERIODE_POULS_MS = 60_000;

/**
 * Le « pouls » de la plateforme : GET /api/admin/tableau-de-bord, relu toutes
 * les 60 s tant que la console est ouverte. Le menu y lit ses pastilles
 * (cas sans vétérinaire, conseils à modérer, alertes actives) ; le tableau
 * de bord, ses chiffres et son fil « En direct ».
 *
 * `signal` change à chaque nouveau signalement reçu depuis la lecture
 * précédente.
 */
@Injectable({ providedIn: 'root' })
export class PoulsService {
  private readonly api = inject(ApiService);
  readonly donnees = signal<TableauDeBordAdmin | null>(null);
  readonly erreur = signal<string | null>(null);
  readonly enCours = signal(false);
  /** Incrémenté quand un signalement inconnu apparaît. */
  readonly signal = signal(0);
  private abonnement?: Subscription;
  private minuterie?: ReturnType<typeof setInterval>;
  private connus = new Set<number>();

  charger(): void {
    this.abonnement?.unsubscribe();
    this.enCours.set(true);
    this.abonnement = this.api.tableauDeBord().subscribe({
      next: (d) => {
        const ids = d.derniersSignalements.map((s) => s.id);
        if (this.connus.size && ids.some((id) => !this.connus.has(id))) {
          this.signal.update((n) => n + 1);
        }
        this.connus = new Set(ids);
        this.donnees.set(d);
        this.erreur.set(null);
        this.enCours.set(false);
      },
      error: (e) => {
        this.erreur.set(messageErreur(e));
        this.enCours.set(false);
      },
    });
  }

  demarrer(): void {
    if (this.minuterie) return;
    this.charger();
    this.minuterie = setInterval(() => {
      if (typeof document === 'undefined' || document.visibilityState === 'visible') this.charger();
    }, PERIODE_POULS_MS);
  }

  arreter(): void {
    clearInterval(this.minuterie);
    this.minuterie = undefined;
    this.abonnement?.unsubscribe();
  }
}
