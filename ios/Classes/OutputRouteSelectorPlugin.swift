import Flutter
import UIKit
import AVFoundation
import os.log

@available(iOS 14.0, *)
public class OutputRouteSelectorPlugin: NSObject, FlutterPlugin {
    private let logger = Logger(subsystem: "OutputRouteSelectorPlugin", category: "audio")
    private var eventSink: FlutterEventSink?
    private var isHandlingAudioRouteChange = false
    private static var sharedInstance: OutputRouteSelectorPlugin?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "output_route_selector", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "output_route_selector/events", binaryMessenger: registrar.messenger())
        let instance = OutputRouteSelectorPlugin()
        sharedInstance = instance
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
        
        // Register PlatformView factory for native button
        let factory = AudioOutputButtonFactory(messenger: registrar.messenger(), plugin: instance)
        registrar.register(factory, withId: "audio_output_button")
    }
    
    static func getSharedInstance() -> OutputRouteSelectorPlugin? {
        return sharedInstance
    }
    
    override init() {
        super.init()
        setupAudioRouteChangeObserver()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getAvailableAudioOutputs":
            handleGetAvailableAudioOutputs(result)
        case "changeAudioOutput":
            handleChangeAudioOutput(call, result: result)
        case "showAudioOutputMenu":
            handleShowAudioOutputMenu(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Get Available Audio Outputs
    
    private func handleGetAvailableAudioOutputs(_ result: @escaping FlutterResult) {
        let session = AVAudioSession.sharedInstance()
        let currentRoute = session.currentRoute
        
        // Determine which output is currently active from currentRoute.outputs
        let activeOutputTypes = Set(currentRoute.outputs.map { $0.portType })
        let isSpeakerActive = activeOutputTypes.contains(.builtInSpeaker)
        let isReceiverActive = activeOutputTypes.contains(.builtInReceiver)
        
        // Get active Bluetooth device UIDs from current route outputs
        let activeBluetoothUIDs = Set(currentRoute.outputs.compactMap { output in
            isBluetoothDevice(output.portType) ? output.uid : nil
        })
        
        var devices: [[String: Any]] = []
        
        // Always available outputs
        devices.append([
            "title": "speaker",
            "isActive": isSpeakerActive,
            "deviceType": "speaker"
        ])
        
        if UIDevice.current.userInterfaceIdiom == .phone {
            devices.append([
                "title": "receiver",
                "isActive": isReceiverActive,
                "deviceType": "receiver"
            ])
        }
        
        // Wired headset - only show if present in current route
        let hasWiredHeadset = currentRoute.outputs.contains { output in
            output.portType == .headphones || output.portType == .headsetMic || output.portType == .usbAudio
        }
        if hasWiredHeadset {
            devices.append([
                "title": "wiredHeadset",
                "isActive": true,
                "deviceType": "wiredHeadset"
            ])
        }
        
        // All Bluetooth devices from availableInputs
        if let availableInputs = session.availableInputs {
            for input in availableInputs where isBluetoothDevice(input.portType) {
                devices.append([
                    "title": input.portName,
                    "isActive": activeBluetoothUIDs.contains(input.uid),
                    "deviceType": "bluetooth"
                ])
            }
        }
        
        logger.info("✅ Available audio outputs: \(devices.count) devices")
        result(devices)
    }
    
    // MARK: - Change Audio Output
    
    private func handleChangeAudioOutput(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let deviceTitle = args["deviceTitle"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "deviceTitle is required", details: nil))
            return
        }
        
        // Set flag to prevent observer from reacting to our own change
        isHandlingAudioRouteChange = true
        
        do {
            // Determine device type by title
            let lowercasedTitle = deviceTitle.lowercased()
            
            if lowercasedTitle == "speaker" {
                try switchToSpeaker()
                logger.info("✅ Switched to speaker")
            } else if lowercasedTitle == "receiver" {
                try switchToReceiver()
                logger.info("✅ Switched to receiver")
            } else if lowercasedTitle == "wiredheadset" {
                try switchToWiredHeadset(result: result)
                return
            } else {
                // Bluetooth device
                try switchToBluetooth(deviceTitle: deviceTitle, result: result)
                return
            }
            
            // Reset flag after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.isHandlingAudioRouteChange = false
            }
            
            result(nil)
        } catch {
            logger.error("❌ Error changing audio output: \(error.localizedDescription)")
            isHandlingAudioRouteChange = false
            result(FlutterError(code: "AUDIO_ROUTE_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    // MARK: - Audio Switching Methods
    
    private func switchToSpeaker() throws {
        let session = AVAudioSession.sharedInstance()
        try session.overrideOutputAudioPort(.speaker)
    }
    
    private func switchToReceiver() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setPreferredInput(nil)
        try session.overrideOutputAudioPort(.none)
    }
    
    private func switchToWiredHeadset(result: @escaping FlutterResult) {
        let session = AVAudioSession.sharedInstance()
        guard let availableInputs = session.availableInputs else {
            isHandlingAudioRouteChange = false
            result(FlutterError(code: "NO_INPUTS", message: "No audio inputs available", details: nil))
            return
        }
        
        guard let wiredInput = availableInputs.first(where: { input in
            input.portType == .headphones || input.portType == .headsetMic || input.portType == .usbAudio
        }) else {
            isHandlingAudioRouteChange = false
            result(FlutterError(code: "DEVICE_NOT_FOUND", message: "Wired headset not available", details: nil))
            return
        }
        
        do {
            try session.setPreferredInput(wiredInput)
            logger.info("✅ Switched to wired headset")
            
            // Reset flag after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.isHandlingAudioRouteChange = false
            }
            
            result(nil)
        } catch {
            logger.error("❌ Error setting preferred input: \(error.localizedDescription)")
            isHandlingAudioRouteChange = false
            result(FlutterError(code: "AUDIO_ROUTE_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    private func switchToBluetooth(deviceTitle: String, result: @escaping FlutterResult) {
        let session = AVAudioSession.sharedInstance()
        guard let availableInputs = session.availableInputs else {
            isHandlingAudioRouteChange = false
            result(FlutterError(code: "NO_INPUTS", message: "No audio inputs available", details: nil))
            return
        }
        
        guard let bluetoothInput = availableInputs.first(where: { input in
            isBluetoothDevice(input.portType) && input.portName == deviceTitle
        }) else {
            let availableDevices = availableInputs
                .filter { isBluetoothDevice($0.portType) }
                .map { $0.portName }
                .joined(separator: ", ")
            logger.warning("⚠️ Bluetooth device '\(deviceTitle)' not found. Available: [\(availableDevices)]")
            isHandlingAudioRouteChange = false
            result(FlutterError(code: "DEVICE_NOT_FOUND", message: "Bluetooth device '\(deviceTitle)' not found", details: nil))
            return
        }
        
        do {
            try session.setPreferredInput(bluetoothInput)
            logger.info("✅ Switched to Bluetooth: \(deviceTitle)")
            
            // Reset flag after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.isHandlingAudioRouteChange = false
            }
            
            result(nil)
        } catch {
            logger.error("❌ Error setting preferred input: \(error.localizedDescription)")
            isHandlingAudioRouteChange = false
            result(FlutterError(code: "AUDIO_ROUTE_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    // MARK: - Show Native Audio Output Menu
    
    private func handleShowAudioOutputMenu(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let x = args["x"] as? Double,
              let y = args["y"] as? Double else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "x and y coordinates are required", details: nil))
            return
        }
        
        // Show menu on main thread
        DispatchQueue.main.async { [weak self] in
            self?.showNativeMenu(at: CGPoint(x: x, y: y))
        }
        
        result(nil)
    }
    
    private var menuButton: UIButton?
    
    @available(iOS 14.0, *)
    private func showNativeMenu(at point: CGPoint) {
        // Get the window
        guard
            let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
            let window = windowScene.windows.first(where: { $0.isKeyWindow })
        else {
            logger.error("❌ Could not find window")
            return
        }
        
        // Remove previous button if exists
        menuButton?.removeFromSuperview()
        
        // Create menu actions with icons (system style)
        let item1 = UIAction(
            title: "Item 1",
            image: UIImage(systemName: "speaker.wave.2.fill"),
            state: .on  // Checkmark
        ) { [weak self] _ in
            print("Selected Item 1")
            self?.cleanupMenuButton()
        }
        
        let item2 = UIAction(
            title: "Item 2", 
            image: UIImage(systemName: "laptopcomputer"),
            state: .off
        ) { [weak self] _ in
            print("Selected Item 2")
            self?.cleanupMenuButton()
        }
        
        let item3 = UIAction(
            title: "Item 3",
            image: UIImage(systemName: "iphone"),
            state: .off
        ) { [weak self] _ in
            print("Selected Item 3")
            self?.cleanupMenuButton()
        }
        
        // Create menu
        let menu = UIMenu(title: "", children: [item1, item2, item3])
        
        // Create VISIBLE button at tap location
        let button = UIButton(type: .system)
        button.frame = CGRect(x: point.x - 22, y: point.y - 22, width: 44, height: 44)
        button.setImage(UIImage(systemName: "speaker.wave.2"), for: .normal)
        button.tintColor = .clear  // Transparent icon
        button.backgroundColor = .clear
        
        // Attach menu - UIKit will show it on tap
        button.menu = menu
        button.showsMenuAsPrimaryAction = true
        
        // Add to window (above everything)
        window.addSubview(button)
        menuButton = button
        
        // Simulate tap to trigger menu immediately
        DispatchQueue.main.async {
            // Use UIKit's built-in menu presentation
            if let interaction = button.interactions.first(where: { $0 is UIContextMenuInteraction }) as? UIContextMenuInteraction {
                // Found the context menu interaction, but we can't trigger it directly
            }
            
            // Alternative: create a touch event
            button.becomeFirstResponder()
            
            // The button is now ready - user's next tap will open menu
            // Or we can try to present it via accessibility
        }
        
        logger.info("✅ Menu button placed at (\(point.x), \(point.y))")
    }
    
    private func cleanupMenuButton() {
        menuButton?.removeFromSuperview()
        menuButton = nil
    }
    
    private func selectAudioOutput(title: String) {
        logger.info("🎯 Selected audio output: \(title)")
        
        // Set flag to prevent observer from reacting
        isHandlingAudioRouteChange = true
        
        let lowercasedTitle = title.lowercased()
        
        do {
            if lowercasedTitle == "speaker" {
                try switchToSpeaker()
                logger.info("✅ Switched to speaker via menu")
            } else if lowercasedTitle == "receiver" {
                try switchToReceiver()
                logger.info("✅ Switched to receiver via menu")
            } else if lowercasedTitle == "wiredheadset" || lowercasedTitle == "headphones" {
                switchToWiredHeadsetViaMenu()
                return
            } else {
                // Bluetooth device
                switchToBluetoothViaMenu(deviceTitle: title)
                return
            }
            
            // Reset flag after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.isHandlingAudioRouteChange = false
                // Refresh outputs after change
                self?.refreshAudioOutputs()
            }
        } catch {
            logger.error("❌ Error switching audio output via menu: \(error.localizedDescription)")
            isHandlingAudioRouteChange = false
        }
    }
    
    private func switchToWiredHeadsetViaMenu() {
        let session = AVAudioSession.sharedInstance()
        guard let availableInputs = session.availableInputs,
              let wiredInput = availableInputs.first(where: { input in
                  input.portType == .headphones || input.portType == .headsetMic || input.portType == .usbAudio
              }) else {
            logger.error("❌ Wired headset not available")
            isHandlingAudioRouteChange = false
            return
        }
        
        do {
            try session.setPreferredInput(wiredInput)
            logger.info("✅ Switched to wired headset via menu")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.isHandlingAudioRouteChange = false
                self?.refreshAudioOutputs()
            }
        } catch {
            logger.error("❌ Error setting wired headset: \(error.localizedDescription)")
            isHandlingAudioRouteChange = false
        }
    }
    
    private func switchToBluetoothViaMenu(deviceTitle: String) {
        let session = AVAudioSession.sharedInstance()
        guard let availableInputs = session.availableInputs,
              let bluetoothInput = availableInputs.first(where: { input in
                  isBluetoothDevice(input.portType) && input.portName == deviceTitle
              }) else {
            logger.error("❌ Bluetooth device '\(deviceTitle)' not available")
            isHandlingAudioRouteChange = false
            return
        }
        
        do {
            try session.setPreferredInput(bluetoothInput)
            logger.info("✅ Switched to Bluetooth '\(deviceTitle)' via menu")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.isHandlingAudioRouteChange = false
                self?.refreshAudioOutputs()
            }
        } catch {
            logger.error("❌ Error setting Bluetooth device: \(error.localizedDescription)")
            isHandlingAudioRouteChange = false
        }
    }
    
    private func refreshAudioOutputs() {
        // Send event to Flutter to refresh outputs
        sendEvent([
            "event": "audioOutputsRefreshed"
        ])
    }
    
    // MARK: - Helper Methods
    
    private func isBluetoothDevice(_ portType: AVAudioSession.Port) -> Bool {
        return portType == .bluetoothHFP || portType == .bluetoothA2DP || portType == .bluetoothLE
    }
    
    // MARK: - Audio Route Change Observer
    
    private func setupAudioRouteChangeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    @objc private func handleAudioRouteChange(notification: Notification) {
        // Skip if we're currently handling a route change ourselves
        guard !isHandlingAudioRouteChange else {
            logger.info("⚠️ Audio route change ignored - handling our own change")
            return
        }
        
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        // Handle route changes that are user-initiated (e.g., from Control Center, Dynamic Island)
        // .override is used when overrideOutputAudioPort is called (from Control Center or native UI)
        // .newDeviceAvailable/.oldDeviceUnavailable for device changes (connect/disconnect)
        // .categoryChange for category changes
        let isUserInitiated = reason == .override || 
                              reason == .newDeviceAvailable || 
                              reason == .oldDeviceUnavailable || 
                              reason == .categoryChange
        
        guard isUserInitiated else {
            logger.info("⚠️ Audio route change ignored - reason: \(reason.rawValue)")
            return
        }
        
        // Log current state when route changes
        logger.info("🔄 Audio route change detected - reason: \(reason.rawValue)")
        
        // Check route change with retry mechanism to ensure we catch the change
        checkAudioRouteWithRetry(reason: reason, attempt: 1, maxAttempts: 3)
    }
    
    private func checkAudioRouteWithRetry(reason: AVAudioSession.RouteChangeReason, attempt: Int, maxAttempts: Int) {
        let delay = Double(attempt) * 0.1 // Increasing delay: 0.1s, 0.2s, 0.3s
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            
            let session = AVAudioSession.sharedInstance()
            let currentRoute = session.currentRoute
            
            // Get current active device info
            var activeDevice: [String: Any]?
            let activeOutputTypes = Set(currentRoute.outputs.map { $0.portType })
            
            if activeOutputTypes.contains(.builtInSpeaker) {
                activeDevice = [
                    "title": "speaker",
                    "isActive": true,
                    "deviceType": "speaker"
                ]
            } else if activeOutputTypes.contains(.builtInReceiver) {
                activeDevice = [
                    "title": "receiver",
                    "isActive": true,
                    "deviceType": "receiver"
                ]
            } else if let wiredOutput = currentRoute.outputs.first(where: { output in
                output.portType == .headphones || output.portType == .headsetMic || output.portType == .usbAudio
            }) {
                activeDevice = [
                    "title": "wiredHeadset",
                    "isActive": true,
                    "deviceType": "wiredHeadset",
                    "portName": wiredOutput.portName
                ]
            } else if let bluetoothOutput = currentRoute.outputs.first(where: { output in
                self.isBluetoothDevice(output.portType)
            }) {
                activeDevice = [
                    "title": bluetoothOutput.portName,
                    "isActive": true,
                    "deviceType": "bluetooth"
                ]
            }
            
            // Log detailed route information for debugging
            let outputPorts = currentRoute.outputs.map { "\($0.portType.rawValue):\($0.portName)" }.joined(separator: ", ")
            self.logger.info("🔊 Audio route check (attempt \(attempt)/\(maxAttempts)) - reason: \(reason.rawValue), outputs: [\(outputPorts)]")
            
            // Send event to Flutter on first successful detection or final attempt
            if activeDevice != nil || attempt >= maxAttempts {
                if let device = activeDevice {
                    self.sendEvent([
                        "event": "audioRouteChanged",
                        "reason": reason.rawValue,
                        "activeDevice": device
                    ])
                    self.logger.info("✅ Audio route changed detected (attempt \(attempt)/\(maxAttempts))")
                    
                    // Refresh outputs after route change detected
                    self.refreshAudioOutputs()
                } else {
                    self.sendEvent([
                        "event": "audioRouteChanged",
                        "reason": reason.rawValue
                    ])
                    self.logger.warning("⚠️ Audio route changed but no active device detected after \(maxAttempts) attempts")
                    
                    // Refresh outputs even if no device detected
                    self.refreshAudioOutputs()
                }
            } else if attempt < maxAttempts {
                // If no device detected yet, retry
                self.logger.info("⚠️ No active device detected, retrying... (attempt \(attempt)/\(maxAttempts))")
                self.checkAudioRouteWithRetry(reason: reason, attempt: attempt + 1, maxAttempts: maxAttempts)
            }
        }
    }
    
    private func sendEvent(_ data: [String: Any]) {
        guard let eventSink = eventSink else {
            logger.warning("⚠️ No event sink available")
            return
        }
        eventSink(data)
    }
}

// MARK: - FlutterStreamHandler

extension OutputRouteSelectorPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        logger.info("✅ Event stream listener registered")
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        logger.info("❌ Event stream listener cancelled")
        return nil
    }
}


// MARK: - Helper Functions

@available(iOS 14.0, *)
extension OutputRouteSelectorPlugin {
    /// Get the top-most view controller in the hierarchy
    private func topViewController(from root: UIViewController?) -> UIViewController? {
        // If there's a presented view controller, go deeper
        if let presented = root?.presentedViewController {
            return topViewController(from: presented)
        }
        
        // If it's a navigation controller, get the visible controller
        if let nav = root as? UINavigationController {
            return topViewController(from: nav.visibleViewController)
        }
        
        // If it's a tab bar controller, get the selected controller
        if let tab = root as? UITabBarController {
            return topViewController(from: tab.selectedViewController)
        }
        
        // Otherwise, return the root itself
        return root
    }
    
    /// Build UIMenu with current audio outputs (used by PlatformView)
    func buildAudioOutputMenu(onSelection: @escaping (String) -> Void) -> UIMenu {
        let session = AVAudioSession.sharedInstance()
        let currentRoute = session.currentRoute
        
        // Determine which output is currently active
        let activeOutputTypes = Set(currentRoute.outputs.map { $0.portType })
        let activeBluetoothUIDs = Set(currentRoute.outputs.compactMap { output in
            isBluetoothDevice(output.portType) ? output.uid : nil
        })
        
        var menuActions: [UIAction] = []
        
        // Speaker option
        let isSpeakerActive = activeOutputTypes.contains(.builtInSpeaker)
        let speakerAction = UIAction(
            title: "Speaker",
            image: UIImage(systemName: "speaker.wave.2.fill"),
            state: isSpeakerActive ? .on : .off
        ) { _ in
            onSelection("speaker")
        }
        menuActions.append(speakerAction)
        
        // Receiver option (iPhone only)
        if UIDevice.current.userInterfaceIdiom == .phone {
            let isReceiverActive = activeOutputTypes.contains(.builtInReceiver)
            let receiverAction = UIAction(
                title: "iPhone",
                image: UIImage(systemName: "iphone"),
                state: isReceiverActive ? .on : .off
            ) { _ in
                onSelection("receiver")
            }
            menuActions.append(receiverAction)
        }
        
        // Wired headset if present
        let hasWiredHeadset = currentRoute.outputs.contains { output in
            output.portType == .headphones || output.portType == .headsetMic || output.portType == .usbAudio
        }
        if hasWiredHeadset {
            let wiredAction = UIAction(
                title: "Headphones",
                image: UIImage(systemName: "headphones"),
                state: .on
            ) { _ in
                onSelection("wiredHeadset")
            }
            menuActions.append(wiredAction)
        }
        
        // Bluetooth devices
        if let availableInputs = session.availableInputs {
            for input in availableInputs where isBluetoothDevice(input.portType) {
                let isActive = activeBluetoothUIDs.contains(input.uid)
                let bluetoothAction = UIAction(
                    title: input.portName,
                    image: UIImage(systemName: "airpodspro"),
                    state: isActive ? .on : .off
                ) { _ in
                    onSelection(input.portName)
                }
                menuActions.append(bluetoothAction)
            }
        }
        
        return UIMenu(title: "", children: menuActions)
    }
    
    /// Handle audio output selection from menu
    func handleMenuSelection(_ title: String) {
        selectAudioOutput(title: title)
    }
}

// MARK: - PlatformView Factory

@available(iOS 14.0, *)
class AudioOutputButtonFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger
    private weak var plugin: OutputRouteSelectorPlugin?
    
    init(messenger: FlutterBinaryMessenger, plugin: OutputRouteSelectorPlugin) {
        self.messenger = messenger
        self.plugin = plugin
        super.init()
    }
    
    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return AudioOutputButtonView(
            frame: frame,
            viewId: viewId,
            args: args,
            messenger: messenger,
            plugin: plugin
        )
    }
    
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

// MARK: - PlatformView (Native UIButton with UIMenu)

@available(iOS 14.0, *)
class AudioOutputButtonView: NSObject, FlutterPlatformView {
    private let logger = Logger(subsystem: "AudioOutputButtonView", category: "ui")
    private let containerView: UIView
    private let menuButton: UIButton
    private weak var plugin: OutputRouteSelectorPlugin?
    
    init(
        frame: CGRect,
        viewId: Int64,
        args: Any?,
        messenger: FlutterBinaryMessenger,
        plugin: OutputRouteSelectorPlugin?
    ) {
        self.plugin = plugin
        
        // Parse arguments
        var buttonWidth: CGFloat = 44
        var buttonHeight: CGFloat = 44
        var isTransparent = false
        
        if let arguments = args as? [String: Any] {
            if let width = arguments["width"] as? Double {
                buttonWidth = CGFloat(width)
            }
            if let height = arguments["height"] as? Double {
                buttonHeight = CGFloat(height)
            }
            if let transparent = arguments["transparent"] as? Bool {
                isTransparent = transparent
            }
        }
        
        // Create container view
        containerView = UIView(frame: CGRect(x: 0, y: 0, width: buttonWidth, height: buttonHeight))
        containerView.backgroundColor = .clear
        
        // Create button - fully transparent, just for tap handling
        menuButton = UIButton(type: .custom)
        menuButton.frame = containerView.bounds
        menuButton.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        menuButton.backgroundColor = .clear
        
        // No visible content - Flutter widget shows underneath
        // Button is just for capturing taps and showing UIMenu
        
        // Enable menu as primary action - THIS IS THE KEY!
        menuButton.showsMenuAsPrimaryAction = true
        
        containerView.addSubview(menuButton)
        
        super.init()
        
        // Build and attach menu
        updateMenu()
        
        // Listen for audio route changes to update menu
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioRouteChanged),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        
        logger.info("✅ AudioOutputButtonView created (transparent overlay)")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func view() -> UIView {
        return containerView
    }
    
    @objc private func audioRouteChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.updateMenu()
        }
    }
    
    private func updateMenu() {
        guard let plugin = plugin else { return }
        
        let menu = plugin.buildAudioOutputMenu { [weak self] selectedTitle in
            self?.logger.info("🎯 Menu selection: \(selectedTitle)")
            plugin.handleMenuSelection(selectedTitle)
            
            // Update menu after selection
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.updateMenu()
            }
        }
        
        menuButton.menu = menu
        logger.info("✅ Menu updated with \(menu.children.count) items")
    }
}
