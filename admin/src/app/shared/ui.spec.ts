import { describe, expect, it } from 'vitest';
import { numerosDePage } from './ui';

describe('numerosDePage', () => {
  it('montre toutes les pages jusqu’à sept', () => {
    expect(numerosDePage(0, 1)).toEqual([0]);
    expect(numerosDePage(3, 7)).toEqual([0, 1, 2, 3, 4, 5, 6]);
  });

  it('replie les pages éloignées autour de la page courante', () => {
    expect(numerosDePage(5, 12)).toEqual([0, null, 4, 5, 6, null, 11]);
  });

  it('garde un bloc de cinq pages aux extrémités', () => {
    expect(numerosDePage(0, 12)).toEqual([0, 1, 2, 3, null, 11]);
    expect(numerosDePage(11, 12)).toEqual([0, null, 8, 9, 10, 11]);
  });
});
