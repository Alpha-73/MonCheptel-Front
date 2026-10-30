import { ConseilDetail } from '../core/modeles';
import { auteurConseil, cleAuteur, correspond, dateConseil, lireVueConseils } from './conseils/conseils-moderation';
import { bornerPoids } from './maladies/maladie-formulaire';
import { formaterDelai, regrouperAutres } from './statistiques/statistiques';
import { nomCourtVeterinaire, nomVeterinaire } from './veterinaires/veterinaire-nom';

describe('aides des écrans', () => {
  it('borne le poids d’un symptôme dans [0, 1]', () => {
    expect(bornerPoids('0,75')).toBe(0.75);
    expect(bornerPoids(1.4)).toBe(1);
    expect(bornerPoids(-2)).toBe(0);
    expect(bornerPoids('abc')).toBe(0);
    expect(bornerPoids(0.333)).toBe(0.33);
  });

  it('regroupe les petites zones en « Autres »', () => {
    const lignes = ['A', 'B', 'C', 'D', 'E', 'F', 'G'].map((libelle, i) => ({ libelle, valeur: 70 - i * 10 }));
    const r = regrouperAutres(lignes, 5);
    expect(r.map((l) => l.libelle)).toEqual(['A', 'B', 'C', 'D', 'E', 'Autres']);
    expect(r[5].valeur).toBe(20 + 10);
    expect(regrouperAutres(lignes.slice(0, 6), 5)).toHaveLength(6);
  });

  it('formate le délai de prise en charge', () => {
    expect(formaterDelai(6)).toBe('6 h');
    expect(formaterDelai(1.5)).toBe('1,5 h');
    expect(formaterDelai(0.5)).toBe('30 min');
    expect(formaterDelai(null)).toBe('—');
  });

  it('compose le nom d’un vétérinaire', () => {
    expect(nomVeterinaire({ nom: 'Aïssata Traoré', titre: 'Dr' })).toBe('Dr Aïssata Traoré');
    expect(nomVeterinaire({ nom: 'Dr Essai', titre: 'Docteur' })).toBe('Dr Essai');
    expect(nomVeterinaire({ nom: 'Moussa Diarra' })).toBe('Moussa Diarra');
    expect(nomCourtVeterinaire({ nom: 'Aïssata Traoré', titre: 'Dr' })).toBe('Dr A. Traoré');
  });

  it('affiche l’administration comme auteur d’un conseil sans auteur', () => {
    const base = { id: 1, titre: 't', contenu: 'c', filiere: 'VOLAILLE', categorie: 'SANTE', nombreLectures: 0, statut: 'PUBLIE' } as ConseilDetail;
    expect(auteurConseil(base)).toBe('Administration');
    expect(dateConseil({ ...base, dateCreation: 'x', datePublication: 'y' })).toBe('y');
    expect(dateConseil({ ...base, dateCreation: 'x', dateSoumission: 'z', datePublication: 'y' })).toBe('z');
  });

  it('cherche un conseil par auteur, sans tenir compte des accents', () => {
    const base = { id: 1, titre: 'Vaccin Newcastle', contenu: 'Rappel à J21', filiere: 'VOLAILLE', categorie: 'SANTE', nombreLectures: 0, statut: 'PUBLIE' } as ConseilDetail;
    const traore = { ...base, auteur: { id: 4, nom: 'Aïssata Traoré', titre: 'Dr', disponible: true } };
    expect(correspond(traore, 'traore')).toBe(true);
    expect(correspond(traore, 'Aissata')).toBe(true);
    expect(correspond(traore, 'dr a. traoré')).toBe(true);
    expect(correspond(traore, 'newcastle')).toBe(true);
    expect(correspond(traore, 'diarra')).toBe(false);
    expect(correspond(base, 'administration')).toBe(true);
    expect(correspond(base, '  ')).toBe(true);
    // Deux homonymes restent deux auteurs distincts.
    const homonyme = { ...traore, auteur: { ...traore.auteur, id: 9 } };
    expect(cleAuteur(traore)).not.toBe(cleAuteur(homonyme));
    expect(cleAuteur(base)).toBe('administration');
  });

  it('ouvre la modération sur « À modérer », ou sur le statut de l’adresse (A4)', () => {
    expect(lireVueConseils(null)).toBe('EN_MODERATION');
    expect(lireVueConseils('PUBLIE')).toBe('PUBLIE');
    expect(lireVueConseils('TOUS')).toBe('TOUS');
    expect(lireVueConseils('BROUILLON')).toBe('EN_MODERATION');
  });
});
