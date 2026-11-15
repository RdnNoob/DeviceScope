package com.rdnnoob.devicescope

import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.telephony.TelephonyManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.BufferedReader
import java.io.InputStreamReader

class MainActivity : FlutterActivity() {

    private val CHANNEL =
        "com.rdnnoob.devicescope/diagnostics"

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "getSystemDiagnostics" -> {
                    result.success(getSystemDiagnostics())
                }

                "getVendorDiagnostics" -> {
                    result.success(getVendorDiagnostics())
                }

                "getNetworkDiagnostics" -> {
                    result.success(getNetworkDiagnostics())
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // =====================================================
    // SYSTEM DIAGNOSTICS
    // =====================================================

    private fun getSystemDiagnostics(): Map<String, Any?> {

        val tags = Build.TAGS ?: ""
        val type = Build.TYPE ?: ""

        val suPaths = listOf(
            "/system/bin/su",
            "/system/xbin/su",
            "/sbin/su",
            "/system/su",
            "/vendor/bin/su",
            "/data/local/bin/su",
            "/data/local/xbin/su"
        )

        val suDetected = suPaths.any {
            File(it).exists()
        }

        val rootPackages = listOf(
            "com.topjohnwu.magisk",
            "eu.chainfire.supersu",
            "com.koushikdutta.superuser"
        )

        val rootPackageDetected = rootPackages.any {
            try {
                packageManager.getPackageInfo(it, 0)
                true
            } catch (_: Exception) {
                false
            }
        }

        val verifiedBoot = readSystemProperty(
            "ro.boot.verifiedbootstate"
        )

        val flashLocked = readSystemProperty(
            "ro.boot.flash.locked"
        )

        val vbmetaState = readSystemProperty(
            "ro.boot.vbmeta.device_state"
        )

        val bootloader = readSystemProperty(
            "ro.bootloader"
        )

        val kernelVersion = try {
            System.getProperty("os.version") ?: "UNKNOWN"
        } catch (_: Exception) {
            "UNKNOWN"
        }

        val twrpVersion = readSystemProperty(
            "ro.twrp.version"
        )

        val recoveryVersion = readSystemProperty(
            "ro.bootimage.build.version"
        )

        val rootIndicators = mutableListOf<String>()

        if (suDetected) {
            rootIndicators.add("SU_BINARY_DETECTED")
        }

        if (rootPackageDetected) {
            rootIndicators.add("ROOT_PACKAGE_DETECTED")
        }

        if (tags.contains("test-keys", ignoreCase = true)) {
            rootIndicators.add("TEST_KEYS")
        }

        return mapOf(

            "buildTags" to tags,
            "buildType" to type,

            "buildFingerprint" to Build.FINGERPRINT,

            "securityPatch" to
                if (Build.VERSION.SDK_INT >= 23)
                    Build.VERSION.SECURITY_PATCH
                else
                    "UNSUPPORTED",

            "bootloader" to
                if (bootloader.isNotBlank())
                    bootloader
                else
                    "UNKNOWN",

            "kernelVersion" to kernelVersion,

            "suBinaryDetected" to suDetected,

            "rootPackageDetected" to rootPackageDetected,

            "rootIndicators" to rootIndicators,

            "rootStatus" to when {
                suDetected || rootPackageDetected ->
                    "DETECTED"

                else ->
                    "NOT_DETECTED"
            },

            "verifiedBoot" to
                if (verifiedBoot.isNotBlank())
                    verifiedBoot
                else
                    "UNKNOWN",

            "bootloaderLock" to
                if (flashLocked.isNotBlank())
                    flashLocked
                else
                    "UNKNOWN",

            "vbmetaDeviceState" to
                if (vbmetaState.isNotBlank())
                    vbmetaState
                else
                    "UNKNOWN",

            "twrpVersion" to
                if (twrpVersion.isNotBlank())
                    twrpVersion
                else
                    "UNKNOWN",

            "recoveryVersion" to
                if (recoveryVersion.isNotBlank())
                    recoveryVersion
                else
                    "UNKNOWN",

            "previouslyRooted" to "UNKNOWN",

            "officialFirmware" to "NOT_VERIFIED"
        )
    }

    // =====================================================
    // VENDOR DIAGNOSTICS
    // =====================================================

    private fun getVendorDiagnostics(): Map<String, Any?> {

        val manufacturer = Build.MANUFACTURER
        val brand = Build.BRAND
        val model = Build.MODEL
        val product = Build.PRODUCT
        val device = Build.DEVICE

        val properties = mapOf(
            "manufacturer" to manufacturer,
            "brand" to brand,
            "model" to model,
            "product" to product,
            "device" to device,

            "salesRegion" to readSystemProperty(
                "ro.csc.sales_code"
            ),

            "salesCode" to readSystemProperty(
                "ro.boot.sales_code"
            ),

            "carrierBranding" to readSystemProperty(
                "ro.carrier"
            ),

            "operatorBranding" to readSystemProperty(
                "ro.boot.carrierid"
            ),

            "countryCode" to readSystemProperty(
                "ro.csc.country_code"
            ),

            "hardwarePlatform" to readSystemProperty(
                "ro.board.platform"
            ),

            "manufacturingCountry" to "UNKNOWN",

            "originalMarket" to "UNKNOWN"
        )

        return properties.mapValues { (_, value) ->
            if (value is String && value.isBlank()) {
                "UNKNOWN"
            } else {
                value
            }
        }
    }

    // =====================================================
    // NETWORK DIAGNOSTICS
    // =====================================================

    private fun getNetworkDiagnostics(): Map<String, Any?> {

        val telephony = getSystemService(
            Context.TELEPHONY_SERVICE
        ) as TelephonyManager

        val simState = try {
            telephony.simState
        } catch (_: SecurityException) {
            -1
        }

        val simStateName = when (simState) {

            TelephonyManager.SIM_STATE_ABSENT ->
                "ABSENT"

            TelephonyManager.SIM_STATE_READY ->
                "READY"

            TelephonyManager.SIM_STATE_PIN_REQUIRED ->
                "PIN_REQUIRED"

            TelephonyManager.SIM_STATE_PUK_REQUIRED ->
                "PUK_REQUIRED"

            TelephonyManager.SIM_STATE_NETWORK_LOCKED ->
                "NETWORK_LOCKED"

            TelephonyManager.SIM_STATE_UNKNOWN ->
                "UNKNOWN"

            else ->
                "PERMISSION_REQUIRED_OR_UNKNOWN"
        }

        return mapOf(
            "simState" to simStateName,
            "simOperator" to "PERMISSION_REQUIRED",
            "simCountry" to "PERMISSION_REQUIRED",
            "networkOperator" to "PERMISSION_REQUIRED",
            "networkType" to "PERMISSION_REQUIRED",
            "roaming" to "PERMISSION_REQUIRED",
            "carrierLock" to "UNKNOWN",
            "simValidity" to "NOT_VERIFIED"
        )
    }

    // =====================================================
    // ANDROID SYSTEM PROPERTY READER
    // =====================================================

    private fun readSystemProperty(
        key: String
    ): String {

        return try {

            val systemProperties = Class.forName(
                "android.os.SystemProperties"
            )

            val getMethod = systemProperties.getMethod(
                "get",
                String::class.java
            )

            getMethod.invoke(
                null,
                key
            ) as? String ?: ""

        } catch (_: Exception) {

            ""
        }
    }
}
