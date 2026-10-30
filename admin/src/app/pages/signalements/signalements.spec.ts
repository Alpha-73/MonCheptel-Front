import { describe, expect, it } from 'vitest';
import {
  CandidatVeterinaire,
  RefusCas,
  SignalementAdmin,
  argumentsCandidat,
  candidatConseille,
  lireVue,
  resumeRefus,
} from './signalements.api';

const candidat = (p: Partial<CandidatVeterinaire>): CandidatVeterinaire => ({
  id: 1, nom: 'Dr Sow', zone: 'Koutiala', competent: false, memeZone: false, disponible: true, casOuverts: 0, actuel: false, ...p,
});

describe('écran Signalements', () => {
  it('lit la vue de l’URL, « Tous » par défaut', () => {
    expect(lireVue('A_ATTRIBUER')).toBe('A_ATTRIBUER');
    expect(lireVue('n’importe quoi')).toBe('TOUS');
    expect(lireVue(null)).toBe('TOUS');
    expect(lireVue('ORIENTES')).toBe('ORIENTES');
  });

  it('conseille le premier vétérinaire disponible qui ne suit pas déjà le cas (A8)', () => {
    const l = [candidat({ id: 1, actuel: true }), candidat({ id: 2, disponible: false }), candidat({ id: 3 })];
    expect(candidatConseille(l)?.id).toBe(3);
    expect(candidatConseille([candidat({ id: 1, actuel: true }), candidat({ id: 2, disponible: false })])?.id).toBe(2);
    expect(candidatConseille([candidat({ actuel: true })])).toBeNull();
  });

  it('ne conseille pas un vétérinaire qui a déjà refusé le cas (V14)', () => {
    const l = [candidat({ id: 1, aRefuse: true }), candidat({ id: 2 })];
    expect(candidatConseille(l)?.id).toBe(2);
    expect(argumentsCandidat(candidat({ aRefuse: true }))).toBe('Koutiala · aucun cas en cours · a déjà refusé ce cas');
  });

  it('résume le dernier refus d’un cas (V14)', () => {
    const s = (refus: RefusCas[]) => ({ refus }) as unknown as SignalementAdmin;
    expect(resumeRefus(s([]))).toBeNull();
    expect(resumeRefus(s([{ veterinaireNom: 'Dr Sow', motif: 'En déplacement', dateRefus: '2026-10-29T10:00:00Z' }]))).toBe(
      'Refusé par Dr Sow (En déplacement)',
    );
    expect(
      resumeRefus(s([
        { veterinaireNom: 'Dr Sow', dateRefus: '2026-10-29T10:00:00Z' },
        { veterinaireNom: 'Dr Diarra', dateRefus: '2026-10-29T08:00:00Z' },
      ])),
    ).toBe('Refusé par Dr Sow et 1 autre');
  });

  it('résume pourquoi un vétérinaire est proposé', () => {
    expect(argumentsCandidat(candidat({ competent: true, memeZone: true, casOuverts: 2 }))).toBe(
      'compétent pour cette maladie · même zone · 2 cas en cours',
    );
    expect(argumentsCandidat(candidat({ casOuverts: 1, disponible: false }))).toBe('Koutiala · 1 cas en cours · indisponible');
    expect(argumentsCandidat(candidat({ zone: null }))).toBe('zone inconnue · aucun cas en cours');
  });
});
