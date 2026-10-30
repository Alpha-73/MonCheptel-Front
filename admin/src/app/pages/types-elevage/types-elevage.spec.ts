import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { environment } from '../../../environments/environment';
import { SEPARATEUR_MILLIERS } from '../../core/format';
import { TypeElevageFormulaire } from './type-elevage-formulaire';
import {
  TypeElevageAdmin,
  coutPoste,
  dureeCyclePourRequete,
  erreurCycle,
  estimerCouts,
  pourcentageDepuisTaux,
  sujetsAchetes,
  tauxDepuisPourcentage,
} from './types-elevage.api';
import { TypesElevageListe } from './types-elevage-liste';

const URL = `${environment.apiUrl}/api/admin/types-elevage`;

/** Poulet de chair du jeu de données V3 (Admin - Référentiel fiche). */
const POULET: TypeElevageAdmin = {
  id: 1,
  filiere: 'VOLAILLE',
  libelle: 'Poulet de chair',
  modeEvaluation: 'PAR_PERIODE',
  dureeCycleJours: 45,
  capaciteReference: 100,
  tauxMortalite: 0.08,
  difficulte: 'ACCESSIBLE',
  actif: true,
  postesCout: [
    { libelle: 'Bâtiment', montant: 1800, unite: 'm²', phase: 'INSTALLATION', modeQuantite: 'PAR_CAPACITE', coefficient: 0.1, ordre: 0 },
    { libelle: 'Mangeoires', montant: 6000, phase: 'INSTALLATION', modeQuantite: 'FORFAIT', coefficient: 1, ordre: 1 },
    { libelle: 'Aliment', montant: 345, unite: 'kg', phase: 'CYCLE', modeQuantite: 'PAR_SUJET', coefficient: 1.8, ordre: 2 },
  ],
};

describe('types d’élevage : aides', () => {
  it('convertit le taux de mortalité entre % et fraction', () => {
    expect(tauxDepuisPourcentage(8)).toBe(0.08);
    expect(tauxDepuisPourcentage('12,5')).toBe(0.125);
    expect(tauxDepuisPourcentage(0)).toBe(0);
    expect(tauxDepuisPourcentage(90)).toBe(0.9);
    expect(tauxDepuisPourcentage(90.5)).toBeNull();
    expect(tauxDepuisPourcentage(-1)).toBeNull();
    expect(tauxDepuisPourcentage('')).toBeNull();
    expect(pourcentageDepuisTaux(0.08)).toBe(8);
    expect(pourcentageDepuisTaux(0.0725)).toBe(7.25);
    expect(pourcentageDepuisTaux(null)).toBeNull();
  });

  it('applique la règle de la durée de cycle', () => {
    expect(erreurCycle('PAR_PERIODE', 45)).toBeNull();
    expect(erreurCycle('PAR_PERIODE', null)).toContain('durée de cycle');
    expect(erreurCycle('PAR_PERIODE', 0)).toContain('supérieur à zéro');
    expect(erreurCycle('PAR_PERIODE', 4.5)).toContain('entier');
    expect(erreurCycle('PAR_ENTREE', null)).toBeNull();
    expect(dureeCyclePourRequete('PAR_ENTREE', 45)).toBeNull();
    expect(dureeCyclePourRequete('PAR_PERIODE', 45)).toBe(45);
  });

  it('provisionne la mortalité sur une bande seulement', () => {
    // 100 × 1,08 vaut 108,00000000000001 en flottant : il faut bien 108, pas 109.
    expect(sujetsAchetes('VOLAILLE', 100, 0.08)).toBe(108);
    expect(sujetsAchetes('VOLAILLE', 10, 0.05)).toBe(11);
    expect(sujetsAchetes('CAPRINS', 10, 0.05)).toBe(10);
    expect(sujetsAchetes('VOLAILLE', 0, 0.08)).toBe(0);
  });

  it('chiffre les postes comme le simulateur', () => {
    expect(coutPoste({ modeQuantite: 'PAR_SUJET', coefficient: 1.8, montant: 345 }, 108, 100)).toBe(67068);
    expect(coutPoste({ modeQuantite: 'PAR_CAPACITE', coefficient: 0.1, montant: 1800 }, 108, 100)).toBe(18000);
    expect(coutPoste({ modeQuantite: 'FORFAIT', coefficient: 1, montant: 6000 }, 108, 100)).toBe(6000);
    expect(estimerCouts(POULET)).toEqual({ sujetsAchetes: 108, installation: 24000, cycle: 67068 });
  });
});

describe('types d’élevage : écrans', () => {
  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideRouter([]), provideHttpClient(), provideHttpClientTesting()],
    });
  });

  it('affiche la liste des types actifs', async () => {
    const f = TestBed.createComponent(TypesElevageListe);
    const http = TestBed.inject(HttpTestingController);
    http.expectOne(URL).flush([POULET, { ...POULET, id: 2, libelle: 'Pondeuse', actif: false }]);
    await f.whenStable();
    const texte = (f.nativeElement as HTMLElement).textContent ?? '';
    expect(texte).toContain('Poulet de chair');
    expect(texte).not.toContain('Pondeuse');
    expect(texte).toContain(`67${SEPARATEUR_MILLIERS}068 F`);
    http.verify();
  });

  it('remplit le formulaire et renvoie le taux en fraction', async () => {
    const f = TestBed.createComponent(TypeElevageFormulaire);
    f.componentRef.setInput('id', '1');
    const http = TestBed.inject(HttpTestingController);
    f.detectChanges();
    http.expectOne(`${URL}/1`).flush(POULET);
    await f.whenStable();
    const racine = f.nativeElement as HTMLElement;
    expect(racine.querySelector<HTMLInputElement>('#mortalite')?.value).toBe('8');
    expect(racine.querySelectorAll('table.postes tbody tr')).toHaveLength(3);

    racine.querySelector<HTMLButtonElement>('button[type=submit]')!.click();
    const requete = http.expectOne(`${URL}/1`);
    expect(requete.request.method).toBe('PUT');
    expect(requete.request.body.tauxMortalite).toBe(0.08);
    expect(requete.request.body.dureeCycleJours).toBe(45);
    expect(requete.request.body.postesCout.map((p: { ordre: number }) => p.ordre)).toEqual([0, 1, 2]);
  });
});
