import { ChangeDetectionStrategy, Component, computed, effect, inject, signal, untracked } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { RouterLink } from '@angular/router';
import { catchError, of } from 'rxjs';
import { ApiService } from '../../core/api.service';
import { chargement } from '../../core/chargement';
import { libelleFiliere } from '../../core/format';
import { FILIERES, Filiere } from '../../core/modeles';
import { FilieresPipe, InitialesPipe } from '../../shared/pipes';
import { EnTete, Etat, Filtre, OptionFiltre, Pagination, Recherche } from '../../shared/ui';

/**
 * Écran « Admin - Utilisateurs liste » : éleveurs inscrits.
 * GET /api/admin/utilisateurs?recherche=&filiere=&zoneId=&actif=&page=
 * (recherche, filtres et pagination côté serveur, 10 par page).
 */
@Component({
  selector: 'app-utilisateurs-liste',
  imports: [RouterLink, EnTete, Etat, Filtre, Pagination, Recherche, FilieresPipe, InitialesPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './utilisateurs-liste.html',
})
export class UtilisateursListe {
  private readonly api = inject(ApiService);

  protected readonly recherche = signal('');
  protected readonly filiere = signal<Filiere | null>(null);
  protected readonly zoneId = signal<number | null>(null);
  protected readonly actif = signal<boolean | null>(null);
  protected readonly page = signal(0);

  protected readonly optionsFiliere: OptionFiltre<Filiere>[] = FILIERES.map((f) => ({ valeur: f, libelle: libelleFiliere(f) }));
  protected readonly optionsStatut: OptionFiltre<boolean>[] = [
    { valeur: true, libelle: 'Actif' },
    { valeur: false, libelle: 'Désactivé' },
  ];
  private readonly zones = toSignal(this.api.zones().pipe(catchError(() => of([]))), { initialValue: [] });
  protected readonly optionsZone = computed<OptionFiltre<number>[]>(() =>
    this.zones().map((z) => ({ valeur: z.id, libelle: z.nom })),
  );

  protected readonly liste = chargement(() =>
    this.api.utilisateurs({
      recherche: this.recherche(),
      filiere: this.filiere(),
      zoneId: this.zoneId(),
      actif: this.actif(),
      page: this.page(),
    }),
  );

  private minuterie?: ReturnType<typeof setTimeout>;

  constructor() {
    // Les filtres relancent la requête ; la saisie est temporisée (300 ms).
    effect(() => {
      this.recherche();
      this.filiere();
      this.zoneId();
      this.actif();
      this.page();
      untracked(() => {
        clearTimeout(this.minuterie);
        this.minuterie = setTimeout(() => this.liste.charger(), this.liste.donnees() ? 300 : 0);
      });
    });
  }

  /** Tout changement de filtre ramène à la première page. */
  protected filtrer(action: () => void): void {
    action();
    this.page.set(0);
  }
}
