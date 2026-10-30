import { ChangeDetectionStrategy, Component, computed, inject, input } from '@angular/core';
import { DomSanitizer } from '@angular/platform-browser';

/** Tracés repris tels quels des SVG de la maquette (ecrans/*.svg). */
const TRACES: Record<string, string> = {
  accueil: '<path d="M3 11.2 L12 3.5 L21 11.2"/><path d="M5.5 9.6V20h13V9.6"/>',
  utilisateur: '<circle cx="12" cy="8" r="3.6"/><path d="M4.8 20.4c0-3.6 3.2-5.6 7.2-5.6s7.2 2 7.2 5.6"/>',
  bouclier: '<path d="M12 3.2 20 6.4v5.6c0 4.4-3.3 7.6-8 8.8-4.7-1.2-8-4.4-8-8.8V6.4z"/><path d="M12 9.2v5.6M9.2 12h5.6"/>',
  triangle: '<path d="M12 3.6 22 20.4H2z"/><path d="M12 9.8v4.6"/><path d="M12 17.4v.4"/>',
  document: '<path d="M6 3.4h9l3.6 3.6v13.6H6z"/><path d="M9.4 11.6h5.2M9.4 15.2h3.6"/>',
  cloche: '<path d="M6.4 9.6a5.6 5.6 0 0 1 11.2 0v4.8l1.8 2.8H4.6l1.8-2.8z"/><path d="M10 20h4"/>',
  diffusion: '<circle cx="12" cy="12" r="1.8"/><path d="M8.2 15.8a5.4 5.4 0 0 1 0-7.6M15.8 8.2a5.4 5.4 0 0 1 0 7.6"/><path d="M5.2 18.8a9.6 9.6 0 0 1 0-13.6M18.8 5.2a9.6 9.6 0 0 1 0 13.6"/>',
  courbe: '<path d="M4 19.6 10 12l4 3.6 6-8"/><path d="M20 7.6h-4.4M20 7.6v4.4"/>',
  crayon: '<path d="M4 20h4L19 9a2.8 2.8 0 0 0-4-4L4 16z"/><path d="M13.5 6.5l4 4"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  coche: '<path d="M5 12.5l4.5 4.5L19 7"/>',
  loupe: '<circle cx="11" cy="11" r="6.4"/><path d="M15.8 15.8 20 20"/>',
  chevronDroite: '<path d="M9 5l7 7-7 7"/>',
  chevronBas: '<path d="M5 9l7 7 7-7"/>',
  chevronGauche: '<path d="M15 19 L8 12 L15 5"/>',
  patte: '<circle cx="5.6" cy="10.4" r="1.9"/><circle cx="9.4" cy="5.8" r="1.9"/><circle cx="14.6" cy="5.8" r="1.9"/><circle cx="18.4" cy="10.4" r="1.9"/><path d="M7.6 17.6c0-2.9 2-5.6 4.4-5.6s4.4 2.7 4.4 5.6c0 1.9-1.5 2.8-3 2.3a4.6 4.6 0 0 0-2.8 0c-1.5.5-3-.4-3-2.3z"/>',
  horloge: '<circle cx="12" cy="12" r="8.4"/><path d="M12 7.4V12l3.2 2"/>',
  envoi: '<path d="M20.6 3.4 10.4 13.6"/><path d="M20.6 3.4 14.2 20.6l-3.8-7-7-3.8z"/>',
  orientation: '<circle cx="6" cy="18" r="2.4"/><circle cx="18" cy="6" r="2.4"/><path d="M8 16.2c4-1 2.6-6.8 7.6-8.6"/>',
  pourcent: '<path d="M18.5 5.5l-13 13"/><circle cx="7" cy="7" r="2.4"/><circle cx="17" cy="17" r="2.4"/>',
  oeil: '<path d="M2.6 12S6 5.6 12 5.6 21.4 12 21.4 12 18 18.4 12 18.4 2.6 12 2.6 12z"/><circle cx="12" cy="12" r="2.8"/>',
  oeilBarre: '<path d="M9.9 6A9.6 9.6 0 0 1 12 5.6c6 0 9.4 6.4 9.4 6.4a16 16 0 0 1-2.2 3"/><path d="M6.4 7.6C4 9.2 2.6 12 2.6 12S6 18.4 12 18.4a9 9 0 0 0 4.6-1.3"/><path d="M10 10a2.8 2.8 0 0 0 4 4"/><path d="M3.6 3.6l16.8 16.8"/>',
  sortie: '<path d="M14 4h4.5A1.5 1.5 0 0 1 20 5.5v13a1.5 1.5 0 0 1-1.5 1.5H14"/><path d="M10 16l-4-4 4-4"/><path d="M6 12h10"/>',
};

/** Icône au trait, de la couleur du texte courant (`currentColor`). */
@Component({
  selector: 'app-icone',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<svg
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    stroke-linecap="round"
    stroke-linejoin="round"
    [attr.width]="taille()"
    [attr.height]="taille()"
    [attr.stroke-width]="epaisseur()"
    aria-hidden="true"
    [innerHTML]="trace()"
  ></svg>`,
  styles: `:host { display: inline-flex; flex: none; line-height: 0; }`,
})
export class Icone {
  readonly nom = input.required<string>();
  readonly taille = input(24);
  readonly epaisseur = input(1.8);
  private readonly assainisseur = inject(DomSanitizer);
  // Les tracés sont des constantes du code (jamais une saisie) : on peut
  // contourner l'assainisseur, qui retirerait sinon les éléments SVG.
  protected readonly trace = computed(() => this.assainisseur.bypassSecurityTrustHtml(TRACES[this.nom()] ?? ''));
}
