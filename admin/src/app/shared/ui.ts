import {
  ChangeDetectionStrategy,
  Component,
  ElementRef,
  computed,
  inject,
  input,
  model,
  output,
} from '@angular/core';
import { RouterLink } from '@angular/router';
import { Icone } from './icone';

let compteurIdentifiants = 0;
/** Identifiant unique dans la page (« filtre-3 »). */
export function identifiantUnique(prefixe: string): string {
  return `${prefixe}-${++compteurIdentifiants}`;
}

/**
 * En-tête de page « vivant », de la famille de l'application mobile
 * (EnteteVivant) : dégradé du vert du logo au vert de marque, sans
 * filigrane, bord inférieur DROIT (10 octobre : la vague faisait
 * décoratif), point orange devant le sous-titre.
 *
 * Collé en haut au défilement : il ne garde alors que sa ligne de titre et
 * ses actions (le haut glisse sous le bord de la fenêtre).
 * `grand` : variante du tableau de bord, qui porte aussi des chiffres
 * (contenu projeté avec l'attribut `bas`).
 */
@Component({
  selector: 'app-en-tete',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { '[class.grand]': 'grand()' },
  template: `
    <div class="ligne">
      <div class="textes">
        @if (surtitre()) {
          <p class="surtitre">{{ surtitre() }}</p>
        }
        <h1>{{ titre() }}</h1>
        @if (sousTitre()) {
          <p class="sous"><i class="point" aria-hidden="true"></i>{{ sousTitre() }}</p>
        }
      </div>
      <div class="actions"><ng-content /></div>
    </div>
    <ng-content select="[bas]" />
  `,
  styles: `
    :host {
      position: sticky; top: -26px; z-index: 5;
      display: block; overflow: hidden; isolation: isolate;
      padding: 30px 32px 24px;
      color: var(--sur-marque);
      background:
        radial-gradient(90% 160% at 100% 0%, rgba(31, 138, 131, 0.55), transparent 60%),
        linear-gradient(115deg, var(--logo-vert) 0%, var(--vert) 100%);
    }
    :host(.grand) { position: relative; top: 0; padding: 30px 32px 30px; }
    .ligne { position: relative; display: flex; align-items: center; justify-content: space-between; gap: 16px; min-height: 44px; }
    .textes { min-width: 0; }
    h1 {
      margin: 0; font-family: var(--police-titre); font-size: 26px; line-height: 32px; font-weight: 800;
      color: var(--sur-marque); letter-spacing: -0.2px;
    }
    :host(.grand) h1 { font-size: 28px; line-height: 34px; }
    .surtitre { margin: 0 0 2px; font-size: 13px; font-weight: 700; color: var(--sur-marque-discret); }
    .sous { display: flex; align-items: center; gap: 8px; margin: 2px 0 0; font-size: 13.5px; font-weight: 700; color: var(--sur-marque-discret); }
    .point { flex: none; width: 7px; height: 7px; border-radius: 50%; background: var(--logo-orange); }
    .actions { flex: none; display: flex; align-items: center; gap: 10px; }

    /* Boutons portés par l'en-tête vert. */
    :host ::ng-deep .actions .bouton-primaire { background: var(--blanc); color: var(--vert-sombre); }
    :host ::ng-deep .actions .bouton-contour { background: transparent; color: var(--blanc); border-color: rgba(255, 255, 255, 0.7); }

    @media (max-width: 900px) {
      :host { padding: 24px 16px 20px; }
      .ligne { flex-wrap: wrap; }
      h1 { font-size: 22px; line-height: 28px; }
    }
  `,
})
export class EnTete {
  readonly titre = input.required<string>();
  readonly sousTitre = input<string | null>(null);
  readonly surtitre = input<string | null>(null);
  readonly grand = input(false);
}

/** Lien « ‹ Retour à la liste » au-dessus des formulaires. */
@Component({
  selector: 'app-retour',
  imports: [RouterLink, Icone],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<a [routerLink]="lien()"><app-icone nom="chevronGauche" [taille]="16" [epaisseur]="2.6" />{{ texte() }}</a>`,
  styles: `
    :host { display: block; margin: 0 0 14px; }
    a { display: inline-flex; align-items: center; gap: 6px; color: var(--texte); font-weight: 800; font-size: 14px; text-decoration: none; }
    a:hover { color: var(--vert); }
  `,
})
export class Retour {
  readonly lien = input.required<string | unknown[]>();
  readonly texte = input.required<string>();
}

/**
 * Les trois états d'un écran qui charge des données : chargement (squelettes
 * sable qui scintillent, comme l'application), erreur (message du back +
 * Réessayer) et liste vide.
 */
@Component({
  selector: 'app-etat',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    @switch (type()) {
      @case ('chargement') {
        <div class="chargement" role="status" aria-busy="true">
          <span class="visuellement-cache">{{ message() || 'Chargement…' }}</span>
          @for (l of lignesSquelette(); track $index) {
            <div class="ligne-sq" aria-hidden="true">
              <span class="squelette rond"></span>
              <span class="squelette" [style.width.%]="l"></span>
              <span class="squelette court"></span>
            </div>
          }
        </div>
      }
      @case ('erreur') {
        <div class="erreur" role="alert">
          <strong>Impossible d'afficher ces données.</strong>
          <span>{{ message() }}</span>
          @if (reessayable()) {
            <button type="button" class="bouton bouton-contour petit" (click)="reessayer.emit()">Réessayer</button>
          }
        </div>
      }
      @case ('vide') {
        <div class="vide">{{ message() || 'Aucun élément à afficher.' }}</div>
      }
    }
  `,
  styles: `
    :host { display: block; }
    .vide { padding: 26px 20px; color: var(--gris); font-size: 14px; text-align: center; }
    .chargement { display: flex; flex-direction: column; gap: 16px; padding: 18px 20px; }
    .ligne-sq { display: flex; align-items: center; gap: 14px; }
    .ligne-sq .squelette { height: 12px; }
    .ligne-sq .rond { flex: none; width: 30px; height: 30px; border-radius: 50%; }
    .ligne-sq .court { width: 12%; margin-left: auto; }
    .erreur {
      display: flex; flex-wrap: wrap; align-items: center; gap: 8px 14px;
      padding: 14px 18px; border-radius: var(--rayon-petit); background: var(--rouge-pale);
      border-left: 3px solid var(--rouge); color: var(--texte); font-size: 14px;
    }
    .erreur strong { color: var(--rouge-texte); }
    .erreur button { margin-left: auto; }
  `,
})
export class Etat {
  readonly type = input.required<'chargement' | 'erreur' | 'vide'>();
  readonly message = input<string | null>(null);
  readonly reessayable = input(true);
  readonly lignes = input(4);
  readonly reessayer = output<void>();
  protected readonly lignesSquelette = computed(() =>
    Array.from({ length: this.lignes() }, (_, i) => [46, 62, 38, 54, 44, 58][i % 6]),
  );
}

export interface OptionFiltre<T> {
  valeur: T;
  libelle: string;
}

/**
 * Filtre d'une liste. Peu de choix (cinq au plus) : des puces cliquables,
 * comme dans l'application (un groupe de boutons radio natifs : flèches,
 * Espace et lecteurs d'écran fonctionnent d'office). Au-delà : une liste
 * déroulante native (A25).
 */
@Component({
  selector: 'app-filtre',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    @if (enPuces()) {
      <fieldset class="puces">
        <legend>{{ libelle() }}</legend>
        <label class="puce" [class.choisie]="valeur() === null">
          <input type="radio" [name]="nom" [checked]="valeur() === null" (change)="valeur.set(null)" />{{ libelleTous() }}
        </label>
        @for (o of options(); track o.valeur) {
          <label class="puce" [class.choisie]="o.valeur === valeur()">
            <input type="radio" [name]="nom" [checked]="o.valeur === valeur()" (change)="valeur.set(o.valeur)" />{{ o.libelle }}
          </label>
        }
      </fieldset>
    } @else {
      <label class="liste" [class.actif]="valeur() !== null">
        <span>{{ libelle() }}</span>
        <select (change)="choisirIndex($any($event.target).value)" [attr.aria-label]="libelle()">
          <option value="" [selected]="valeur() === null">{{ libelleTous() }}</option>
          @for (o of options(); track o.valeur; let i = $index) {
            <option [value]="i" [selected]="o.valeur === valeur()">{{ o.libelle }}</option>
          }
        </select>
      </label>
    }
  `,
  styles: `
    :host { display: inline-flex; }
    .puces { display: flex; flex-wrap: wrap; align-items: center; gap: 6px; margin: 0; padding: 0; border: 0; min-width: 0; }
    legend { float: left; margin-right: 6px; padding: 0; font-size: 13px; font-weight: 800; color: var(--gris); }
    .puce {
      position: relative; display: inline-flex; align-items: center; height: 32px; padding: 0 13px;
      border: 1px solid var(--bordure); border-radius: 16px; background: var(--blanc);
      font-size: 13px; font-weight: 700; color: var(--texte); cursor: pointer; user-select: none; white-space: nowrap;
      transition: background-color .15s, color .15s, border-color .15s, transform .15s;
    }
    .puce:hover { border-color: var(--vert); }
    .puce:active { transform: scale(.97); }
    .puce input { position: absolute; inset: 0; margin: 0; opacity: 0; cursor: pointer; }
    .puce.choisie { background: var(--vert); border-color: var(--vert); color: var(--blanc); }
    .puce:focus-within { box-shadow: var(--focus); }
    .liste {
      display: inline-flex; align-items: center; gap: 0; height: 36px; padding-left: 13px;
      border: 1px solid var(--bordure); border-radius: 18px; background: var(--blanc); cursor: pointer;
    }
    .liste.actif { border-color: var(--vert); box-shadow: inset 0 0 0 1px var(--vert); }
    .liste:focus-within { box-shadow: var(--focus); }
    .liste span { font-size: 13px; font-weight: 800; color: var(--gris); }
    select {
      appearance: none; height: 100%; padding: 0 34px 0 8px; border: 0; border-radius: 18px; outline: none; cursor: pointer;
      font: inherit; font-size: 13px; font-weight: 700; color: var(--texte);
      background: transparent url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='16' height='16' fill='none' stroke='%235e5e5c' stroke-width='2.2' stroke-linecap='round'%3E%3Cpath d='M5 9l7 7 7-7'/%3E%3C/svg%3E") no-repeat right 12px center;
    }
  `,
})
export class Filtre<T> {
  readonly libelle = input.required<string>();
  readonly options = input.required<OptionFiltre<T>[]>();
  readonly valeur = model<T | null>(null);
  readonly libelleTous = input('Tous');
  /** Forcer la liste déroulante même avec peu de choix. */
  readonly liste = input(false);
  protected readonly nom = identifiantUnique('filtre');
  protected readonly enPuces = computed(() => !this.liste() && this.options().length <= 4);

  protected choisirIndex(index: string): void {
    this.valeur.set(index === '' ? null : (this.options()[+index]?.valeur ?? null));
  }
}

export interface OptionOnglet<T> {
  valeur: T;
  libelle: string;
  /** Petit compte affiché après le libellé. */
  compte?: number | null;
  /** Compte en rouge (cas urgents). */
  alerte?: boolean;
}

/**
 * Onglets accessibles (A28) : un seul arrêt de tabulation, flèches gauche et
 * droite, Début et Fin ; chaque onglet commande le panneau `ident-panneau`
 * que la page pose sous lui (`role="tabpanel"`).
 */
@Component({
  selector: 'app-onglets',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="onglets" role="tablist" [attr.aria-label]="libelle()">
      @for (o of options(); track o.valeur; let i = $index) {
        <button type="button" role="tab" [id]="idOnglet(o.valeur)" [attr.aria-selected]="o.valeur === valeur()"
          [attr.aria-controls]="ident() + '-panneau'" [tabindex]="o.valeur === valeur() ? 0 : -1"
          [class.actif]="o.valeur === valeur()" (click)="valeur.set(o.valeur)" (keydown)="clavier($event, i)">
          {{ o.libelle }}
          @if (o.compte !== null && o.compte !== undefined) {
            <span class="compte" [class.alerte]="o.alerte && o.compte > 0">{{ o.compte }}</span>
          }
        </button>
      }
    </div>
  `,
  styles: `
    :host { display: inline-flex; max-width: 100%; }
    .onglets { display: inline-flex; flex-wrap: wrap; gap: 4px; padding: 4px; border-radius: 12px; background: var(--sable); }
    button {
      display: inline-flex; align-items: center; gap: 7px; height: 32px; padding: 0 14px; border: 0; border-radius: 9px; background: none;
      font: inherit; font-size: 13px; font-weight: 800; color: var(--gris-fort); cursor: pointer;
      transition: background .2s, color .2s, box-shadow .2s;
    }
    button:hover { color: var(--titre); }
    button.actif { background: var(--blanc); color: var(--vert); box-shadow: 0 1px 3px rgba(14, 63, 60, .12); }
    .compte {
      min-width: 20px; height: 20px; padding: 0 6px; border-radius: 10px; display: inline-grid; place-items: center;
      background: rgba(14, 63, 60, .08); color: var(--titre); font-size: 11.5px; font-variant-numeric: tabular-nums;
    }
    .compte.alerte { background: var(--rouge); color: var(--blanc); }
  `,
})
export class Onglets<T extends string | number | boolean> {
  private readonly hote = inject<ElementRef<HTMLElement>>(ElementRef);
  readonly libelle = input.required<string>();
  /** Préfixe des identifiants : `ident-onglet-VALEUR`, `ident-panneau`. */
  readonly ident = input.required<string>();
  readonly options = input.required<OptionOnglet<T>[]>();
  readonly valeur = model.required<T>();

  protected idOnglet(v: T): string {
    return `${this.ident()}-onglet-${String(v)}`;
  }

  protected clavier(e: KeyboardEvent, i: number): void {
    const n = this.options().length;
    const cible =
      e.key === 'ArrowRight' ? (i + 1) % n : e.key === 'ArrowLeft' ? (i - 1 + n) % n : e.key === 'Home' ? 0 : e.key === 'End' ? n - 1 : -1;
    if (cible < 0) return;
    e.preventDefault();
    this.valeur.set(this.options()[cible].valeur);
    queueMicrotask(() => this.hote.nativeElement.querySelectorAll<HTMLElement>('[role=tab]')[cible]?.focus());
  }
}

/** Champ de recherche à loupe des listes. */
@Component({
  selector: 'app-recherche',
  imports: [Icone],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <app-icone nom="loupe" [taille]="17" [epaisseur]="2.2" />
    <input type="search" [placeholder]="placeholder()" [value]="valeur()" (input)="valeur.set($any($event.target).value)"
      [attr.aria-label]="placeholder()" />
  `,
  styles: `
    :host {
      display: flex; align-items: center; gap: 10px; width: 320px; max-width: 100%; height: 36px; padding: 0 14px;
      border: 1px solid var(--bordure); border-radius: 18px; background: var(--blanc); color: var(--gris-fort);
    }
    :host(:focus-within) { border-color: var(--vert); box-shadow: var(--focus); }
    input { flex: 1; min-width: 0; border: 0; outline: 0; font: inherit; font-size: 14px; color: var(--texte); background: none; }
    input::placeholder { color: var(--gris); }
  `,
})
export class Recherche {
  readonly placeholder = input('Rechercher…');
  readonly valeur = model('');
}

/**
 * Pied de liste paginée : « 1–10 sur 23 » à gauche, pages à droite.
 * `page` part de 0. Au-delà de sept pages, les pages éloignées se replient
 * en « … » autour de la page courante.
 */
@Component({
  selector: 'app-pagination',
  imports: [Icone],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="pied-liste">
      <span>
        @if (total() > 0) {
          <strong>{{ debut() }}–{{ fin() }}</strong> sur {{ total() }} {{ total() > 1 ? unite() + 's' : unite() }}
        } @else {
          0 {{ unite() }}
        }
      </span>
      @if (nombrePages() > 1) {
        <nav class="pages" aria-label="Pagination">
          <button type="button" class="page fleche" [disabled]="page() === 0" (click)="aller(page() - 1)" aria-label="Page précédente">
            <app-icone nom="chevronGauche" [taille]="14" [epaisseur]="2.4" />
          </button>
          @for (n of numeros(); track $index) {
            @if (n === null) {
              <span class="ellipse" aria-hidden="true">…</span>
            } @else {
              <button type="button" class="page" [class.courante]="n === page()" [attr.aria-current]="n === page() ? 'page' : null"
                      [attr.aria-label]="'Page ' + (n + 1)" (click)="aller(n)">{{ n + 1 }}</button>
            }
          }
          <button type="button" class="page fleche" [disabled]="page() >= nombrePages() - 1" (click)="aller(page() + 1)" aria-label="Page suivante">
            <app-icone nom="chevronDroite" [taille]="14" [epaisseur]="2.4" />
          </button>
        </nav>
      }
    </div>
  `,
  styles: `
    .pied-liste { justify-content: space-between; }
    strong { color: var(--texte); font-weight: 800; }
    .pages { display: flex; align-items: center; gap: 4px; }
    .page {
      min-width: 32px; height: 32px; padding: 0 8px; border-radius: 8px; border: 1px solid transparent;
      display: grid; place-items: center; background: none; cursor: pointer;
      font: inherit; font-size: 13px; font-weight: 800; color: var(--texte);
      transition: background .15s, border-color .15s, color .15s;
    }
    .page:hover:not(:disabled):not(.courante) { background: var(--blanc); border-color: var(--filet); }
    .page.courante { background: var(--vert); color: #fff; }
    .page:disabled { opacity: .35; cursor: default; }
    .ellipse { width: 20px; text-align: center; color: var(--gris); }
  `,
})
export class Pagination {
  readonly page = input.required<number>();
  readonly taille = input.required<number>();
  readonly total = input.required<number>();
  /** « éleveur », « vétérinaire »… ; un « s » est ajouté au pluriel. */
  readonly unite = input('élément');
  readonly pageChange = output<number>();

  protected readonly nombrePages = computed(() => Math.max(1, Math.ceil(this.total() / this.taille())));
  protected readonly debut = computed(() => this.page() * this.taille() + 1);
  protected readonly fin = computed(() => Math.min(this.total(), (this.page() + 1) * this.taille()));

  protected readonly numeros = computed<(number | null)[]>(() => numerosDePage(this.page(), this.nombrePages()));

  protected aller(n: number): void {
    if (n >= 0 && n < this.nombrePages() && n !== this.page()) {
      this.pageChange.emit(n);
    }
  }
}

/** Pages à afficher : toutes jusqu'à 7, sinon 1 … (p-1 p p+1) … n. `null` = « … ». */
export function numerosDePage(page: number, nombre: number): (number | null)[] {
  if (nombre <= 7) {
    return Array.from({ length: nombre }, (_, i) => i);
  }
  const garde = new Set([0, nombre - 1, page - 1, page, page + 1].filter((n) => n >= 0 && n < nombre));
  if (page <= 2) [1, 2, 3].forEach((n) => garde.add(n));
  if (page >= nombre - 3) [nombre - 4, nombre - 3, nombre - 2].forEach((n) => garde.add(n));
  const tries = [...garde].sort((a, b) => a - b);
  const sortie: (number | null)[] = [];
  tries.forEach((n, i) => {
    if (i > 0 && n - tries[i - 1] > 1) sortie.push(null);
    sortie.push(n);
  });
  return sortie;
}
