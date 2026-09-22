package com.maindivine.main_divine_multiservices

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var mobiPrintChannel: MobiPrintChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        mobiPrintChannel = MobiPrintChannel(flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        mobiPrintChannel?.dispose()
        mobiPrintChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
