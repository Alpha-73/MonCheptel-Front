import { Directive, inject } from '@angular/core';
import { NgControl } from '@angular/forms';

/**
 * Pose `aria-invalid` sur un champ de formulaire réactif invalide et déjà
 * touché, et le relie au message d'erreur du formulaire (A27) :
 * `<input formControlName="nom" appChamp />`.
 */
@Directive({
  selector: '[appChamp]',
  host: {
    '[attr.aria-invalid]': 'invalide() ? "true" : null',
    '[attr.aria-describedby]': 'invalide() ? "erreur-formulaire" : null',
  },
})
export class Champ {
  private readonly controle = inject(NgControl, { self: true });

  protected invalide(): boolean {
    const c = this.controle.control;
    return !!c && c.invalid && (c.touched || c.dirty);
  }
}
