import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { chargement } from '../../core/chargement';
import { libelleFiliere, pluriel } from '../../core/format';
import { FILIERES, Filiere } from '../../core/modeles';
import { Icone } from '../../shared/icone';
import { LibellePipe, NombrePipe } from '../../shared/pipes';
import { EnTete, Etat, Filtre, OptionFiltre, OptionOnglet, Onglets, Recherche } from '../../shared/ui';
import {
  EstimationCouts,
  LIBELLES_DIFFICULTE,
  LIBELLES_MODE_EVALUATION,
  TypeElevageAdmin,
  TypesElevageApi,
  couleurDifficulte,
  estimerCouts,
} from './types-elevage.api';

interface LigneType {
  type: TypeElevageAdmin;
  couts: EstimationCouts;
}

/**
 * Écran « Admin - Référentiel » : GET /api/admin/types-elevage.
 * Les types retirés (`actif = false`) sont cachés par défaut ; l'onglet
 * « Retirés » les montre pour les remettre en service. Le coût affiché est
 * celui que le simulateur annoncerait pour la capacité de référence.
 */
@Component({
  selector: 'app-types-elevage-liste',
  imports: [RouterLink, EnTete, Etat, Filtre, Onglets, Recherche, Icone, LibellePipe, NombrePipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './types-elevage-liste.html',
  styleUrl: './types-elevage-liste.scss',
})
export class TypesElevageListe {
  private readonly api = inject(TypesElevageApi);

  protected readonly recherche = signal('');
  protected readonly filiere = signal<Filiere | null>(null);
  /** Deux onglets : les types en service, et les retirés à remettre en service. */
  protected readonly vue = signal<'ACTIFS' | 'RETIRES'>('ACTIFS');
  protected readonly optionsFiliere: OptionFiltre<Filiere>[] = FILIERES.map((f) => ({ valeur: f, libelle: libelleFiliere(f) }));

  protected readonly liste = chargement(() => this.api.liste());
  protected readonly libellesMode = LIBELLES_MODE_EVALUATION;
  protected readonly libellesDifficulte = LIBELLES_DIFFICULTE;
  protected readonly couleurDifficulte = couleurDifficulte;
  protected readonly pluriel = pluriel;

  protected readonly duStatut = computed(() =>
    (this.liste.donnees() ?? []).filter((t) => (this.vue() === 'RETIRES' ? !t.actif : t.actif)),
  );
  protected readonly onglets = computed<OptionOnglet<'ACTIFS' | 'RETIRES'>[]>(() => {
    const l = this.liste.donnees() ?? [];
    return [
      { valeur: 'ACTIFS', libelle: 'En service', compte: l.filter((t) => t.actif).length },
      { valeur: 'RETIRES', libelle: 'Retirés', compte: l.filter((t) => !t.actif).length },
    ];
  });
  protected readonly affiches = computed<LigneType[]>(() => {
    const terme = normaliser(this.recherche());
    return this.duStatut()
      .filter((t) => (!terme || normaliser(t.libelle).includes(terme)) && (!this.filiere() || t.filiere === this.filiere()))
      .sort((a, b) => FILIERES.indexOf(a.filiere) - FILIERES.indexOf(b.filiere) || a.libelle.localeCompare(b.libelle, 'fr'))
      .map((type) => ({ type, couts: estimerCouts(type) }));
  });

  constructor() {
    this.liste.charger();
  }
}

function normaliser(texte: string): string {
  return texte.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase().trim();
}
