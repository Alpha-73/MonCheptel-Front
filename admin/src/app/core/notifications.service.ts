import { Injectable, inject, signal } from '@angular/core';
import { Subscription } from 'rxjs';
import { ApiService } from './api.service';
import { messageErreur } from './erreurs';
import { NotificationAdmin } from './modeles';

/** Relecture du compte de non-lues, en millisecondes. */
export const PERIODE_NOTIFICATIONS_MS = 30_000;

/**
 * Écran à ouvrir au clic sur une notification, d'après sa référence.
 * `null` : la notification ne mène nulle part dans la console.
 */
export function destination(n: Pick<NotificationAdmin, 'referenceType' | 'referenceId'>): {
  lien: string[];
  parametres?: Record<string, string>;
} | null {
  switch (n.referenceType) {
    case 'MALADIE':
      return n.referenceId != null ? { lien: ['/maladies', String(n.referenceId)] } : { lien: ['/maladies'] };
    case 'ALERTE':
      return n.referenceId != null ? { lien: ['/alertes', String(n.referenceId)] } : { lien: ['/alertes'] };
    case 'SIGNALEMENT':
      // Les cas signalés à l'administration sont ceux qui attendent un vétérinaire.
      return { lien: ['/signalements'], parametres: { vue: 'A_ATTRIBUER' } };
    case 'CONSEIL':
      return { lien: ['/conseils'] };
    default:
      return null;
  }
}

/**
 * Centre de notifications de l'administrateur : maladie ajoutée par un
 * vétérinaire, cas grave sans vétérinaire… (AvisAdministration côté back).
 *
 * Le compte de non-lues est relu toutes les 30 s tant que l'onglet est
 * visible ; la liste n'est chargée qu'à l'ouverture du panneau.
 */
@Injectable({ providedIn: 'root' })
export class NotificationsService {
  private readonly api = inject(ApiService);

  readonly nonLues = signal(0);
  readonly liste = signal<NotificationAdmin[]>([]);
  readonly enCours = signal(false);
  readonly erreur = signal<string | null>(null);
  readonly derniere = signal(true);

  private page = 0;
  private minuterie?: ReturnType<typeof setInterval>;
  private compte?: Subscription;
  private chargement?: Subscription;

  compter(): void {
    this.compte?.unsubscribe();
    this.compte = this.api.notificationsNonLues().subscribe({
      next: (n) => this.nonLues.set(Number(n) || 0),
      // Le compte est secondaire : une panne ne doit pas gêner la console.
      error: () => undefined,
    });
  }

  demarrer(): void {
    if (this.minuterie) return;
    this.compter();
    this.minuterie = setInterval(() => {
      if (typeof document === 'undefined' || document.visibilityState === 'visible') this.compter();
    }, PERIODE_NOTIFICATIONS_MS);
  }

  arreter(): void {
    clearInterval(this.minuterie);
    this.minuterie = undefined;
    this.compte?.unsubscribe();
    this.chargement?.unsubscribe();
  }

  /**
   * Première page, puis tout est marqué lu côté serveur. Les éléments
   * gardent leur état `lue` d'origine dans la liste affichée : l'administrateur
   * voit encore ce qui était nouveau à l'ouverture.
   */
  ouvrir(): void {
    this.page = 0;
    this.charger(false);
  }

  suite(): void {
    if (this.derniere() || this.enCours()) return;
    this.page++;
    this.charger(true);
  }

  private charger(ajouter: boolean): void {
    this.chargement?.unsubscribe();
    this.enCours.set(true);
    this.erreur.set(null);
    this.chargement = this.api.notifications(this.page).subscribe({
      next: (p) => {
        this.liste.set(ajouter ? [...this.liste(), ...p.elements] : p.elements);
        this.derniere.set(p.derniere);
        this.enCours.set(false);
        if (!ajouter && p.elements.some((n) => !n.lue)) {
          this.api.marquerNotificationsLues().subscribe({ next: () => this.nonLues.set(0), error: () => undefined });
        }
      },
      error: (e) => {
        this.erreur.set(messageErreur(e));
        this.enCours.set(false);
      },
    });
  }
}
