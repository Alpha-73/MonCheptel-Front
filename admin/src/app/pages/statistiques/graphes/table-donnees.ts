import { ChangeDetectionStrategy, Component, input } from '@angular/core';

export interface LigneTable {
  titre: string;
  cellules: string[];
}

/** Vue « Tableau » d'un graphique : les mêmes chiffres, lisibles sans survol. */
@Component({
  selector: 'app-table-donnees',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <table>
      @if (legende()) {
        <caption class="visuellement-cache">{{ legende() }}</caption>
      }
      <thead>
        <tr>
          @for (e of entetes(); track $index) {
            <th scope="col">{{ e }}</th>
          }
        </tr>
      </thead>
      <tbody>
        @for (l of lignes(); track $index) {
          <tr>
            <th scope="row">{{ l.titre }}</th>
            @for (c of l.cellules; track $index) {
              <td>{{ c }}</td>
            }
          </tr>
        }
      </tbody>
    </table>
  `,
  styles: `
    :host { display: block; margin-top: 12px; overflow-x: auto; }
    table { width: 100%; border-collapse: collapse; font-size: 13px; }
    th, td { padding: 6px 8px; border-bottom: 1px solid #eff2f1; text-align: right; white-space: nowrap; }
    th:first-child { text-align: left; padding-left: 0; }
    thead th { font-size: 11px; font-weight: 700; letter-spacing: .5px; text-transform: uppercase; color: var(--gris); }
    tbody th { font-weight: 600; color: var(--texte); }
    td { font-variant-numeric: tabular-nums; color: var(--titre); }
  `,
})
export class TableDonnees {
  readonly entetes = input.required<string[]>();
  readonly lignes = input.required<LigneTable[]>();
  readonly legende = input<string | null>(null);
}
