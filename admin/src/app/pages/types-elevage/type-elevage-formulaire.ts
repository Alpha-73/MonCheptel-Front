import { HttpErrorResponse } from '@angular/common/http';
import { ChangeDetectionStrategy, Component, OnInit, computed, inject, input, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { FormArray, FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { Observable, map, of, switchMap } from 'rxjs';
import { messageErreur } from '../../core/erreurs';
import { libelleFiliere } from '../../core/format';
import { FILIERES, Filiere } from '../../core/modeles';
import { Icone } from '../../shared/icone';
import { Modale } from '../../shared/modale';
import { NombrePipe } from '../../shared/pipes';
import { EnTete, Etat, Retour } from '../../shared/ui';
import { AvecSaisie } from '../../core/gardes';
import { AnnonceService } from '../../shared/annonce';
import { Champ } from '../../shared/champ';
import {
  ACTES_PROTOCOLE,
  ActeProtocole,
  DIFFICULTES,
  EtapeProtocole,
  LIBELLES_ACTE,
  LIBELLES_DIFFICULTE,
  LIBELLES_MODE_EVALUATION,
  LIBELLES_MODE_QUANTITE,
  LIBELLES_PHASE,
  MODES_EVALUATION,
  MODES_QUANTITE,
  ModeEvaluation,
  ModeQuantite,
  NiveauDifficulte,
  PHASES_COUT,
  PhaseCout,
  PosteCout,
  TypeElevageAdmin,
  TypeElevageRequete,
  TypesElevageApi,
  couleurDifficulte,
  coutPoste,
  dureeCyclePourRequete,
  erreurCycle,
  estimerCouts,
  lireNombre,
  pourcentageDepuisTaux,
  tauxDepuisPourcentage,
} from './types-elevage.api';

type LignePoste = FormGroup<{
  libelle: FormControl<string>;
  montant: FormControl<number | null>;
  unite: FormControl<string>;
  phase: FormControl<PhaseCout>;
  modeQuantite: FormControl<ModeQuantite>;
  coefficient: FormControl<number | null>;
}>;

type LigneEtape = FormGroup<{
  id: FormControl<number | null>;
  libelle: FormControl<string>;
  typeEvenement: FormControl<ActeProtocole>;
  jourDuCycle: FormControl<number | null>;
  obligatoire: FormControl<boolean>;
}>;

function ligneEtape(e?: Partial<EtapeProtocole>): LigneEtape {
  return new FormGroup({
    id: new FormControl<number | null>(e?.id ?? null),
    libelle: new FormControl(e?.libelle ?? '', { nonNullable: true, validators: [Validators.required, Validators.maxLength(120)] }),
    typeEvenement: new FormControl<ActeProtocole>(e?.typeEvenement ?? 'VACCINATION', { nonNullable: true }),
    jourDuCycle: new FormControl<number | null>(e?.jourDuCycle ?? null, [Validators.required, Validators.min(0), Validators.max(3650)]),
    obligatoire: new FormControl(e?.obligatoire ?? true, { nonNullable: true }),
  });
}

function lignePoste(p?: Partial<PosteCout>): LignePoste {
  return new FormGroup({
    libelle: new FormControl(p?.libelle ?? '', { nonNullable: true, validators: [Validators.required, Validators.maxLength(80)] }),
    montant: new FormControl<number | null>(p?.montant ?? null, [Validators.required, Validators.min(0)]),
    unite: new FormControl(p?.unite ?? '', { nonNullable: true, validators: [Validators.maxLength(20)] }),
    phase: new FormControl<PhaseCout>(p?.phase ?? 'CYCLE', { nonNullable: true }),
    modeQuantite: new FormControl<ModeQuantite>(p?.modeQuantite ?? 'PAR_SUJET', { nonNullable: true }),
    coefficient: new FormControl<number | null>(p?.coefficient ?? 1, [Validators.required, Validators.min(0)]),
  });
}

/**
 * Écrans « Admin - Référentiel fiche » (création et modification)
 * (+ pop-ups « Retirer » = retrait réversible, POST …/{id}/retrait,
 * et « Supprimer » = suppression DÉFINITIVE, DELETE, refusée en 409 si un
 * élevage emploie le type).
 * GET/POST/PUT/DELETE /api/admin/types-elevage ; POST …/{id}/reactivation.
 * Les postes de coût sont renvoyés tous à chaque enregistrement : le serveur
 * les remplace en bloc, `ordre` = rang de la ligne.
 */
@Component({
  selector: 'app-type-elevage-formulaire',
  imports: [ReactiveFormsModule, EnTete, Etat, Retour, Icone, Modale, NombrePipe, Champ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './type-elevage-formulaire.html',
  styleUrl: './type-elevage-formulaire.scss',
})
export class TypeElevageFormulaire implements OnInit, AvecSaisie {
  private readonly api = inject(TypesElevageApi);
  private readonly router = inject(Router);
  private readonly annonces = inject(AnnonceService);
  /** Vrai une fois la page quittée volontairement. */
  private termine = false;

  /** Absent sur /types-elevage/nouveau. */
  readonly id = input<string>();

  protected readonly filieres = FILIERES;
  protected readonly modes = MODES_EVALUATION;
  protected readonly difficultes = DIFFICULTES;
  protected readonly phases = PHASES_COUT;
  protected readonly modesQuantite = MODES_QUANTITE;
  protected readonly libelleFiliere = libelleFiliere;
  protected readonly libellesMode = LIBELLES_MODE_EVALUATION;
  protected readonly libellesDifficulte = LIBELLES_DIFFICULTE;
  protected readonly libellesPhase = LIBELLES_PHASE;
  protected readonly libellesQuantite = LIBELLES_MODE_QUANTITE;
  protected readonly couleurDifficulte = couleurDifficulte;
  protected readonly actes = ACTES_PROTOCOLE;
  protected readonly libellesActe = LIBELLES_ACTE;

  protected readonly type = signal<TypeElevageAdmin | null>(null);
  protected readonly erreurChargement = signal<string | null>(null);
  protected readonly envoi = signal(false);
  protected readonly erreur = signal<string | null>(null);
  protected readonly popup = signal(false);
  /** Pop-up « Supprimer définitivement ». */
  protected readonly popupSuppression = signal(false);
  /** Protocole sanitaire : chargé à part, il ne retarde pas la fiche. */
  protected readonly protocoleCharge = signal(false);
  protected readonly erreurProtocole = signal<string | null>(null);
  protected readonly etapes = new FormArray<LigneEtape>([]);
  /** Hors du formulaire principal : le protocole s'enregistre à part (PUT …/protocole). */
  protected readonly formulaireEtapes = new FormGroup({ etapes: this.etapes });

  protected readonly modification = computed(() => !!this.id());
  protected readonly pret = computed(() => !this.modification() || this.type() !== null);

  protected readonly postes = new FormArray<LignePoste>([lignePoste()]);
  protected readonly formulaire = new FormGroup({
    libelle: new FormControl('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(80)] }),
    filiere: new FormControl<Filiere>('VOLAILLE', { nonNullable: true }),
    modeEvaluation: new FormControl<ModeEvaluation>('PAR_PERIODE', { nonNullable: true }),
    dureeCycleJours: new FormControl<number | null>(null, [Validators.min(1)]),
    capaciteReference: new FormControl<number | null>(null, [Validators.required, Validators.min(1)]),
    difficulte: new FormControl<NiveauDifficulte>('ACCESSIBLE', { nonNullable: true }),
    espaceParSujetM2: new FormControl<number | null>(null, [Validators.min(0)]),
    temperatureMin: new FormControl<number | null>(null),
    temperatureMax: new FormControl<number | null>(null),
    alimentParSujetKg: new FormControl<number | null>(null, [Validators.min(0)]),
    eauParSujetJourL: new FormControl<number | null>(null, [Validators.min(0)]),
    /** En % à l'écran (0–90), en fraction pour l'API. */
    mortalitePourcent: new FormControl<number | null>(null, [Validators.required, Validators.min(0), Validators.max(90)]),
    vaccinsObligatoires: new FormControl('', { nonNullable: true, validators: [Validators.maxLength(500)] }),
    postesCout: this.postes,
  });

  /** Valeur courante du formulaire, en signal, pour le chiffrage en direct. */
  private readonly valeur = toSignal(this.formulaire.valueChanges.pipe(map(() => this.formulaire.getRawValue())), {
    initialValue: this.formulaire.getRawValue(),
  });
  protected readonly parPeriode = computed(() => this.valeur().modeEvaluation === 'PAR_PERIODE');
  /** Ce que le simulateur annoncerait pour la capacité de référence. */
  protected readonly estimation = computed(() => {
    const v = this.valeur();
    return estimerCouts({
      filiere: v.filiere,
      capaciteReference: lireNombre(v.capaciteReference) ?? 0,
      tauxMortalite: tauxDepuisPourcentage(v.mortalitePourcent) ?? 0,
      postesCout: v.postesCout.map((p) => ({ ...p, montant: p.montant ?? 0, coefficient: p.coefficient ?? 0 })),
    });
  });
  protected readonly coutsLignes = computed(() => {
    const v = this.valeur();
    const achetes = this.estimation().sujetsAchetes;
    const capacite = lireNombre(v.capaciteReference) ?? 0;
    return v.postesCout.map((p) => coutPoste({ ...p, montant: p.montant ?? 0, coefficient: p.coefficient ?? 0 }, achetes, capacite));
  });

  constructor() {
    // Par entrée : pas de durée de cycle, le champ masqué est vidé.
    this.formulaire.controls.modeEvaluation.valueChanges.subscribe((m) => {
      if (m === 'PAR_ENTREE') {
        this.formulaire.controls.dureeCycleJours.setValue(null);
      }
    });
  }

  ngOnInit(): void {
    this.charger();
  }

  protected charger(): void {
    const id = this.id();
    if (!id) {
      return;
    }
    this.erreurChargement.set(null);
    this.api.lire(+id).subscribe({
      next: (t) => {
        this.remplir(t);
        this.type.set(t);
      },
      error: (e) => this.erreurChargement.set(messageErreur(e)),
    });
    this.chargerProtocole();
  }

  protected chargerProtocole(): void {
    const id = this.id();
    if (!id) {
      this.protocoleCharge.set(true);
      return;
    }
    this.erreurProtocole.set(null);
    this.api.protocole(+id).subscribe({
      next: (etapes) => {
        this.etapes.clear();
        etapes.forEach((e) => this.etapes.push(ligneEtape(e)));
        this.etapes.markAsPristine();
        this.protocoleCharge.set(true);
      },
      error: (e) => this.erreurProtocole.set(messageErreur(e)),
    });
  }

  // ── Protocole sanitaire ─────────────────────────────────────────────

  protected ajouterEtape(): void {
    const derniere = this.etapes.at(this.etapes.length - 1)?.getRawValue();
    this.etapes.push(ligneEtape({ typeEvenement: derniere?.typeEvenement ?? 'VACCINATION' }));
    this.etapes.markAsDirty();
  }

  protected supprimerEtape(i: number): void {
    this.etapes.removeAt(i);
    this.etapes.markAsDirty();
  }

  private remplir(t: TypeElevageAdmin): void {
    this.postes.clear({ emitEvent: false });
    [...(t.postesCout ?? [])].sort((a, b) => a.ordre - b.ordre).forEach((p) => this.postes.push(lignePoste(p), { emitEvent: false }));
    this.formulaire.setValue({
      libelle: t.libelle,
      filiere: t.filiere,
      modeEvaluation: t.modeEvaluation,
      dureeCycleJours: t.dureeCycleJours ?? null,
      capaciteReference: t.capaciteReference,
      difficulte: t.difficulte,
      espaceParSujetM2: lireNombre(t.espaceParSujetM2),
      temperatureMin: t.temperatureMin ?? null,
      temperatureMax: t.temperatureMax ?? null,
      alimentParSujetKg: lireNombre(t.alimentParSujetKg),
      eauParSujetJourL: lireNombre(t.eauParSujetJourL),
      mortalitePourcent: pourcentageDepuisTaux(t.tauxMortalite),
      vaccinsObligatoires: t.vaccinsObligatoires ?? '',
      postesCout: this.postes.getRawValue(),
    });
  }

  // ── Postes de coût ──────────────────────────────────────────────────

  protected ajouterPoste(): void {
    // La nouvelle ligne reprend la phase de la précédente : on saisit souvent par bloc.
    const derniere = this.postes.at(this.postes.length - 1)?.getRawValue();
    this.postes.push(lignePoste({ phase: derniere?.phase ?? 'CYCLE' }));
  }

  protected supprimerPoste(i: number): void {
    this.postes.removeAt(i);
  }

  protected deplacerPoste(i: number, sens: -1 | 1): void {
    const j = i + sens;
    if (j < 0 || j >= this.postes.length) {
      return;
    }
    const ligne = this.postes.at(i);
    this.postes.removeAt(i, { emitEvent: false });
    this.postes.insert(j, ligne);
  }

  // ── Enregistrement ──────────────────────────────────────────────────

  /** Premier problème bloquant, dans l'ordre de l'écran ; null si tout est prêt. */
  private probleme(): string | null {
    const c = this.formulaire.controls;
    const v = this.formulaire.getRawValue();
    if (!v.libelle.trim() || c.libelle.invalid) {
      return 'Le libellé est obligatoire (80 caractères au plus).';
    }
    const cycle = erreurCycle(v.modeEvaluation, v.dureeCycleJours);
    if (cycle) {
      return cycle;
    }
    if (c.capaciteReference.invalid || !Number.isInteger(v.capaciteReference)) {
      return 'La capacité de référence est un nombre entier de sujets, au moins 1.';
    }
    if (tauxDepuisPourcentage(v.mortalitePourcent) === null) {
      return 'Le taux de mortalité prévisionnel se saisit en %, entre 0 et 90.';
    }
    if (v.temperatureMin !== null && v.temperatureMax !== null && v.temperatureMin > v.temperatureMax) {
      return 'La température minimale dépasse la température maximale.';
    }
    if (c.espaceParSujetM2.invalid || c.alimentParSujetKg.invalid || c.eauParSujetJourL.invalid) {
      return "Les conditions d'élevage ne peuvent pas être négatives.";
    }
    if (c.vaccinsObligatoires.invalid) {
      return 'Les vaccins obligatoires tiennent en 500 caractères.';
    }
    const etapeFautive = this.etapes.controls.findIndex((e) => e.invalid || !e.controls.libelle.value.trim());
    if (etapeFautive >= 0) {
      return `Étape n° ${etapeFautive + 1} du protocole : libellé et jour (0 ou plus) sont obligatoires.`;
    }
    const v0 = this.formulaire.getRawValue();
    const cycle0 = v0.modeEvaluation === 'PAR_PERIODE' ? v0.dureeCycleJours : null;
    const tardive = cycle0 ? this.etapes.getRawValue().findIndex((e) => (e.jourDuCycle ?? 0) > cycle0) : -1;
    if (tardive >= 0) {
      return `Étape n° ${tardive + 1} du protocole : elle tombe après la fin du cycle (${cycle0} jours).`;
    }
    if (!this.postes.length) {
      return 'Ajoutez au moins un poste de coût : sans eux, le simulateur chiffrerait ce type à zéro.';
    }
    const fautif = this.postes.controls.findIndex((p) => p.invalid || !p.controls.libelle.value.trim());
    if (fautif >= 0) {
      return `Poste n° ${fautif + 1} : libellé, montant et coefficient sont obligatoires, et positifs.`;
    }
    return null;
  }

  protected enregistrer(): void {
    const probleme = this.probleme();
    if (probleme) {
      this.formulaire.markAllAsTouched();
      this.erreur.set(probleme);
      return;
    }
    const v = this.formulaire.getRawValue();
    const requete: TypeElevageRequete = {
      filiere: v.filiere,
      libelle: v.libelle.trim(),
      modeEvaluation: v.modeEvaluation,
      dureeCycleJours: dureeCyclePourRequete(v.modeEvaluation, v.dureeCycleJours),
      capaciteReference: v.capaciteReference!,
      espaceParSujetM2: v.espaceParSujetM2,
      temperatureMin: v.temperatureMin,
      temperatureMax: v.temperatureMax,
      alimentParSujetKg: v.alimentParSujetKg,
      eauParSujetJourL: v.eauParSujetJourL,
      vaccinsObligatoires: v.vaccinsObligatoires.trim() || null,
      tauxMortalite: tauxDepuisPourcentage(v.mortalitePourcent)!,
      difficulte: v.difficulte,
      postesCout: v.postesCout.map((p, ordre) => ({
        libelle: p.libelle.trim(),
        montant: Math.round(p.montant ?? 0),
        unite: p.unite.trim(),
        phase: p.phase,
        modeQuantite: p.modeQuantite,
        coefficient: p.coefficient ?? 0,
        ordre,
      })),
    };
    const id = this.id();
    this.envoi.set(true);
    this.erreur.set(null);
    const protocoleAEnvoyer = this.etapes.dirty || (!id && this.etapes.length > 0);
    const etapes: EtapeProtocole[] = this.etapes.getRawValue().map((e) => ({
      id: e.id,
      libelle: e.libelle.trim(),
      typeEvenement: e.typeEvenement,
      jourDuCycle: e.jourDuCycle ?? 0,
      obligatoire: e.obligatoire,
    }));
    let cree: number | null = null;
    (id ? this.api.modifier(+id, requete) : this.api.creer(requete))
      .pipe(
        switchMap((t): Observable<TypeElevageAdmin> => {
          cree = id ? null : t.id;
          return protocoleAEnvoyer ? this.api.remplacerProtocole(t.id, etapes).pipe(map(() => t)) : of(t);
        }),
      )
      .subscribe({
      next: () => this.quitter(id ? 'Type enregistré' : 'Type ajouté au référentiel'),
      error: (e) => {
        if (cree !== null) {
          // Le type existe déjà : on ouvre sa fiche pour corriger le protocole, sans le recréer.
          this.termine = true;
          this.annonces.annoncer(`Type ajouté, mais le protocole est refusé : ${messageErreur(e)}`, 8000);
          void this.router.navigate(['/types-elevage', cree]);
          return;
        }
        this.envoi.set(false);
        this.erreur.set(
          e instanceof HttpErrorResponse && e.status === 409
            ? messageErreur(e, `Un type « ${requete.libelle} » existe déjà en ${libelleFiliere(requete.filiere)}.`)
            : messageErreur(e),
        );
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
    this.api.retirer(+id).subscribe({
      next: () => this.quitter('Type retiré du référentiel'),
      error: (e) => {
        this.envoi.set(false);
        this.erreur.set(messageErreur(e));
      },
    });
  }

  protected supprimer(): void {
    const id = this.id();
    if (!id) {
      return;
    }
    this.envoi.set(true);
    this.erreur.set(null);
    this.api.supprimer(+id).subscribe({
      next: () => this.quitter('Type supprimé définitivement'),
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
    this.api.reactiver(+id).subscribe({
      next: (t) => {
        this.envoi.set(false);
        this.type.set(t);
        this.annonces.annoncer('Type remis en service');
      },
      error: (e) => {
        this.envoi.set(false);
        this.erreur.set(messageErreur(e));
      },
    });
  }

  protected annuler(): void {
    void this.router.navigateByUrl('/types-elevage');
  }

  saisieEnCours(): boolean {
    return !this.termine && (this.formulaire.dirty || this.etapes.dirty);
  }

  private quitter(message: string): void {
    this.termine = true;
    this.annonces.annoncer(message);
    void this.router.navigateByUrl('/types-elevage');
  }
}
