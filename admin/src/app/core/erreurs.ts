import { HttpErrorResponse } from '@angular/common/http';
import { ErreurReponse } from './modeles';

/**
 * Message lisible à partir d'une erreur HTTP. On affiche en priorité le
 * `message` français du back (ErreurReponse), complété du détail des champs
 * invalides pour une erreur de validation.
 */
export function messageErreur(erreur: unknown, parDefaut = 'Une erreur est survenue.'): string {
  if (!(erreur instanceof HttpErrorResponse)) {
    return erreur instanceof Error && erreur.message ? erreur.message : parDefaut;
  }
  if (erreur.status === 0) {
    return "Impossible de joindre le serveur MonCheptel. Vérifiez qu'il est démarré et votre connexion.";
  }
  const corps = (typeof erreur.error === 'object' ? erreur.error : null) as ErreurReponse | null;
  const champs = corps?.champs ? Object.values(corps.champs).filter(Boolean) : [];
  if (corps?.message) {
    return champs.length ? `${corps.message} : ${champs.join(' ; ')}.` : corps.message;
  }
  if (typeof erreur.error === 'string' && erreur.error.trim() && erreur.error.length < 300) {
    return erreur.error;
  }
  switch (erreur.status) {
    case 403:
      return "Accès refusé : votre session a expiré ou vos droits ne le permettent pas.";
    case 404:
      return 'Élément introuvable.';
    case 422:
      return 'Opération refusée par le serveur.';
    default:
      return erreur.status >= 500 ? `Erreur du serveur (${erreur.status}).` : parDefaut;
  }
}
