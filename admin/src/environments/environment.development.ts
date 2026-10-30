// Configuration de développement : le back Spring Boot tourne en local et
// autorise http://localhost:4200 en CORS, aucun proxy n'est nécessaire.
export const environment = {
  production: false,
  apiUrl: 'http://localhost:8080',
};
