import { ChangeDetectionStrategy, Component, ElementRef, computed, inject, input, signal, viewChild } from '@angular/core';
import { indexClavier } from './echelles';
import { formaterNombre } from '../../../core/format';
import { CarteGraphe } from './carte-graphe';
import { pourcentage, somme } from './echelles';
import { ContenuInfobulle, Infobulle, ancrer } from './infobulle';
import { LigneTable, TableDonnees } from './table-donnees';

export interface PartRepartition {
  libelle: string;
  valeur: number;
  couleur: string;
}

/**
 * Une seule barre à 100 % découpée en parts (2 px de fond entre elles), et
 * sous elle la légende qui porte les chiffres : un tout, lu d'un coup d'œil.
 */
@Component({
  selector: 'app-repartition',
  imports: [Infobulle, TableDonnees],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    @if (vueTableau()) {
      <app-table-donnees [entetes]="[entete(), 'Nombre', 'Part']" [lignes]="lignesTable()" [legende]="resume()" />
    } @else {
      <div class="graphique" #graphique role="img" tabindex="0" [attr.aria-label]="resume() + ' Flèches gauche et droite pour lire chaque part.'"
        (keydown)="clavier($event)" (blur)="cacher()">
        <div class="barre" [class.survol]="actif() !== null">
          @for (p of parts(); track p.libelle; let i = $index) {
            @if (p.valeur > 0) {
              <span class="part" [attr.data-i]="i" [class.active]="actif() === i"
                [style.flex-grow]="p.valeur" [style.background]="p.couleur" [style.--i]="i"
                (pointerenter)="montrer(i, $event.currentTarget)" (pointerleave)="cacher()"></span>
            }
          }
        </div>
        <ul class="legende" aria-hidden="true">
          @for (p of parts(); track p.libelle; let i = $index) {
            <li [class.active]="actif() === i">
              <i [style.background]="p.couleur"></i>
              <span>{{ p.libelle }}</span>
              <strong>{{ formater(p.valeur) }}</strong>
              <small>{{ part(i) }}</small>
            </li>
          }
        </ul>
        @if (bulle(); as b) {
          <app-infobulle [contenu]="b" />
        }
      </div>
      <p class="visuellement-cache" aria-live="polite">{{ annonce() }}</p>
    }
  `,
  styles: `
    :host { display: block; margin-top: 12px; }
    .graphique { position: relative; padding-top: 4px; border-radius: 6px; outline-offset: 4px; }
    .graphique:focus-visible { outline: 2px solid var(--vert); }
    .barre { display: flex; gap: 2px; height: 14px; border-radius: 4px; overflow: hidden; }
    .part {
      flex: 1 1 0; min-width: 3px; outline: none; transform-origin: left center;
      animation: etirer .7s cubic-bezier(.2, .7, .2, 1) backwards; animation-delay: .15s;
      transition: opacity .2s, filter .2s;
      &:focus-visible { filter: brightness(1.15); box-shadow: inset 0 0 0 2px rgba(255, 255, 255, .8); }
    }
    .survol .part:not(.active) { opacity: .45; }
    .legende {
      display: flex; flex-wrap: wrap; gap: 6px 18px; margin: 10px 0 0; padding: 0; list-style: none; font-size: 12.5px;
      li { display: inline-flex; align-items: baseline; gap: 6px; transition: opacity .15s; }
      i { align-self: center; width: 10px; height: 10px; border-radius: 2px; }
      span { color: var(--texte); }
      strong { color: var(--titre); font-weight: 700; }
      small { color: var(--gris); }
    }
    @keyframes etirer { from { transform: scaleX(0); } }
    @media (prefers-reduced-motion: reduce) { .part { animation: none; } }
  `,
})
export class Repartition {
  readonly parts = input.required<PartRepartition[]>();
  readonly resume = input.required<string>();
  readonly entete = input('Catégorie');

  private readonly carte = inject(CarteGraphe, { optional: true });
  protected readonly vueTableau = computed(() => this.carte?.vueTableau() ?? false);
  private readonly graphique = viewChild<ElementRef<HTMLElement>>('graphique');

  private readonly total = computed(() => somme(this.parts().map((p) => p.valeur)));
  protected readonly actif = signal<number | null>(null);
  private readonly indexPossibles = computed(() => this.parts().flatMap((p, i) => (p.valeur > 0 ? [i] : [])));
  private readonly ancrage = signal({ x: 0, y: 0 });
  protected readonly formater = formaterNombre;

  protected readonly bulle = computed<ContenuInfobulle | null>(() => {
    const i = this.actif();
    const p = i === null ? null : this.parts()[i];
    if (i === null || !p) {
      return null;
    }
    return {
      titre: p.libelle,
      lignes: [{ couleur: p.couleur, libelle: `sur ${formaterNombre(this.total())}`, valeur: formaterNombre(p.valeur) }],
      pied: this.part(i),
      ...this.ancrage(),
    };
  });

  protected readonly lignesTable = computed<LigneTable[]>(() =>
    this.parts().map((p, i) => ({ titre: p.libelle, cellules: [formaterNombre(p.valeur), this.part(i)] })),
  );

  /** « 92 % » ; « < 1 % » pour une part non nulle qui s'arrondirait à zéro. */
  protected part(i: number): string {
    const p = this.parts()[i];
    const pct = pourcentage(p?.valeur ?? 0, this.total());
    if (pct === null) {
      return '—';
    }
    return pct === 0 && (p?.valeur ?? 0) > 0 ? '< 1 %' : `${pct} %`;
  }

  protected lecture(i: number): string {
    const p = this.parts()[i];
    return `${p.libelle} : ${formaterNombre(p.valeur)}, ${this.part(i)}`;
  }

  protected montrer(i: number, part: EventTarget | null): void {
    const graphique = this.graphique()?.nativeElement;
    if (graphique && part instanceof Element) {
      this.ancrage.set(ancrer(part, graphique));
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
}
