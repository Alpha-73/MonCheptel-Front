import { Routes } from '@angular/router';
import { gardeAdministrateur, gardeChangementMotDePasse, gardeInvite, gardeSortieFormulaire } from './core/gardes';
import { Coque } from './layout/coque';

/**
 * Correspondance avec la maquette (voir README) : chaque écran « Admin - … »
 * a sa route ; les pop-up s'ouvrent par-dessus l'écran qui les appelle.
 */
export const routes: Routes = [
  {
    path: 'connexion',
    canActivate: [gardeInvite],
    title: 'Connexion · MonCheptel Administration',
    loadComponent: () => import('./pages/connexion/connexion').then((m) => m.Connexion),
  },
  {
    path: 'mot-de-passe',
    canActivate: [gardeChangementMotDePasse],
    title: 'Nouveau mot de passe · MonCheptel Administration',
    loadComponent: () => import('./pages/connexion/mot-de-passe').then((m) => m.MotDePasse),
  },
  {
    path: '',
    component: Coque,
    canActivate: [gardeAdministrateur],
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'tableau-de-bord' },
      {
        path: 'tableau-de-bord',
        title: 'Tableau de bord · MonCheptel',
        loadComponent: () => import('./pages/tableau-de-bord/tableau-de-bord').then((m) => m.TableauDeBord),
      },
      {
        path: 'utilisateurs',
        title: 'Éleveurs · MonCheptel',
        loadComponent: () => import('./pages/utilisateurs/utilisateurs-liste').then((m) => m.UtilisateursListe),
      },
      {
        path: 'utilisateurs/:id',
        title: 'Fiche éleveur · MonCheptel',
        loadComponent: () => import('./pages/utilisateurs/utilisateur-fiche').then((m) => m.UtilisateurFiche),
      },
      {
        path: 'utilisateurs/:id/modifier',
        title: 'Modifier un éleveur · MonCheptel',
        loadComponent: () => import('./pages/utilisateurs/utilisateur-modifier').then((m) => m.UtilisateurModifier),
      },
      {
        path: 'veterinaires',
        title: 'Vétérinaires · MonCheptel',
        loadComponent: () => import('./pages/veterinaires/veterinaires-liste').then((m) => m.VeterinairesListe),
      },
      {
        path: 'veterinaires/nouveau',
        title: 'Nouveau compte vétérinaire · MonCheptel',
        loadComponent: () => import('./pages/veterinaires/veterinaire-formulaire').then((m) => m.VeterinaireFormulaire),
        canDeactivate: [gardeSortieFormulaire],
      },
      {
        path: 'veterinaires/:id',
        title: 'Modifier un vétérinaire · MonCheptel',
        loadComponent: () => import('./pages/veterinaires/veterinaire-formulaire').then((m) => m.VeterinaireFormulaire),
        canDeactivate: [gardeSortieFormulaire],
      },
      {
        path: 'maladies',
        title: 'Catalogue des maladies · MonCheptel',
        loadComponent: () => import('./pages/maladies/maladies-catalogue').then((m) => m.MaladiesCatalogue),
      },
      {
        path: 'maladies/nouvelle',
        title: 'Ajouter une maladie · MonCheptel',
        loadComponent: () => import('./pages/maladies/maladie-formulaire').then((m) => m.MaladieFormulaire),
        canDeactivate: [gardeSortieFormulaire],
      },
      {
        path: 'maladies/:id',
        title: 'Modifier une maladie · MonCheptel',
        loadComponent: () => import('./pages/maladies/maladie-formulaire').then((m) => m.MaladieFormulaire),
        canDeactivate: [gardeSortieFormulaire],
      },
      {
        path: 'types-elevage',
        title: "Types d'élevage · MonCheptel",
        loadComponent: () => import('./pages/types-elevage/types-elevage-liste').then((m) => m.TypesElevageListe),
      },
      {
        path: 'types-elevage/nouveau',
        title: "Nouveau type d'élevage · MonCheptel",
        loadComponent: () => import('./pages/types-elevage/type-elevage-formulaire').then((m) => m.TypeElevageFormulaire),
        canDeactivate: [gardeSortieFormulaire],
      },
      {
        path: 'types-elevage/:id',
        title: "Modifier un type d'élevage · MonCheptel",
        loadComponent: () => import('./pages/types-elevage/type-elevage-formulaire').then((m) => m.TypeElevageFormulaire),
        canDeactivate: [gardeSortieFormulaire],
      },
      {
        path: 'signalements',
        title: 'Signalements · MonCheptel',
        loadComponent: () => import('./pages/signalements/signalements-liste').then((m) => m.SignalementsListe),
      },
      {
        path: 'conseils',
        title: 'Conseils · MonCheptel',
        loadComponent: () => import('./pages/conseils/conseils-moderation').then((m) => m.ConseilsModeration),
      },
      {
        path: 'conseils/nouveau',
        title: 'Ajouter un conseil · MonCheptel',
        loadComponent: () => import('./pages/conseils/conseil-creer').then((m) => m.ConseilCreer),
      },
      {
        path: 'alertes',
        title: 'Alertes sanitaires · MonCheptel',
        loadComponent: () => import('./pages/alertes/alertes-liste').then((m) => m.AlertesListe),
      },
      {
        path: 'alertes/nouvelle',
        title: 'Déclencher une alerte · MonCheptel',
        loadComponent: () => import('./pages/alertes/alerte-declencher').then((m) => m.AlerteDeclencher),
      },
      {
        path: 'alertes/:id',
        title: 'Modifier une alerte · MonCheptel',
        loadComponent: () => import('./pages/alertes/alerte-modifier').then((m) => m.AlerteModifier),
      },
      {
        path: 'statistiques',
        title: 'Statistiques · MonCheptel',
        loadComponent: () => import('./pages/statistiques/statistiques').then((m) => m.Statistiques),
      },
    ],
  },
  { path: '**', redirectTo: 'tableau-de-bord' },
];
