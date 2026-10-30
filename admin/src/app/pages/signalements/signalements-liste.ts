import { ChangeDetectionStrategy, Component, computed, effect, inject, signal, untracked } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { chargement } from '../../core/chargement';
import { messageErreur } from '../../core/erreurs';
import { couleurGravite, depuis } from '../../core/format';
import { Modale } from '../../shared/modale';
import { DateCourtePipe, LibellePipe } from '../../shared/pipes';
import { EnTete, Etat, OptionOnglet, Onglets, Pagination } from '../../shared/ui';
import { AnnonceService } from '../../shared/annonce';
import { PoulsService } from '../../core/pouls.service';
import {
  CandidatVeterinaire,
  SignalementAdmin,
  SignalementsApi,
  VUES,
  VueSignalements,
  argumentsCandidat,
  resumeRefus,
  candidatConseille,
  lireVue,
} from './signalements.api';

/**
 * Écran « Signalements » : tous les cas de la plateforme, et l'attribution
 * manuelle d'un cas à un vétérinaire précis.
 * GET /api/admin/signalements?vue=&page= ; GET …/{id}/candidats ;
 * POST …/{id}/orientation.
 *
 * L'orientation automatique reste la règle. On attribue à la main quand
 * personne ne couvre la zone, ou qu'un confrère est mieux placé.
 */
@Component({
  selector: 'app-signalements-liste',
  imports: [RouterLink, EnTete, Etat, Modale, Onglets, Pagination, DateCourtePipe, LibellePipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './signalements-liste.html',
  styleUrl: './signalements-liste.scss',
})
export class SignalementsListe {
  private readonly api = inject(SignalementsApi);
  private readonly router = inject(Router);
  private readonly annonces = inject(AnnonceService);
  private readonly pouls = inject(PoulsService);

  protected readonly vue = signal<VueSignalements>(lireVue(inject(ActivatedRoute).snapshot.queryParamMap.get('vue')));
  /** Onglets, avec le compte des cas qui attendent l'administration (pouls de la console). */
  protected readonly onglets = computed<OptionOnglet<VueSignalements>[]>(() => {
    const d = this.pouls.donnees();
    return VUES.map((v) => ({
      ...v,
      compte: v.valeur === 'A_ATTRIBUER' ? d?.casSansVeterinaire : v.valeur === 'ORIENTES' ? d?.orientesEnAttente : undefined,
      alerte: v.valeur === 'A_ATTRIBUER',
    }));
  });
  protected readonly libelleVue = computed(() => VUES.find((v) => v.valeur === this.vue())?.libelle ?? '');
  protected readonly page = signal(0);
  protected readonly liste = chargement(() => this.api.liste(this.vue(), this.page()));

  protected readonly couleurGravite = couleurGravite;
  protected readonly depuis = depuis;
  protected readonly argumentsCandidat = argumentsCandidat;
  protected readonly resumeRefus = resumeRefus;

  /** Fenêtre « Attribuer ». */
  protected readonly cas = signal<SignalementAdmin | null>(null);
  protected readonly candidats = signal<CandidatVeterinaire[] | null>(null);
  protected readonly choisi = signal<number | null>(null);
  protected readonly envoi = signal(false);
  protected readonly erreurAction = signal<string | null>(null);
  /** Candidat présélectionné : marqué « conseillé ». */
  protected readonly conseille = signal<number | null>(null);

  constructor() {
    effect(() => {
      this.vue();
      this.page();
      untracked(() => this.liste.charger());
    });
  }

  protected changerVue(v: VueSignalements): void {
    if (v === this.vue()) {
      return;
    }
    this.vue.set(v);
    this.page.set(0);
    void this.router.navigate([], { queryParams: { vue: v === 'TOUS' ? null : v }, replaceUrl: true });
  }

  protected ouvrirAttribution(s: SignalementAdmin): void {
    this.cas.set(s);
    this.candidats.set(null);
    this.choisi.set(null);
    this.erreurAction.set(null);
    this.api.candidats(s.id).subscribe({
      next: (l) => {
        this.candidats.set(l);
        // Le mieux placé est présélectionné, sauf s'il suit déjà le cas ou s'il est indisponible.
        const c = candidatConseille(l)?.id ?? null;
        this.conseille.set(c);
        this.choisi.set(c);
      },
      error: (e) => this.erreurAction.set(messageErreur(e)),
    });
  }

  protected fermer(): void {
    this.cas.set(null);
  }

  protected attribuer(): void {
    const s = this.cas();
    const v = this.choisi();
    if (!s || v === null) {
      return;
    }
    this.envoi.set(true);
    this.erreurAction.set(null);
    this.api.attribuer(s.id, v).subscribe({
      next: (maj) => {
        this.envoi.set(false);
        this.cas.set(null);
        this.annonces.annoncer(`Cas de ${maj.eleveurNom} confié à ${maj.veterinaireNom}, prévenu par notification.`, 6000);
        this.liste.charger();
        this.pouls.charger();
      },
      error: (e) => {
        this.envoi.set(false);
        this.erreurAction.set(messageErreur(e));
      },
    });
  }

  /** « Newcastle », « Coccidiose → Newcastle » quand le vétérinaire a requalifié. */
  protected diagnostic(s: SignalementAdmin): { proposee: string; confirmee: string | null; corrige: boolean } {
    const proposee = s.maladieProposee ?? 'Non identifiée';
    const confirmee = s.maladieConfirmee ?? null;
    return { proposee, confirmee, corrige: !!confirmee && confirmee !== s.maladieProposee };
  }
}
