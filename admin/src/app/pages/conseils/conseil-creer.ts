import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { ApiService } from '../../core/api.service';
import { messageErreur } from '../../core/erreurs';
import { libelleFiliere } from '../../core/format';
import { CATEGORIES, CategorieConseil, FILIERES, Filiere } from '../../core/modeles';
import { EnTete, Retour } from '../../shared/ui';
import { AnnonceService } from '../../shared/annonce';
import { Champ } from '../../shared/champ';

/** Libellés de catégorie du formulaire (la maquette écrit « Santé animale »). */
export const LIBELLES_CATEGORIE_FORMULAIRE: Record<CategorieConseil, string> = {
  SANTE: 'Santé animale',
  PRODUCTION: 'Production',
  HYGIENE: 'Hygiène',
};

/**
 * Écran « Admin - Conseil creer » : POST /api/admin/conseils, publié
 * directement (sans modération).
 */
@Component({
  selector: 'app-conseil-creer',
  imports: [ReactiveFormsModule, EnTete, Retour, Champ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './conseil-creer.html',
})
export class ConseilCreer {
  private readonly api = inject(ApiService);
  private readonly router = inject(Router);
  private readonly annonces = inject(AnnonceService);

  protected readonly filieres = FILIERES;
  protected readonly categories = CATEGORIES;
  protected readonly libelleFiliere = libelleFiliere;
  protected readonly libelleCategorie = LIBELLES_CATEGORIE_FORMULAIRE;

  protected readonly envoi = signal(false);
  protected readonly erreur = signal<string | null>(null);

  protected readonly formulaire = new FormGroup({
    filiere: new FormControl<Filiere>('VOLAILLE', { nonNullable: true }),
    categorie: new FormControl<CategorieConseil>('SANTE', { nonNullable: true }),
    titre: new FormControl('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(160)] }),
    contenu: new FormControl('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(10000)] }),
  });

  protected publier(): void {
    const v = this.formulaire.getRawValue();
    if (this.formulaire.invalid || !v.titre.trim() || !v.contenu.trim()) {
      this.formulaire.markAllAsTouched();
      this.erreur.set('Le titre et le contenu sont obligatoires.');
      return;
    }
    this.envoi.set(true);
    this.erreur.set(null);
    this.api.creerConseil({ ...v, titre: v.titre.trim(), contenu: v.contenu.trim() }).subscribe({
      next: () => {
        this.annonces.annoncer('Conseil publié');
        void this.router.navigateByUrl('/conseils?statut=PUBLIE');
      },
      error: (e) => {
        this.envoi.set(false);
        this.erreur.set(messageErreur(e));
      },
    });
  }

  protected annuler(): void {
    void this.router.navigateByUrl('/conseils');
  }
}
