package com.rdnnoob.devicescope

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Best-effort software inventory and metadata reader.
 *
 * The caller must declare QUERY_ALL_PACKAGES in the app manifest if it intends
 * to request broad package visibility. Android/Google Play policy may restrict
 * distribution of apps using this permission.
 */
class SoftwareDiagnostics(private val context: Context) {
    private val pm: PackageManager = context.packageManager

    private fun installedPackages(): List<PackageInfo> {
        return try {
            if (Build.VERSION.SDK_INT >= 33) {
                pm.getInstalledPackages(PackageManager.PackageInfoFlags.of(0L))
            } else {
                @Suppress("DEPRECATION")
                pm.getInstalledPackages(0)
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun launchablePackages(): Set<String> {
        return try {
            val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
            val resolved = if (Build.VERSION.SDK_INT >= 33) {
                pm.queryIntentActivities(
                    intent,
                    PackageManager.ResolveInfoFlags.of(0L)
                )
            } else {
                @Suppress("DEPRECATION")
                pm.queryIntentActivities(intent, 0)
            }
            resolved.mapNotNull { it.activityInfo?.packageName }.toSet()
        } catch (_: Exception) {
            emptySet()
        }
    }

    private fun runningPackages(): Set<String> {
        return try {
            val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            manager.runningAppProcesses
                ?.flatMap { it.pkgList?.toList() ?: emptyList() }
                ?.toSet() ?: emptySet()
        } catch (_: Exception) {
            emptySet()
        }
    }

    private fun packageInfo(packageName: String): PackageInfo? {
        return try {
            val flags = PackageManager.GET_PERMISSIONS or
                if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else 0
            if (Build.VERSION.SDK_INT >= 33) {
                pm.getPackageInfo(
                    packageName,
                    PackageManager.PackageInfoFlags.of(flags.toLong())
                )
            } else {
                @Suppress("DEPRECATION")
                pm.getPackageInfo(packageName, flags)
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun applicationInfo(packageName: String): ApplicationInfo? {
        return try {
            if (Build.VERSION.SDK_INT >= 33) {
                pm.getApplicationInfo(
                    packageName,
                    PackageManager.ApplicationInfoFlags.of(0L)
                )
            } else {
                @Suppress("DEPRECATION")
                pm.getApplicationInfo(packageName, 0)
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun label(info: ApplicationInfo): String {
        return try { pm.getApplicationLabel(info).toString() }
        catch (_: Exception) { info.packageName }
    }

    private fun isSystemApp(info: ApplicationInfo): Boolean {
        val flags = info.flags
        return (flags and ApplicationInfo.FLAG_SYSTEM) != 0 ||
            (flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
    }

    private fun enabledState(packageName: String): String {
        return try {
            when (pm.getApplicationEnabledSetting(packageName)) {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED -> "DISABLED"
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED_USER -> "DISABLED_BY_USER"
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED_UNTIL_USED -> "DISABLED_UNTIL_USED"
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> "ENABLED"
                else -> "DEFAULT"
            }
        } catch (_: Exception) {
            "UNAVAILABLE"
        }
    }

    private fun signingSha256(info: PackageInfo): String {
        return try {
            val certs = if (Build.VERSION.SDK_INT >= 28) {
                val signing = info.signingInfo ?: return "UNAVAILABLE"
                if (signing.hasMultipleSigners()) signing.apkContentsSigners
                else signing.signingCertificateHistory
            } else {
                @Suppress("DEPRECATION")
                info.signatures
            }
            val cert = certs?.firstOrNull() ?: return "UNAVAILABLE"
            MessageDigest.getInstance("SHA-256")
                .digest(cert.toByteArray())
                .joinToString(":") { "%02X".format(it) }
        } catch (_: Exception) {
            "UNAVAILABLE"
        }
    }

    private fun installer(packageName: String): String {
        return try {
            if (Build.VERSION.SDK_INT >= 30) {
                pm.getInstallSourceInfo(packageName).installingPackageName ?: "UNKNOWN"
            } else {
                @Suppress("DEPRECATION")
                pm.getInstallerPackageName(packageName) ?: "UNKNOWN"
            }
        } catch (_: Exception) {
            "UNAVAILABLE"
        }
    }

    private fun formatTime(millis: Long): String {
        if (millis <= 0L) return "UNKNOWN"
        return SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date(millis))
    }

    fun getSoftwareInventory(): List<Map<String, Any?>> {
        val launchable = launchablePackages()
        val running = runningPackages()
        return installedPackages().mapNotNull { info ->
            val app = info.applicationInfo ?: return@mapNotNull null
            val packageName = info.packageName ?: return@mapNotNull null
            mapOf(
                "packageName" to packageName,
                "label" to label(app),
                "versionName" to (info.versionName ?: "UNKNOWN"),
                "systemApp" to isSystemApp(app),
                "enabled" to app.enabled,
                "enabledState" to enabledState(packageName),
                "hasLauncherActivity" to launchable.contains(packageName),
                "processObserved" to running.contains(packageName)
            )
        }.sortedBy { (it["label"] as? String ?: "").lowercase(Locale.ROOT) }
    }

    fun getSoftwareAppDetails(packageName: String?): Map<String, Any?> {
        if (packageName.isNullOrBlank()) return mapOf("status" to "INVALID_PACKAGE_NAME")
        val info = packageInfo(packageName)
            ?: return mapOf("status" to "PACKAGE_NOT_VISIBLE_OR_NOT_FOUND", "packageName" to packageName)
        val app = info.applicationInfo
            ?: return mapOf("status" to "APPLICATION_INFO_UNAVAILABLE", "packageName" to packageName)

        val launchable = launchablePackages().contains(packageName)
        val permissions = info.requestedPermissions?.toList() ?: emptyList<String>()
        val targetSdk = app.targetSdkVersion
        val minSdk: Any = if (Build.VERSION.SDK_INT >= 24) app.minSdkVersion else "UNSUPPORTED_ON_API_LEVEL"
        val flags = app.flags

        return mapOf(
            "status" to "OK",
            "packageName" to packageName,
            "label" to label(app),
            "versionName" to (info.versionName ?: "UNKNOWN"),
            "versionCode" to if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else @Suppress("DEPRECATION") info.versionCode.toLong(),
            "targetSdk" to targetSdk,
            "minSdk" to minSdk,
            "installer" to installer(packageName),
            "enabled" to app.enabled,
            "enabledState" to enabledState(packageName),
            "hasLauncherActivity" to launchable,
            "systemApp" to isSystemApp(app),
            "firstInstallTime" to formatTime(info.firstInstallTime),
            "lastUpdateTime" to formatTime(info.lastUpdateTime),
            "debuggable" to ((flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0),
            "allowBackup" to ((flags and ApplicationInfo.FLAG_ALLOW_BACKUP) != 0),
            "suspended" to if (Build.VERSION.SDK_INT >= 24) {
                (flags and ApplicationInfo.FLAG_SUSPENDED) != 0
            } else {
                "UNSUPPORTED"
            },
            "signingCertificateSha256" to signingSha256(info),
            "requestedPermissions" to permissions
        )
    }

    private fun findPackage(vararg candidates: String): String {
        for (name in candidates) {
            if (applicationInfo(name) != null) return name
        }
        return "NOT_FOUND_OR_NOT_VISIBLE"
    }

    fun getSystemSoftwareDiagnostics(): Map<String, Any?> {
        val webView = findPackage(
            "com.google.android.webview",
            "com.android.webview",
            "com.android.chrome"
        )
        return mapOf(
            "webView" to webView,
            "playServices" to findPackage("com.google.android.gms"),
            "playStore" to findPackage("com.android.vending"),
            "systemUi" to findPackage("com.android.systemui"),
            "packageInstaller" to findPackage("com.google.android.packageinstaller", "com.android.packageinstaller"),
            "googleServicesFramework" to findPackage("com.google.android.gsf"),
            "oneUiHome" to findPackage("com.sec.android.app.launcher"),
            "galaxyStore" to findPackage("com.sec.android.app.samsungapps")
        )
    }

    fun getRuntimeDiagnostics(): Map<String, Any?> {
        return mapOf(
            "javaRuntime" to (System.getProperty("java.runtime.version") ?: "UNKNOWN"),
            "javaVm" to (System.getProperty("java.vm.name") ?: "UNKNOWN"),
            "javaVmVersion" to (System.getProperty("java.vm.version") ?: "UNKNOWN"),
            "osName" to (System.getProperty("os.name") ?: "UNKNOWN"),
            "osVersion" to (System.getProperty("os.version") ?: "UNKNOWN"),
            "supportedAbis" to Build.SUPPORTED_ABIS.toList(),
            "sdkInt" to Build.VERSION.SDK_INT,
            "release" to Build.VERSION.RELEASE
        )
    }

    fun getSoftwareSecurityDiagnostics(): Map<String, Any?> {
        val tags = Build.TAGS ?: "UNKNOWN"
        return mapOf(
            "debugBuild" to (Build.TYPE == "eng" || Build.TYPE == "userdebug"),
            "buildType" to (Build.TYPE ?: "UNKNOWN"),
            "buildTags" to tags,
            "testKeysPresent" to tags.contains("test-keys", ignoreCase = true),
            "playProtect" to "NOT_EXPOSED_BY_PUBLIC_API",
            "malwareScan" to "NOT_PERFORMED",
            "rootStatus" to "SEE_SYSTEM_DIAGNOSTICS",
            "assessmentScope" to "LIMITED_INDICATORS_ONLY"
        )
    }

    fun getAppCompatibilityDiagnostics(): Map<String, Any?> {
        val features = try { pm.systemAvailableFeatures?.toList() ?: emptyList() }
        catch (_: Exception) { emptyList() }
        val vulkan = features.mapNotNull { it.name }
            .filter { it.contains("vulkan", ignoreCase = true) }
        val glFeature = features.firstOrNull { it.name == null }
        val glVersion = glFeature?.reqGlEsVersion?.let {
            val major = (it shr 16) and 0xffff
            val minor = it and 0xffff
            "$major.$minor"
        } ?: "NOT_DECLARED"
        return mapOf(
            "openGlesVersion" to glVersion,
            "vulkanFeatures" to if (vulkan.isEmpty()) "NOT_DECLARED" else vulkan,
            "featureCount" to features.size,
            "featureDeclarations" to features.map {
                mapOf("name" to (it.name ?: "GL_ES"), "version" to it.version)
            },
            "note" to "Feature declarations are not a full hardware conformance test."
        )
    }

    fun getSoftwareUpdateDiagnostics(): Map<String, Any?> {
        return mapOf(
            "androidRelease" to Build.VERSION.RELEASE,
            "sdkInt" to Build.VERSION.SDK_INT,
            "securityPatch" to if (Build.VERSION.SDK_INT >= 23) Build.VERSION.SECURITY_PATCH else "UNSUPPORTED",
            "pendingOsUpdate" to "NOT_EXPOSED_BY_PUBLIC_API",
            "otaStatus" to "NOT_VERIFIED"
        )
    }
}
