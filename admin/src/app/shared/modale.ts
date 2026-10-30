import {
  AfterViewInit,
  ChangeDetectionStrategy,
  Component,
  ElementRef,
  OnDestroy,
  input,
  output,
  viewChild,
} from '@angular/core';
import { Icone } from './icone';
import { identifiantUnique } from './ui';

/**
 * Fenêtre de confirmation, en `<dialog>` natif ouvert par `showModal()`
 * (A23) : le navigateur rend le fond inerte, garde le focus dans la fenêtre
 * et gère Échap.
 *
 * - focus initial sur le bouton le moins risqué (« Annuler ») pour un ton
 *   danger, sinon sur le premier contrôle ;
 * - retour du focus sur le déclencheur à la fermeture ;
 * - `aria-labelledby` sur le titre, `aria-describedby` sur le corps ;
 * - `fermable` à faux pendant un envoi : ni Échap ni clic au dehors ne ferment.
 *
 * Les boutons d'action se posent dans `<ng-container actions>` : Annuler
 * d'abord, l'action ensuite (elle s'affiche à droite).
 */
@Component({
  selector: 'app-modale',
  imports: [Icone],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <dialog #dialogue [attr.aria-labelledby]="id + '-titre'" [attr.aria-describedby]="id + '-corps'"
      (cancel)="annulation($event)" (click)="clicFond($event)">
      <div class="carte">
        <div class="tete">
          <div class="pastille" [class.danger]="ton() === 'danger'" aria-hidden="true">
            <app-icone [nom]="ton() === 'danger' ? 'triangle' : 'coche'" [taille]="22" [epaisseur]="2.2" />
          </div>
          <h2 [id]="id + '-titre'">{{ titre() }}</h2>
        </div>
        <div class="corps" [id]="id + '-corps'"><ng-content /></div>
        <div class="actions"><ng-content select="[actions]" /></div>
      </div>
    </dialog>
  `,
  styles: `
    dialog {
      width: 520px; max-width: calc(100vw - 32px); max-height: calc(100vh - 32px); padding: 0;
      border: 0; border-radius: 18px; background: var(--blanc); color: var(--texte);
      box-shadow: var(--ombre-flottante); overflow: auto;
      animation: entrer .22s cubic-bezier(.2, .8, .2, 1);
    }
    dialog::backdrop { background: rgba(14, 32, 31, 0.45); animation: fondu .2s ease-out; }
    .carte { padding: 24px 24px 20px; }
    .tete { display: flex; align-items: center; gap: 14px; margin-bottom: 10px; }
    .pastille {
      flex: none; width: 44px; height: 44px; border-radius: 50%;
      display: grid; place-items: center; background: var(--vert-pale); color: var(--vert);
    }
    .pastille.danger { background: var(--rouge-pale); color: var(--rouge); }
    h2 { margin: 0; font-family: var(--police-titre); font-size: 21px; line-height: 26px; font-weight: 700; color: var(--titre); }
    .corps { color: var(--texte); font-size: 14px; line-height: 21px; }
    .corps ::ng-deep p { margin: 0; }
    .actions { display: flex; flex-wrap: wrap; justify-content: flex-end; gap: 10px; margin-top: 20px; }
    @keyframes entrer { from { opacity: 0; transform: translateY(12px) scale(.98); } }
    @keyframes fondu { from { opacity: 0; } }
  `,
})
export class Modale implements AfterViewInit, OnDestroy {
  readonly titre = input.required<string>();
  readonly ton = input<'succes' | 'danger'>('succes');
  /** Faux pendant un envoi : Échap et le clic au dehors sont sans effet. */
  readonly fermable = input(true);
  readonly fermer = output<void>();

  protected readonly id = identifiantUnique('modale');
  private readonly dialogue = viewChild.required<ElementRef<HTMLDialogElement>>('dialogue');
  private declencheur: HTMLElement | null = null;

  ngAfterViewInit(): void {
    const d = this.dialogue().nativeElement;
    this.declencheur = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    if (typeof d.showModal === 'function') {
      d.showModal();
    } else {
      d.setAttribute('open', '');
    }
    this.focusInitial(d);
  }

  ngOnDestroy(): void {
    const d = this.dialogue().nativeElement;
    if (d.open && typeof d.close === 'function') {
      d.close();
    }
    // Retour du focus au déclencheur s'il est encore dans la page.
    if (this.declencheur?.isConnected) {
      this.declencheur.focus();
    }
  }

  private focusInitial(d: HTMLDialogElement): void {
    const boutons = [...d.querySelectorAll<HTMLElement>('.actions button:not([disabled])')];
    const annuler = boutons.find((b) => /^\s*(Annuler|Fermer|Terminer)\s*$/.test(b.textContent ?? ''));
    const premierChamp = d.querySelector<HTMLElement>('.corps input:not([disabled]), .corps textarea, .corps select');
    const cible = this.ton() === 'danger' ? (annuler ?? boutons[0]) : (premierChamp ?? boutons[boutons.length - 1] ?? boutons[0]);
    (cible ?? d).focus();
  }

  protected annulation(e: Event): void {
    e.preventDefault();
    if (this.fermable()) {
      this.fermer.emit();
    }
  }

  protected clicFond(e: MouseEvent): void {
    if (e.target === this.dialogue().nativeElement && this.fermable()) {
      this.fermer.emit();
    }
  }
}
