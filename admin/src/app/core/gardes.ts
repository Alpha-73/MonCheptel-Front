import { inject } from '@angular/core';
import { CanActivateFn, CanDeactivateFn, Router } from '@angular/router';
import { SessionService } from './session.service';

/**
 * Pages de la console : session ouverte, rôle ADMINISTRATEUR, et mot de
 * passe provisoire déjà remplacé.
 */
export const gardeAdministrateur: CanActivateFn = () => {
  const session = inject(SessionService);
  const router = inject(Router);
  const s = session.session();
  if (!s) {
    return router.createUrlTree(['/connexion']);
  }
  if (s.role !== 'ADMINISTRATEUR') {
    session.effacer();
    return router.createUrlTree(['/connexion'], { queryParams: { refuse: 1 } });
  }
  if (s.doitChangerMotDePasse) {
    return router.createUrlTree(['/mot-de-passe']);
  }
  return true;
};

/** Écran de changement de mot de passe imposé : seulement si une session existe. */
export const gardeChangementMotDePasse: CanActivateFn = () => {
  const session = inject(SessionService);
  const router = inject(Router);
  const s = session.session();
  if (!s || s.role !== 'ADMINISTRATEUR') {
    return router.createUrlTree(['/connexion']);
  }
  return true;
};

/** Page de connexion : inutile si l'administrateur est déjà connecté. */
export const gardeInvite: CanActivateFn = () => {
  const session = inject(SessionService);
  const router = inject(Router);
  const s = session.session();
  if (s && s.role === 'ADMINISTRATEUR') {
    return router.createUrlTree([s.doitChangerMotDePasse ? '/mot-de-passe' : '/tableau-de-bord']);
  }
  return true;
};

/** Un écran de saisie qui sait dire s'il porte des modifications non enregistrées. */
export interface AvecSaisie {
  saisieEnCours(): boolean;
}

/** Texte de la confirmation de sortie (A19). */
export const QUESTION_SORTIE = 'Quitter sans enregistrer ? Vos modifications seront perdues.';

/**
 * Garde de sortie des formulaires longs (types d'élevage, maladies,
 * vétérinaires) : un clic dans le menu ne perd plus la saisie sans prévenir.
 */
export const gardeSortieFormulaire: CanDeactivateFn<AvecSaisie> = (ecran) =>
  !ecran?.saisieEnCours?.() || (typeof window !== 'undefined' && window.confirm(QUESTION_SORTIE));
