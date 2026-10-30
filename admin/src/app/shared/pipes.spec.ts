import { Component } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { DateCourtePipe, DateLonguePipe, FilieresPipe, LibellePipe, NombrePipe } from './pipes';

describe('pipes de format', () => {
  it('NombrePipe : « 1 248 »', () => {
    expect(new NombrePipe().transform(1248)).toBe('1 248');
    expect(new NombrePipe().transform(null)).toBe('—');
  });

  it('DateCourtePipe : « 18 sept. »', () => {
    expect(new DateCourtePipe().transform('2026-09-18T10:00:00Z')).toBe('18 sept.');
  });

  it('DateLonguePipe : « 3 août 2026 »', () => {
    expect(new DateLonguePipe().transform('2026-08-03')).toBe('3 août 2026');
    expect(new DateLonguePipe().transform('2026-09-18T10:00:00Z', false)).toBe('18 septembre');
  });

  it('LibellePipe et FilieresPipe', () => {
    expect(new LibellePipe().transform('ELEVE', 'gravite')).toBe('Élevé');
    expect(new FilieresPipe().transform(['BOVINS', 'VOLAILLE'])).toBe('Volaille, Bovins');
  });

  it('s’utilisent dans un gabarit', () => {
    @Component({
      imports: [NombrePipe, DateCourtePipe, LibellePipe],
      template: `<span>{{ 34720 | nombre }}</span> <span>{{ '2026-09-16T08:00:00Z' | dateCourte }}</span> <span>{{ 'EN_MODERATION' | libelle: 'statutConseil' }}</span>`,
    })
    class Hote {}
    const f = TestBed.createComponent(Hote);
    f.detectChanges();
    const textes = [...(f.nativeElement as HTMLElement).querySelectorAll('span')].map((s) => s.textContent);
    expect(textes).toEqual(['34\u00a0720', '16 sept.', 'En modération']);
  });
});
