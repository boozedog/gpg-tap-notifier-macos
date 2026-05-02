// Copyright 2026 Palantir Technologies, Inc. All rights reserved.
// Licensed under the Apache License, Version 2.0.

import AVFoundation
import Foundation
import GpgTapNotifierUserDefaults
import Intents
import os

final class DeliveryMechanismTTS: NSObject, DeliveryMechanism {
    private let logger = Logger()
    private let synthesizer = AVSpeechSynthesizer()

    func present(title: String, body: String) async -> PresentStopReason {
        // Respect Focus / Do Not Disturb when the user has already authorized
        // focus-status access (granted from the configuration GUI). The agent
        // is a headless LSUIElement process and cannot present the
        // authorization prompt itself; we only consult the status here.
        if INFocusStatusCenter.default.authorizationStatus == .authorized
            && INFocusStatusCenter.default.focusStatus.isFocused == true {
            logger.debug("Skipping TTS reminder while user is in a Focus mode.")
            return .dismissed
        }

        let voiceId = AppUserDefaults.ttsSuite?.string(forKey: AppUserDefaults.ttsVoiceIdentifier.key)
        let utterance = AVSpeechUtterance(string: title)
        if let voiceId, !voiceId.isEmpty, let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = voice
        }

        await MainActor.run {
            synthesizer.speak(utterance)
        }

        return .dismissed
    }

    func dismiss() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}
