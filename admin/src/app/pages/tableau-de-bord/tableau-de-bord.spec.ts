import { describe, expect, it } from 'vitest';
import { TableauDeBordAdmin } from '../../core/modeles';
import { groupeDate, resumeTaches, tachesDuJour } from './tableau-de-bord';

const tdb = (p: Partial<TableauDeBordAdmin>): TableauDeBordAdmin => ({
  utilisateurs: 0, inscritsCeMois: 0, tetesVivantes: 0, tetesVolaille: 0, alertesActives: 0, zonesSousAlerte: [],
  veterinaires: 0, zonesCouvertes: 0, signalements30j: 0, alertes30j: 0, orientesEnAttente: 0, casSansVeterinaire: 0,
  conseilsPublies: 0, conseilsEnModeration: 0, derniersSignalements: [], parFiliere: [], ...p,
});

describe('tableau de bord (A2, A3, A13)', () => {
  it('liste les sujets à traiter, le plus urgent d’abord, avec le bon filtre', () => {
    const t = tachesDuJour(tdb({ casSansVeterinaire: 2, alertesActives: 1, orientesEnAttente: 3, conseilsEnModeration: 1, zonesSousAlerte: ['Kayes'] }));
    expect(t.map((x) => x.texte)).toEqual(['cas graves sans vétérinaire', 'alerte active', 'cas sans réponse', 'conseil à modérer']);
    expect(t[0]).toMatchObject({ urgent: true, lien: '/signalements', params: { vue: 'A_ATTRIBUER' } });
    expect(t[2].params).toEqual({ vue: 'ORIENTES' });
    expect(t[3].params).toEqual({ statut: 'EN_MODERATION' });
    expect(t[1].detail).toBe('Kayes');
  });

  it('compte des sujets, pas la somme des éléments', () => {
    expect(resumeTaches(tachesDuJour(tdb({ casSansVeterinaire: 4, conseilsEnModeration: 12 })))).toBe('2 sujets à traiter, dont 1 urgent');
    expect(resumeTaches(tachesDuJour(tdb({ conseilsEnModeration: 12 })))).toBe('1 sujet à traiter');
    expect(resumeTaches([])).toBe('Tout est calme sur la plateforme');
  });

  it('range le fil par jour', () => {
    const maintenant = new Date(2026, 9, 8, 10);
    expect(groupeDate(new Date(2026, 9, 8, 1), maintenant)).toBe("Aujourd'hui");
    expect(groupeDate(new Date(2026, 9, 7, 23), maintenant)).toBe('Hier');
    expect(groupeDate(new Date(2026, 9, 3), maintenant)).toBe('Cette semaine');
    expect(groupeDate(new Date(2026, 8, 20), maintenant)).toBe('Plus tôt');
  });
});
