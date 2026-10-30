import { ChangeDetectionStrategy, Component, ElementRef, computed, inject, input, signal, viewChild } from '@angular/core';
import { indexClavier } from './echelles';
import { formaterNombre } from '../../../core/format';
import { CarteGraphe } from './carte-graphe';
import { SerieGraphe, graduations, libelleVisible, proportion, somme } from './echelles';
import { ContenuInfobulle, Infobulle, ancrer } from './infobulle';
import { LigneTable, TableDonnees } from './table-donnees';
import { NombrePipe } from '../../../shared/pipes';

export interface CategorieColonne {
  /** Sous l'axe : « 20 juil. », « nov. ». */
  libelle: string;
  /** Deuxième ligne discrète sous l'axe (l'année). */
  sousLibelle?: string | null;
  /** Titre de l'infobulle et ligne du tableau : « 20 – 26 juil. ». */
  titre: string;
}

/**
 * Colonnes (empilées quand il y a plusieurs séries) partant d'une même ligne
 * de base. Un seul axe, à gauche, aux graduations rondes ; quadrillage en
 * filet. `contigu` : histogramme, classes jointives séparées d'un filet de
 * 2 px, chaque classe étiquetée à son sommet (l'axe devient inutile).
 */
@Component({
  selector: 'app-colonnes',
  imports: [Infobulle, TableDonnees, NombrePipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './colonnes.html',
  styleUrl: './colonnes.scss',
})
export class Colonnes {
  readonly categories = input.required<CategorieColonne[]>();
  readonly series = input.required<SerieGraphe[]>();
  /** valeurs[catégorie][série]. */
  readonly valeurs = input.required<number[][]>();
  /** Couleur propre à chaque catégorie (échelle ordonnée) pour une série unique. */
  readonly couleursCategories = input<string[] | null>(null);
  readonly contigu = input(false);
  /** Phrase lue par les lecteurs d'écran à l'entrée du graphique. */
  readonly resume = input.required<string>();
  /** En-tête de la première colonne du tableau (« Semaine », « Mois »). */
  readonly entete = input('Période');
  readonly unite = input<[string, string]>(['cas', 'cas']);
  /** Au-delà, un libellé d'axe sur deux (les mois courts tiennent tous). */
  readonly maxLibelles = input(8);

  private readonly carte = inject(CarteGraphe, { optional: true });
  protected readonly vueTableau = computed(() => this.carte?.vueTableau() ?? false);
  private readonly graphique = viewChild<ElementRef<HTMLElement>>('graphique');

  protected readonly totaux = computed(() => this.valeurs().map((v) => somme(v)));
  /** Histogramme : chaque classe porte sa valeur, on se passe d'axe. */
  protected readonly avecAxe = computed(() => !this.contigu());
  protected readonly ticks = computed(() => graduations(Math.max(0, ...this.totaux()), 4));
  protected readonly sommet = computed(() => this.ticks()[this.ticks().length - 1]);
  protected readonly gabarit = computed(() => `repeat(${this.categories().length}, minmax(0, 1fr))`);
  /** Sans axe, la plus haute classe occupe toute la hauteur. */
  protected readonly echelle = computed(() => (this.avecAxe() ? this.sommet() : Math.max(1, ...this.totaux())));

  protected readonly actif = signal<number | null>(null);
  private readonly indexPossibles = computed(() => this.categories().map((_, i) => i));
  private readonly ancrage = signal({ x: 0, y: 0 });

  protected readonly bulle = computed<ContenuInfobulle | null>(() => {
    const i = this.actif();
    if (i === null) {
      return null;
    }
    const multi = this.series().length > 1;
    return {
      titre: this.categories()[i]?.titre ?? '',
      lignes: this.series()
        .map((s, j) => ({ couleur: this.couleur(i, j), libelle: multi ? s.libelle : this.nomUnite(this.totaux()[i]), valeur: formaterNombre(this.valeurs()[i]?.[j] ?? 0) }))
        .reverse(),
      pied: multi ? `Total : ${formaterNombre(this.totaux()[i])}` : null,
      ...this.ancrage(),
    };
  });

  protected readonly entetes = computed(() => {
    const multi = this.series().length > 1;
    return [this.entete(), ...this.series().map((s) => s.libelle), ...(multi ? ['Total'] : [])];
  });
  protected readonly lignesTable = computed<LigneTable[]>(() => {
    const multi = this.series().length > 1;
    return this.categories().map((c, i) => ({
      titre: c.titre,
      cellules: [...(this.valeurs()[i] ?? []).map((v) => formaterNombre(v)), ...(multi ? [formaterNombre(this.totaux()[i])] : [])],
    }));
  });

  protected hauteur(valeur: number): number {
    return proportion(valeur, this.echelle());
  }

  protected couleur(i: number, j: number): string {
    return this.couleursCategories()?.[i] ?? this.series()[j]?.couleur ?? 'var(--vert)';
  }

  protected libelleVisible(i: number): boolean {
    return this.contigu() || libelleVisible(i, this.categories().length, this.maxLibelles());
  }

  /** Lecture complète d'une colonne, pour le clavier et les lecteurs d'écran. */
  protected lecture(i: number): string {
    const c = this.categories()[i];
    const total = this.totaux()[i];
    if (this.series().length === 1) {
      return `${c.titre} : ${formaterNombre(total)} ${this.nomUnite(total)}`;
    }
    const detail = this.series()
      .map((s, j) => `${s.libelle} ${formaterNombre(this.valeurs()[i]?.[j] ?? 0)}`)
      .join(', ');
    return `${c.titre} : ${formaterNombre(total)} ${this.nomUnite(total)} (${detail})`;
  }

  protected montrer(i: number, colonne: EventTarget | null): void {
    const graphique = this.graphique()?.nativeElement;
    const pile = (colonne as HTMLElement | null)?.querySelector('.pile');
    if (graphique && pile) {
      this.ancrage.set(ancrer(pile, graphique));
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
