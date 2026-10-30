import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { takeUntilDestroyed, toSignal } from '@angular/core/rxjs-interop';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { catchError, debounceTime, map, of, startWith, switchMap } from 'rxjs';
import { ApiService } from '../../core/api.service';
import { chargement } from '../../core/chargement';
import { messageErreur } from '../../core/erreurs';
import { libelleFiliere, libellesFilieres, pluriel, jourIso } from '../../core/format';
import { ApercuAlerte, FILIERES, Filiere } from '../../core/modeles';
import { DateLonguePipe, NombrePipe } from '../../shared/pipes';
import { Modale } from '../../shared/modale';
import { EnTete, Etat, Retour } from '../../shared/ui';
import { AnnonceService } from '../../shared/annonce';
import { Champ } from '../../shared/champ';
import { PoulsService } from '../../core/pouls.service';

/** Message proposé par défaut (texte de la maquette), modifiable. */
export const MESSAGE_ALERTE_PAR_DEFAUT =
  "Épidémie signalée dans votre zone. Évitez les mouvements d'animaux et contactez un vétérinaire.";

type Apercu = { etat: 'attente' } | { etat: 'chargement' } | { etat: 'ok'; valeur: ApercuAlerte } | { etat: 'erreur'; message: string };

/**
 * Écran « Admin - Alerte declencher ».
 * Portée recalculée en direct : GET /api/admin/alertes/apercu ;
 * envoi : POST /api/admin/alertes.
 */
@Component({
  selector: 'app-alerte-declencher',
  imports: [ReactiveFormsModule, EnTete, Etat, Retour, Modale, NombrePipe, DateLonguePipe, Champ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './alerte-declencher.html',
  styleUrl: './alertes.scss',
})
export class AlerteDeclencher {
  private readonly api = inject(ApiService);
  private readonly router = inject(Router);
  private readonly annonces = inject(AnnonceService);
  private readonly pouls = inject(PoulsService);

  protected readonly libelleFiliere = libelleFiliere;
  protected readonly pluriel = pluriel;
  protected readonly zones = toSignal(this.api.zones().pipe(catchError(() => of([]))), { initialValue: [] });
  protected readonly maladies = chargement(() => this.api.maladies().pipe(map((l) => l.filter((m) => m.active !== false))));

  protected readonly formulaire = new FormGroup({
    maladieId: new FormControl<number | null>(null, { validators: [Validators.required] }),
    filiere: new FormControl<Filiere | null>(null),
    zoneId: new FormControl<number | null>(null, { validators: [Validators.required] }),
    message: new FormControl(MESSAGE_ALERTE_PAR_DEFAUT, {
      nonNullable: true,
      validators: [Validators.required, Validators.maxLength(500)],
    }),
    /** Dernier jour, facultatif : l'alerte se clôt d'elle-même le lendemain. */
    dateFin: new FormControl('', { nonNullable: true }),
  });
  protected readonly aujourdhui = jourIso();

  private readonly valeurs = toSignal(this.formulaire.valueChanges.pipe(startWith(this.formulaire.getRawValue())), {
    initialValue: this.formulaire.getRawValue(),
  });

  /** Filières de la maladie choisie : une alerte ne vise qu'elles (A1). */
  protected readonly filieresMaladie = computed<Filiere[]>(() => {
    const id = this.valeurs().maladieId;
    const m = this.maladies.donnees()?.find((x) => x.id === id);
    return m ? FILIERES.filter((f) => m.filieres.includes(f)) : [];
  });
  /** « Toutes ses filières (Ovins, Caprins) ». */
  protected readonly libelleToutes = computed(() => {
    const f = this.filieresMaladie();
    return f.length ? `Toutes ses filières (${libellesFilieres(f)})` : 'Toutes ses filières';
  });

  /** « éleveurs de volaille à Bamako ». */
  protected readonly cible = computed(() => {
    const v = this.valeurs();
    const zone = this.zones().find((z) => z.id === v.zoneId)?.nom;
    const filieres = v.filiere ? [v.filiere] : this.filieresMaladie();
    const de = filieres.length ? ` · ${libellesFilieres(filieres).toLowerCase()}` : '';
    return `éleveurs${zone ? ' à ' + zone : ''}${de}`;
  });

  protected readonly apercu = signal<Apercu>({ etat: 'attente' });
  protected readonly envoi = signal(false);
  protected readonly confirmation = signal(false);
  protected readonly erreur = signal<string | null>(null);

  constructor() {
    this.maladies.charger();

    // Choisir une maladie propose sa filière si elle n'en touche qu'une ;
    // sinon toutes les filières, pour ne laisser aucun éleveur concerné de côté.
    this.formulaire.controls.maladieId.valueChanges.pipe(takeUntilDestroyed()).subscribe((id) => {
      const m = this.maladies.donnees()?.find((x) => x.id === id);
      this.formulaire.controls.filiere.setValue(m?.filieres?.length === 1 ? m.filieres[0] : null);
    });

    // Aperçu de la portée, recalculé à chaque changement (temporisé).
    this.formulaire.valueChanges
      .pipe(
        map(() => this.formulaire.getRawValue()),
        map((v) => ({ maladieId: v.maladieId, zoneId: v.zoneId, filiere: v.filiere })),
        debounceTime(250),
        switchMap((v) => {
          if (!v.maladieId || !v.zoneId) {
            return of<Apercu>({ etat: 'attente' });
          }
          this.apercu.set({ etat: 'chargement' });
          return this.api.apercuAlerte(v.maladieId, v.zoneId, v.filiere).pipe(
            map((valeur): Apercu => ({ etat: 'ok', valeur })),
            catchError((e) => of<Apercu>({ etat: 'erreur', message: messageErreur(e) })),
          );
        }),
        takeUntilDestroyed(),
      )
      .subscribe((a) => this.apercu.set(a));
  }

  /** Le formulaire est complet : on demande confirmation avant d'envoyer. */
  protected declencher(): void {
    const v = this.formulaire.getRawValue();
    if (v.dateFin && v.dateFin < this.aujourdhui) {
      this.erreur.set('La date de fin ne peut pas être passée.');
      return;
    }
    if (this.formulaire.invalid || !v.message.trim()) {
      this.formulaire.markAllAsTouched();
      this.erreur.set('Choisissez la maladie et la zone, et rédigez le message envoyé aux éleveurs.');
      return;
    }
    this.erreur.set(null);
    this.confirmation.set(true);
  }

  /** Nombre d'éleveurs ciblés, si l'aperçu est connu. */
  protected readonly cibles = computed(() => {
    const a = this.apercu();
    return a.etat === 'ok' ? a.valeur.eleveursCibles : null;
  });

  protected envoyer(): void {
    const v = this.formulaire.getRawValue();
    this.envoi.set(true);
    this.erreur.set(null);
    this.api
      .declencherAlerte({ maladieId: v.maladieId!, zoneId: v.zoneId!, filiere: v.filiere, message: v.message.trim(), dateFin: v.dateFin || null })
      .subscribe({
        next: (a) => {
          this.annonces.annoncer(`Alerte déclenchée : ${pluriel(a.portee, 'éleveur prévenu', 'éleveurs prévenus')}`, 6000);
          this.pouls.charger();
          void this.router.navigateByUrl('/alertes');
        },
        error: (e) => {
          this.envoi.set(false);
          this.confirmation.set(false);
          this.erreur.set(messageErreur(e));
        },
      });
  }

  protected annuler(): void {
    void this.router.navigateByUrl('/alertes');
  }
}
