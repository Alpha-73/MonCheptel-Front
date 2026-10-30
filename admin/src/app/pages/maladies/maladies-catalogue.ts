import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { ApiService } from '../../core/api.service';
import { chargement } from '../../core/chargement';
import { couleurGravite, libelleFiliere, libelleGravite, pluriel } from '../../core/format';
import { FILIERES, Filiere, GRAVITES, MaladieAdmin, NiveauGravite } from '../../core/modeles';
import { Icone } from '../../shared/icone';
import { FilieresPipe, LibellePipe } from '../../shared/pipes';
import { EnTete, Etat, Filtre, OptionFiltre, OptionOnglet, Onglets, Recherche } from '../../shared/ui';

/**
 * Écran « Admin - Maladies catalogue » : GET /api/admin/maladies.
 * Les maladies retirées (retrait logique, `active = false`) sont cachées par
 * défaut ; l'onglet « Retirées » les montre pour les réactiver. Recherche et
 * filtres côté client.
 */
@Component({
  selector: 'app-maladies-catalogue',
  imports: [RouterLink, EnTete, Etat, Filtre, Onglets, Recherche, Icone, FilieresPipe, LibellePipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './maladies-catalogue.html',
  styles: `
    .nom { font-weight: 800; color: var(--titre); }
    .nom + .badge { margin-left: 8px; }
    .symptomes { max-width: 340px; color: var(--gris); font-size: 13px; }
    .nowrap { white-space: nowrap; }
    .auteur { color: var(--gris); font-size: 13px; margin-top: 2px; }
    tr.retiree td { color: var(--gris); }
  `,
})
export class MaladiesCatalogue {
  private readonly api = inject(ApiService);

  protected readonly recherche = signal('');
  protected readonly filiere = signal<Filiere | null>(null);
  protected readonly gravite = signal<NiveauGravite | null>(null);
  /** Deux onglets, plus d'option fantôme « Tous » (A15). */
  protected readonly vue = signal<'CATALOGUE' | 'RETIREES'>('CATALOGUE');
  protected readonly optionsFiliere: OptionFiltre<Filiere>[] = FILIERES.map((f) => ({ valeur: f, libelle: libelleFiliere(f) }));
  protected readonly optionsGravite: OptionFiltre<NiveauGravite>[] = [...GRAVITES]
    .reverse()
    .map((g) => ({ valeur: g, libelle: libelleGravite(g) }));

  protected readonly liste = chargement(() => this.api.maladies(true));
  protected readonly couleurGravite = couleurGravite;
  protected readonly pluriel = pluriel;

  protected readonly duStatut = computed(() =>
    (this.liste.donnees() ?? []).filter((m) => (this.vue() === 'RETIREES' ? m.active === false : m.active !== false)),
  );
  protected readonly onglets = computed<OptionOnglet<'CATALOGUE' | 'RETIREES'>[]>(() => {
    const l = this.liste.donnees() ?? [];
    return [
      { valeur: 'CATALOGUE', libelle: 'Au catalogue', compte: l.filter((m) => m.active !== false).length },
      { valeur: 'RETIREES', libelle: 'Retirées', compte: l.filter((m) => m.active === false).length },
    ];
  });
  protected readonly affichees = computed<MaladieAdmin[]>(() => {
    const terme = normaliser(this.recherche());
    return this.duStatut().filter(
      (m) =>
        (!terme || normaliser(`${m.nom} ${m.symptomesTexte ?? ''}`).includes(terme)) &&
        (!this.filiere() || m.filieres.includes(this.filiere()!)) &&
        (!this.gravite() || m.gravite === this.gravite()),
    );
  });

  constructor() {
    this.liste.charger();
  }
}

function normaliser(texte: string): string {
  return texte.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase().trim();
}
