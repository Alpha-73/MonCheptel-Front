import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { ApiService } from '../../core/api.service';
import { chargement } from '../../core/chargement';
import { messageErreur } from '../../core/erreurs';
import { couleurStatutAlerte, desEleveursConcernes, pluriel } from '../../core/format';
import { AlerteReponse } from '../../core/modeles';
import { Icone } from '../../shared/icone';
import { Modale } from '../../shared/modale';
import { DateCourtePipe, LibellePipe } from '../../shared/pipes';
import { EnTete, Etat, OptionOnglet, Onglets } from '../../shared/ui';
import { AnnonceService } from '../../shared/annonce';
import { PoulsService } from '../../core/pouls.service';

/**
 * Écran « Admin - Alertes liste » (+ pop-up « Clôturer »).
 * GET /api/admin/alertes ; POST /api/admin/alertes/{id}/cloture.
 */
@Component({
  selector: 'app-alertes-liste',
  imports: [RouterLink, EnTete, Etat, Icone, Modale, Onglets, DateCourtePipe, LibellePipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './alertes-liste.html',
  styleUrl: './alertes.scss',
})
export class AlertesListe {
  private readonly api = inject(ApiService);
  private readonly annonces = inject(AnnonceService);
  private readonly pouls = inject(PoulsService);

  protected readonly liste = chargement(() => this.api.alertes());
  protected readonly couleurStatut = couleurStatutAlerte;
  protected readonly pluriel = pluriel;
  protected readonly desEleveursConcernes = desEleveursConcernes;

  /** Deux onglets : les alertes en cours, et l'historique. */
  protected readonly vue = signal<'ACTIVES' | 'TERMINEES'>('ACTIVES');
  /** De la plus récente à la plus ancienne, dans l'onglet choisi. */
  protected readonly triees = computed(() =>
    (this.liste.donnees() ?? [])
      .filter((a) => (this.vue() === 'ACTIVES') === (a.statut === 'ACTIVE'))
      .sort((a, b) => b.dateDeclenchement.localeCompare(a.dateDeclenchement)),
  );
  protected readonly actives = computed(() => (this.liste.donnees() ?? []).filter((a) => a.statut === 'ACTIVE').length);
  protected readonly onglets = computed<OptionOnglet<'ACTIVES' | 'TERMINEES'>[]>(() => {
    const l = this.liste.donnees();
    return [
      { valeur: 'ACTIVES', libelle: 'Actives', compte: l ? this.actives() : undefined },
      { valeur: 'TERMINEES', libelle: 'Terminées', compte: l ? l.length - this.actives() : undefined },
    ];
  });
  protected readonly sousTitre = computed(() => {
    if (!this.liste.donnees()) {
      return 'Alertes sanitaires de la plateforme';
    }
    const n = this.actives();
    return n === 0 ? 'Aucune alerte active sur la plateforme' : `${pluriel(n, 'alerte active', 'alertes actives')} sur la plateforme`;
  });

  protected readonly aCloturer = signal<AlerteReponse | null>(null);
  protected readonly envoi = signal(false);
  protected readonly erreurAction = signal<string | null>(null);

  constructor() {
    this.liste.charger();
  }

  protected demanderCloture(a: AlerteReponse): void {
    this.erreurAction.set(null);
    this.aCloturer.set(a);
  }

  protected cloturer(a: AlerteReponse): void {
    this.envoi.set(true);
    this.erreurAction.set(null);
    this.api.cloturerAlerte(a.id).subscribe({
      next: (maj) => {
        this.envoi.set(false);
        this.aCloturer.set(null);
        this.liste.donnees.update((l) => (l ? l.map((x) => (x.id === maj.id ? maj : x)) : l));
        this.annonces.annoncer(`Alerte ${maj.maladie} — ${maj.zone} terminée`);
        this.pouls.charger();
      },
      error: (e) => {
        this.envoi.set(false);
        this.erreurAction.set(messageErreur(e));
      },
    });
  }
}
