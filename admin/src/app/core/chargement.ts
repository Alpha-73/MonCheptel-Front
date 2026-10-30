import { DestroyRef, inject, signal } from '@angular/core';
import { Observable, Subscription } from 'rxjs';
import { messageErreur } from './erreurs';

/**
 * Petit état de chargement partagé par les écrans : données, chargement en
 * cours, message d'erreur du back. `charger()` peut être rappelé (bouton
 * Réessayer, filtres) : la requête précédente est alors abandonnée.
 *
 * À créer dans un contexte d'injection (champ de composant).
 */
export class Chargement<T> {
  readonly donnees = signal<T | null>(null);
  readonly enCours = signal(false);
  readonly erreur = signal<string | null>(null);
  private abonnement?: Subscription;

  constructor(private readonly source: () => Observable<T>) {
    inject(DestroyRef).onDestroy(() => this.abonnement?.unsubscribe());
  }

  charger(): void {
    this.abonnement?.unsubscribe();
    this.enCours.set(true);
    this.erreur.set(null);
    this.abonnement = this.source().subscribe({
      next: (valeur) => {
        this.donnees.set(valeur);
        this.enCours.set(false);
      },
      error: (e) => {
        this.erreur.set(messageErreur(e));
        this.enCours.set(false);
      },
    });
  }
}

/** Raccourci : `chargement(() => this.api.alertes())`. */
export function chargement<T>(source: () => Observable<T>): Chargement<T> {
  return new Chargement(source);
}
