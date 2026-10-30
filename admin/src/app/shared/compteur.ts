import { Directive, ElementRef, effect, inject, input, OnDestroy } from '@angular/core';
import { formaterNombre } from '../core/format';

/**
 * Chiffre qui défile de 0 à sa valeur en 0,9 s (ease-out) à l'affichage :
 * `<span [appCompteur]="1248"></span>`. Sans animation si l'utilisateur a
 * demandé de réduire les mouvements.
 */
@Directive({ selector: '[appCompteur]' })
export class Compteur implements OnDestroy {
  readonly appCompteur = input.required<number>();
  private readonly hote = inject<ElementRef<HTMLElement>>(ElementRef);
  private image = 0;

  constructor() {
    effect(() => this.animer(this.appCompteur() ?? 0));
  }

  private animer(cible: number): void {
    cancelAnimationFrame(this.image);
    const el = this.hote.nativeElement;
    const reduit = typeof matchMedia === 'function' && matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (reduit || typeof requestAnimationFrame !== 'function' || cible === 0) {
      el.textContent = formaterNombre(cible);
      return;
    }
    const debut = performance.now();
    const duree = 900;
    const pas = (t: number) => {
      const p = Math.min(1, (t - debut) / duree);
      const ease = 1 - Math.pow(1 - p, 3);
      el.textContent = formaterNombre(Math.round(cible * ease));
      if (p < 1) this.image = requestAnimationFrame(pas);
    };
    this.image = requestAnimationFrame(pas);
  }

  ngOnDestroy(): void {
    cancelAnimationFrame(this.image);
  }
}
