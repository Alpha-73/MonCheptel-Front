import { ChangeDetectionStrategy, Component, OnInit, WritableSignal, computed, inject, input, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { Observable, catchError, concat, forkJoin, last, map, of, switchMap, toArray } from 'rxjs';
import { ApiService } from '../../core/api.service';
import { messageErreur } from '../../core/erreurs';
import { MaladieAdmin, VeterinaireAdmin, VeterinaireRequete } from '../../core/modeles';
import { Icone } from '../../shared/icone';
import { Modale } from '../../shared/modale';
import { EnTete, Etat, Retour } from '../../shared/ui';
import { nomVeterinaire } from './veterinaire-nom';
import { AvecSaisie } from '../../core/gardes';
import { AnnonceService } from '../../shared/annonce';
import { Champ } from '../../shared/champ';

/**
 * Écrans « Admin - Veterinaire creer » et « Admin - Veterinaire modifier »
 * (+ pop-up « Désactiver »). Même formulaire : la route `:id` le passe en
 * modification.
 *
 * Création : POST /api/admin/veterinaires puis une requête par compétence
 * cochée (POST …/competences/{maladieId}). Modification : PUT, puis
 * POST/DELETE des seules compétences qui ont changé.
 */
@Component({
  selector: 'app-veterinaire-formulaire',
  imports: [ReactiveFormsModule, EnTete, Etat, Retour, Icone, Modale, Champ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './veterinaire-formulaire.html',
})
export class VeterinaireFormulaire implements OnInit, AvecSaisie {
  private readonly api = inject(ApiService);
  private readonly router = inject(Router);
  private readonly annonces = inject(AnnonceService);
  /** Vrai une fois la page quittée volontairement (enregistrement, annulation). */
  private termine = false;

  /** Absent sur /veterinaires/nouveau. */
  readonly id = input<string>();

  protected readonly zones = toSignal(this.api.zones().pipe(catchError(() => of([]))), { initialValue: [] });
  protected readonly maladies = signal<MaladieAdmin[] | null>(null);
  protected readonly veterinaire = signal<VeterinaireAdmin | null>(null);
  protected readonly erreurChargement = signal<string | null>(null);
  protected readonly coches = signal<Set<number>>(new Set());
  protected readonly envoi = signal(false);
  protected readonly erreur = signal<string | null>(null);
  protected readonly popup = signal(false);
  protected readonly suppression = signal(false);
  protected readonly reinit = signal(false);
  protected readonly information = signal<string | null>(null);

  /** Identifiant du compte une fois créé (ou en modification). */
  private readonly idCourant = signal<number | null>(null);
  /** Compétences telles qu'enregistrées côté serveur. */
  private competencesServeur = new Set<number>();

  protected readonly modification = computed(() => !!this.id());
  protected readonly pret = computed(() => this.maladies() !== null && (!this.modification() || this.veterinaire() !== null));
  protected readonly nomAffiche = computed(() => {
    const v = this.veterinaire();
    return v ? nomVeterinaire(v) : '';
  });

  protected readonly formulaire = new FormGroup({
    nom: new FormControl('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(120)] }),
    telephone: new FormControl('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(20)] }),
    email: new FormControl('', { nonNullable: true, validators: [Validators.required, Validators.email, Validators.maxLength(160)] }),
    zoneInterventionId: new FormControl<number | null>(null, { validators: [Validators.required] }),
    titre: new FormControl('Dr', { nonNullable: true, validators: [Validators.maxLength(60)] }),
    specialite: new FormControl('', { nonNullable: true, validators: [Validators.maxLength(120)] }),
  });

  ngOnInit(): void {
    this.charger();
  }

  protected charger(): void {
    this.erreurChargement.set(null);
    const id = this.id();
    const veterinaire$: Observable<VeterinaireAdmin | null> = id ? this.api.veterinaire(+id) : of(null);
    forkJoin([this.api.maladies(), veterinaire$]).subscribe({
      next: ([maladies, v]) => {
        if (v) {
          this.formulaire.setValue({
            nom: v.nom,
            telephone: v.telephone ?? '',
            email: v.email ?? '',
            zoneInterventionId: v.zoneIntervention?.id ?? v.zone?.id ?? null,
            titre: v.titre ?? '',
            specialite: v.specialite ?? '',
          });
          this.competencesServeur = new Set(v.competences ?? []);
          this.coches.set(new Set(this.competencesServeur));
          this.idCourant.set(v.id);
          this.veterinaire.set(v);
        }
        // Le catalogue actif, plus toute maladie retirée encore cochée.
        this.maladies.set(maladies.filter((m) => m.active || this.competencesServeur.has(m.id)));
      },
      error: (e) => this.erreurChargement.set(messageErreur(e)),
    });
  }

  /** Garde de sortie (A19) : une saisie ou une compétence changée et non enregistrée. */
  saisieEnCours(): boolean {
    if (this.termine) return false;
    const c = this.coches();
    const competencesChangees = c.size !== this.competencesServeur.size || [...c].some((m) => !this.competencesServeur.has(m));
    return this.formulaire.dirty || competencesChangees;
  }

  protected ouvrir(fenetre: WritableSignal<boolean>): void {
    this.erreur.set(null);
    this.information.set(null);
    fenetre.set(true);
  }

  private quitter(message?: string): void {
    this.termine = true;
    if (message) this.annonces.annoncer(message);
    void this.router.navigateByUrl('/veterinaires');
  }

  protected basculer(id: number): void {
    const s = new Set(this.coches());
    if (s.has(id)) {
      s.delete(id);
    } else {
      s.add(id);
    }
    this.coches.set(s);
  }

  protected enregistrer(): void {
    if (this.formulaire.invalid) {
      this.formulaire.markAllAsTouched();
      this.erreur.set('Renseignez le nom, le téléphone, une adresse e-mail valide et la zone d’intervention.');
      return;
    }
    const v = this.formulaire.getRawValue();
    const existant = this.veterinaire();
    const requete: VeterinaireRequete = {
      nom: v.nom.trim(),
      telephone: v.telephone.trim(),
      email: v.email.trim(),
      zoneInterventionId: v.zoneInterventionId!,
      // La maquette n'a qu'un champ « Zone d'intervention » : à la création,
      // la zone de rattachement est la même ; en modification on garde l'existante.
      zoneId: existant?.zone?.id ?? v.zoneInterventionId!,
      titre: v.titre.trim() || undefined,
      specialite: v.specialite.trim() || undefined,
    };
    const id = this.idCourant();
    const compte$ = id ? this.api.modifierVeterinaire(id, requete) : this.api.creerVeterinaire(requete);

    this.envoi.set(true);
    this.erreur.set(null);
    compte$
      .pipe(
        switchMap((compte) => {
          this.idCourant.set(compte.id);
          return this.synchroniserCompetences(compte.id);
        }),
      )
      .subscribe({
        next: () => this.quitter(id ? 'Modifications enregistrées' : 'Compte vétérinaire créé'),
        error: (e) => {
          this.envoi.set(false);
          const prefixe = this.idCourant() && !id ? 'Le compte a été créé, mais ' : '';
          this.erreur.set(prefixe + messageErreur(e));
        },
      });
  }

  /** Ajoute / retire une à une les compétences qui ont changé (en séquence). */
  private synchroniserCompetences(veterinaireId: number): Observable<void> {
    const voulues = this.coches();
    const ajouts = [...voulues].filter((m) => !this.competencesServeur.has(m));
    const retraits = [...this.competencesServeur].filter((m) => !voulues.has(m));
    const requetes = [
      ...ajouts.map((m) => this.api.ajouterCompetence(veterinaireId, m).pipe(map(() => (this.competencesServeur.add(m), void 0)))),
      ...retraits.map((m) => this.api.retirerCompetence(veterinaireId, m).pipe(map(() => (this.competencesServeur.delete(m), void 0)))),
    ];
    if (!requetes.length) {
      return of(undefined);
    }
    return concat(...requetes).pipe(toArray(), last(), map(() => undefined));
  }

  protected changerActivation(actif: boolean): void {
    const id = this.idCourant();
    if (!id) {
      return;
    }
    this.envoi.set(true);
    this.erreur.set(null);
    this.api.changerActivation(id, actif).subscribe({
      next: () => {
        this.popup.set(false);
        if (actif) {
          this.envoi.set(false);
          this.veterinaire.update((v) => (v ? { ...v, actif: true } : v));
        } else {
          this.quitter('Compte désactivé');
        }
      },
      error: (e) => {
        this.envoi.set(false);
        this.erreur.set(messageErreur(e));
      },
    });
  }

  protected reinitialiser(): void {
    const id = this.idCourant();
    if (!id) {
      return;
    }
    this.envoi.set(true);
    this.erreur.set(null);
    this.api.reinitialiserMotDePasse(id).subscribe({
      next: () => {
        this.envoi.set(false);
        this.reinit.set(false);
        this.information.set('Mot de passe provisoire envoyé par e-mail.');
      },
      error: (e) => {
        this.envoi.set(false);
        this.erreur.set(messageErreur(e));
      },
    });
  }

  /** Suppression définitive, après confirmation → liste. */
  protected supprimer(): void {
    const id = this.idCourant();
    if (!id) {
      return;
    }
    this.envoi.set(true);
    this.erreur.set(null);
    this.api.supprimerUtilisateur(id).subscribe({
      next: () => this.quitter('Compte supprimé'),
      error: (e) => {
        this.envoi.set(false);
        this.erreur.set(messageErreur(e));
      },
    });
  }

  protected annuler(): void {
    this.quitter();
  }
}
