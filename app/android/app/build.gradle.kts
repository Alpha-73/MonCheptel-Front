import java.util.Base64
import java.util.Properties

// Signature de publication : lue dans android/key.properties, jamais commite
// (modele : android/key.properties.exemple, guide : GUIDE-ESSAI.md).
//
// Audit global G19 : sans ce fichier, la version de publication partait
// signee avec la cle de DEBOGAGE, sans un mot. Un APK diffuse ainsi ne peut
// plus jamais etre mis a jour avec la vraie cle. Desormais toute tache
// « release » ECHOUE, avec la marche a suivre.
val fichierCle = rootProject.file("key.properties")
val proprietesCle = Properties().apply {
    if (fichierCle.exists()) fichierCle.inputStream().use { load(it) }
}
val cleDePublication = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    .all { !proprietesCle.getProperty(it).isNullOrBlank() }

// Les --dart-define arrivent ici encodes en base64, separes par des virgules.
val definitionsDart: Map<String, String> = (project.findProperty("dart-defines") as String?)
    ?.split(",")
    ?.mapNotNull { brut ->
        runCatching { String(Base64.getDecoder().decode(brut), Charsets.UTF_8) }.getOrNull()
    }
    ?.filter { it.contains("=") }
    ?.associate { it.substringBefore("=") to it.substringAfter("=") }
    ?: emptyMap()

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "ml.moncheptel.moncheptel"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "ml.moncheptel.moncheptel"
        // Firebase Messaging exige Android 6 (API 23) au minimum. Selon la
        // version de Flutter, flutter.minSdkVersion vaut 21 ou plus : on
        // garde le plus grand des deux.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (cleDePublication) {
            create("publication") {
                storeFile = file(proprietesCle.getProperty("storeFile"))
                storePassword = proprietesCle.getProperty("storePassword")
                keyAlias = proprietesCle.getProperty("keyAlias")
                keyPassword = proprietesCle.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Jamais la cle de debogage : sans key.properties, la tache
            // echoue plus bas, avant de produire quoi que ce soit.
            if (cleDePublication) {
                signingConfig = signingConfigs.getByName("publication")
            }
        }
    }
}

// Garde-fou de publication (audit global G19) : verifie, au moment ou une
// tache « Release » va reellement s'executer, que la cle de publication et
// une API en HTTPS sont fournies. Un build debug ou profile n'est pas touche.
gradle.taskGraph.whenReady {
    val publication = allTasks.any {
        it.project == project && it.name.contains("Release") &&
            (it.name.startsWith("assemble") || it.name.startsWith("bundle"))
    }
    if (!publication) return@whenReady

    if (!cleDePublication) {
        throw GradleException(
            "Version de publication refusee : android/key.properties est absent ou incomplet " +
                "(storeFile, storePassword, keyAlias, keyPassword).\n" +
                "Copiez android/key.properties.exemple en android/key.properties et remplissez-le " +
                "(GUIDE-ESSAI.md, « Version de publication »). L'APK ne sera jamais signe avec la " +
                "cle de debogage."
        )
    }
    val fichierMagasin = file(proprietesCle.getProperty("storeFile"))
    if (!fichierMagasin.exists()) {
        throw GradleException(
            "Version de publication refusee : le magasin de cles « ${fichierMagasin.path} » " +
                "indique dans android/key.properties (storeFile) est introuvable."
        )
    }
    val urlApi = definitionsDart["API_URL"]
    if (urlApi == null || !urlApi.startsWith("https://")) {
        throw GradleException(
            "Version de publication refusee : l'adresse de l'API doit etre en HTTPS.\n" +
                "Ajoutez --dart-define=API_URL=https://votre-domaine (recu : ${urlApi ?: "rien"})."
        )
    }
}

// Notifications poussees (Firebase). Le plugin exige google-services.json :
// sans ce fichier, il n'est pas applique et l'application se construit
// comme avant, sans notifications poussees. Le fichier se telecharge dans la
// console Firebase (application Android ml.moncheptel.moncheptel) et se
// place dans android/app/.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.warn("MonCheptel : android/app/google-services.json absent, notifications poussees desactivees.")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
