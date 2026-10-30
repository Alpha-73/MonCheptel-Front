import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { AbstractControl, FormControl, FormGroup, ReactiveFormsModule, ValidationErrors, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { ApiService } from '../../core/api.service';
import { messageErreur } from '../../core/erreurs';
import { SessionService } from '../../core/session.service';
import { Oeil } from '../../shared/oeil';

function confirmationIdentique(groupe: AbstractControl): ValidationErrors | null {
  const ancien = groupe.get('ancien')?.value;
  const nouveau = groupe.get('nouveau')?.value;
  const confirmation = groupe.get('confirmation')?.value;
  if (nouveau && confirmation && nouveau !== confirmation) {
    return { differents: true };
  }
  return ancien && nouveau && ancien === nouveau ? { inchange: true } : null;
}

/**
 * Changement de mot de passe IMPOSÉ (`doitChangerMotDePasse`) : le compte
 * a reçu un mot de passe provisoire. Le back révoque toutes les sessions
 * après le changement : on se reconnecte donc aussitôt avec le nouveau.
 *
 * Les deux étapes sont distinctes (audit A7) : si seule la reconnexion
 * échoue, le mot de passe EST changé. On ne l'annonce donc pas comme un
 * échec : on renvoie à la connexion avec « Mot de passe changé ».
 */
@Component({
  selector: 'app-mot-de-passe',
  imports: [ReactiveFormsModule, Oeil],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './mot-de-passe.html',
  styleUrl: './connexion.scss',
})
export class MotDePasse {
  private readonly api = inject(ApiService);
  private readonly session = inject(SessionService);
  private readonly router = inject(Router);

  protected readonly envoi = signal(false);
  protected readonly erreur = signal<string | null>(null);

  protected readonly formulaire = new FormGroup(
    {
      ancien: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
      nouveau: new FormControl('', {
        nonNullable: true,
        validators: [Validators.required, Validators.minLength(8), Validators.maxLength(72)],
      }),
      confirmation: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
    },
    { validators: confirmationIdentique },
  );

  protected enregistrer(): void {
    if (this.formulaire.invalid) {
      this.formulaire.markAllAsTouched();
      this.erreur.set(
        this.formulaire.hasError('differents')
          ? 'La confirmation ne correspond pas au nouveau mot de passe.'
          : this.formulaire.hasError('inchange')
            ? 'Choisissez un mot de passe différent du mot de passe provisoire.'
            : 'Le nouveau mot de passe doit compter de 8 à 72 caractères.',
      );
      return;
    }
    const { ancien, nouveau } = this.formulaire.getRawValue();
    const email = this.session.session()?.email ?? '';
    this.envoi.set(true);
    this.erreur.set(null);
    this.api.changerMotDePasse(ancien, nouveau).subscribe({
      next: () => this.reconnecter(email, nouveau),
      error: (e) => {
        this.envoi.set(false);
        this.erreur.set(messageErreur(e, 'Le mot de passe n’a pas pu être changé.'));
      },
    });
  }

  /** Le mot de passe est changé : reconnexion, ou retour à la connexion si elle échoue. */
  private reconnecter(email: string, nouveau: string): void {
    this.api.connexion(email, nouveau).subscribe({
      next: (reponse) => {
        this.session.enregistrer(reponse, email);
        this.session.marquerMotDePasseChange();
        void this.router.navigateByUrl('/tableau-de-bord');
      },
      error: () => {
        this.session.effacer();
        void this.router.navigate(['/connexion'], { queryParams: { change: 1 } });
      },
    });
  }

  protected deconnecter(): void {
    this.session.deconnecter();
  }
}
