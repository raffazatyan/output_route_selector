package dev.raffazatyan.output_route_selector

import android.app.Dialog
import android.content.Context
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
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
    private val onDeviceSelected: (title: String, deviceType: String) -> Unit
) : Dialog(context) {

    private val items = mutableListOf<AudioOutputItem>()

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
        window?.setLayout(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT
        )
        window?.setGravity(Gravity.BOTTOM)
        window?.attributes?.windowAnimations = android.R.style.Animation_InputMethod

        buildDeviceList()
        setContentView(createDialogView())
    }

    private fun buildDeviceList() {
        items.clear()

        // Determine current active output
        val isSpeakerOn = audioManager.isSpeakerphoneOn
        val isBluetoothOn = audioManager.isBluetoothScoOn || audioManager.isBluetoothA2dpOn
        val isWiredOn = audioManager.isWiredHeadsetOn

        // Speaker (always available)
        items.add(AudioOutputItem(
            title = "speaker",
            displayTitle = "Speaker",
            deviceType = "speaker",
            iconResName = "ic_volume_up",
            isActive = isSpeakerOn && !isBluetoothOn && !isWiredOn
        ))

        // Earpiece (for phones)
        if (context.packageManager.hasSystemFeature("android.hardware.telephony")) {
            items.add(AudioOutputItem(
                title = "receiver",
                displayTitle = "Earpiece",
                deviceType = "receiver",
                iconResName = "ic_phone",
                isActive = !isSpeakerOn && !isBluetoothOn && !isWiredOn
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
                        items.add(AudioOutputItem(
                            title = name,
                            displayTitle = name,
                            deviceType = "bluetooth",
                            iconResName = "ic_bluetooth",
                            isActive = isBluetoothOn
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
                isActive = true
            ))
        }
    }

    private fun createDialogView(): View {
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
            
            // Dark background with rounded corners (like WhatsApp)
            val bgDrawable = GradientDrawable().apply {
                setColor(Color.parseColor("#303030"))
                cornerRadii = floatArrayOf(
                    dp(16).toFloat(), dp(16).toFloat(),  // top-left
                    dp(16).toFloat(), dp(16).toFloat(),  // top-right
                    0f, 0f,  // bottom-right
                    0f, 0f   // bottom-left
                )
            }
            background = bgDrawable
            setPadding(dp(8), dp(16), dp(8), dp(24))
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
                dp(56)
            )
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(16), dp(8), dp(16), dp(8))
            
            // Ripple effect
            val outValue = TypedValue()
            context.theme.resolveAttribute(android.R.attr.selectableItemBackground, outValue, true)
            setBackgroundResource(outValue.resourceId)
            
            isClickable = true
            isFocusable = true
            
            setOnClickListener {
                onDeviceSelected(item.title, item.deviceType)
                dismiss()
            }
        }

        // Icon
        val iconView = ImageView(context).apply {
            layoutParams = LinearLayout.LayoutParams(dp(24), dp(24)).apply {
                marginEnd = dp(24)
            }
            setColorFilter(Color.WHITE)
            
            // Use system icons
            val iconRes = when (item.iconResName) {
                "ic_volume_up" -> android.R.drawable.ic_lock_silent_mode_off
                "ic_phone" -> android.R.drawable.ic_menu_call
                "ic_bluetooth" -> android.R.drawable.stat_sys_data_bluetooth
                "ic_headset" -> android.R.drawable.ic_lock_silent_mode_off
                else -> android.R.drawable.ic_lock_silent_mode_off
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
            textSize = 16f
        }
        itemLayout.addView(titleView)

        // Checkmark if active
        if (item.isActive) {
            val checkView = ImageView(context).apply {
                layoutParams = LinearLayout.LayoutParams(dp(24), dp(24))
                setColorFilter(Color.WHITE)
                setImageResource(android.R.drawable.checkbox_on_background)
            }
            itemLayout.addView(checkView)
        }

        return itemLayout
    }
}
