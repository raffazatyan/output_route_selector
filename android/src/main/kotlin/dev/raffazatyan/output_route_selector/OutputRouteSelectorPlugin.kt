package dev.raffazatyan.output_route_selector

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothProfile
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.mediarouter.media.MediaControlIntent
import androidx.mediarouter.media.MediaRouteSelector
import androidx.mediarouter.media.MediaRouter
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformViewRegistry

class OutputRouteSelectorPlugin : FlutterPlugin, ActivityAware, EventChannel.StreamHandler, MethodChannel.MethodCallHandler {
    private val TAG = "OutputRouteSelector"
    
    private lateinit var context: Context
    private var activity: Activity? = null
    private var eventSink: EventChannel.EventSink? = null
    private lateinit var eventChannel: EventChannel
    private lateinit var methodChannel: MethodChannel
    private lateinit var audioManager: AudioManager
    private var mediaRouter: MediaRouter? = null
    private val handler = Handler(Looper.getMainLooper())
    private var audioRouteReceiver: BroadcastReceiver? = null
    
    // Track last sent state to avoid duplicate events
    private var lastSentDeviceType: String? = null
    
    // MediaRouter callback to detect route changes
    private val mediaRouterCallback = object : MediaRouter.Callback() {
        override fun onRouteSelected(router: MediaRouter, route: MediaRouter.RouteInfo, reason: Int) {
            super.onRouteSelected(router, route, reason)
            Log.d(TAG, "Route selected: ${route.name} (ignored, using checkAndSendCurrentRoute)")
            // Don't send event directly - use checkAndSendCurrentRoute to get actual state
            handler.postDelayed({ checkAndSendCurrentRoute() }, 200)
        }
        
        override fun onRouteChanged(router: MediaRouter, route: MediaRouter.RouteInfo) {
            super.onRouteChanged(router, route)
            Log.d(TAG, "Route changed: ${route.name}")
        }
    }
    
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        
        // Setup EventChannel for sending events to Flutter
        eventChannel = EventChannel(binding.binaryMessenger, "output_route_selector/events")
        eventChannel.setStreamHandler(this)
        
        // Setup MethodChannel for receiving calls from Flutter
        methodChannel = MethodChannel(binding.binaryMessenger, "output_route_selector/methods")
        methodChannel.setMethodCallHandler(this)
        
        // Register broadcast receiver for audio route changes
        registerAudioRouteReceiver()
        
        Log.d(TAG, "Plugin attached to engine")
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        eventChannel.setStreamHandler(null)
        methodChannel.setMethodCallHandler(null)
        mediaRouter?.removeCallback(mediaRouterCallback)
        unregisterAudioRouteReceiver()
        Log.d(TAG, "Plugin detached from engine")
    }
    
    // MethodChannel.MethodCallHandler
    override fun onMethodCall(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "showAudioOutputDialog" -> {
                val x = call.argument<Int>("x") ?: 0
                val y = call.argument<Int>("y") ?: 0
                val width = call.argument<Int>("width") ?: 44
                val height = call.argument<Int>("height") ?: 44
                showAudioOutputDialog(x, y, width, height)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
    
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        setupMediaRouter()
    }
    
    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }
    
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        setupMediaRouter()
    }
    
    override fun onDetachedFromActivity() {
        mediaRouter?.removeCallback(mediaRouterCallback)
        activity = null
    }
    
    // EventChannel.StreamHandler
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        Log.d(TAG, "Event stream listener registered")
        
        // Send current audio route immediately after listener is registered
        handler.postDelayed({ sendCurrentRoute() }, 100)
    }
    
    override fun onCancel(arguments: Any?) {
        eventSink = null
        Log.d(TAG, "Event stream listener cancelled")
    }
    
    private fun setupMediaRouter() {
        activity?.let { act ->
            mediaRouter = MediaRouter.getInstance(act)
            val selector = MediaRouteSelector.Builder()
                .addControlCategory(MediaControlIntent.CATEGORY_LIVE_AUDIO)
                .build()
            mediaRouter?.addCallback(selector, mediaRouterCallback, MediaRouter.CALLBACK_FLAG_REQUEST_DISCOVERY)
            Log.d(TAG, "MediaRouter setup complete")
        }
    }
    
    private fun registerAudioRouteReceiver() {
        audioRouteReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    AudioManager.ACTION_SPEAKERPHONE_STATE_CHANGED -> {
                        Log.d(TAG, "Speakerphone state changed")
                        handler.postDelayed({ checkAndSendCurrentRoute() }, 100)
                    }
                    AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED -> {
                        val state = intent.getIntExtra(AudioManager.EXTRA_SCO_AUDIO_STATE, -1)
                        Log.d(TAG, "SCO audio state changed: $state")
                        handler.postDelayed({ checkAndSendCurrentRoute() }, 100)
                    }
                    AudioManager.ACTION_HEADSET_PLUG -> {
                        val state = intent.getIntExtra("state", -1)
                        Log.d(TAG, "Headset plug state: $state")
                        handler.postDelayed({ checkAndSendCurrentRoute() }, 100)
                    }
                    BluetoothAdapter.ACTION_CONNECTION_STATE_CHANGED,
                    "android.bluetooth.a2dp.profile.action.CONNECTION_STATE_CHANGED",
                    "android.bluetooth.headset.profile.action.CONNECTION_STATE_CHANGED" -> {
                        Log.d(TAG, "Bluetooth connection state changed: ${intent.action}")
                        // Longer delay for Bluetooth disconnect to propagate
                        handler.postDelayed({ checkAndSendCurrentRoute() }, 300)
                    }
                }
            }
        }
        
        val filter = IntentFilter().apply {
            addAction(AudioManager.ACTION_SPEAKERPHONE_STATE_CHANGED)
            addAction(AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED)
            addAction(AudioManager.ACTION_HEADSET_PLUG)
            addAction(BluetoothAdapter.ACTION_CONNECTION_STATE_CHANGED)
            addAction("android.bluetooth.a2dp.profile.action.CONNECTION_STATE_CHANGED")
            addAction("android.bluetooth.headset.profile.action.CONNECTION_STATE_CHANGED")
        }
        
        // RECEIVER_EXPORTED is required to receive system broadcasts on Android 13+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(audioRouteReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            context.registerReceiver(audioRouteReceiver, filter)
        }
        Log.d(TAG, "Audio route receiver registered")
    }
    
    private fun unregisterAudioRouteReceiver() {
        audioRouteReceiver?.let {
            try {
                context.unregisterReceiver(it)
                Log.d(TAG, "Audio route receiver unregistered")
            } catch (e: Exception) {
                Log.e(TAG, "Error unregistering receiver: ${e.message}")
            }
        }
        audioRouteReceiver = null
    }
    
    /// Get current audio route info
    private fun getCurrentRoute(): Pair<String, String> {
        val isSpeakerOn = audioManager.isSpeakerphoneOn
        val isBluetoothScoOn = audioManager.isBluetoothScoOn
        val isWiredOn = audioManager.isWiredHeadsetOn
        
        var title: String
        var deviceType: String
        
        when {
            isSpeakerOn -> {
                title = "speaker"
                deviceType = "speaker"
            }
            isWiredOn -> {
                title = "wiredHeadset"
                deviceType = "wiredHeadset"
            }
            isBluetoothScoOn -> {
                title = "Bluetooth"
                deviceType = "bluetooth"
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    val audioDevices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                    for (device in audioDevices) {
                        if (device.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                            device.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO) {
                            title = device.productName?.toString() ?: "Bluetooth"
                            break
                        }
                    }
                }
            }
            else -> {
                title = "receiver"
                deviceType = "receiver"
            }
        }
        
        return Pair(title, deviceType)
    }
    
    /// Send current audio route immediately (for initial state)
    private fun sendCurrentRoute() {
        val (title, deviceType) = getCurrentRoute()
        lastSentDeviceType = deviceType
        sendDeviceEvent(title, deviceType)
        Log.d(TAG, "Sent initial route: $title (type: $deviceType)")
    }
    
    /// Check current audio route and send event if changed
    private fun checkAndSendCurrentRoute() {
        val (title, deviceType) = getCurrentRoute()
        
        // Only send if changed
        if (deviceType != lastSentDeviceType) {
            lastSentDeviceType = deviceType
            sendDeviceEvent(title, deviceType)
            Log.d(TAG, "Route changed externally to: $title")
        }
    }
    
    fun getActivity(): Activity? = activity
    
    fun getAudioManager(): AudioManager = audioManager
    
    /// Show the audio output selection dialog (WhatsApp style)
    fun showAudioOutputDialog(anchorX: Int, anchorY: Int, anchorWidth: Int, anchorHeight: Int) {
        activity?.let { act ->
            handler.post {
                try {
                    val dialog = AudioOutputDialog(
                        act, 
                        audioManager,
                        anchorX,
                        anchorY,
                        anchorWidth,
                        anchorHeight
                    ) { title, deviceType ->
                        switchAudioOutput(title, deviceType)
                    }
                    dialog.show()
                    Log.d(TAG, "Audio output dialog shown at ($anchorX, $anchorY)")
                } catch (e: Exception) {
                    Log.e(TAG, "Error showing audio output dialog: ${e.message}")
                }
            }
        } ?: Log.e(TAG, "No activity available to show dialog")
    }
    
    /// Get available audio output devices
    fun getAvailableAudioOutputs(): List<Map<String, Any>> {
        val devices = mutableListOf<Map<String, Any>>()
        
        // Get current active route
        val currentRoute = mediaRouter?.selectedRoute
        
        // Add speaker (always available)
        devices.add(mapOf(
            "title" to "speaker",
            "isActive" to (audioManager.isSpeakerphoneOn || currentRoute?.isDefault == true),
            "deviceType" to "speaker"
        ))
        
        // Add earpiece for phones
        if (context.packageManager.hasSystemFeature("android.hardware.telephony")) {
            devices.add(mapOf(
                "title" to "receiver",
                "isActive" to (!audioManager.isSpeakerphoneOn && !audioManager.isBluetoothA2dpOn && !audioManager.isWiredHeadsetOn),
                "deviceType" to "receiver"
            ))
        }
        
        // Add wired headset if connected
        if (audioManager.isWiredHeadsetOn) {
            devices.add(mapOf(
                "title" to "wiredHeadset",
                "isActive" to true,
                "deviceType" to "wiredHeadset"
            ))
        }
        
        // Add Bluetooth devices
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val audioDevices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            for (device in audioDevices) {
                if (device.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                    device.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO) {
                    val name = device.productName?.toString() ?: "Bluetooth"
                    devices.add(mapOf(
                        "title" to name,
                        "isActive" to audioManager.isBluetoothA2dpOn,
                        "deviceType" to "bluetooth"
                    ))
                }
            }
        }
        
        // Also check MediaRouter routes
        mediaRouter?.let { router ->
            for (i in 0 until router.routes.size) {
                val route = router.routes[i]
                if (!route.isDefault && route.isEnabled) {
                    val deviceType = getDeviceType(route)
                    if (deviceType == "bluetooth" && !devices.any { it["title"] == route.name }) {
                        devices.add(mapOf(
                            "title" to route.name,
                            "isActive" to route.isSelected,
                            "deviceType" to deviceType
                        ))
                    }
                }
            }
        }
        
        Log.d(TAG, "Available outputs: ${devices.size} devices")
        return devices
    }
    
    /// Switch to a specific audio output
    fun switchAudioOutput(deviceTitle: String, deviceType: String) {
        handler.post {
            try {
                var actualTitle = deviceTitle
                var actualType = deviceType
                
                when (deviceType) {
                    "speaker" -> {
                        audioManager.stopBluetoothSco()
                        audioManager.isBluetoothScoOn = false
                        audioManager.isSpeakerphoneOn = true
                        actualTitle = "speaker"
                        actualType = "speaker"
                        Log.d(TAG, "Set speaker ON, bluetooth OFF")
                    }
                    "receiver" -> {
                        audioManager.stopBluetoothSco()
                        audioManager.isBluetoothScoOn = false
                        audioManager.isSpeakerphoneOn = false
                        actualTitle = "receiver"
                        actualType = "receiver"
                        Log.d(TAG, "Set speaker OFF, bluetooth OFF (receiver)")
                    }
                    "bluetooth" -> {
                        audioManager.isSpeakerphoneOn = false
                        audioManager.startBluetoothSco()
                        audioManager.isBluetoothScoOn = true
                        Log.d(TAG, "Set speaker OFF, bluetooth ON: $deviceTitle")
                    }
                    "wiredHeadset" -> {
                        audioManager.stopBluetoothSco()
                        audioManager.isBluetoothScoOn = false
                        audioManager.isSpeakerphoneOn = false
                        actualTitle = "wiredHeadset"
                        actualType = "wiredHeadset"
                        Log.d(TAG, "Set speaker OFF, bluetooth OFF (wired)")
                    }
                }
                
                // Send event with what we set
                handler.postDelayed({
                    sendDeviceEvent(actualTitle, actualType)
                }, 300)
                
            } catch (e: Exception) {
                Log.e(TAG, "Error switching audio output: ${e.message}")
            }
        }
    }
    
    private fun sendDeviceEvent(title: String, deviceType: String) {
        // Update last sent state
        lastSentDeviceType = deviceType
        
        val event = mapOf(
            "event" to "audioRouteChanged",
            "activeDevice" to mapOf(
                "title" to title,
                "isActive" to true,
                "deviceType" to deviceType
            )
        )
        
        handler.post {
            eventSink?.success(event)
            Log.d(TAG, "Sent device event: $title (type: $deviceType)")
        }
    }
    
    private fun getDeviceType(route: MediaRouter.RouteInfo): String {
        return when {
            route.isDefault -> "speaker"
            route.isBluetooth -> "bluetooth"
            else -> "speaker"
        }
    }
}
