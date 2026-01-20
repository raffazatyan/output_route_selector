package dev.raffazatyan.output_route_selector

import android.app.Dialog
import android.bluetooth.BluetoothAdapter
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.DisplayMetrics
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.Window
import android.view.WindowManager
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

class AudioOutputDialog(
    context: Context,
    private val audioManager: AudioManager,
    private val anchorX: Int,
    private val anchorY: Int,
    private val anchorWidth: Int,
    private val anchorHeight: Int,
    private val onDeviceSelected: (title: String, deviceType: String) -> Unit
) : Dialog(context) {

    private val items = mutableListOf<AudioOutputItem>()
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var containerView: LinearLayout
    private var audioRouteReceiver: BroadcastReceiver? = null
    private var pollingRunnable: Runnable? = null
    private var lastDeviceState: String = ""

    data class AudioOutputItem(
        val title: String,
        val displayTitle: String,
        val deviceType: String,
        val iconResName: String,
        val isActive: Boolean
    )

    init {
        requestWindowFeature(Window.FEATURE_NO_TITLE)
        window?.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        
        // Remove background dim
        window?.clearFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
        
        buildDeviceList()
        containerView = createDialogView()
        setContentView(containerView)
        
        // Position dialog near the anchor button
        positionDialog()
        
        // Register receiver to update dialog when audio route changes
        registerAudioRouteReceiver()
        
        // Start polling for device changes (backup for missed broadcasts)
        startPolling()
        
        // Save initial state
        lastDeviceState = getCurrentDeviceState()
        
        // Unregister when dialog is dismissed
        setOnDismissListener {
            stopPolling()
            unregisterAudioRouteReceiver()
        }
    }
    
    private fun getCurrentDeviceState(): String {
        val isSpeakerOn = audioManager.isSpeakerphoneOn
        val isBluetoothScoOn = audioManager.isBluetoothScoOn
        val isWiredOn = audioManager.isWiredHeadsetOn
        
        // Build a string representing current state including connected Bluetooth devices
        val sb = StringBuilder()
        sb.append("spk=$isSpeakerOn,bt=$isBluetoothScoOn,wired=$isWiredOn")
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val audioDevices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            for (device in audioDevices) {
                if (device.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                    device.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO) {
                    sb.append(",bt_dev=${device.productName}")
                }
            }
        }
        
        return sb.toString()
    }
    
    private fun startPolling() {
        pollingRunnable = object : Runnable {
            override fun run() {
                if (!isShowing) return
                
                val currentState = getCurrentDeviceState()
                if (currentState != lastDeviceState) {
                    android.util.Log.d("AudioOutputDialog", "State changed: $lastDeviceState -> $currentState")
                    lastDeviceState = currentState
                    refreshDialogContent()
                }
                
                // Check every 300ms
                handler.postDelayed(this, 300)
            }
        }
        handler.postDelayed(pollingRunnable!!, 300)
    }
    
    private fun stopPolling() {
        pollingRunnable?.let { handler.removeCallbacks(it) }
        pollingRunnable = null
    }
    
    private fun registerAudioRouteReceiver() {
        audioRouteReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                android.util.Log.d("AudioOutputDialog", "Received broadcast: ${intent?.action}")
                // Rebuild and refresh the dialog content
                handler.postDelayed({ refreshDialogContent() }, 200)
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
        android.util.Log.d("AudioOutputDialog", "Audio route receiver registered")
    }
    
    private fun unregisterAudioRouteReceiver() {
        audioRouteReceiver?.let {
            try {
                context.unregisterReceiver(it)
            } catch (e: Exception) {
                // Already unregistered
            }
        }
        audioRouteReceiver = null
    }
    
    private fun refreshDialogContent() {
        if (!isShowing) return
        
        // Rebuild device list
        buildDeviceList()
        
        // Clear and rebuild UI
        containerView.removeAllViews()
        
        val dp = { value: Int -> 
            TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP, 
                value.toFloat(), 
                context.resources.displayMetrics
            ).toInt()
        }
        
        // Add items
        for (item in items) {
            containerView.addView(createItemView(item, dp))
        }
        
        // Reposition in case item count changed
        positionDialog()
    }
    
    private fun positionDialog() {
        val displayMetrics = context.resources.displayMetrics
        val density = displayMetrics.density
        
        // Convert Flutter logical pixels to Android pixels
        val anchorXPx = (anchorX * density).toInt()
        val anchorYPx = (anchorY * density).toInt()
        val anchorWidthPx = (anchorWidth * density).toInt()
        val anchorHeightPx = (anchorHeight * density).toInt()
        
        val screenWidth = displayMetrics.widthPixels
        val screenHeight = displayMetrics.heightPixels
        
        // Dialog width (max 200dp)
        val dialogWidth = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, 
            200f, 
            displayMetrics
        ).toInt()
        
        window?.setLayout(dialogWidth, WindowManager.LayoutParams.WRAP_CONTENT)
        
        val wlp = window?.attributes
        wlp?.gravity = Gravity.TOP or Gravity.START
        
        // Center dialog horizontally on the button
        var dialogX = anchorXPx + (anchorWidthPx / 2) - (dialogWidth / 2)
        
        // Estimate dialog height (44dp per item + padding)
        val itemHeight = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, 
            44f, 
            displayMetrics
        ).toInt()
        val estimatedHeight = (items.size * itemHeight) + 
            TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 24f, displayMetrics).toInt()
        
        // Position above button
        var dialogY = anchorYPx - estimatedHeight - 16
        
        // If not enough space above, position below
        if (dialogY < 0) {
            dialogY = anchorYPx + anchorHeightPx + 16
        }
        
        // Clamp to screen bounds
        val margin = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 16f, displayMetrics).toInt()
        wlp?.x = dialogX.coerceIn(margin, screenWidth - dialogWidth - margin)
        wlp?.y = dialogY.coerceIn(margin, screenHeight - estimatedHeight - margin)
        
        window?.attributes = wlp
        window?.attributes?.windowAnimations = android.R.style.Animation_Dialog
    }

    private fun buildDeviceList() {
        items.clear()

        // Determine current active output with correct priority
        val isSpeakerOn = audioManager.isSpeakerphoneOn
        val isBluetoothScoOn = audioManager.isBluetoothScoOn
        val isWiredOn = audioManager.isWiredHeadsetOn
        
        // Determine which one is ACTUALLY active (priority: speaker > wired > bluetooth > receiver)
        val activeSpeaker = isSpeakerOn
        val activeWired = !isSpeakerOn && isWiredOn
        val activeBluetooth = !isSpeakerOn && !isWiredOn && isBluetoothScoOn
        val activeReceiver = !isSpeakerOn && !isWiredOn && !isBluetoothScoOn

        // Speaker (always available)
        items.add(AudioOutputItem(
            title = "speaker",
            displayTitle = "Speaker",
            deviceType = "speaker",
            iconResName = "ic_volume_up",
            isActive = activeSpeaker
        ))

        // Phone (for phones)
        if (context.packageManager.hasSystemFeature("android.hardware.telephony")) {
            items.add(AudioOutputItem(
                title = "receiver",
                displayTitle = "Phone",
                deviceType = "receiver",
                iconResName = "ic_phone",
                isActive = activeReceiver
            ))
        }

        // Bluetooth devices
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val audioDevices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            val addedBluetoothNames = mutableSetOf<String>()
            
            for (device in audioDevices) {
                if (device.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                    device.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO) {
                    val name = device.productName?.toString() ?: "Bluetooth"
                    if (!addedBluetoothNames.contains(name)) {
                        addedBluetoothNames.add(name)
                        // Use airpods icon if name contains "airpods", otherwise bluetooth speaker
                        val icon = if (name.lowercase().contains("airpods")) "ic_airpods" else "ic_bluetooth"
                        items.add(AudioOutputItem(
                            title = name,
                            displayTitle = name,
                            deviceType = "bluetooth",
                            iconResName = icon,
                            isActive = activeBluetooth
                        ))
                    }
                }
            }
        }

        // Wired headset
        if (isWiredOn) {
            items.add(AudioOutputItem(
                title = "wiredHeadset",
                displayTitle = "Headphones",
                deviceType = "wiredHeadset",
                iconResName = "ic_headset",
                isActive = activeWired
            ))
        }
    }

    private fun createDialogView(): LinearLayout {
        val dp = { value: Int -> 
            TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP, 
                value.toFloat(), 
                context.resources.displayMetrics
            ).toInt()
        }

        // Main container
        val container = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            
            // Dark background with rounded corners (popup style)
            val bgDrawable = GradientDrawable().apply {
                setColor(Color.parseColor("#303030"))
                cornerRadius = dp(12).toFloat()
            }
            background = bgDrawable
            elevation = dp(8).toFloat()
            setPadding(dp(4), dp(8), dp(4), dp(8))
        }

        // Add items
        for (item in items) {
            container.addView(createItemView(item, dp))
        }

        return container
    }

    private fun createItemView(item: AudioOutputItem, dp: (Int) -> Int): View {
        val itemLayout = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(44)
            )
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(12), dp(6), dp(12), dp(6))
            
            // Gray ripple effect
            val rippleDrawable = android.graphics.drawable.RippleDrawable(
                android.content.res.ColorStateList.valueOf(Color.parseColor("#505050")),
                null,
                android.graphics.drawable.ColorDrawable(Color.WHITE)
            )
            background = rippleDrawable
            
            isClickable = true
            isFocusable = true
            
            setOnClickListener {
                onDeviceSelected(item.title, item.deviceType)
                dismiss()
            }
        }

        // Icon
        val iconView = ImageView(context).apply {
            layoutParams = LinearLayout.LayoutParams(dp(20), dp(20)).apply {
                marginEnd = dp(12)
            }
            
            // Use custom icons from drawable resources
            val iconRes = when (item.iconResName) {
                "ic_volume_up" -> R.drawable.ic_phone_speaker
                "ic_phone" -> R.drawable.ic_phone
                "ic_bluetooth" -> R.drawable.ic_bluetooth_speaker
                "ic_airpods" -> R.drawable.ic_airpods
                "ic_headset" -> R.drawable.ic_headphones
                else -> R.drawable.ic_phone_speaker
            }
            setImageResource(iconRes)
        }
        itemLayout.addView(iconView)

        // Title
        val titleView = TextView(context).apply {
            layoutParams = LinearLayout.LayoutParams(
                0,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                1f
            )
            text = item.displayTitle
            setTextColor(Color.WHITE)
            textSize = 14f
        }
        itemLayout.addView(titleView)

        // Checkmark if active
        if (item.isActive) {
            val checkView = ImageView(context).apply {
                layoutParams = LinearLayout.LayoutParams(dp(18), dp(18))
                setImageResource(R.drawable.ic_checkmark)
            }
            itemLayout.addView(checkView)
        }

        return itemLayout
    }
}
