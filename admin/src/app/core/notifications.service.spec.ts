import { destination } from './notifications.service';

describe('destination d’une notification', () => {
  it('ouvre la fiche de la maladie ajoutée par un vétérinaire', () => {
    expect(destination({ referenceType: 'MALADIE', referenceId: 42 })).toEqual({ lien: ['/maladies', '42'] });
  });

  it('ouvre les cas à attribuer pour un cas grave sans vétérinaire', () => {
    expect(destination({ referenceType: 'SIGNALEMENT', referenceId: 7 })).toEqual({
      lien: ['/signalements'],
      parametres: { vue: 'A_ATTRIBUER' },
    });
  });

  it('ouvre l’alerte concernée', () => {
    expect(destination({ referenceType: 'ALERTE', referenceId: 3 })).toEqual({ lien: ['/alertes', '3'] });
  });

  it('ne mène nulle part sans référence connue', () => {
    expect(destination({ referenceType: null, referenceId: null })).toBeNull();
    expect(destination({ referenceType: 'UNITE', referenceId: 1 })).toBeNull();
  });
});
