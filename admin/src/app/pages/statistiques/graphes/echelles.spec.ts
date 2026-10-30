import {
  anneeAAfficher,
  indexClavier,
  etapesEntonnoir,
  graduations,
  libelleMois,
  libelleSemaine,
  libelleVisible,
  moisLong,
  phraseMoteur,
  plageSemaine,
  pourcentage,
  proportion,
  somme,
} from './echelles';

describe('échelles des graphiques', () => {
  it('gradue un axe de comptes avec des pas ronds', () => {
    expect(graduations(7)).toEqual([0, 2, 4, 6, 8]);
    expect(graduations(3)).toEqual([0, 1, 2, 3]);
    expect(graduations(40)).toEqual([0, 10, 20, 30, 40]);
    expect(graduations(41)).toEqual([0, 20, 40, 60]);
    expect(graduations(1234)).toEqual([0, 500, 1000, 1500]);
    expect(graduations(1)).toEqual([0, 1]);
    expect(graduations(0)).toEqual([0, 1]);
    expect(graduations(-3)).toEqual([0, 1]);
    expect(graduations(Number.NaN)).toEqual([0, 1]);
  });

  it('place une valeur en % du sommet, bornée', () => {
    expect(proportion(5, 10)).toBe(50);
    expect(proportion(12, 10)).toBe(100);
    expect(proportion(0, 10)).toBe(0);
    expect(proportion(3, 0)).toBe(0);
  });

  it('calcule des parts arrondies et des sommes', () => {
    expect(pourcentage(18, 40)).toBe(45);
    expect(pourcentage(2, 3)).toBe(67);
    expect(pourcentage(1, 0)).toBeNull();
    expect(somme([1, 2, 3])).toBe(6);
    expect(somme([])).toBe(0);
  });
});

describe('libellés de dates', () => {
  it('nomme une semaine par son lundi et donne son étendue', () => {
    expect(libelleSemaine('2026-07-20')).toBe('20 juil.');
    expect(plageSemaine('2026-07-20')).toBe('20 – 26 juil.');
    expect(plageSemaine('2026-07-27')).toBe('27 juil. – 2 août');
    expect(plageSemaine('2025-12-29')).toBe('29 déc. – 4 janv.');
    expect(plageSemaine('pas une date')).toBe('—');
  });

  it('nomme les mois, avec l’année au début et à chaque janvier', () => {
    expect(libelleMois('2025-11')).toBe('nov.');
    expect(libelleMois('2026-05')).toBe('mai');
    expect(moisLong('2025-11')).toBe('novembre 2025');
    expect(moisLong('2026-08')).toBe('août 2026');
    expect(libelleMois('n/a')).toBe('n/a');
    expect(anneeAAfficher('2025-11', 0)).toBe('2025');
    expect(anneeAAfficher('2025-12', 1)).toBeNull();
    expect(anneeAAfficher('2026-01', 2)).toBe('2026');
  });

  it('éclaircit un axe trop dense en gardant le dernier libellé', () => {
    const visibles = Array.from({ length: 12 }, (_, i) => libelleVisible(i, 12)).map((v, i) => (v ? i : -1)).filter((i) => i >= 0);
    expect(visibles).toEqual([1, 3, 5, 7, 9, 11]);
    expect(libelleVisible(0, 5)).toBe(true);
  });
});

describe('parcours d’un signalement', () => {
  it('rapporte chaque étape à la précédente et au départ', () => {
    const etapes = etapesEntonnoir({ signales: 40, aOrienter: 18, orientes: 16, prisEnCharge: 12, traites: 9 });
    expect(etapes.map((e) => e.libelle)).toEqual(['Signalés', 'À orienter', 'Orientés', 'Pris en charge', 'Traités']);
    expect(etapes.map((e) => e.partPrecedente)).toEqual([null, 45, 89, 75, 75]);
    expect(etapes.map((e) => e.partInitiale)).toEqual([100, 45, 40, 30, 23]);
  });

  it('reste lisible sans données', () => {
    const etapes = etapesEntonnoir(null);
    expect(etapes.map((e) => e.nombre)).toEqual([0, 0, 0, 0, 0]);
    expect(etapes.map((e) => e.partPrecedente)).toEqual([null, null, null, null, null]);
  });
});

describe('précision du moteur', () => {
  it('résume les diagnostics vérifiés', () => {
    expect(phraseMoteur({ verifies: 14, concordants: 11 })).toBe('Le moteur a vu juste dans 11 cas sur 14 vérifiés');
    expect(phraseMoteur({ verifies: 1, concordants: 1 })).toBe('Le moteur a vu juste dans 1 cas sur 1 vérifié');
    expect(phraseMoteur({ verifies: 0, concordants: 0 })).toBe('Aucun diagnostic vétérinaire encore saisi');
    expect(phraseMoteur(undefined)).toBe('Aucun diagnostic vétérinaire encore saisi');
  });

  it('parcourt un graphique au clavier, en sautant les parts vides (A26)', () => {
    expect(indexClavier('ArrowRight', null, [0, 1, 2])).toBe(0);
    expect(indexClavier('ArrowRight', 0, [0, 1, 2])).toBe(1);
    expect(indexClavier('ArrowRight', 2, [0, 1, 2])).toBe(2);
    expect(indexClavier('ArrowLeft', null, [0, 1, 2])).toBe(2);
    expect(indexClavier('ArrowLeft', 3, [0, 3, 5])).toBe(0);
    expect(indexClavier('End', 0, [0, 3, 5])).toBe(5);
    expect(indexClavier('Home', 5, [0, 3, 5])).toBe(0);
    expect(indexClavier('Tab', 0, [0, 1])).toBeNull();
    expect(indexClavier('ArrowRight', null, [])).toBeNull();
  });
});
