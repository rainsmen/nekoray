package com.nekoray.client

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.nekoray.client/vpn"
        private const val REQUEST_VPN_CODE = 2026
    }

    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "prepare" -> handlePrepare(result)
                "start" -> handleStart(call, result)
                "stop" -> handleStop(result)
                "isRunning" -> result.success(NekoVpnService.isRunning)
                else -> result.notImplemented()
            }
        }
    }

    private fun handlePrepare(result: MethodChannel.Result) {
        val intent = VpnService.prepare(this)
        if (intent == null) {
            // Already authorized
            result.success(true)
        } else {
            // Needs user consent; launch Android system dialog
            pendingResult = result
            startActivityForResult(intent, REQUEST_VPN_CODE)
        }
    }

    private fun handleStart(call: MethodCall, result: MethodChannel.Result) {
        val mtu = call.argument<Int>("mtu") ?: 1500
        val ipv6 = call.argument<Boolean>("ipv6") ?: false
        val fd = NekoVpnService.start(this, mtu, ipv6)
        if (fd >= 0) {
            result.success(fd)
        } else {
            result.error("VPN_ESTABLISH_FAILED", "Failed to establish VPN interface", null)
        }
    }

    private fun handleStop(result: MethodChannel.Result) {
        NekoVpnService.stop(this)
        result.success(true)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_VPN_CODE) {
            pendingResult?.success(resultCode == Activity.RESULT_OK)
            pendingResult = null
        } else {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }
}
