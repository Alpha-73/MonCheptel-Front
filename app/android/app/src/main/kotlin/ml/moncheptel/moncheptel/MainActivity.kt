package ml.moncheptel.moncheptel

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

/**
 * Cree les deux categories de notifications de MonCheptel (Android 8 et
 * plus). Le serveur choisit la categorie de chaque notification
 * (PasserelleFirebase) ; l'utilisateur peut en couper une dans les reglages
 * du telephone sans perdre l'autre.
 *
 *  - moncheptel_urgent : cas confie, reponse du veterinaire, alerte de zone.
 *    Importance haute : bandeau en haut de l'ecran et son.
 *  - moncheptel_infos  : rappels de soins, moderation des conseils.
 *    Importance normale : son, sans bandeau.
 *
 * Creer une categorie qui existe deja ne fait rien : appel sans risque a
 * chaque lancement.
 */
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val gestionnaire = getSystemService(NotificationManager::class.java)
            gestionnaire?.createNotificationChannels(listOf(
                NotificationChannel(
                    "moncheptel_urgent",
                    "Cas et alertes sanitaires",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "Nouveau cas confié, réponse du vétérinaire, alerte dans votre zone."
                },
                NotificationChannel(
                    "moncheptel_infos",
                    "Rappels et informations",
                    NotificationManager.IMPORTANCE_DEFAULT,
                ).apply {
                    description = "Soins à faire, conseils publiés ou à revoir."
                },
            ))
        }
    }
}
