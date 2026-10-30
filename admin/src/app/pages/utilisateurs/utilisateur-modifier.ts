import { ChangeDetectionStrategy, Component, OnInit, inject, input, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { catchError, of } from 'rxjs';
import { ApiService } from '../../core/api.service';
import { messageErreur } from '../../core/erreurs';
import { libelleFiliere, libelleLangue } from '../../core/format';
import { FILIERES, Filiere, LANGUES, Langue, ProfilReponse } from '../../core/modeles';
import { Icone } from '../../shared/icone';
import { EnTete, Etat, Retour } from '../../shared/ui';
import { Champ } from '../../shared/champ';
import { AnnonceService } from '../../shared/annonce';

/**
 * Écran « Admin - Utilisateur modifier ».
 * Lecture : GET /api/admin/utilisateurs/{id}/fiche ; écriture : PUT /api/admin/utilisateurs/{id}.
 * L'adresse e-mail (obligatoire dans ProfilRequete) n'est pas dans la
 * maquette : elle est renvoyée telle quelle.
 */
@Component({
  selector: 'app-utilisateur-modifier',
  imports: [ReactiveFormsModule, EnTete, Etat, Retour, Icone, Champ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './utilisateur-modifier.html',
})
export class UtilisateurModifier implements OnInit {
  private readonly api = inject(ApiService);
  private readonly router = inject(Router);

  readonly id = input.required<string>();

  protected readonly filieres = FILIERES;
  protected readonly langues = LANGUES;
  protected readonly libelleFiliere = libelleFiliere;
  protected readonly libelleLangue = libelleLangue;
  protected readonly zones = toSignal(this.api.zones().pipe(catchError(() => of([]))), { initialValue: [] });

  protected readonly profil = signal<ProfilReponse | null>(null);
  protected readonly erreurChargement = signal<string | null>(null);
  protected readonly envoi = signal(false);
  protected readonly erreur = signal<string | null>(null);
  protected readonly coches = signal<Set<Filiere>>(new Set());
  /** Message du serveur, repris côté client (A10). */
  protected readonly sansFiliere = signal(false);
  private readonly annonces = inject(AnnonceService);

  protected readonly formulaire = new FormGroup({
    nom: new FormControl('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(120)] }),
    email: new FormControl('', { nonNullable: true, validators: [Validators.required, Validators.email, Validators.maxLength(160)] }),
    telephone: new FormControl('', { nonNullable: true, validators: [Validators.maxLength(20)] }),
    zoneId: new FormControl<number | null>(null, { validators: [Validators.required] }),
    langue: new FormControl<Langue>('FR', { nonNullable: true }),
  });

  ngOnInit(): void {
    this.charger();
  }

  protected charger(): void {
    this.erreurChargement.set(null);
    this.api.ficheUtilisateur(+this.id()).subscribe({
      next: (fiche) => {
        const p = fiche.profil;
        this.formulaire.setValue({
          nom: p.nom ?? '',
          email: p.email ?? '',
          telephone: p.telephone ?? '',
          zoneId: p.zone?.id ?? null,
          langue: p.langue ?? 'FR',
        });
        this.coches.set(new Set(p.filieresPratiquees ?? []));
        this.profil.set(p);
      },
      error: (e) => this.erreurChargement.set(messageErreur(e)),
    });
  }

  protected basculer(f: Filiere): void {
    const s = new Set(this.coches());
    if (s.has(f)) {
      s.delete(f);
    } else {
      s.add(f);
    }
    this.coches.set(s);
    if (s.size) this.sansFiliere.set(false);
  }

  protected enregistrer(): void {
    const p = this.profil();
    if (!p) {
      return;
    }
    if (this.formulaire.invalid) {
      this.formulaire.markAllAsTouched();
      this.erreur.set('Le nom, une adresse e-mail valide et la zone sont obligatoires.');
      return;
    }
    if (!this.coches().size) {
      this.sansFiliere.set(true);
      this.erreur.set('Indiquez au moins une filière.');
      return;
    }
    const v = this.formulaire.getRawValue();
    this.envoi.set(true);
    this.erreur.set(null);
    this.api
      .modifierUtilisateur(p.id, {
        nom: v.nom.trim(),
        email: v.email.trim(),
        telephone: v.telephone.trim(),
        zoneId: v.zoneId!,
        langue: v.langue,
        filieres: FILIERES.filter((f) => this.coches().has(f)),
      })
      .subscribe({
        next: () => {
          this.annonces.annoncer('Modifications enregistrées');
          void this.router.navigate(['/utilisateurs', p.id]);
        },
        error: (e) => {
          this.envoi.set(false);
          this.erreur.set(messageErreur(e));
        },
      });
  }

  protected annuler(): void {
    void this.router.navigate(['/utilisateurs', this.id()]);
  }
}
