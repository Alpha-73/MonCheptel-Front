import { ChangeDetectionStrategy, Component, OnInit, WritableSignal, computed, effect, inject, input, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { ApiService } from '../../core/api.service';
import { chargement } from '../../core/chargement';
import { messageErreur } from '../../core/erreurs';
import { formaterDateLongue, initiales, libelleRole, pluriel } from '../../core/format';
import { AnnonceService } from '../../shared/annonce';
import { Icone } from '../../shared/icone';
import { Modale } from '../../shared/modale';
import { DateCourtePipe, DateLonguePipe, LibellePipe, NombrePipe } from '../../shared/pipes';
import { EnTete, Etat, Retour } from '../../shared/ui';

/**
 * Écran « Admin - Utilisateur fiche » (+ pop-up « Désactiver »).
 * GET /api/admin/utilisateurs/{id}/fiche ; POST …/activation?actif=.
 */
@Component({
  selector: 'app-utilisateur-fiche',
  imports: [RouterLink, EnTete, Etat, Retour, Icone, Modale, NombrePipe, DateCourtePipe, DateLonguePipe, LibellePipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './utilisateur-fiche.html',
  styleUrl: './utilisateur-fiche.scss',
})
export class UtilisateurFiche implements OnInit {
  private readonly api = inject(ApiService);
  private readonly router = inject(Router);
  private readonly annonces = inject(AnnonceService);

  /** Paramètre de route `:id`. */
  readonly id = input.required<string>();

  protected readonly fiche = chargement(() => this.api.ficheUtilisateur(+this.id()));
  protected readonly initiales = initiales;
  protected readonly pluriel = pluriel;

  protected readonly popup = signal(false);
  protected readonly suppression = signal(false);
  protected readonly reinit = signal(false);
  /** Confirmation affichée après l'envoi du mot de passe provisoire. */
  protected readonly information = signal<string | null>(null);
  protected readonly envoi = signal(false);
  protected readonly erreurAction = signal<string | null>(null);

  protected readonly sousTitre = computed(() => {
    const f = this.fiche.donnees();
    return f ? `${libelleRole(f.profil.role)} · ${f.profil.zone?.nom ?? 'sans zone'} · inscrit le ${formaterDateLongue(f.profil.dateInscription)}` : null;
  });

  constructor() {
    // Un vétérinaire se gère depuis son écran (A30).
    effect(() => {
      const f = this.fiche.donnees();
      if (f?.profil.role === 'VETERINAIRE') {
        void this.router.navigate(['/veterinaires', f.profil.id], { replaceUrl: true });
      }
    });
  }

  ngOnInit(): void {
    this.fiche.charger();
  }

  /** Ouvre une fenêtre avec une erreur remise à zéro (A29). */
  protected ouvrir(fenetre: WritableSignal<boolean>): void {
    this.erreurAction.set(null);
    this.information.set(null);
    fenetre.set(true);
  }

  /** « Désactiver le compte » → liste ; la réactivation reste sur la fiche. */
  protected changerActivation(actif: boolean): void {
    this.envoi.set(true);
    this.erreurAction.set(null);
    this.api.changerActivation(+this.id(), actif).subscribe({
      next: () => {
        this.envoi.set(false);
        this.popup.set(false);
        if (actif) {
          this.annonces.annoncer('Compte réactivé');
          this.fiche.charger();
        } else {
          this.annonces.annoncer('Compte désactivé');
          void this.router.navigateByUrl('/utilisateurs');
        }
      },
      error: (e) => {
        this.envoi.set(false);
        this.erreurAction.set(messageErreur(e));
      },
    });
  }

  protected reinitialiser(): void {
    this.envoi.set(true);
    this.erreurAction.set(null);
    this.api.reinitialiserMotDePasse(+this.id()).subscribe({
      next: () => {
        this.envoi.set(false);
        this.reinit.set(false);
        this.information.set('Mot de passe provisoire envoyé par e-mail.');
        this.fiche.charger();
      },
      error: (e) => {
        this.envoi.set(false);
        this.erreurAction.set(messageErreur(e));
      },
    });
  }

  /** Suppression définitive, après confirmation → liste. */
  protected supprimer(): void {
    this.envoi.set(true);
    this.erreurAction.set(null);
    this.api.supprimerUtilisateur(+this.id()).subscribe({
      next: () => {
        this.annonces.annoncer('Compte supprimé');
        void this.router.navigateByUrl('/utilisateurs');
      },
      error: (e) => {
        this.envoi.set(false);
        this.erreurAction.set(messageErreur(e));
      },
    });
  }
}
