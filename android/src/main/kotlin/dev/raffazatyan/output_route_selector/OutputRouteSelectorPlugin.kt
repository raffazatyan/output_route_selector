package dev.raffazatyan.output_route_selector

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothProfile
import android.content.Context
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

class OutputRouteSelectorPlugin : FlutterPlugin, ActivityAware, EventChannel.StreamHandler {
    private val TAG = "OutputRouteSelector"
    
    private lateinit var context: Context
    private var activity: Activity? = null
    private var eventSink: EventChannel.EventSink? = null
    private lateinit var eventChannel: EventChannel
    private lateinit var audioManager: AudioManager
    private var mediaRouter: MediaRouter? = null
    private val handler = Handler(Looper.getMainLooper())
    
    // MediaRouter callback to detect route changes
    private val mediaRouterCallback = object : MediaRouter.Callback() {
        override fun onRouteSelected(router: MediaRouter, route: MediaRouter.RouteInfo, reason: Int) {
            super.onRouteSelected(router, route, reason)
            Log.d(TAG, "Route selected: ${route.name}")
            sendActiveDeviceEvent(route.name, getDeviceType(route))
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
        
        // Register PlatformView factory
        binding.platformViewRegistry.registerViewFactory(
            "audio_output_button",
            AudioOutputButtonFactory(binding.binaryMessenger, this)
        )
        
        Log.d(TAG, "Plugin attached to engine")
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        eventChannel.setStreamHandler(null)
        mediaRouter?.removeCallback(mediaRouterCallback)
        Log.d(TAG, "Plugin detached from engine")
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
    
    fun getActivity(): Activity? = activity
    
    fun getAudioManager(): AudioManager = audioManager
    
    /// Show the audio output selection dialog (WhatsApp style)
    fun showAudioOutputDialog() {
        activity?.let { act ->
            handler.post {
                try {
                    val dialog = AudioOutputDialog(act, audioManager) { title, deviceType ->
                        switchAudioOutput(title, deviceType)
                    }
                    dialog.show()
                    Log.d(TAG, "Audio output dialog shown")
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
                when (deviceType) {
                    "speaker" -> {
                        audioManager.isSpeakerphoneOn = true
                        audioManager.isBluetoothScoOn = false
                        Log.d(TAG, "Switched to speaker")
                    }
                    "receiver" -> {
                        audioManager.isSpeakerphoneOn = false
                        audioManager.isBluetoothScoOn = false
                        Log.d(TAG, "Switched to receiver")
                    }
                    "bluetooth" -> {
                        audioManager.isBluetoothScoOn = true
                        audioManager.startBluetoothSco()
                        Log.d(TAG, "Switched to Bluetooth: $deviceTitle")
                    }
                    "wiredHeadset" -> {
                        audioManager.isSpeakerphoneOn = false
                        audioManager.isBluetoothScoOn = false
                        Log.d(TAG, "Switched to wired headset")
                    }
                }
                
                // Send event after successful switch
                handler.postDelayed({
                    sendActiveDeviceEvent(deviceTitle, deviceType)
                }, 300)
                
            } catch (e: Exception) {
                Log.e(TAG, "Error switching audio output: ${e.message}")
            }
        }
    }
    
    private fun getDeviceType(route: MediaRouter.RouteInfo): String {
        return when {
            route.isDefault -> "speaker"
            route.isBluetooth -> "bluetooth"
            else -> "speaker"
        }
    }
    
    private fun sendActiveDeviceEvent(title: String, deviceType: String) {
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
            Log.d(TAG, "Sent active device event: $title")
        }
    }
}
