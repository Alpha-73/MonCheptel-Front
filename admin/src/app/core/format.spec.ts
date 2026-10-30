import {
  accentuer,
  couleurGravite,
  depuis,
  desEleveursConcernes,
  formaterJour,
  formaterDateCourte,
  formaterDateLongue,
  formaterNombre,
  initiales,
  libelle,
  libellesFilieres,
  lireDate,
  pluriel,
} from './format';

const ESP = ' ';

describe('formaterNombre', () => {
  it('sépare les milliers par une espace insécable', () => {
    expect(formaterNombre(1248)).toBe(`1${ESP}248`);
    expect(formaterNombre(34720)).toBe(`34${ESP}720`);
    expect(formaterNombre(1234567)).toBe(`1${ESP}234${ESP}567`);
  });
  it('laisse les petits nombres intacts', () => {
    expect(formaterNombre(0)).toBe('0');
    expect(formaterNombre(742)).toBe('742');
  });
  it('gère les négatifs et la virgule décimale', () => {
    expect(formaterNombre(-1500)).toBe(`-1${ESP}500`);
    expect(formaterNombre(1.5, 1)).toBe('1,5');
    expect(formaterNombre(6, 1)).toBe('6');
  });
  it('rend un tiret pour une valeur absente', () => {
    expect(formaterNombre(null)).toBe('—');
    expect(formaterNombre(undefined)).toBe('—');
    expect(formaterNombre(Number.NaN)).toBe('—');
  });
});

describe('dates', () => {
  it('formate « 18 sept. » à partir d’un Instant', () => {
    expect(formaterDateCourte('2026-09-18T12:00:00Z')).toBe('18 sept.');
    expect(formaterDateCourte('2026-08-28T12:00:00Z')).toBe('28 août');
    expect(formaterDateCourte('2026-03-05T12:00:00Z')).toBe('5 mars');
  });
  it('lit une LocalDate comme une date civile, sans décalage de fuseau', () => {
    const d = lireDate('2026-08-03')!;
    expect([d.getFullYear(), d.getMonth(), d.getDate()]).toEqual([2026, 7, 3]);
    expect(formaterDateLongue('2026-08-03')).toBe('3 août 2026');
  });
  it('formate sans l’année sur demande', () => {
    expect(formaterDateLongue('2026-09-18T12:00:00Z', false)).toBe('18 septembre');
  });
  it('rend un tiret pour une date absente ou invalide', () => {
    expect(formaterDateCourte(undefined)).toBe('—');
    expect(formaterDateCourte('pas une date')).toBe('—');
  });
});

describe('libellés des énumérations', () => {
  it('traduit les codes en français', () => {
    expect(libelle('filiere', 'VOLAILLE')).toBe('Volaille');
    expect(libelle('gravite', 'ELEVE')).toBe('Élevé');
    expect(libelle('statutConseil', 'EN_MODERATION')).toBe('En modération');
    expect(libelle('statutAlerte', 'TERMINEE')).toBe('Terminée');
    expect(libelle('langue', 'BM')).toBe('Bambara');
  });
  it('rend le code tel quel s’il est inconnu, un tiret s’il est absent', () => {
    expect(libelle('filiere', 'PORCINS')).toBe('PORCINS');
    expect(libelle('filiere', null)).toBe('—');
  });
  it('liste les filières dans l’ordre canonique', () => {
    expect(libellesFilieres(['CAPRINS', 'VOLAILLE', 'OVINS'])).toBe('Volaille, Ovins, Caprins');
    expect(libellesFilieres([])).toBe('—');
  });
  it('rétablit les accents des rôles renvoyés par le serveur', () => {
    expect(accentuer('Eleveurs')).toBe('Éleveurs');
    expect(accentuer('Veterinaires')).toBe('Vétérinaires');
    expect(accentuer('Administrateurs')).toBe('Administrateurs');
  });
});

describe('petits utilitaires', () => {
  it('accorde le pluriel', () => {
    expect(pluriel(0, 'vétérinaire')).toBe('0 vétérinaire');
    expect(pluriel(1, 'vétérinaire')).toBe('1 vétérinaire');
    expect(pluriel(3, 'vétérinaire')).toBe('3 vétérinaires');
    expect(pluriel(1248, 'éleveur')).toBe(`1${ESP}248 éleveurs`);
  });
  it('calcule les initiales', () => {
    expect(initiales('Mamadou Traoré')).toBe('MT');
    expect(initiales('Dr Aïssata Traoré')).toBe('AT');
    expect(initiales('Administrateur')).toBe('AD');
    // Les nombres ne font pas d'initiales : « CJ », pas « C1 ».
    expect(initiales('Compte Jetable 1007120509')).toBe('CJ');
    expect(initiales('1234')).toBe('?');
    expect(initiales('')).toBe('?');
  });
  it('accorde « des éleveurs concernés »', () => {
    expect(desEleveursConcernes(742)).toBe('des 742 éleveurs concernés');
    expect(desEleveursConcernes(1)).toBe("de l'éleveur concerné");
    expect(desEleveursConcernes(0)).toBe("d'aucun éleveur");
  });
  it('colore la gravité comme la maquette', () => {
    expect(couleurGravite('ELEVE')).toBe('rouge');
    expect(couleurGravite('MOYEN')).toBe('orange');
    expect(couleurGravite('FAIBLE')).toBe('vert');
  });
});

describe('depuis et formaterJour', () => {
  const maintenant = new Date(2026, 9, 7, 12, 0, 0);
  it('rend une ancienneté lisible', () => {
    expect(depuis(new Date(2026, 9, 7, 11, 59, 40), maintenant)).toBe('à l’instant');
    expect(depuis(new Date(2026, 9, 7, 11, 48), maintenant)).toBe('il y a 12 min');
    expect(depuis(new Date(2026, 9, 7, 9, 0), maintenant)).toBe('il y a 3 h');
    expect(depuis(new Date(2026, 9, 5, 12, 0), maintenant)).toBe('il y a 2 j');
    expect(depuis(new Date(2026, 8, 18, 12, 0), maintenant)).toBe('18 sept.');
  });
  it('écrit le jour en toutes lettres', () => {
    expect(formaterJour(maintenant)).toBe('Mercredi 7 octobre 2026');
  });
});
