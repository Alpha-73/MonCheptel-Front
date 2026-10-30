import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { describe, expect, it } from 'vitest';
import { Modale } from './modale';

@Component({
  imports: [Modale],
  template: `
    <button id="declencheur" type="button" (click)="ouvert.set(true)">Ouvrir</button>
    @if (ouvert()) {
      <app-modale titre="Supprimer ?" [ton]="ton()" [fermable]="fermable()" (fermer)="fermetures = fermetures + 1; ouvert.set(false)">
        <p>Texte</p>
        <ng-container actions>
          <button id="annuler" type="button" class="bouton" (click)="ouvert.set(false)">Annuler</button>
          <button id="action" type="button" class="bouton">Supprimer</button>
        </ng-container>
      </app-modale>
    }
  `,
})
class Hote {
  readonly ouvert = signal(false);
  readonly ton = signal<'succes' | 'danger'>('danger');
  readonly fermable = signal(true);
  fermetures = 0;
}

function monter() {
  const f = TestBed.createComponent(Hote);
  f.detectChanges();
  const racine = f.nativeElement as HTMLElement;
  document.body.appendChild(racine);
  const declencheur = racine.querySelector<HTMLButtonElement>('#declencheur')!;
  declencheur.focus();
  declencheur.click();
  f.detectChanges();
  return { f, racine, declencheur };
}

describe('Modale (A23)', () => {
  it('nomme la fenêtre et met le focus sur « Annuler » pour une action risquée', () => {
    const { racine } = monter();
    const dialogue = racine.querySelector('dialog')!;
    expect(dialogue.hasAttribute('open')).toBe(true);
    const titre = racine.querySelector(`#${dialogue.getAttribute('aria-labelledby')}`);
    expect(titre?.textContent).toContain('Supprimer ?');
    expect(document.activeElement?.id).toBe('annuler');
  });

  it('Échap ferme la fenêtre, et le focus revient au déclencheur', () => {
    const { f, racine, declencheur } = monter();
    racine.querySelector('dialog')!.dispatchEvent(new Event('cancel', { cancelable: true }));
    f.detectChanges();
    expect(f.componentInstance.fermetures).toBe(1);
    expect(racine.querySelector('dialog')).toBeNull();
    expect(document.activeElement).toBe(declencheur);
  });

  it('pendant un envoi, Échap ne ferme pas', () => {
    const { f, racine } = monter();
    f.componentInstance.fermable.set(false);
    f.detectChanges();
    const annulation = new Event('cancel', { cancelable: true });
    racine.querySelector('dialog')!.dispatchEvent(annulation);
    f.detectChanges();
    expect(annulation.defaultPrevented).toBe(true);
    expect(f.componentInstance.fermetures).toBe(0);
    expect(racine.querySelector('dialog')).not.toBeNull();
  });
});
