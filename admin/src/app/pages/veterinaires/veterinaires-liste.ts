import { ChangeDetectionStrategy, Component, computed, effect, inject, signal, untracked } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { RouterLink } from '@angular/router';
import { catchError, of } from 'rxjs';
import { ApiService } from '../../core/api.service';
import { chargement } from '../../core/chargement';
import { libelleFiliere, pluriel } from '../../core/format';
import { FILIERES, Filiere, VeterinaireAdmin } from '../../core/modeles';
import { Icone } from '../../shared/icone';
import { FilieresPipe, InitialesPipe } from '../../shared/pipes';
import { EnTete, Etat, Filtre, OptionFiltre, Pagination, Recherche } from '../../shared/ui';
import { nomVeterinaire } from './veterinaire-nom';

/**
 * Écran « Admin - Vétérinaires liste ».
 * GET /api/admin/veterinaires?zoneId= ; recherche et filière filtrées ici
 * (la route ne les prend pas). 10 par page, comme les éleveurs.
 */
@Component({
  selector: 'app-veterinaires-liste',
  imports: [RouterLink, EnTete, Etat, Filtre, Pagination, Recherche, Icone, FilieresPipe, InitialesPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './veterinaires-liste.html',
  styles: `
    .dispo { display: inline-flex; align-items: center; gap: 7px; font-size: 13px; font-weight: 700; color: var(--gris); }
    .dispo::before { content: ''; width: 9px; height: 9px; border-radius: 50%; background: #a9a59c; }
    .dispo.oui { color: var(--vert); }
    .dispo.oui::before { background: var(--gravite-faible); box-shadow: 0 0 0 3px rgba(42, 140, 110, .18); }
  `,
})
export class VeterinairesListe {
  private readonly api = inject(ApiService);

  protected readonly recherche = signal('');
  protected readonly zoneId = signal<number | null>(null);
  protected readonly filiere = signal<Filiere | null>(null);

  protected readonly optionsFiliere: OptionFiltre<Filiere>[] = FILIERES.map((f) => ({ valeur: f, libelle: libelleFiliere(f) }));
  private readonly zones = toSignal(this.api.zones().pipe(catchError(() => of([]))), { initialValue: [] });
  protected readonly optionsZone = computed<OptionFiltre<number>[]>(() =>
    this.zones().map((z) => ({ valeur: z.id, libelle: z.nom })),
  );

  protected readonly liste = chargement(() => this.api.veterinaires(this.zoneId()));
  protected readonly nomVeterinaire = nomVeterinaire;
  protected readonly pluriel = pluriel;

  protected readonly taillePage = TAILLE_PAGE;
  protected readonly page = signal(0);

  protected readonly filtres = computed<VeterinaireAdmin[]>(() => {
    const terme = normaliser(this.recherche());
    const filiere = this.filiere();
    return (this.liste.donnees() ?? []).filter(
      (v) =>
        (!terme || normaliser(`${nomVeterinaire(v)} ${v.email ?? ''} ${v.telephone ?? ''}`).includes(terme)) &&
        (!filiere || v.filieres?.includes(filiere)),
    );
  });

  /** La page courante des vétérinaires filtrés. */
  protected readonly affiches = computed(() => {
    const debut = this.page() * TAILLE_PAGE;
    return this.filtres().slice(debut, debut + TAILLE_PAGE);
  });

  constructor() {
    effect(() => {
      this.zoneId();
      untracked(() => this.liste.charger());
    });
    // Tout changement de critère ramène à la première page.
    effect(() => {
      this.recherche();
      this.zoneId();
      this.filiere();
      untracked(() => this.page.set(0));
    });
  }
}

const TAILLE_PAGE = 10;

function normaliser(texte: string): string {
  return texte.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase().trim();
}
