import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  ElementRef,
  afterNextRender,
  computed,
  inject,
  signal,
  viewChild,
} from '@angular/core';
import { NavigationEnd, Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { filter } from 'rxjs';
import { initiales } from '../core/format';
import { TableauDeBordAdmin } from '../core/modeles';
import { PoulsService } from '../core/pouls.service';
import { SessionService } from '../core/session.service';
import { Annonce } from '../shared/annonce';
import { Icone } from '../shared/icone';
import { Notifications } from './notifications';

interface EntreeMenu {
  lien: string;
  libelle: string;
  icone: string;
  /** Compte affiché en pastille, lu dans le pouls de la plateforme. */
  pastille?: { lire: (d: TableauDeBordAdmin) => number; ton: 'rouge' | 'orange' | 'clair'; sens: (n: number) => string };
}

interface GroupeMenu {
  cle: string;
  titre: string;
  entrees: EntreeMenu[];
}

/**
 * Coque commune des écrans : menu latéral fixe vert sombre groupé par
 * métier, pastilles de compte, indicateur orange qui glisse, lien
 * d'évitement, bandeau de confirmation, cloche des notifications (la cloche
 * est réservée aux notifications ; les alertes sanitaires, diffusées sur une
 * zone, ont l'icône « diffusion »).
 */
@Component({
  selector: 'app-coque',
  imports: [RouterOutlet, RouterLink, RouterLinkActive, Icone, Annonce, Notifications],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './coque.html',
  styleUrl: './coque.scss',
  host: { '(window:resize)': 'placerIndicateur()' },
})
export class Coque {
  private readonly session = inject(SessionService);
  private readonly pouls = inject(PoulsService);
  private readonly router = inject(Router);
  private readonly nav = viewChild.required<ElementRef<HTMLElement>>('nav');

  protected readonly groupes: GroupeMenu[] = [
    {
      cle: 'pilotage', titre: 'Pilotage',
      entrees: [
        { lien: '/tableau-de-bord', libelle: 'Tableau de bord', icone: 'accueil' },
        { lien: '/statistiques', libelle: 'Statistiques', icone: 'courbe' },
      ],
    },
    {
      cle: 'sante', titre: 'Santé animale',
      entrees: [
        {
          lien: '/signalements', libelle: 'Signalements', icone: 'orientation',
          pastille: { lire: (d) => d.casSansVeterinaire, ton: 'rouge', sens: (n) => `${n} cas sans vétérinaire` },
        },
        {
          lien: '/alertes', libelle: 'Alertes', icone: 'diffusion',
          pastille: { lire: (d) => d.alertesActives, ton: 'clair', sens: (n) => `${n} ${n > 1 ? 'alertes actives' : 'alerte active'}` },
        },
        { lien: '/maladies', libelle: 'Maladies', icone: 'triangle' },
      ],
    },
    {
      cle: 'comptes', titre: 'Comptes',
      entrees: [
        { lien: '/utilisateurs', libelle: 'Éleveurs', icone: 'utilisateur' },
        { lien: '/veterinaires', libelle: 'Vétérinaires', icone: 'bouclier' },
      ],
    },
    {
      cle: 'contenus', titre: 'Contenus',
      entrees: [
        {
          lien: '/conseils', libelle: 'Conseils', icone: 'document',
          pastille: { lire: (d) => d.conseilsEnModeration, ton: 'orange', sens: (n) => `${n} à modérer` },
        },
        { lien: '/types-elevage', libelle: "Types d'élevage", icone: 'patte' },
      ],
    },
  ];

  protected readonly nom = computed(() => this.session.session()?.nom || 'Administrateur');
  protected readonly email = computed(() => this.session.session()?.email ?? '');
  protected readonly initiales = computed(() => initiales(this.nom()));
  /** Position verticale de l'indicateur orange ; -1 = caché. */
  protected readonly indicateur = signal(-1);

  constructor() {
    this.pouls.demarrer();
    inject(DestroyRef).onDestroy(() => this.pouls.arreter());
    afterNextRender(() => this.placerIndicateur());
    this.router.events.pipe(filter((e) => e instanceof NavigationEnd)).subscribe(() => {
      // Après le rendu de routerLinkActive.
      setTimeout(() => this.placerIndicateur());
    });
  }

  protected compte(e: EntreeMenu): number | null {
    const d = this.pouls.donnees();
    const n = d && e.pastille ? e.pastille.lire(d) : 0;
    return n > 0 ? n : null;
  }

  protected placerIndicateur(): void {
    const nav = this.nav()?.nativeElement;
    const actif = nav?.querySelector<HTMLElement>('a.actif');
    if (!nav || !actif) {
      this.indicateur.set(-1);
      return;
    }
    this.indicateur.set(actif.getBoundingClientRect().top - nav.getBoundingClientRect().top + actif.offsetHeight / 2 - 10);
  }

  protected allerAuContenu(e: Event): void {
    e.preventDefault();
    document.getElementById('contenu')?.focus();
  }

  protected deconnecter(): void {
    this.session.deconnecter();
  }
}
