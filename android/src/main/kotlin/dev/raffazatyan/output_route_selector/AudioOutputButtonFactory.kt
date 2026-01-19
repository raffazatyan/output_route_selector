package dev.raffazatyan.output_route_selector

import android.content.Context
import android.view.View
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class AudioOutputButtonFactory(
    private val messenger: BinaryMessenger,
    private val plugin: OutputRouteSelectorPlugin
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as? Map<*, *>
        return AudioOutputButtonView(context, viewId, creationParams, plugin)
    }
}
