import { VeterinaireAdmin, VeterinaireResume } from '../../core/modeles';

/** « Dr Aïssata Traoré » : titre + nom, sans doubler un titre déjà dans le nom. */
export function nomVeterinaire(v: Pick<VeterinaireAdmin | VeterinaireResume, 'nom' | 'titre'>): string {
  const titre = v.titre?.trim();
  // Pas de titre, ou nom qui en porte déjà un (« Dr Essai » avec titre « Docteur »).
  if (!titre || v.nom.toLowerCase().startsWith(titre.toLowerCase()) || /^(dr|pr|docteur|professeur)\.?\s/i.test(v.nom)) {
    return v.nom;
  }
  return `${titre} ${v.nom}`;
}

/** « Dr A. Traoré » : forme courte de la colonne Auteur des conseils. */
export function nomCourtVeterinaire(v: Pick<VeterinaireResume, 'nom' | 'titre'>): string {
  const complet = nomVeterinaire(v);
  const mots = complet.split(/\s+/);
  const titre = /^(dr|pr)\.?$/i.test(mots[0]) ? mots.shift()! : '';
  if (mots.length < 2) {
    return complet;
  }
  const nomFamille = mots.pop()!;
  const initialesPrenoms = mots.map((m) => m.charAt(0).toUpperCase() + '.').join(' ');
  return [titre, initialesPrenoms, nomFamille].filter(Boolean).join(' ');
}
