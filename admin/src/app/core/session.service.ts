import { HttpBackend, HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Injectable, computed, inject, signal } from '@angular/core';
import { Router } from '@angular/router';
import { Observable, catchError, finalize, map, shareReplay, tap, throwError } from 'rxjs';
import { environment } from '../../environments/environment';
import { JetonReponse, Role } from './modeles';

/** Ce que la console garde de la session, en `sessionStorage`. */
export interface Session {
  jetonAcces: string;
  jetonRafraichissement: string;
  /** Échéance du jeton d'accès, en millisecondes depuis l'époque. */
  expireA: number;
  utilisateurId: number;
  nom: string;
  role: Role;
  email: string;
  doitChangerMotDePasse: boolean;
}

export const CLE_SESSION = 'moncheptel.admin.session';

/** Marge avant l'échéance à partir de laquelle on renouvelle d'avance. */
export const MARGE_RENOUVELLEMENT_MS = 30_000;

/** Message affiché quand le compte connecté n'est pas administrateur. */
export const MESSAGE_ROLE_REFUSE = "Cet espace est réservé à l'administration MonCheptel.";

/**
 * Détient les jetons et sait les renouveler.
 *
 * Le renouvellement passe par `HttpBackend` (sans intercepteur) pour ne pas
 * se rappeler lui-même. Le back fait TOURNER le jeton de rafraîchissement :
 * deux renouvellements simultanés avec le même jeton feraient échouer le
 * second et fermeraient la session. Un seul renouvellement est donc partagé
 * entre toutes les requêtes concurrentes (`shareReplay`).
 */
@Injectable({ providedIn: 'root' })
export class SessionService {
  private readonly http = new HttpClient(inject(HttpBackend));
  private readonly router = inject(Router);

  private readonly etat = signal<Session | null>(lireStockage());
  private renouvellementEnCours: Observable<string> | null = null;

  readonly session = this.etat.asReadonly();
  readonly connecte = computed(() => this.etat() !== null);
  readonly estAdministrateur = computed(() => this.etat()?.role === 'ADMINISTRATEUR');

  get jetonAcces(): string | null {
    return this.etat()?.jetonAcces ?? null;
  }

  /** Vrai si le jeton d'accès expire dans moins de la marge. */
  doitRenouveler(maintenant = Date.now()): boolean {
    const s = this.etat();
    return !!s && s.expireA - maintenant < MARGE_RENOUVELLEMENT_MS;
  }

  /** Enregistre la réponse de connexion ou de renouvellement. */
  enregistrer(reponse: JetonReponse, email?: string): void {
    const precedente = this.etat();
    const session: Session = {
      jetonAcces: reponse.jetonAcces,
      jetonRafraichissement: reponse.jetonRafraichissement,
      expireA: Date.now() + reponse.expireDansSecondes * 1000,
      utilisateurId: reponse.utilisateurId,
      nom: reponse.nom,
      role: reponse.role,
      email: email ?? precedente?.email ?? '',
      doitChangerMotDePasse: reponse.doitChangerMotDePasse,
    };
    this.etat.set(session);
    ecrireStockage(session);
  }

  marquerMotDePasseChange(): void {
    const s = this.etat();
    if (s) {
      const maj = { ...s, doitChangerMotDePasse: false };
      this.etat.set(maj);
      ecrireStockage(maj);
    }
  }

  effacer(): void {
    this.etat.set(null);
    this.renouvellementEnCours = null;
    try {
      sessionStorage.removeItem(CLE_SESSION);
    } catch {
      /* stockage indisponible : rien à effacer */
    }
  }

  /**
   * Renouvelle le jeton d'accès et rend le nouveau. Les appels simultanés
   * reçoivent le MÊME observable : un seul POST /api/auth/rafraichir part.
   * Si le serveur répond 422 (session expirée) ou refuse le jeton, la
   * session est fermée et l'utilisateur renvoyé à la connexion.
   */
  renouveler(): Observable<string> {
    if (this.renouvellementEnCours) {
      return this.renouvellementEnCours;
    }
    const s = this.etat();
    if (!s) {
      return throwError(() => new HttpErrorResponse({ status: 401, statusText: 'Session absente' }));
    }
    this.renouvellementEnCours = this.http
      .post<JetonReponse>(`${environment.apiUrl}/api/auth/rafraichir`, {
        jetonRafraichissement: s.jetonRafraichissement,
      })
      .pipe(
        tap((reponse) => this.enregistrer(reponse)),
        map((reponse) => reponse.jetonAcces),
        catchError((erreur: HttpErrorResponse) => {
          // 0 = réseau coupé : on garde la session, la prochaine requête retentera.
          if (erreur.status !== 0) {
            this.expirer();
          }
          return throwError(() => erreur);
        }),
        finalize(() => (this.renouvellementEnCours = null)),
        shareReplay({ bufferSize: 1, refCount: false }),
      );
    return this.renouvellementEnCours;
  }

  /** Ferme la session côté client et retourne à la connexion. */
  expirer(): void {
    this.effacer();
    void this.router.navigate(['/connexion'], { queryParams: { expiree: 1 } });
  }

  /** Déconnexion volontaire : révoque le jeton côté serveur, sans attendre. */
  deconnecter(): void {
    const s = this.etat();
    if (s) {
      this.revoquer(s.jetonRafraichissement);
    }
    this.effacer();
    void this.router.navigate(['/connexion']);
  }

  /**
   * Révoque un jeton de rafraîchissement côté serveur (sans attendre la
   * réponse). Le contrôleur lit l'en-tête X-Refresh-Token ; le contrat parle
   * d'un corps JSON : on envoie les deux, l'un des deux suffit.
   */
  revoquer(jetonRafraichissement: string): void {
    this.http
      .post(
        `${environment.apiUrl}/api/auth/deconnexion`,
        { jetonRafraichissement },
        { headers: { 'X-Refresh-Token': jetonRafraichissement } },
      )
      .subscribe({ error: () => undefined });
  }
}

function lireStockage(): Session | null {
  try {
    const brut = sessionStorage.getItem(CLE_SESSION);
    if (!brut) {
      return null;
    }
    const session = JSON.parse(brut) as Session;
    return session?.jetonAcces && session?.jetonRafraichissement ? session : null;
  } catch {
    return null;
  }
}

function ecrireStockage(session: Session): void {
  try {
    sessionStorage.setItem(CLE_SESSION, JSON.stringify(session));
  } catch {
    /* navigation privée stricte : la session vit seulement en mémoire */
  }
}
