import { HttpErrorResponse } from '@angular/common/http';
import { messageErreur } from './erreurs';

describe('messageErreur', () => {
  it('reprend le message français du back', () => {
    const e = new HttpErrorResponse({ status: 422, error: { statut: 422, message: 'Une alerte active existe deja.' } });
    expect(messageErreur(e)).toBe('Une alerte active existe deja.');
  });
  it('détaille les champs invalides', () => {
    const e = new HttpErrorResponse({
      status: 400,
      error: { message: 'Certains champs sont invalides', champs: { email: 'Adresse e-mail invalide' } },
    });
    expect(messageErreur(e)).toBe('Certains champs sont invalides : Adresse e-mail invalide.');
  });
  it('explique un serveur injoignable', () => {
    expect(messageErreur(new HttpErrorResponse({ status: 0 }))).toContain('Impossible de joindre le serveur');
  });
});
