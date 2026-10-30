import { ChangeDetectionStrategy, Component, ElementRef, computed, inject, input, signal, viewChild } from '@angular/core';
import { indexClavier } from './echelles';
import { formaterNombre } from '../../../core/format';
import { CarteGraphe } from './carte-graphe';
import { SerieGraphe, proportion, somme } from './echelles';
import { ContenuInfobulle, Infobulle, ancrer } from './infobulle';
import { LigneTable, TableDonnees } from './table-donnees';

export interface LigneBarre {
  libelle: string;
  /** Repère discret sous le libellé (la gravité d'une maladie). */
  repere?: { couleur: string; texte: string } | null;
  /** Une valeur par série, segments dans l'ordre des séries. */
  valeurs: number[];
  /** Couleur propre à la ligne (série unique : étape ordonnée, « Autres » en gris). */
  couleur?: string | null;
  /** Complément discret après la valeur (« 45 % »). */
  detail?: string | null;
  /** Pied de l'infobulle (« 45 % de l'étape précédente »). */
  explication?: string | null;
}

/**
 * Barres horizontales partant d'une même ligne de base, segmentées quand il y
 * a plusieurs séries. Libellé à gauche, valeur au bout (colonne alignée).
 */
@Component({
  selector: 'app-barres',
  imports: [Infobulle, TableDonnees],
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { '[style.--col-libelle]': 'largeurLibelle()' },
  template: `
    @if (vueTableau()) {
      <app-table-donnees [entetes]="entetes()" [lignes]="lignesTable()" [legende]="resume()" />
    } @else {
      <div class="graphique" #graphique role="img" tabindex="0" [attr.aria-label]="resume() + ' Flèches haut et bas pour lire chaque ligne.'"
        (keydown)="clavier($event)" (blur)="cacher()" [class.survol]="actif() !== null">
        @for (l of lignes(); track l.libelle; let i = $index) {
          <div class="ligne" [attr.data-i]="i" [class.active]="actif() === i"
            (pointerenter)="montrer(i, $event.currentTarget)" (pointerleave)="cacher()">
            <div class="libelle" [title]="l.libelle">
              <span>{{ l.libelle }}</span>
              @if (l.repere) {
                <small><i [style.background]="l.repere.couleur"></i>{{ l.repere.texte }}</small>
              }
            </div>
            <div class="piste">
              <div class="barre" [style.width.%]="largeur(i)" [style.--i]="i">
                @for (v of l.valeurs; track $index; let j = $index) {
                  @if (v > 0) {
                    <span class="segment" [style.flex-grow]="v" [style.background]="couleur(i, j)"></span>
                  }
                }
              </div>
            </div>
            <div class="valeur" aria-hidden="true">
              <strong>{{ formater(totaux()[i]) }}</strong>
              @if (l.detail) {
                <small>{{ l.detail }}</small>
              }
            </div>
          </div>
        }
        @if (bulle(); as b) {
          <app-infobulle [contenu]="b" />
        }
      </div>
      <p class="visuellement-cache" aria-live="polite">{{ annonce() }}</p>
    }
  `,
  styleUrl: './barres.scss',
})
export class Barres {
  readonly lignes = input.required<LigneBarre[]>();
  readonly series = input.required<SerieGraphe[]>();
  /** Sommet de l'échelle ; par défaut, la plus longue barre. */
  readonly maximum = input<number | null>(null);
  readonly resume = input.required<string>();
  readonly entete = input('Libellé');
  readonly unite = input<[string, string]>(['cas', 'cas']);
  /** Largeur de la colonne des libellés. */
  readonly largeurLibelle = input('minmax(84px, 32%)');

  private readonly carte = inject(CarteGraphe, { optional: true });
  protected readonly vueTableau = computed(() => this.carte?.vueTableau() ?? false);
  private readonly graphique = viewChild<ElementRef<HTMLElement>>('graphique');

  protected readonly totaux = computed(() => this.lignes().map((l) => somme(l.valeurs)));
  private readonly echelle = computed(() => this.maximum() ?? Math.max(0, ...this.totaux()));

  protected readonly actif = signal<number | null>(null);
  private readonly indexPossibles = computed(() => this.lignes().map((_, i) => i));
  private readonly ancrage = signal({ x: 0, y: 0 });

  protected readonly bulle = computed<ContenuInfobulle | null>(() => {
    const i = this.actif();
    const l = i === null ? null : this.lignes()[i];
    if (i === null || !l) {
      return null;
    }
    const multi = this.series().length > 1;
    return {
      titre: l.libelle,
      lignes: multi
        ? this.series().map((s, j) => ({ couleur: this.couleur(i, j), libelle: s.libelle, valeur: formaterNombre(l.valeurs[j] ?? 0) }))
        : [{ couleur: this.couleur(i, 0), libelle: this.nomUnite(this.totaux()[i]), valeur: formaterNombre(this.totaux()[i]) }],
      pied: l.explication ?? (multi ? `Total : ${formaterNombre(this.totaux()[i])}` : null),
      ...this.ancrage(),
    };
  });

  protected readonly entetes = computed(() => {
    const multi = this.series().length > 1;
    const detail = this.lignes().some((l) => l.detail);
    return [
      this.entete(),
      ...(multi ? [...this.series().map((s) => s.libelle), 'Total'] : [this.series()[0]?.libelle ?? 'Nombre']),
      ...(detail ? ['Part'] : []),
    ];
  });
  protected readonly lignesTable = computed<LigneTable[]>(() => {
    const multi = this.series().length > 1;
    const detail = this.lignes().some((l) => l.detail);
    return this.lignes().map((l, i) => ({
      titre: l.repere ? `${l.libelle} (${l.repere.texte})` : l.libelle,
      cellules: [
        ...(multi ? l.valeurs.map((v) => formaterNombre(v)) : []),
        formaterNombre(this.totaux()[i]),
        ...(detail ? [l.detail ?? '—'] : []),
      ],
    }));
  });

  protected readonly formater = formaterNombre;

  protected largeur(i: number): number {
    const p = proportion(this.totaux()[i], this.echelle());
    return p > 0 ? Math.max(p, 1.5) : 0;
  }

  protected couleur(i: number, j: number): string {
    return this.lignes()[i]?.couleur ?? this.series()[j]?.couleur ?? 'var(--vert)';
  }

  protected lecture(i: number): string {
    const l = this.lignes()[i];
    const total = this.totaux()[i];
    const parties: string[] = [`${l.libelle}${l.repere ? ` (${l.repere.texte})` : ''} : ${formaterNombre(total)} ${this.nomUnite(total)}`];
    if (this.series().length > 1) {
      parties.push(`dont ${this.series().map((s, j) => `${s.libelle.toLowerCase()} ${formaterNombre(l.valeurs[j] ?? 0)}`).join(', ')}`);
    }
    if (l.explication) {
      parties.push(l.explication);
    }
    return parties.join(', ');
  }

  protected montrer(i: number, ligne: EventTarget | null): void {
    const graphique = this.graphique()?.nativeElement;
    const barre = (ligne as HTMLElement | null)?.querySelector('.barre');
    if (graphique && barre) {
      this.ancrage.set(ancrer(barre, graphique));
    }
    this.actif.set(i);
  }

  protected cacher(): void {
    this.actif.set(null);
    this.annonce.set('');
  }

  /** Lecture au clavier : le graphique est un seul arrêt de tabulation. */
  protected readonly annonce = signal('');

  protected clavier(e: KeyboardEvent): void {
    const i = indexClavier(e.key, this.actif(), this.indexPossibles());
    if (i === null) {
      return;
    }
    e.preventDefault();
    const cible = this.graphique()?.nativeElement.querySelector(`[data-i="${i}"]`) ?? null;
    this.montrer(i, cible);
    this.annonce.set(this.lecture(i));
  }

  private nomUnite(n: number): string {
    const [un, plusieurs] = this.unite();
    return n >= 2 ? plusieurs : un;
  }
}
