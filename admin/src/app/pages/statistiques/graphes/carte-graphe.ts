import { ChangeDetectionStrategy, Component, input, signal } from '@angular/core';
import { SerieGraphe } from './echelles';

/**
 * Cadre d'un graphique : titre, ligne d'explication, légende éventuelle et
 * bascule « Tableau » qui remplace le dessin par ses chiffres (les graphiques
 * enfants lisent `vueTableau` par injection).
 */
@Component({
  selector: 'app-carte-graphe',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <header>
      <div class="textes">
        <h2>{{ titre() }}</h2>
        @if (sousTitre()) {
          <p>{{ sousTitre() }}</p>
        }
        <ng-content select="[sous-titre]" />
      </div>
      @if (bascule()) {
        <button type="button" class="bascule" [attr.aria-pressed]="vueTableau()" (click)="vueTableau.set(!vueTableau())">
          {{ vueTableau() ? 'Graphique' : 'Tableau' }}
        </button>
      }
    </header>
    @if (series().length > 1 && !vueTableau()) {
      <ul class="legende">
        @for (s of series(); track s.libelle) {
          <li><i [style.background]="s.couleur"></i>{{ s.libelle }}</li>
        }
      </ul>
    }
    <ng-content />
  `,
  styles: `
    :host {
      display: block; min-width: 0; padding: 16px 18px 14px;
      background: var(--blanc); border: 1px solid var(--filet); border-radius: var(--rayon);
      animation: monter .45s ease-out backwards; animation-delay: calc(var(--rang, 0) * 70ms);
    }
    header { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; }
    h2 { margin: 0; font-family: var(--police-titre); font-size: 17px; line-height: 22px; font-weight: 700; color: var(--titre); }
    p { margin: 2px 0 0; font-size: 12.5px; line-height: 17px; color: var(--gris); }
    .bascule {
      flex: none; height: 26px; padding: 0 10px; border: 1px solid var(--filet); border-radius: 13px;
      background: var(--blanc); color: var(--gris); font: inherit; font-size: 12px; font-weight: 600; cursor: pointer;
      transition: color .15s, border-color .15s, background-color .15s;
      &:hover { color: var(--vert); border-color: #cfe0dd; background: var(--survol-ligne); }
      &:focus-visible { outline: 3px solid rgba(20, 107, 102, 0.35); outline-offset: 2px; }
      &[aria-pressed='true'] { color: var(--vert); border-color: var(--vert); }
    }
    .legende {
      display: flex; flex-wrap: wrap; gap: 4px 14px; margin: 10px 0 0; padding: 0; list-style: none;
      font-size: 12px; color: var(--texte);
      li { display: inline-flex; align-items: center; gap: 6px; }
      i { width: 10px; height: 10px; border-radius: 2px; }
    }
    @keyframes monter { from { opacity: 0; transform: translateY(10px); } }
    @media (prefers-reduced-motion: reduce) { :host { animation: none; } }
  `,
})
export class CarteGraphe {
  readonly titre = input.required<string>();
  readonly sousTitre = input<string | null>(null);
  /** Séries de la légende (affichée à partir de deux). */
  readonly series = input<SerieGraphe[]>([]);
  /** Bouton « Tableau » : à couper quand la carte n'a rien à tabuler. */
  readonly bascule = input(true);
  readonly vueTableau = signal(false);
}
