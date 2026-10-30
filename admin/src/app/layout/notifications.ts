import { ChangeDetectionStrategy, Component, ElementRef, inject, signal, viewChild } from '@angular/core';
import { Router } from '@angular/router';
import { depuis } from '../core/format';
import { NotificationAdmin } from '../core/modeles';
import { NotificationsService, destination } from '../core/notifications.service';
import { Icone } from '../shared/icone';

/** Icône d'une notification, d'après l'écran auquel elle renvoie. */
function iconeDe(n: NotificationAdmin): string {
  switch (n.referenceType) {
    case 'MALADIE': return 'triangle';
    case 'SIGNALEMENT': return 'orientation';
    case 'ALERTE': return 'diffusion';
    case 'CONSEIL': return 'document';
    default: return 'cloche';
  }
}

/**
 * Cloche du menu latéral et panneau des notifications de l'administrateur.
 *
 * Panneau non modal : il s'ouvre à droite du menu, se ferme par Échap, par
 * un clic ailleurs ou en suivant une notification ; le focus revient alors
 * sur la cloche.
 */
@Component({
  selector: 'app-notifications',
  imports: [Icone],
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: {
    '(document:keydown.escape)': 'fermer(true)',
    '(document:click)': 'clicAilleurs($event)',
  },
  template: `
    <button #cloche type="button" class="cloche" [class.ouvert]="ouvert()"
      [attr.aria-expanded]="ouvert()" aria-controls="panneau-notifications"
      [attr.aria-label]="sens()" [title]="sens()" (click)="basculer()">
      <app-icone nom="cloche" [taille]="18" [epaisseur]="1.9" />
      <span class="libelle">Notifications</span>
      @if (centre.nonLues(); as n) {
        <span class="pastille" aria-hidden="true">{{ n > 99 ? '99+' : n }}</span>
      }
    </button>

    @if (ouvert()) {
      <section #panneau id="panneau-notifications" class="panneau" aria-labelledby="titre-notifications" tabindex="-1">
        <header>
          <h2 id="titre-notifications">Notifications</h2>
          <button type="button" class="fermer" aria-label="Fermer les notifications" (click)="fermer(true)">×</button>
        </header>

        @if (centre.erreur(); as e) {
          <div class="etat erreur" role="alert">
            <span>{{ e }}</span>
            <button type="button" class="bouton bouton-contour petit" (click)="centre.ouvrir()">Réessayer</button>
          </div>
        } @else if (centre.liste().length === 0 && !centre.enCours()) {
          <p class="etat">Aucune notification pour le moment.</p>
        }

        <ul>
          @for (n of centre.liste(); track n.id) {
            <li>
              <button type="button" class="element" [class.nouvelle]="!n.lue" [disabled]="!mene(n)" (click)="suivre(n)">
                <span class="pictogramme" aria-hidden="true"><app-icone [nom]="icone(n)" [taille]="18" [epaisseur]="2" /></span>
                <span class="textes">
                  <strong>{{ n.titre }}</strong>
                  <span class="corps">{{ n.corps }}</span>
                  <small>
                    @if (!n.lue) { <span class="nouveau">Nouveau · </span> }
                    <time [attr.datetime]="n.dateCreation">{{ quand(n) }}</time>
                  </small>
                </span>
              </button>
            </li>
          }
        </ul>

        @if (centre.enCours()) {
          <p class="etat" role="status">Chargement…</p>
        } @else if (!centre.derniere()) {
          <button type="button" class="plus" (click)="centre.suite()">Afficher les plus anciennes</button>
        }
      </section>
    }
  `,
  styles: `
    :host { display: block; position: relative; padding: 0 12px; }
    .cloche {
      position: relative; display: flex; align-items: center; gap: 12px; width: 100%; height: 40px; padding: 0 12px 0 14px;
      border: 1px solid var(--barre-trait); border-radius: 10px; background: none; cursor: pointer;
      color: var(--barre-texte); font: inherit; font-size: 14.5px; font-weight: 700; text-align: left;
      transition: background-color .15s, color .15s;
      &:hover, &.ouvert { background: rgba(255, 255, 255, 0.07); color: var(--blanc); }
      .libelle { flex: 1; min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    }
    .pastille {
      flex: none; min-width: 22px; height: 20px; padding: 0 6px; border-radius: 10px;
      display: inline-grid; place-items: center; font-size: 11.5px; font-weight: 800; font-variant-numeric: tabular-nums;
      background: var(--logo-orange); color: var(--vert-sombre);
      animation: apparaitre .3s cubic-bezier(.2, .8, .2, 1);
    }
    @keyframes apparaitre { from { transform: scale(.4); opacity: 0; } }

    .panneau {
      position: fixed; z-index: 50; top: 12px; left: calc(var(--largeur-menu) + 12px); max-height: calc(100vh - 24px);
      width: min(400px, calc(100vw - var(--largeur-menu) - 24px));
      display: flex; flex-direction: column; overflow: hidden;
      border-radius: var(--rayon); background: var(--blanc); color: var(--texte);
      box-shadow: var(--ombre-flottante); outline: none;
      animation: glisser .22s cubic-bezier(.2, .8, .2, 1);
    }
    @keyframes glisser { from { transform: translateX(-12px); opacity: 0; } }
    header {
      flex: none; display: flex; align-items: center; justify-content: space-between;
      padding: 16px 14px 12px 20px; border-bottom: 1px solid var(--filet);
    }
    h2 { margin: 0; font-size: 19px; }
    .fermer {
      width: 32px; height: 32px; border: 0; border-radius: 8px; background: none; cursor: pointer;
      color: var(--gris); font-size: 22px; line-height: 1;
      &:hover { background: var(--survol-ligne); color: var(--texte); }
    }
    ul { flex: 1; overflow-y: auto; list-style: none; margin: 0; padding: 6px 0; }
    li + li { border-top: 1px solid var(--filet); }
    .element {
      display: flex; gap: 12px; width: 100%; padding: 12px 18px; border: 0; background: none; cursor: pointer;
      font: inherit; color: inherit; text-align: left;
      &:hover:not(:disabled) { background: var(--survol-ligne); }
      &:disabled { cursor: default; }
      &.nouvelle { background: var(--orange-pale); }
      &.nouvelle:hover { background: #ffe8cc; }
    }
    .pictogramme {
      flex: none; width: 34px; height: 34px; border-radius: 50%; display: grid; place-items: center;
      background: var(--vert-pale); color: var(--vert);
    }
    .textes { min-width: 0; display: flex; flex-direction: column; gap: 3px; }
    strong { font-size: 14px; font-weight: 800; color: var(--titre); }
    .corps { font-size: 13.5px; line-height: 1.45; color: var(--texte); }
    small { font-size: 12.5px; color: var(--gris); }
    .nouveau { font-weight: 800; color: var(--orange-texte); }
    .etat { margin: 0; padding: 20px; color: var(--gris); font-size: 14px; text-align: center; }
    .erreur { display: flex; flex-direction: column; align-items: center; gap: 10px; color: var(--rouge-texte); }
    .plus {
      flex: none; margin: 0; padding: 12px; border: 0; border-top: 1px solid var(--filet); background: var(--entete-tableau);
      font: inherit; font-size: 14px; font-weight: 800; color: var(--vert); cursor: pointer;
      &:hover { background: var(--survol-ligne); }
    }

    /* Rail d'icônes du menu (sous 1100 px), comme les entrées de navigation. */
    @media (max-width: 1100px) {
      :host { padding: 0 10px; }
      .cloche { justify-content: center; padding: 0; height: 44px; gap: 0; }
      .cloche .libelle { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0); }
      .pastille { position: absolute; top: 2px; right: 0; min-width: 18px; height: 16px; font-size: 10px; padding: 0 4px; }
    }
    @media (prefers-reduced-motion: reduce) {
      .panneau, .pastille { animation: none; }
    }
  `,
})
export class Notifications {
  protected readonly centre = inject(NotificationsService);
  private readonly router = inject(Router);
  private readonly hote = inject<ElementRef<HTMLElement>>(ElementRef);
  private readonly cloche = viewChild.required<ElementRef<HTMLButtonElement>>('cloche');
  private readonly panneau = viewChild<ElementRef<HTMLElement>>('panneau');

  protected readonly ouvert = signal(false);

  constructor() {
    this.centre.demarrer();
  }

  protected sens(): string {
    const n = this.centre.nonLues();
    return n ? `Notifications, ${n} non ${n > 1 ? 'lues' : 'lue'}` : 'Notifications';
  }

  protected basculer(): void {
    if (this.ouvert()) {
      this.fermer(true);
      return;
    }
    this.ouvert.set(true);
    this.centre.ouvrir();
    setTimeout(() => this.panneau()?.nativeElement.focus());
  }

  protected fermer(rendreFocus: boolean): void {
    if (!this.ouvert()) return;
    this.ouvert.set(false);
    if (rendreFocus) this.cloche().nativeElement.focus();
  }

  protected clicAilleurs(e: MouseEvent): void {
    // composedPath : la cible peut avoir quitté le DOM entre-temps (bouton Réessayer).
    if (this.ouvert() && !e.composedPath().includes(this.hote.nativeElement)) this.fermer(false);
  }

  protected mene(n: NotificationAdmin): boolean {
    return destination(n) !== null;
  }

  protected suivre(n: NotificationAdmin): void {
    const d = destination(n);
    if (!d) return;
    this.fermer(false);
    void this.router.navigate(d.lien, { queryParams: d.parametres });
  }

  protected icone(n: NotificationAdmin): string {
    return iconeDe(n);
  }

  protected quand(n: NotificationAdmin): string {
    return depuis(n.dateCreation);
  }
}
