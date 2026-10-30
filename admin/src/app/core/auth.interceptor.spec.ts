import { HttpClient, HttpErrorResponse, provideHttpClient, withInterceptors } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { environment } from '../../environments/environment';
import { authInterceptor } from './auth.interceptor';
import { JetonReponse } from './modeles';
import { CLE_SESSION, SessionService } from './session.service';

const API = environment.apiUrl;
const URL_TDB = `${API}/api/admin/tableau-de-bord`;
const URL_STATS = `${API}/api/admin/statistiques`;
const URL_RAFRAICHIR = `${API}/api/auth/rafraichir`;

function jetons(acces: string, rafraichissement: string, expireDansSecondes = 900): JetonReponse {
  return {
    jetonAcces: acces,
    jetonRafraichissement: rafraichissement,
    expireDansSecondes,
    utilisateurId: 3,
    nom: 'Administrateur',
    role: 'ADMINISTRATEUR',
    doitChangerMotDePasse: false,
  };
}

describe('authInterceptor', () => {
  let http: HttpClient;
  let controle: HttpTestingController;
  let session: SessionService;
  let router: Router;

  beforeEach(() => {
    sessionStorage.clear();
    TestBed.configureTestingModule({
      providers: [
        provideRouter([]),
        provideHttpClient(withInterceptors([authInterceptor])),
        provideHttpClientTesting(),
      ],
    });
    http = TestBed.inject(HttpClient);
    controle = TestBed.inject(HttpTestingController);
    session = TestBed.inject(SessionService);
    router = TestBed.inject(Router);
    vi.spyOn(router, 'navigate').mockResolvedValue(true);
  });

  afterEach(() => {
    controle.verify();
    sessionStorage.clear();
  });

  it('ajoute « Authorization: Bearer » aux appels de l’API', () => {
    session.enregistrer(jetons('A1', 'R1'), 'admin@moncheptel.ml');
    http.get(URL_TDB).subscribe();
    const req = controle.expectOne(URL_TDB);
    expect(req.request.headers.get('Authorization')).toBe('Bearer A1');
    req.flush({});
  });

  it('n’ajoute rien à la connexion ni aux URL hors API', () => {
    session.enregistrer(jetons('A1', 'R1'));
    http.post(`${API}/api/auth/connexion`, {}).subscribe();
    http.get('https://fonts.googleapis.com/css2').subscribe();
    expect(controle.expectOne(`${API}/api/auth/connexion`).request.headers.has('Authorization')).toBe(false);
    expect(controle.expectOne('https://fonts.googleapis.com/css2').request.headers.has('Authorization')).toBe(false);
    controle.match(() => true).forEach((r) => r.flush({}));
  });

  it('conserve la session en sessionStorage', () => {
    session.enregistrer(jetons('A1', 'R1'), 'admin@moncheptel.ml');
    const stocke = JSON.parse(sessionStorage.getItem(CLE_SESSION)!);
    expect(stocke.jetonAcces).toBe('A1');
    expect(stocke.email).toBe('admin@moncheptel.ml');
  });

  it('renouvelle AVANT l’envoi quand le jeton expire bientôt', () => {
    session.enregistrer(jetons('A1', 'R1', 10)); // 10 s < marge de 30 s
    let resultat: unknown;
    http.get(URL_TDB).subscribe((r) => (resultat = r));

    const renouvellement = controle.expectOne(URL_RAFRAICHIR);
    expect(renouvellement.request.body).toEqual({ jetonRafraichissement: 'R1' });
    expect(renouvellement.request.headers.has('Authorization')).toBe(false);
    renouvellement.flush(jetons('A2', 'R2'));

    const req = controle.expectOne(URL_TDB);
    expect(req.request.headers.get('Authorization')).toBe('Bearer A2');
    req.flush({ ok: true });
    expect(resultat).toEqual({ ok: true });
    expect(session.session()?.jetonRafraichissement).toBe('R2');
  });

  it('sur 401, renouvelle puis rejoue la requête', () => {
    session.enregistrer(jetons('A1', 'R1'));
    let resultat: unknown;
    http.get(URL_TDB).subscribe((r) => (resultat = r));

    controle.expectOne(URL_TDB).flush(null, { status: 401, statusText: 'Unauthorized' });
    controle.expectOne(URL_RAFRAICHIR).flush(jetons('A2', 'R2'));
    const rejeu = controle.expectOne(URL_TDB);
    expect(rejeu.request.headers.get('Authorization')).toBe('Bearer A2');
    rejeu.flush({ ok: true });
    expect(resultat).toEqual({ ok: true });
  });

  it('partage UN SEUL renouvellement entre requêtes concurrentes', () => {
    session.enregistrer(jetons('A1', 'R1'));
    const resultats: unknown[] = [];
    http.get(URL_TDB).subscribe((r) => resultats.push(r));
    http.get(URL_STATS).subscribe((r) => resultats.push(r));

    controle.expectOne(URL_TDB).flush(null, { status: 401, statusText: 'Unauthorized' });
    controle.expectOne(URL_STATS).flush(null, { status: 401, statusText: 'Unauthorized' });

    // Le jeton de rafraîchissement tourne : un second POST le ferait échouer.
    const renouvellements = controle.match(URL_RAFRAICHIR);
    expect(renouvellements).toHaveLength(1);
    renouvellements[0].flush(jetons('A2', 'R2'));

    const rejoues = [controle.expectOne(URL_TDB), controle.expectOne(URL_STATS)];
    rejoues.forEach((r) => expect(r.request.headers.get('Authorization')).toBe('Bearer A2'));
    rejoues.forEach((r, i) => r.flush({ i }));
    expect(resultats).toHaveLength(2);
  });

  it('rejoue sans renouveler si une autre requête a déjà changé le jeton', () => {
    session.enregistrer(jetons('A1', 'R1'));
    http.get(URL_TDB).subscribe();
    const enVol = controle.expectOne(URL_TDB);
    // Entre-temps, une autre requête a renouvelé la session.
    session.enregistrer(jetons('A2', 'R2'));
    enVol.flush(null, { status: 401, statusText: 'Unauthorized' });

    controle.expectNone(URL_RAFRAICHIR);
    const rejeu = controle.expectOne(URL_TDB);
    expect(rejeu.request.headers.get('Authorization')).toBe('Bearer A2');
    rejeu.flush({});
  });

  it('un 422 au renouvellement ferme la session et renvoie à la connexion', () => {
    session.enregistrer(jetons('A1', 'R1'));
    let erreur: HttpErrorResponse | undefined;
    http.get(URL_TDB).subscribe({ error: (e) => (erreur = e) });

    controle.expectOne(URL_TDB).flush(null, { status: 401, statusText: 'Unauthorized' });
    controle
      .expectOne(URL_RAFRAICHIR)
      .flush({ statut: 422, message: 'Session expiree. Reconnectez-vous.' }, { status: 422, statusText: 'Unprocessable' });

    expect(erreur?.status).toBe(422);
    expect(session.session()).toBeNull();
    expect(sessionStorage.getItem(CLE_SESSION)).toBeNull();
    expect(router.navigate).toHaveBeenCalledWith(['/connexion'], { queryParams: { expiree: 1 } });
  });

  it('un second 401 après renouvellement remonte', () => {
    session.enregistrer(jetons('A1', 'R1'));
    let erreur: HttpErrorResponse | undefined;
    http.get(URL_TDB).subscribe({ error: (e) => (erreur = e) });

    controle.expectOne(URL_TDB).flush(null, { status: 401, statusText: 'Unauthorized' });
    controle.expectOne(URL_RAFRAICHIR).flush(jetons('A2', 'R2'));
    controle.expectOne(URL_TDB).flush(null, { status: 401, statusText: 'Unauthorized' });

    expect(erreur?.status).toBe(401);
    controle.expectNone(URL_RAFRAICHIR);
    expect(session.session()?.jetonAcces).toBe('A2');
  });

  it('les autres erreurs passent sans renouvellement', () => {
    session.enregistrer(jetons('A1', 'R1'));
    let statut = 0;
    http.get(URL_TDB).subscribe({ error: (e: HttpErrorResponse) => (statut = e.status) });
    controle.expectOne(URL_TDB).flush({ message: 'Introuvable' }, { status: 404, statusText: 'Not Found' });
    controle.expectNone(URL_RAFRAICHIR);
    expect(statut).toBe(404);
  });

  it('un 403 est un vrai refus : il remonte sans renouvellement', () => {
    session.enregistrer(jetons('A1', 'R1'));
    let statut = 0;
    http.get(URL_TDB).subscribe({ error: (e: HttpErrorResponse) => (statut = e.status) });
    controle.expectOne(URL_TDB).flush(null, { status: 403, statusText: 'Forbidden' });
    controle.expectNone(URL_RAFRAICHIR);
    expect(statut).toBe(403);
  });
});
