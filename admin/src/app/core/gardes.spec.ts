import { afterEach, describe, expect, it, vi } from 'vitest';
import { ActivatedRouteSnapshot, RouterStateSnapshot } from '@angular/router';
import { AvecSaisie, QUESTION_SORTIE, gardeSortieFormulaire } from './gardes';

const appeler = (ecran: AvecSaisie) =>
  gardeSortieFormulaire(ecran, {} as ActivatedRouteSnapshot, {} as RouterStateSnapshot, {} as RouterStateSnapshot);

describe('garde de sortie d’un formulaire (A19)', () => {
  afterEach(() => vi.restoreAllMocks());

  it('laisse partir sans question quand rien n’est saisi', () => {
    const confirmer = vi.spyOn(window, 'confirm');
    expect(appeler({ saisieEnCours: () => false })).toBe(true);
    expect(confirmer).not.toHaveBeenCalled();
  });

  it('demande confirmation quand une saisie est en cours', () => {
    const confirmer = vi.spyOn(window, 'confirm').mockReturnValue(false);
    expect(appeler({ saisieEnCours: () => true })).toBe(false);
    expect(confirmer).toHaveBeenCalledWith(QUESTION_SORTIE);
    confirmer.mockReturnValue(true);
    expect(appeler({ saisieEnCours: () => true })).toBe(true);
  });
});
