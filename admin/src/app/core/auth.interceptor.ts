import { HttpErrorResponse, HttpEvent, HttpInterceptorFn, HttpRequest } from '@angular/common/http';
import { inject } from '@angular/core';
import { Observable, catchError, of, switchMap, throwError } from 'rxjs';
import { environment } from '../../environments/environment';
import { SessionService } from './session.service';

/** Routes d'authentification qui ne portent jamais de jeton. */
const ROUTES_PUBLIQUES = ['/api/auth/connexion', '/api/auth/rafraichir'];

function avecJeton(requete: HttpRequest<unknown>, jeton: string): HttpRequest<unknown> {
  return requete.clone({ setHeaders: { Authorization: `Bearer ${jeton}` } });
}

function estRequeteApi(url: string): boolean {
  const base = environment.apiUrl;
  return url.startsWith(`${base}/api/`) || (!base && url.startsWith('/api/'));
}

/**
 * Intercepteur unique de la console :
 * 1. ajoute `Authorization: Bearer <jeton>` aux appels de l'API ;
 * 2. renouvelle le jeton AVANT son expiration (marge de 30 s) ;
 * 3. sur un 401 (jeton expiré ou révoqué côté serveur), renouvelle une fois
 *    puis rejoue la requête ; un second 401 remonte. Un 403 est un vrai refus
 *    (droits) : il remonte sans renouvellement.
 * Le renouvellement est partagé entre requêtes concurrentes (voir
 * SessionService.renouveler) ; un 422 au renouvellement renvoie à la connexion.
 */
export const authInterceptor: HttpInterceptorFn = (requete, suivant) => {
  if (!estRequeteApi(requete.url) || ROUTES_PUBLIQUES.some((r) => requete.url.includes(r))) {
    return suivant(requete);
  }
  const session = inject(SessionService);
  if (!session.jetonAcces) {
    return suivant(requete);
  }

  // Jeton réellement porté par la requête : sert à savoir, sur un 401, si
  // une autre requête a déjà renouvelé la session entre-temps.
  let jetonUtilise = session.jetonAcces;
  const envoyer = (jeton: string) => {
    jetonUtilise = jeton;
    return suivant(avecJeton(requete, jeton));
  };

  const premierEnvoi: Observable<HttpEvent<unknown>> = session.doitRenouveler()
    ? session.renouveler().pipe(switchMap(envoyer))
    : envoyer(session.jetonAcces);

  return premierEnvoi.pipe(
    catchError((erreur: unknown) => {
      if (!(erreur instanceof HttpErrorResponse) || erreur.status !== 401 || !session.jetonAcces) {
        return throwError(() => erreur);
      }
      // Si le jeton a déjà changé (renouvelé par une requête concurrente), on
      // rejoue avec le nouveau SANS renouveler : le jeton de rafraîchissement
      // est à usage unique. Sinon, un seul renouvellement partagé.
      const courant = session.jetonAcces;
      const jeton$ = courant !== jetonUtilise ? of(courant) : session.renouveler();
      // Le rejeu n'est pas re-intercepté : un second 401 remonte.
      return jeton$.pipe(switchMap((jeton) => suivant(avecJeton(requete, jeton))));
    }),
  );
};
