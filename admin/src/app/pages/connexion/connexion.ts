import { ChangeDetectionStrategy, Component, inject, input, signal } from '@angular/core';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { ApiService } from '../../core/api.service';
import { messageErreur } from '../../core/erreurs';
import { MESSAGE_ROLE_REFUSE, SessionService } from '../../core/session.service';
import { Oeil } from '../../shared/oeil';

/**
 * Écran « Admin - Connexion » (absent de l'export SVG) : même charte que la
 * console — panneau vert foncé au logo clair, formulaire sur le sable.
 */
@Component({
  selector: 'app-connexion',
  imports: [ReactiveFormsModule, Oeil],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './connexion.html',
  styleUrl: './connexion.scss',
})
export class Connexion {
  private readonly api = inject(ApiService);
  private readonly session = inject(SessionService);
  private readonly router = inject(Router);

  /** Paramètres d'URL posés par la garde ou le renouvellement de session. */
  readonly expiree = input<string>();
  readonly refuse = input<string>();
  /** Posé après un changement de mot de passe dont la reconnexion a échoué. */
  readonly change = input<string>();

  protected readonly envoi = signal(false);
  protected readonly erreur = signal<string | null>(null);

  protected readonly formulaire = new FormGroup({
    email: new FormControl('', { nonNullable: true, validators: [Validators.required, Validators.email] }),
    motDePasse: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
  });

  protected messageInitial(): string | null {
    if (this.refuse()) {
      return MESSAGE_ROLE_REFUSE;
    }
    return this.expiree() ? 'Votre session a expiré. Reconnectez-vous pour continuer.' : null;
  }

  protected seConnecter(): void {
    if (this.formulaire.invalid) {
      this.formulaire.markAllAsTouched();
      this.erreur.set('Renseignez une adresse e-mail valide et votre mot de passe.');
      return;
    }
    const { email, motDePasse } = this.formulaire.getRawValue();
    this.envoi.set(true);
    this.erreur.set(null);
    this.api.connexion(email.trim(), motDePasse).subscribe({
      next: (reponse) => {
        this.envoi.set(false);
        if (reponse.role !== 'ADMINISTRATEUR') {
          // Compte valide mais pas administrateur : on ferme aussitôt la session ouverte.
          this.session.revoquer(reponse.jetonRafraichissement);
          this.erreur.set(MESSAGE_ROLE_REFUSE);
          return;
        }
        this.session.enregistrer(reponse, email.trim().toLowerCase());
        void this.router.navigateByUrl(reponse.doitChangerMotDePasse ? '/mot-de-passe' : '/tableau-de-bord');
      },
      error: (e) => {
        this.envoi.set(false);
        this.erreur.set(messageErreur(e, 'Connexion impossible.'));
      },
    });
  }
}
