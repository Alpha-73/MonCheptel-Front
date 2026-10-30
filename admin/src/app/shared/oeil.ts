import { ChangeDetectionStrategy, Component, input, signal } from '@angular/core';
import { Icone } from './icone';

/**
 * Bouton « afficher le mot de passe », posé dans le champ qu'il bascule :
 *
 *   <div class="avec-oeil"><input #mdp type="password" …><app-oeil [cible]="mdp" /></div>
 *
 * Libellé fixe et `aria-pressed` (A28) : un lecteur d'écran annonce
 * « Afficher le mot de passe, bouton bascule, activé ».
 *
 * Il change le `type` de l'input ciblé ; le contrôle de formulaire n'en
 * sait rien, la valeur ne bouge pas.
 */
@Component({
  selector: 'app-oeil',
  imports: [Icone],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<button type="button" aria-label="Afficher le mot de passe"
    [attr.aria-pressed]="visible()" [title]="visible() ? 'Masquer le mot de passe' : 'Afficher le mot de passe'" (click)="basculer()">
    <app-icone [nom]="visible() ? 'oeilBarre' : 'oeil'" [taille]="20" [epaisseur]="1.8" />
  </button>`,
  styles: `
    :host { position: absolute; top: 0; right: 4px; bottom: 0; display: flex; align-items: center; }
    button {
      display: grid; place-items: center; width: 36px; height: 36px; padding: 0;
      border: 0; border-radius: 8px; background: none; color: var(--gris-fort); cursor: pointer;
      transition: color .15s, background .15s;
      &:hover { color: var(--vert); background: var(--vert-pale); }
      &:focus-visible { outline: 2px solid var(--vert); outline-offset: 1px; }
    }
  `,
})
export class Oeil {
  readonly cible = input.required<HTMLInputElement>();
  protected readonly visible = signal(false);

  protected basculer(): void {
    const v = !this.visible();
    this.visible.set(v);
    this.cible().type = v ? 'text' : 'password';
    this.cible().focus();
  }
}
