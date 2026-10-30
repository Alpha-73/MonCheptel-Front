import { ChangeDetectionStrategy, Component, OnInit, computed, inject, input, signal } from '@angular/core';
import { FormControl, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { ApiService } from '../../core/api.service';
import { messageErreur } from '../../core/erreurs';
import { formaterDateLongue, libelleFiliere, desEleveursConcernes, pluriel, jourIso } from '../../core/format';
import { AlerteReponse } from '../../core/modeles';
import { Modale } from '../../shared/modale';
import { EnTete, Etat, Retour } from '../../shared/ui';
import { AnnonceService } from '../../shared/annonce';
import { Champ } from '../../shared/champ';
import { PoulsService } from '../../core/pouls.service';

/**
 * Écran « Admin - Alerte modifier » (+ pop-up « Clôturer »).
 * Le message et la date de fin sont modifiables (PUT /api/admin/alertes/{id}) : maladie,
 * filière et zone sont figées au déclenchement (la portée en dépend).
 * GET /api/admin/alertes/{id} pour la lire.
 */
@Component({
  selector: 'app-alerte-modifier',
  imports: [ReactiveFormsModule, EnTete, Etat, Retour, Modale, Champ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './alerte-modifier.html',
})
export class AlerteModifier implements OnInit {
  private readonly api = inject(ApiService);
  private readonly router = inject(Router);
  private readonly annonces = inject(AnnonceService);
  private readonly pouls = inject(PoulsService);

  readonly id = input.required<string>();

  protected readonly alerte = signal<AlerteReponse | null>(null);
  protected readonly erreurChargement = signal<string | null>(null);
  protected readonly envoi = signal(false);
  protected readonly erreur = signal<string | null>(null);
  protected readonly popup = signal(false);
  protected readonly pluriel = pluriel;
  protected readonly desEleveursConcernes = desEleveursConcernes;
  protected readonly libelleFiliere = libelleFiliere;

  protected readonly message = new FormControl('', {
    nonNullable: true,
    validators: [Validators.required, Validators.maxLength(500)],
  });

  protected readonly dateFin = new FormControl('', { nonNullable: true });
  protected readonly aujourdhui = jourIso();

  protected readonly sousTitre = computed(() => {
    const a = this.alerte();
    if (!a) {
      return null;
    }
    const touches = pluriel(a.portee, 'éleveur touché', 'éleveurs touchés');
    return a.statut === 'ACTIVE'
      ? `Alerte active depuis le ${formaterDateLongue(a.dateDeclenchement, false)} · ${touches}`
      : `Alerte terminée · déclenchée le ${formaterDateLongue(a.dateDeclenchement, false)} · ${touches}`;
  });

  ngOnInit(): void {
    this.charger();
  }

  protected charger(): void {
    this.erreurChargement.set(null);
    this.api.alerte(+this.id()).subscribe({
      next: (a) => {
        this.message.setValue(a.message);
        this.dateFin.setValue(a.dateFin ?? '');
        if (a.statut !== 'ACTIVE') {
          this.message.disable();
          this.dateFin.disable();
        }
        this.alerte.set(a);
      },
      error: (e) => this.erreurChargement.set(messageErreur(e)),
    });
  }

  protected enregistrer(): void {
    const a = this.alerte();
    if (!a) {
      return;
    }
    if (this.message.invalid || !this.message.value.trim()) {
      this.message.markAsTouched();
      this.erreur.set('Le message est obligatoire (500 caractères au plus).');
      return;
    }
    if (this.dateFin.value && this.dateFin.value < this.aujourdhui) {
      this.erreur.set('La date de fin ne peut pas être passée.');
      return;
    }
    this.envoi.set(true);
    this.erreur.set(null);
    this.api.modifierAlerte(a.id, this.message.value.trim(), this.dateFin.value || null).subscribe({
      next: () => {
        this.annonces.annoncer('Alerte mise à jour');
        void this.router.navigateByUrl('/alertes');
      },
      error: (e) => {
        this.envoi.set(false);
        this.erreur.set(messageErreur(e));
      },
    });
  }

  protected cloturer(): void {
    const a = this.alerte();
    if (!a) {
      return;
    }
    this.envoi.set(true);
    this.erreur.set(null);
    this.api.cloturerAlerte(a.id).subscribe({
      next: () => {
        this.annonces.annoncer(`Alerte ${a.maladie} — ${a.zone} terminée`);
        this.pouls.charger();
        void this.router.navigateByUrl('/alertes');
      },
      error: (e) => {
        this.envoi.set(false);
        this.erreur.set(messageErreur(e));
      },
    });
  }

  protected annuler(): void {
    void this.router.navigateByUrl('/alertes');
  }
}
