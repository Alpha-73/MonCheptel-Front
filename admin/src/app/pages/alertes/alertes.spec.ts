import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { beforeEach, describe, expect, it } from 'vitest';
import { environment } from '../../../environments/environment';
import { AlerteReponse, MaladieAdmin } from '../../core/modeles';
import { AlerteDeclencher } from './alerte-declencher';
import { AlertesListe } from './alertes-liste';

const ADMIN = `${environment.apiUrl}/api/admin`;
const alerte = (p: Partial<AlerteReponse>): AlerteReponse => ({
  id: 1, maladie: 'Newcastle', zone: 'Kayes', message: 'm', portee: 12, dateDeclenchement: '2026-10-01T08:00:00', statut: 'ACTIVE', ...p,
});
const PPR: MaladieAdmin = {
  id: 7, nom: 'PPR', gravite: 'ELEVE', filieres: ['OVINS', 'CAPRINS'], orienteVersVeterinaire: true, active: true, symptomes: [], veterinairesCompetents: 1,
};

describe('écrans Alertes', () => {
  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideRouter([]), provideHttpClient(), provideHttpClientTesting()] });
  });

  it('liste : squelette, puis les actives en lignes-liens, les terminées dans leur onglet', async () => {
    const f = TestBed.createComponent(AlertesListe);
    f.detectChanges();
    const racine = f.nativeElement as HTMLElement;
    expect(racine.querySelector('app-etat')).not.toBeNull();
    TestBed.inject(HttpTestingController)
      .expectOne(`${ADMIN}/alertes`)
      .flush([alerte({}), alerte({ id: 2, maladie: 'PPR', statut: 'TERMINEE' })]);
    await f.whenStable();
    const liens = [...racine.querySelectorAll<HTMLAnchorElement>('tr.lien-ligne a.etendu')];
    expect(liens.map((a) => a.textContent?.trim())).toEqual(['Newcastle']);
    expect(liens[0].getAttribute('href')).toBe('/alertes/1');
    expect(racine.querySelector('[aria-label="Déclencher une alerte"]')).not.toBeNull();
    racine.querySelectorAll<HTMLButtonElement>('[role=tab]')[1].click();
    await f.whenStable();
    expect(racine.querySelector('tr.lien-ligne a.etendu')?.textContent?.trim()).toBe('PPR');
  });

  it('liste : erreur avec « Réessayer », puis liste vide', async () => {
    const f = TestBed.createComponent(AlertesListe);
    f.detectChanges();
    const http = TestBed.inject(HttpTestingController);
    http.expectOne(`${ADMIN}/alertes`).flush({ message: 'Panne' }, { status: 500, statusText: 'Erreur' });
    await f.whenStable();
    const racine = f.nativeElement as HTMLElement;
    const reessayer = [...racine.querySelectorAll('button')].find((b) => b.textContent?.includes('Réessayer'));
    expect(reessayer).toBeDefined();
    reessayer!.click();
    http.expectOne(`${ADMIN}/alertes`).flush([]);
    await f.whenStable();
    expect(racine.textContent).toContain('Aucune alerte en cours.');
  });

  it('déclencher : la filière ne propose que celles de la maladie (A1)', async () => {
    const f = TestBed.createComponent(AlerteDeclencher);
    f.detectChanges();
    const http = TestBed.inject(HttpTestingController);
    http.expectOne(`${environment.apiUrl}/api/zones`).flush([{ id: 3, nom: 'Mopti' }]);
    http.expectOne((r) => r.url === `${ADMIN}/maladies`).flush([PPR]);
    await f.whenStable();
    const racine = f.nativeElement as HTMLElement;
    const maladie = racine.querySelector<HTMLSelectElement>('#maladie')!;
    maladie.selectedIndex = 1;
    maladie.dispatchEvent(new Event('change'));
    await f.whenStable();
    const options = [...racine.querySelectorAll<HTMLOptionElement>('#filiere option')].map((o) => o.textContent?.trim());
    expect(options).toEqual(['Toutes ses filières (Ovins, Caprins)', 'Ovins', 'Caprins']);
  });
});
