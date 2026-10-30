import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { describe, expect, it } from 'vitest';
import { Filtre, OptionFiltre, OptionOnglet, Onglets } from './ui';

@Component({
  imports: [Filtre, Onglets],
  template: `
    <app-filtre libelle="Gravité" [options]="peu" [(valeur)]="choix" />
    <app-filtre libelle="Zone" [options]="beaucoup" [(valeur)]="zone" />
    <app-onglets libelle="Statut" ident="essai" [options]="onglets" [(valeur)]="vue" />
  `,
})
class Hote {
  readonly peu: OptionFiltre<string>[] = [{ valeur: 'A', libelle: 'Faible' }, { valeur: 'B', libelle: 'Élevée' }];
  readonly beaucoup: OptionFiltre<string>[] = ['Bamako', 'Kayes', 'Mopti', 'Ségou', 'Sikasso'].map((z) => ({ valeur: z, libelle: z }));
  readonly onglets: OptionOnglet<string>[] = [
    { valeur: 'UN', libelle: 'Actifs', compte: 3 },
    { valeur: 'DEUX', libelle: 'Retirés', compte: 0 },
    { valeur: 'TROIS', libelle: 'Tous' },
  ];
  readonly choix = signal<string | null>(null);
  readonly zone = signal<string | null>(null);
  readonly vue = signal('UN');
}

describe('composants partagés (A25, A28)', () => {
  it('Filtre : des pastilles radio jusqu’à quatre options, une liste au-delà', () => {
    const f = TestBed.createComponent(Hote);
    f.detectChanges();
    const racine = f.nativeElement as HTMLElement;
    const filtres = racine.querySelectorAll('app-filtre');
    const radios = filtres[0].querySelectorAll<HTMLInputElement>('input[type=radio]');
    expect(radios.length).toBe(3); // « Toutes » + 2
    radios[2].click();
    f.detectChanges();
    expect(f.componentInstance.choix()).toBe('B');
    expect(filtres[1].querySelector('select')).not.toBeNull();
    expect(filtres[1].querySelectorAll('option').length).toBe(6);
  });

  it('Onglets : tablist, une seule tabulation, flèches pour changer', async () => {
    const f = TestBed.createComponent(Hote);
    f.detectChanges();
    const racine = f.nativeElement as HTMLElement;
    const onglets = [...racine.querySelectorAll<HTMLButtonElement>('[role=tab]')];
    expect(racine.querySelector('[role=tablist]')?.getAttribute('aria-label')).toBe('Statut');
    expect(onglets.map((o) => o.tabIndex)).toEqual([0, -1, -1]);
    expect(onglets[0].getAttribute('aria-selected')).toBe('true');
    expect(onglets[0].getAttribute('aria-controls')).toBe('essai-panneau');
    expect(onglets[0].id).toBe('essai-onglet-UN');
    onglets[0].dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowRight' }));
    f.detectChanges();
    expect(f.componentInstance.vue()).toBe('DEUX');
    onglets[1].dispatchEvent(new KeyboardEvent('keydown', { key: 'End' }));
    f.detectChanges();
    expect(f.componentInstance.vue()).toBe('TROIS');
    onglets[2].dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowRight' }));
    f.detectChanges();
    expect(f.componentInstance.vue()).toBe('UN');
  });
});
