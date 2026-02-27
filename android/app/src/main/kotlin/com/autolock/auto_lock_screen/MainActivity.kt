package com.autolock.auto_lock_screen

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.autolock/lock_screen"
    private val REQUEST_CODE_ENABLE_ADMIN = 1001

    private lateinit var devicePolicyManager: DevicePolicyManager
    private lateinit var adminComponent: ComponentName
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        devicePolicyManager =
            getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        adminComponent = ComponentName(this, AutoLockDeviceAdminReceiver::class.java)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestAdmin" -> {
                        requestDeviceAdmin(result)
                    }

                    "isAdminActive" -> {
                        result.success(devicePolicyManager.isAdminActive(adminComponent))
                    }

                    "isServiceRunning" -> {
                        result.success(LockScreenService.isRunning)
                    }

                    "startService" -> {
                        val timeoutMs = extractLong(call.argument<Any>("timeoutMs"), 5 * 60 * 1000L)
                        startLockService(timeoutMs)
                        result.success(true)
                    }

                    "stopService" -> {
                        stopLockService()
                        result.success(true)
                    }

                    "updateTimeout" -> {
                        val timeoutMs = extractLong(call.argument<Any>("timeoutMs"), 5 * 60 * 1000L)
                        updateServiceTimeout(timeoutMs)
                        result.success(true)
                    }

                    "lockNow" -> {
                        if (devicePolicyManager.isAdminActive(adminComponent)) {
                            devicePolicyManager.lockNow()
                            result.success(true)
                        } else {
                            result.error("NOT_ADMIN", "Device admin not active", null)
                        }
                    }

                    "removeAdmin" -> {
                        if (devicePolicyManager.isAdminActive(adminComponent)) {
                            devicePolicyManager.removeActiveAdmin(adminComponent)
                        }
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun extractLong(value: Any?, default: Long): Long {
        return when (value) {
            is Long -> value
            is Int -> value.toLong()
            is Number -> value.toLong()
            else -> default
        }
    }

    private fun requestDeviceAdmin(result: MethodChannel.Result) {
        if (devicePolicyManager.isAdminActive(adminComponent)) {
            result.success(true)
            return
        }
        pendingResult = result
        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
            putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent)
            putExtra(
                DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                "需要设备管理员权限来锁定屏幕"
            )
        }
        startActivityForResult(intent, REQUEST_CODE_ENABLE_ADMIN)
    }

    private fun startLockService(timeoutMs: Long) {
        val intent = Intent(this, LockScreenService::class.java).apply {
            putExtra(LockScreenService.EXTRA_TIMEOUT, timeoutMs)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopLockService() {
        stopService(Intent(this, LockScreenService::class.java))
    }

    private fun updateServiceTimeout(timeoutMs: Long) {
        val intent = Intent(this, LockScreenService::class.java).apply {
            action = LockScreenService.ACTION_UPDATE_TIMEOUT
            putExtra(LockScreenService.EXTRA_TIMEOUT, timeoutMs)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_ENABLE_ADMIN) {
            val isAdmin = devicePolicyManager.isAdminActive(adminComponent)
            pendingResult?.success(isAdmin)
            pendingResult = null
        }
    }
}
