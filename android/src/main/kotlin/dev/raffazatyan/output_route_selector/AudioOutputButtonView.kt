package dev.raffazatyan.output_route_selector

import android.content.Context
import android.graphics.Color
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import io.flutter.plugin.platform.PlatformView

class AudioOutputButtonView(
    context: Context,
    private val viewId: Int,
    private val creationParams: Map<*, *>?,
    private val plugin: OutputRouteSelectorPlugin
) : PlatformView {
    
    private val TAG = "AudioOutputButtonView"
    private val containerView: FrameLayout
    
    init {
        // Parse creation params
        val width = (creationParams?.get("width") as? Double)?.toInt() ?: 44
        val height = (creationParams?.get("height") as? Double)?.toInt() ?: 44
        
        // Create transparent container that captures taps
        containerView = FrameLayout(context).apply {
            layoutParams = FrameLayout.LayoutParams(width, height)
            setBackgroundColor(Color.TRANSPARENT)
            isClickable = true
            isFocusable = true
            
            setOnClickListener {
                Log.d(TAG, "Audio output button tapped")
                plugin.showAudioOutputDialog()
            }
        }
        
        Log.d(TAG, "AudioOutputButtonView created")
    }
    
    override fun getView(): View = containerView
    
    override fun dispose() {
        Log.d(TAG, "AudioOutputButtonView disposed")
    }
}
