import { ChangeDetectionStrategy, Component, OnInit, computed, inject, input, signal } from '@angular/core';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { Observable, forkJoin, of } from 'rxjs';
import { ApiService } from '../../core/api.service';
import { messageErreur } from '../../core/erreurs';
import { libelleFiliere, libelleGravite } from '../../core/format';
import { FILIERES, Filiere, GRAVITES, MaladieAdmin, MaladieRequete, NiveauGravite, SymptomeReponse } from '../../core/modeles';
import { Icone } from '../../shared/icone';
import { Modale } from '../../shared/modale';
import { EnTete, Etat, Retour } from '../../shared/ui';
import { AvecSaisie } from '../../core/gardes';
import { AnnonceService } from '../../shared/annonce';
import { Champ } from '../../shared/champ';

/** Poids proposé quand on coche un symptôme. */
export const POIDS_PAR_DEFAUT = 0.5;

const MESSAGE_SANS_FILIERE = 'Indiquez au moins une filière concernée.';

/** Borne un poids saisi dans [0, 1], arrondi au centième. */
export function bornerPoids(valeur: unknown): number {
  const n = typeof valeur === 'number' ? valeur : parseFloat(String(valeur).replace(',', '.'));
  if (Number.isNaN(n)) {
    return 0;
  }
  return Math.round(Math.min(1, Math.max(0, n)) * 100) / 100;
}

/**
 * Écrans « Admin - Maladie creer » et « Admin - Maladie modifier »
 * (+ pop-up « Supprimer » = retrait logique).
 * GET/POST/PUT/DELETE /api/admin/maladies ; symptômes : GET /api/signalements/symptomes.
 */
@Component({
  selector: 'app-maladie-formulaire',
  imports: [ReactiveFormsModule, EnTete, Etat, Retour, Icone, Modale, Champ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './maladie-formulaire.html',
  styleUrl: './maladie-formulaire.scss',
})
export class MaladieFormulaire implements OnInit, AvecSaisie {
  private readonly api = inject(ApiService);
  private readonly router = inject(Router);
  private readonly annonces = inject(AnnonceService);
  /** Vrai une fois la page quittée volontairement. */
  private termine = false;
  /** Filières et poids changés depuis le chargement. */
  private touche = false;

  /** Absent sur /maladies/nouvelle. */
  readonly id = input<string>();

  protected readonly filieres = FILIERES;
  protected readonly gravites: NiveauGravite[] = [...GRAVITES].reverse();
  protected readonly libelleFiliere = libelleFiliere;
  protected readonly libelleGravite = libelleGravite;

  protected readonly maladie = signal<MaladieAdmin | null>(null);
  protected readonly symptomes = signal<SymptomeReponse[] | null>(null);
  protected readonly erreurChargement = signal<string | null>(null);
  protected readonly envoi = signal(false);
  protected readonly erreur = signal<string | null>(null);
  protected readonly popup = signal(false);

  protected readonly filieresCochees = signal<Set<Filiere>>(new Set());
  protected readonly sansFiliere = signal(false);
  /** symptomeId → poids (0..1) des symptômes cochés. */
  protected readonly poids = signal<Map<number, number>>(new Map());
  protected readonly filtreSymptomes = signal('');
  /** Saisie d'un symptôme absent de la liste. */
  protected readonly nouveauSymptome = signal('');
  protected readonly ajoutSymptome = signal(false);
  protected readonly erreurSymptome = signal<string | null>(null);

  protected readonly modification = computed(() => !!this.id());
  protected readonly pret = computed(() => this.symptomes() !== null && (!this.modification() || this.maladie() !== null));
  protected readonly symptomesAffiches = computed(() => {
    const terme = this.filtreSymptomes().trim().toLowerCase();
    const liste = this.symptomes() ?? [];
    return terme ? liste.filter((s) => s.libelle.toLowerCase().includes(terme) || this.poids().has(s.id)) : liste;
  });

  protected readonly formulaire = new FormGroup({
    nom: new FormControl('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(120)] }),
    gravite: new FormControl<NiveauGravite>('MOYEN', { nonNullable: true }),
    symptomesTexte: new FormControl('', { nonNullable: true, validators: [Validators.maxLength(1000)] }),
    traitement: new FormControl('', { nonNullable: true, validators: [Validators.maxLength(2000)] }),
    orienteVersVeterinaire: new FormControl(false, { nonNullable: true }),
  });

  constructor() {
    // Gravité élevée : l'application oriente directement vers un vétérinaire.
    this.formulaire.controls.gravite.valueChanges.subscribe((g) => {
      if (g === 'ELEVE') {
        this.formulaire.controls.orienteVersVeterinaire.setValue(true);
      }
    });
  }

  ngOnInit(): void {
    this.charger();
  }

  protected charger(): void {
    this.erreurChargement.set(null);
    const id = this.id();
    const maladie$: Observable<MaladieAdmin | null> = id ? this.api.maladie(+id) : of(null);
    forkJoin([this.api.symptomes(), maladie$]).subscribe({
      next: ([symptomes, m]) => {
        if (m) {
          this.formulaire.setValue({
            nom: m.nom,
            gravite: m.gravite,
            symptomesTexte: m.symptomesTexte ?? '',
            traitement: m.traitement ?? '',
            orienteVersVeterinaire: m.orienteVersVeterinaire,
          });
          this.filieresCochees.set(new Set(m.filieres));
          this.poids.set(new Map((m.symptomes ?? []).map((s) => [s.symptomeId, bornerPoids(s.poids)])));
          // Un symptôme pondéré absent de la liste (filtrée par le serveur) reste affiché.
          const connus = new Set(symptomes.map((s) => s.id));
          const manquants = (m.symptomes ?? [])
            .filter((s) => !connus.has(s.symptomeId))
            .map((s) => ({ id: s.symptomeId, libelle: s.libelle ?? `Symptôme n° ${s.symptomeId}` }));
          symptomes = [...symptomes, ...manquants];
          this.maladie.set(m);
        } else {
          this.formulaire.controls.orienteVersVeterinaire.setValue(false);
        }
        this.symptomes.set([...symptomes].sort((a, b) => a.libelle.localeCompare(b.libelle, 'fr')));
      },
      error: (e) => this.erreurChargement.set(messageErreur(e)),
    });
  }

  protected basculerFiliere(f: Filiere): void {
    const s = new Set(this.filieresCochees());
    if (s.has(f)) {
      s.delete(f);
    } else {
      s.add(f);
    }
    this.filieresCochees.set(s);
    this.touche = true;
    if (s.size) {
      this.sansFiliere.set(false);
      if (this.erreur() === MESSAGE_SANS_FILIERE) {
        this.erreur.set(null);
      }
    }
  }

  /** Crée le symptôme saisi (ou retrouve l'existant), puis le coche. */
  protected ajouterSymptome(): void {
    const libelle = this.nouveauSymptome().trim();
    if (!libelle || this.ajoutSymptome()) {
      return;
    }
    this.ajoutSymptome.set(true);
    this.erreurSymptome.set(null);
    this.api.creerSymptome(libelle).subscribe({
      next: (s) => {
        const liste = this.symptomes() ?? [];
        if (!liste.some((x) => x.id === s.id)) {
          this.symptomes.set([...liste, s].sort((a, b) => a.libelle.localeCompare(b.libelle, 'fr')));
        }
        if (!this.poids().has(s.id)) {
          const m = new Map(this.poids());
          m.set(s.id, POIDS_PAR_DEFAUT);
          this.poids.set(m);
          this.touche = true;
        }
        this.nouveauSymptome.set('');
        this.ajoutSymptome.set(false);
        this.annonces.annoncer(`Symptôme « ${s.libelle} » ajouté et coché.`);
      },
      error: (e) => {
        this.erreurSymptome.set(messageErreur(e));
        this.ajoutSymptome.set(false);
      },
    });
  }

  protected basculerSymptome(id: number): void {
    const m = new Map(this.poids());
    if (m.has(id)) {
      m.delete(id);
    } else {
      m.set(id, POIDS_PAR_DEFAUT);
    }
    this.touche = true;
    this.poids.set(m);
  }

  protected changerPoids(id: number, valeur: string): void {
    const m = new Map(this.poids());
    m.set(id, bornerPoids(valeur));
    this.touche = true;
    this.poids.set(m);
  }

  protected enregistrer(): void {
    const v = this.formulaire.getRawValue();
    if (this.formulaire.invalid || !v.nom.trim()) {
      this.formulaire.markAllAsTouched();
      this.erreur.set('Le nom de la maladie est obligatoire.');
      return;
    }
    if (!this.filieresCochees().size) {
      this.sansFiliere.set(true);
      this.erreur.set(MESSAGE_SANS_FILIERE);
      return;
    }
    if (!this.poids().size) {
      this.erreur.set('Cochez et pondérez au moins un symptôme : il alimente le diagnostic assisté.');
      return;
    }
    const requete: MaladieRequete = {
      nom: v.nom.trim(),
      gravite: v.gravite,
      filieres: FILIERES.filter((f) => this.filieresCochees().has(f)),
      symptomesTexte: v.symptomesTexte.trim(),
      traitement: v.traitement.trim(),
      orienteVersVeterinaire: v.orienteVersVeterinaire,
      symptomes: [...this.poids()].map(([symptomeId, poids]) => ({ symptomeId, poids })),
    };
    const id = this.id();
    this.envoi.set(true);
    this.erreur.set(null);
    (id ? this.api.modifierMaladie(+id, requete) : this.api.creerMaladie(requete)).subscribe({
      next: () => this.quitter(id ? 'Maladie enregistrée' : 'Maladie ajoutée au catalogue'),
      error: (e) => {
        this.envoi.set(false);
        this.erreur.set(messageErreur(e));
      },
    });
  }

  protected retirer(): void {
    const id = this.id();
    if (!id) {
      return;
    }
    this.envoi.set(true);
    this.erreur.set(null);
    this.api.retirerMaladie(+id).subscribe({
      next: () => this.quitter('Maladie retirée du catalogue'),
      error: (e) => {
        this.envoi.set(false);
        this.erreur.set(messageErreur(e));
      },
    });
  }

  protected reactiver(): void {
    const id = this.id();
    if (!id) {
      return;
    }
    this.envoi.set(true);
    this.erreur.set(null);
    this.api.reactiverMaladie(+id).subscribe({
      next: (m) => {
        this.envoi.set(false);
        this.maladie.set(m);
        this.annonces.annoncer('Maladie remise au catalogue');
      },
      error: (e) => {
        this.envoi.set(false);
        this.erreur.set(messageErreur(e));
      },
    });
  }

  protected annuler(): void {
    void this.router.navigateByUrl('/maladies');
  }

  saisieEnCours(): boolean {
    return !this.termine && (this.formulaire.dirty || this.touche);
  }

  private quitter(message: string): void {
    this.termine = true;
    this.annonces.annoncer(message);
    void this.router.navigateByUrl('/maladies');
  }
}
