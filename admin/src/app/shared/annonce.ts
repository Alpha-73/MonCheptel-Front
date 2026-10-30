import { ChangeDetectionStrategy, Component, Injectable, inject, signal } from '@angular/core';

/**
 * Confirmation discrète après une action (« Compte supprimé »), annoncée aux
 * lecteurs d'écran (A29). Elle survit au changement de page : la coque
 * l'affiche, les écrans la déclenchent.
 */
@Injectable({ providedIn: 'root' })
export class AnnonceService {
  readonly message = signal<{ texte: string; n: number } | null>(null);
  private minuterie?: ReturnType<typeof setTimeout>;
  private n = 0;

  annoncer(texte: string, dureeMs = 4500): void {
    clearTimeout(this.minuterie);
    this.message.set({ texte, n: ++this.n });
    this.minuterie = setTimeout(() => this.message.set(null), dureeMs);
  }

  fermer(): void {
    clearTimeout(this.minuterie);
    this.message.set(null);
  }
}

/** Le bandeau de confirmation, avec une coche qui se dessine. */
@Component({
  selector: 'app-annonce',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="zone" role="status" aria-live="polite">
      @if (annonces.message(); as m) {
        @for (cle of [m.n]; track cle) {
          <div class="toast">
            <svg viewBox="0 0 24 24" width="22" height="22" aria-hidden="true">
              <circle cx="12" cy="12" r="11" />
              <path d="M6.5 12.5l3.6 3.6L17.5 8.6" />
            </svg>
            <span>{{ m.texte }}</span>
            <button type="button" aria-label="Fermer la confirmation" (click)="annonces.fermer()">×</button>
          </div>
        }
      }
    </div>
  `,
  styles: `
    .zone { position: fixed; left: 50%; bottom: 24px; z-index: 200; transform: translateX(-50%); }
    .toast {
      display: flex; align-items: center; gap: 10px; padding: 10px 10px 10px 14px; border-radius: 14px;
      background: var(--vert-sombre); color: var(--blanc); font-weight: 700; box-shadow: var(--ombre-flottante);
      animation: monter .3s cubic-bezier(.2, .8, .2, 1);
    }
    svg circle { fill: var(--logo-orange); }
    svg path {
      fill: none; stroke: var(--vert-sombre); stroke-width: 2.6; stroke-linecap: round; stroke-linejoin: round;
      stroke-dasharray: 20; stroke-dashoffset: 20; animation: dessiner .45s .15s ease-out forwards;
    }
    button {
      width: 28px; height: 28px; border: 0; border-radius: 8px; background: none; color: var(--sur-marque-discret);
      font-size: 20px; line-height: 1; cursor: pointer;
    }
    button:hover { background: rgba(255, 255, 255, .1); color: #fff; }
    @keyframes dessiner { to { stroke-dashoffset: 0; } }
    @keyframes monter { from { opacity: 0; transform: translateY(12px); } }
    @media (prefers-reduced-motion: reduce) { svg path { stroke-dashoffset: 0; } }
  `,
})
export class Annonce {
  protected readonly annonces = inject(AnnonceService);
}
