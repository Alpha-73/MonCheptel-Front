import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { ApiService } from '../../core/api.service';
import { chargement } from '../../core/chargement';
import { messageErreur } from '../../core/erreurs';
import { couleurStatutConseil, libelleCategorie, libelleFiliere } from '../../core/format';
import { ConseilDetail, FILIERES, Filiere, StatutConseil } from '../../core/modeles';
import { Icone } from '../../shared/icone';
import { Modale } from '../../shared/modale';
import { DateCourtePipe, LibellePipe } from '../../shared/pipes';
import { EnTete, Etat, Filtre, OptionFiltre, OptionOnglet, Onglets, Recherche } from '../../shared/ui';
import { AnnonceService } from '../../shared/annonce';
import { PoulsService } from '../../core/pouls.service';
import { nomCourtVeterinaire, nomVeterinaire } from '../veterinaires/veterinaire-nom';

/** Auteur affiché d'un conseil : « Dr A. Traoré », ou l'administration. */
export function auteurConseil(c: ConseilDetail): string {
  return c.auteur ? nomCourtVeterinaire(c.auteur) : 'Administration';
}

/** Identifiant stable d'un auteur : deux « Dr A. Traoré » restent distincts. */
export function cleAuteur(c: ConseilDetail): string {
  return c.auteur ? `v${c.auteur.id}` : 'administration';
}

/** Minuscules sans accents : « traore » trouve « Traoré ». */
export function normaliser(texte: string): string {
  return texte.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
}

/**
 * Recherche libre : titre, texte, ou auteur (forme courte « Dr A. Traoré »
 * comme nom complet « Dr Aïssata Traoré »). Remplace l'ancienne rangée de
 * puces « Auteur », qui grandissait avec le nombre de vétérinaires.
 */
export function correspond(c: ConseilDetail, terme: string): boolean {
  const t = normaliser(terme.trim());
  if (!t) return true;
  const auteurs = c.auteur ? `${auteurConseil(c)} ${nomVeterinaire(c.auteur)}` : auteurConseil(c);
  return normaliser(`${c.titre} ${c.contenu} ${auteurs}`).includes(t);
}

/** Date affichée : soumission, sinon publication, sinon création. */
export function dateConseil(c: ConseilDetail): string | undefined {
  return c.dateSoumission ?? c.datePublication ?? c.dateCreation;
}

type Popup = { type: 'valider' | 'retirer'; conseil: ConseilDetail };

/** Onglets de l'écran : un par statut, plus « Tous ». */
export type VueConseils = StatutConseil | 'TOUS';
const VUES_CONSEILS: VueConseils[] = ['EN_MODERATION', 'PUBLIE', 'RETIRE', 'TOUS'];

/** `?statut=` de l'adresse ; « À modérer » par défaut, c'est l'objet de l'écran. */
export function lireVueConseils(valeur: string | null | undefined): VueConseils {
  return VUES_CONSEILS.includes(valeur as VueConseils) ? (valeur as VueConseils) : 'EN_MODERATION';
}

/**
 * Écran « Admin - Conseils moderation » (+ pop-up Valider, Publié, Retirer).
 * GET /api/admin/conseils (tous statuts sauf brouillon) ;
 * POST /api/admin/moderation/{id} {publier: true} ou {publier: false, motif}.
 */
@Component({
  selector: 'app-conseils-moderation',
  imports: [RouterLink, EnTete, Etat, Filtre, Onglets, Recherche, Icone, Modale, DateCourtePipe, LibellePipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './conseils-moderation.html',
  styleUrl: './conseils-moderation.scss',
})
export class ConseilsModeration {
  private readonly api = inject(ApiService);
  private readonly router = inject(Router);
  private readonly annonces = inject(AnnonceService);
  private readonly pouls = inject(PoulsService);

  protected readonly liste = chargement(() => this.api.conseils());
  protected readonly auteurConseil = auteurConseil;
  protected readonly cle = cleAuteur;
  protected readonly dateConseil = dateConseil;
  protected readonly couleurStatut = couleurStatutConseil;
  protected readonly libelleFiliere = libelleFiliere;
  protected readonly libelleCategorie = libelleCategorie;

  protected readonly recherche = signal('');
  protected readonly vue = signal<VueConseils>(lireVueConseils(inject(ActivatedRoute).snapshot.queryParamMap.get('statut')));
  /** Conseil dont l'aperçu est déplié dans la liste. */
  protected readonly deplie = signal<number | null>(null);
  protected readonly filiere = signal<Filiere | null>(null);
  /** Auteur choisi en cliquant son nom dans le tableau ; null = tous. */
  protected readonly auteur = signal<{ cle: string; nom: string } | null>(null);

  protected readonly optionsFiliere: OptionFiltre<Filiere>[] = FILIERES.map((f) => ({ valeur: f, libelle: libelleFiliere(f) }));
  /** Bilan de l'auteur choisi, tous statuts confondus : « 3 à modérer · 8 publiés ». */
  protected readonly bilanAuteur = computed(() => {
    const a = this.auteur();
    if (!a) return '';
    const siens = (this.liste.donnees() ?? []).filter((c) => cleAuteur(c) === a.cle);
    const n = (s: StatutConseil) => siens.filter((c) => c.statut === s).length;
    const parties = [
      `${siens.length} ${siens.length > 1 ? 'conseils' : 'conseil'}`,
      n('EN_MODERATION') ? `${n('EN_MODERATION')} à modérer` : '',
      n('PUBLIE') ? `${n('PUBLIE')} ${n('PUBLIE') > 1 ? 'publiés' : 'publié'}` : '',
      n('RETIRE') ? `${n('RETIRE')} ${n('RETIRE') > 1 ? 'retirés' : 'retiré'}` : '',
    ];
    return parties.filter(Boolean).join(' · ');
  });

  protected readonly compteurs = computed(() => {
    const l = this.liste.donnees() ?? [];
    return {
      enModeration: l.filter((c) => c.statut === 'EN_MODERATION').length,
      publies: l.filter((c) => c.statut === 'PUBLIE').length,
      retires: l.filter((c) => c.statut === 'RETIRE').length,
    };
  });
  protected readonly onglets = computed<OptionOnglet<VueConseils>[]>(() => {
    const n = this.compteurs();
    const charge = !!this.liste.donnees();
    return [
      { valeur: 'EN_MODERATION', libelle: 'À modérer', compte: charge ? n.enModeration : undefined, alerte: true },
      { valeur: 'PUBLIE', libelle: 'Publiés', compte: charge ? n.publies : undefined },
      { valeur: 'RETIRE', libelle: 'Retirés', compte: charge ? n.retires : undefined },
      { valeur: 'TOUS', libelle: 'Tous' },
    ];
  });

  protected readonly affiches = computed(() => {
    const terme = this.recherche();
    const auteur = this.auteur();
    return (this.liste.donnees() ?? []).filter(
      (c) =>
        correspond(c, terme) &&
        (this.vue() === 'TOUS' || c.statut === this.vue()) &&
        (!this.filiere() || c.filiere === this.filiere()) &&
        (!auteur || cleAuteur(c) === auteur.cle),
    );
  });

  protected readonly popup = signal<Popup | null>(null);
  protected readonly motif = signal('');
  protected readonly envoi = signal(false);
  protected readonly erreurAction = signal<string | null>(null);

  constructor() {
    this.liste.charger();
  }

  protected changerVue(v: VueConseils): void {
    this.vue.set(v);
    this.deplie.set(null);
    void this.router.navigate([], { queryParams: { statut: v === 'EN_MODERATION' ? null : v }, replaceUrl: true });
  }

  /** Clic sur un nom d'auteur : n'afficher que ses conseils (ou tout réafficher). */
  protected filtrerAuteur(c: ConseilDetail): void {
    const cle = cleAuteur(c);
    this.auteur.set(this.auteur()?.cle === cle ? null : { cle, nom: auteurConseil(c) });
    this.deplie.set(null);
  }

  protected toutesLesAuteurs(): void {
    this.auteur.set(null);
  }

  protected basculerApercu(id: number): void {
    this.deplie.update((d) => (d === id ? null : id));
  }

  protected ouvrir(type: 'valider' | 'retirer', conseil: ConseilDetail): void {
    this.erreurAction.set(null);
    this.motif.set('');
    this.popup.set({ type, conseil });
  }

  protected fermer(): void {
    if (!this.envoi()) {
      this.popup.set(null);
    }
  }

  protected publier(conseil: ConseilDetail): void {
    this.envoi.set(true);
    this.erreurAction.set(null);
    this.api.publierConseil(conseil.id).subscribe({
      next: (maj) => {
        this.envoi.set(false);
        this.remplacer(maj);
        this.popup.set(null);
        const n = this.compteurs().enModeration;
        this.annonces.annoncer(
          `Conseil publié. ${n === 0 ? 'Plus rien à modérer.' : n === 1 ? 'Il reste 1 conseil à modérer.' : `Il reste ${n} conseils à modérer.`}`,
          6000,
        );
        this.pouls.charger();
      },
      error: (e) => {
        this.envoi.set(false);
        this.erreurAction.set(messageErreur(e));
      },
    });
  }

  protected retirer(conseil: ConseilDetail): void {
    const motif = this.motif().trim();
    if (!motif) {
      this.erreurAction.set('Indiquez le motif du retrait : il est transmis à l’auteur.');
      return;
    }
    this.envoi.set(true);
    this.erreurAction.set(null);
    this.api.retirerConseil(conseil.id, motif).subscribe({
      next: (maj) => {
        this.envoi.set(false);
        this.remplacer(maj);
        this.popup.set(null);
        this.annonces.annoncer("Conseil retiré. L'auteur reçoit le motif.");
        this.pouls.charger();
      },
      error: (e) => {
        this.envoi.set(false);
        this.erreurAction.set(messageErreur(e));
      },
    });
  }

  /** Met la ligne à jour sans recharger toute la liste. */
  private remplacer(maj: ConseilDetail): void {
    this.liste.donnees.update((l) => (l ? l.map((c) => (c.id === maj.id ? { ...c, ...maj } : c)) : l));
  }
}
