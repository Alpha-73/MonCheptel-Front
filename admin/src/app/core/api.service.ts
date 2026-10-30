import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable, shareReplay } from 'rxjs';
import { environment } from '../../environments/environment';
import {
  AlerteReponse,
  AlerteRequete,
  ApercuAlerte,
  ConseilDetail,
  ConseilRequete,
  Filiere,
  FicheUtilisateur,
  FiltresUtilisateurs,
  JetonReponse,
  MaladieAdmin,
  MaladieRequete,
  NotificationAdmin,
  PageReponse,
  ProfilReponse,
  ProfilRequete,
  StatutConseil,
  Statistiques,
  SymptomeReponse,
  TableauDeBordAdmin,
  UtilisateurResume,
  VeterinaireAdmin,
  VeterinaireRequete,
  ZoneReponse,
} from './modeles';

/** Supprime les paramètres vides pour ne pas envoyer `?filiere=&zoneId=`. */
function parametres(valeurs: Record<string, string | number | boolean | null | undefined>): HttpParams {
  let params = new HttpParams();
  for (const [cle, valeur] of Object.entries(valeurs)) {
    if (valeur !== null && valeur !== undefined && valeur !== '') {
      params = params.set(cle, String(valeur));
    }
  }
  return params;
}

/**
 * Toutes les routes de l'API utilisées par la console. Les jetons sont posés
 * par l'intercepteur (core/auth.interceptor.ts), pas ici.
 */
@Injectable({ providedIn: 'root' })
export class ApiService {
  private readonly http = inject(HttpClient);
  private readonly api = `${environment.apiUrl}/api`;
  private readonly admin = `${environment.apiUrl}/api/admin`;

  /** Les zones changent rarement : une seule requête par session de la console. */
  private zones$?: Observable<ZoneReponse[]>;

  // ── Authentification ──────────────────────────────────────────────────

  connexion(email: string, motDePasse: string): Observable<JetonReponse> {
    return this.http.post<JetonReponse>(`${this.api}/auth/connexion`, { email, motDePasse });
  }

  /** Champs de ChangementMotDePasseRequete : ancienMotDePasse / nouveauMotDePasse. */
  changerMotDePasse(ancienMotDePasse: string, nouveauMotDePasse: string): Observable<void> {
    return this.http.post<void>(`${this.api}/auth/mot-de-passe`, { ancienMotDePasse, nouveauMotDePasse });
  }

  // ── Référentiel ───────────────────────────────────────────────────────

  zones(): Observable<ZoneReponse[]> {
    this.zones$ ??= this.http.get<ZoneReponse[]>(`${this.api}/zones`).pipe(shareReplay(1));
    return this.zones$;
  }

  symptomes(filiere?: Filiere | null): Observable<SymptomeReponse[]> {
    return this.http.get<SymptomeReponse[]>(`${this.api}/signalements/symptomes`, {
      params: parametres({ filiere }),
    });
  }
  /** Ajoute un symptôme à la liste ; un libellé déjà présent rend l'existant. */
  creerSymptome(libelle: string): Observable<SymptomeReponse> {
    return this.http.post<SymptomeReponse>(`${this.api}/signalements/symptomes`, { libelle });
  }


  // ── Tableau de bord, statistiques ─────────────────────────────────────

  tableauDeBord(): Observable<TableauDeBordAdmin> {
    return this.http.get<TableauDeBordAdmin>(`${this.admin}/tableau-de-bord`);
  }

  statistiques(): Observable<Statistiques> {
    return this.http.get<Statistiques>(`${this.admin}/statistiques`);
  }

  // ── Utilisateurs (éleveurs) ───────────────────────────────────────────

  utilisateurs(filtres: FiltresUtilisateurs): Observable<PageReponse<UtilisateurResume>> {
    return this.http.get<PageReponse<UtilisateurResume>>(`${this.admin}/utilisateurs`, {
      params: parametres({
        recherche: filtres.recherche?.trim(),
        filiere: filtres.filiere,
        zoneId: filtres.zoneId,
        actif: filtres.actif,
        page: filtres.page ?? 0,
      }),
    });
  }

  ficheUtilisateur(id: number): Observable<FicheUtilisateur> {
    return this.http.get<FicheUtilisateur>(`${this.admin}/utilisateurs/${id}/fiche`);
  }

  modifierUtilisateur(id: number, requete: ProfilRequete): Observable<ProfilReponse> {
    return this.http.put<ProfilReponse>(`${this.admin}/utilisateurs/${id}`, requete);
  }

  /** Vaut pour un éleveur comme pour un vétérinaire. */
  changerActivation(id: number, actif: boolean): Observable<void> {
    return this.http.post<void>(`${this.admin}/utilisateurs/${id}/activation`, null, {
      params: parametres({ actif }),
    });
  }

  /** Mot de passe provisoire envoyé par e-mail ; déverrouille aussi le compte. */
  reinitialiserMotDePasse(id: number): Observable<void> {
    return this.http.post<void>(`${this.admin}/utilisateurs/${id}/mot-de-passe`, null);
  }

  /**
   * Suppression définitive d'un éleveur (avec son cheptel, ses signalements
   * et ses opérations) ou d'un vétérinaire : ses conseils publiés restent en
   * ligne au nom de l'administration, ses brouillons et conseils en
   * modération sont supprimés, ses cas repartent vers un confrère.
   */
  supprimerUtilisateur(id: number): Observable<void> {
    return this.http.delete<void>(`${this.admin}/utilisateurs/${id}`);
  }

  // ── Vétérinaires ──────────────────────────────────────────────────────

  veterinaires(zoneId?: number | null): Observable<VeterinaireAdmin[]> {
    return this.http.get<VeterinaireAdmin[]>(`${this.admin}/veterinaires`, { params: parametres({ zoneId }) });
  }

  veterinaire(id: number): Observable<VeterinaireAdmin> {
    return this.http.get<VeterinaireAdmin>(`${this.admin}/veterinaires/${id}`);
  }

  creerVeterinaire(requete: VeterinaireRequete): Observable<VeterinaireAdmin> {
    return this.http.post<VeterinaireAdmin>(`${this.admin}/veterinaires`, requete);
  }

  modifierVeterinaire(id: number, requete: VeterinaireRequete): Observable<VeterinaireAdmin> {
    return this.http.put<VeterinaireAdmin>(`${this.admin}/veterinaires/${id}`, requete);
  }

  ajouterCompetence(veterinaireId: number, maladieId: number): Observable<void> {
    return this.http.post<void>(`${this.admin}/veterinaires/${veterinaireId}/competences/${maladieId}`, null);
  }

  retirerCompetence(veterinaireId: number, maladieId: number): Observable<void> {
    return this.http.delete<void>(`${this.admin}/veterinaires/${veterinaireId}/competences/${maladieId}`);
  }

  // ── Maladies ──────────────────────────────────────────────────────────

  /** Les maladies du catalogue ; `avecRetirees` ajoute celles qui ont été retirées. */
  maladies(avecRetirees = false): Observable<MaladieAdmin[]> {
    return this.http.get<MaladieAdmin[]>(`${this.admin}/maladies`, {
      params: parametres({ retirees: avecRetirees || null }),
    });
  }

  reactiverMaladie(id: number): Observable<MaladieAdmin> {
    return this.http.post<MaladieAdmin>(`${this.admin}/maladies/${id}/reactivation`, null);
  }

  maladie(id: number): Observable<MaladieAdmin> {
    return this.http.get<MaladieAdmin>(`${this.admin}/maladies/${id}`);
  }

  creerMaladie(requete: MaladieRequete): Observable<MaladieAdmin> {
    return this.http.post<MaladieAdmin>(`${this.admin}/maladies`, requete);
  }

  modifierMaladie(id: number, requete: MaladieRequete): Observable<MaladieAdmin> {
    return this.http.put<MaladieAdmin>(`${this.admin}/maladies/${id}`, requete);
  }

  retirerMaladie(id: number): Observable<void> {
    return this.http.delete<void>(`${this.admin}/maladies/${id}`);
  }

  // ── Conseils ──────────────────────────────────────────────────────────

  conseils(statut?: StatutConseil | null): Observable<ConseilDetail[]> {
    return this.http.get<ConseilDetail[]>(`${this.admin}/conseils`, { params: parametres({ statut }) });
  }

  publierConseil(id: number): Observable<ConseilDetail> {
    return this.http.post<ConseilDetail>(`${this.admin}/moderation/${id}`, { publier: true });
  }

  retirerConseil(id: number, motif: string): Observable<ConseilDetail> {
    return this.http.post<ConseilDetail>(`${this.admin}/moderation/${id}`, { publier: false, motif });
  }

  creerConseil(requete: ConseilRequete): Observable<ConseilDetail> {
    return this.http.post<ConseilDetail>(`${this.admin}/conseils`, requete);
  }

  // ── Alertes ───────────────────────────────────────────────────────────

  alertes(): Observable<AlerteReponse[]> {
    return this.http.get<AlerteReponse[]>(`${this.admin}/alertes`);
  }

  alerte(id: number): Observable<AlerteReponse> {
    return this.http.get<AlerteReponse>(`${this.admin}/alertes/${id}`);
  }

  apercuAlerte(maladieId: number, zoneId: number, filiere?: Filiere | null): Observable<ApercuAlerte> {
    return this.http.get<ApercuAlerte>(`${this.admin}/alertes/apercu`, {
      params: parametres({ maladieId, zoneId, filiere }),
    });
  }

  declencherAlerte(requete: AlerteRequete): Observable<AlerteReponse> {
    return this.http.post<AlerteReponse>(`${this.admin}/alertes`, requete);
  }

  modifierAlerte(id: number, message: string, dateFin: string | null): Observable<AlerteReponse> {
    return this.http.put<AlerteReponse>(`${this.admin}/alertes/${id}`, { message, dateFin });
  }

  cloturerAlerte(id: number): Observable<AlerteReponse> {
    return this.http.post<AlerteReponse>(`${this.admin}/alertes/${id}/cloture`, null);
  }

  // ── Notifications de l'administrateur connecté ────────────────────────
  // Routes communes à tous les rôles (NotificationControleur) : le back
  // filtre sur l'utilisateur du jeton.

  notifications(page = 0): Observable<PageReponse<NotificationAdmin>> {
    return this.http.get<PageReponse<NotificationAdmin>>(`${this.api}/notifications`, { params: parametres({ page }) });
  }

  notificationsNonLues(): Observable<number> {
    return this.http.get<number>(`${this.api}/notifications/non-lues`);
  }

  marquerNotificationsLues(): Observable<void> {
    return this.http.post<void>(`${this.api}/notifications/lecture`, null);
  }
}
