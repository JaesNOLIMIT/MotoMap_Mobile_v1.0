package com.example.motomap_mobile

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val bluetoothPermissionChannel = "io.motomap.app/bluetooth_permissions"
    private val bluetoothPermissionRequestCode = 327
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            bluetoothPermissionChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "request" -> requestBluetoothPermissions(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun requestBluetoothPermissions(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            result.success(true)
            return
        }

        val permissions = arrayOf(
            Manifest.permission.BLUETOOTH_CONNECT,
            Manifest.permission.BLUETOOTH_SCAN,
        )
        val granted = permissions.all {
            checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
        }
        if (granted) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            result.error(
                "permission_request_in_progress",
                "A Bluetooth permission request is already open.",
                null,
            )
            return
        }
        pendingPermissionResult = result
        requestPermissions(permissions, bluetoothPermissionRequestCode)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != bluetoothPermissionRequestCode) return
        val granted = grantResults.isNotEmpty() && grantResults.all {
            it == PackageManager.PERMISSION_GRANTED
        }
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
    }
}
