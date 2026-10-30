import { ChangeDetectionStrategy, Component, input } from '@angular/core';

export interface LigneInfobulle {
  couleur: string;
  libelle: string;
  valeur: string;
}

export interface ContenuInfobulle {
  titre: string;
  lignes: LigneInfobulle[];
  pied?: string | null;
  /** Ancrage (centre haut de la marque), en px dans le graphique. */
  x: number;
  y: number;
}

/**
 * Centre haut d'une marque, en px dans son graphique. L'abscisse est bornée
 * pour que la bulle (centrée dessus) ne déborde pas du graphique.
 */
export function ancrer(marque: Element, graphique: Element, demiLargeur = 92): { x: number; y: number } {
  const m = marque.getBoundingClientRect();
  const g = graphique.getBoundingClientRect();
  const centre = m.left + m.width / 2 - g.left;
  const x = g.width > demiLargeur * 2 ? Math.min(Math.max(centre, demiLargeur), g.width - demiLargeur) : g.width / 2;
  return { x, y: m.top - g.top };
}

/**
 * Bulle de lecture d'une marque (survol ou focus clavier). La valeur mène,
 * la série suit, repérée par un trait de sa couleur. Purement visuelle :
 * la même lecture est dans l'aria-label de la marque et dans le tableau.
 */
@Component({
  selector: 'app-infobulle',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="bulle" aria-hidden="true" [style.left.px]="contenu().x" [style.top.px]="contenu().y">
      <div class="titre">{{ contenu().titre }}</div>
      @for (l of contenu().lignes; track l.libelle) {
        <div class="ligne"><i [style.background]="l.couleur"></i><strong>{{ l.valeur }}</strong><span>{{ l.libelle }}</span></div>
      }
      @if (contenu().pied) {
        <div class="pied">{{ contenu().pied }}</div>
      }
    </div>
  `,
  styles: `
    :host { position: absolute; inset: 0; pointer-events: none; z-index: 3; }
    .bulle {
      position: absolute; min-width: 132px; max-width: 220px; padding: 8px 11px 9px;
      transform: translate(-50%, calc(-100% - 10px));
      background: var(--blanc); border: 1px solid var(--filet); border-radius: 10px;
      box-shadow: var(--ombre-survol); font-size: 12px; line-height: 17px; color: var(--texte);
      animation: surgir .14s ease-out;
    }
    .titre { margin-bottom: 4px; font-weight: 700; color: var(--titre); white-space: nowrap; }
    .ligne { display: flex; align-items: center; gap: 7px; white-space: nowrap; }
    .ligne i { flex: none; width: 12px; height: 3px; border-radius: 2px; }
    .ligne strong { min-width: 18px; font-weight: 700; color: var(--titre); font-variant-numeric: tabular-nums; }
    .ligne span { color: var(--gris); }
    .pied { margin-top: 5px; padding-top: 5px; border-top: 1px solid var(--filet); color: var(--gris); }
    @keyframes surgir { from { opacity: 0; transform: translate(-50%, calc(-100% - 4px)); } }
    @media (prefers-reduced-motion: reduce) { .bulle { animation: none; } }
  `,
})
export class Infobulle {
  readonly contenu = input.required<ContenuInfobulle>();
}
