// Copyright 2026 Palantir Technologies, Inc. All rights reserved.
// Licensed under the Apache License, Version 2.0.

import AVFoundation
import Intents
import SwiftUI
import GpgTapNotifierUserDefaults

private let systemDefaultVoiceTag = ""

struct TextToSpeechView: View {
    @AppStorage(AppUserDefaults.ttsEnabled.key, store: AppUserDefaults.ttsSuite)
    private var ttsEnabled: Bool = AppUserDefaults.ttsEnabled.getDefault()

    // @AppStorage requires a non-optional String to bind a Picker tag, so the
    // empty string represents "system default" both in storage and in the UI.
    @AppStorage(AppUserDefaults.ttsVoiceIdentifier.key, store: AppUserDefaults.ttsSuite)
    private var ttsVoiceIdentifier: String = systemDefaultVoiceTag

    @AppStorage(AppUserDefaults.reminderTitle.key, store: AppUserDefaults.suite)
    private var reminderTitle: String = AppUserDefaults.reminderTitle.getDefault()

    @StateObject private var speaker = TextToSpeechPreviewer()

    private var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .sorted { lhs, rhs in
                if lhs.language == rhs.language { return lhs.name < rhs.name }
                return lhs.language < rhs.language
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Also speak reminders aloud", isOn: $ttsEnabled)
                .onChange(of: ttsEnabled) { newValue in
                    if newValue { requestFocusAuthorizationIfNeeded() }
                }

            HStack {
                Text("Voice:")
                Picker("", selection: $ttsVoiceIdentifier) {
                    Text("System default").tag(systemDefaultVoiceTag)
                    Divider()
                    ForEach(availableVoices, id: \.identifier) { voice in
                        Text("\(voice.name) (\(voice.language))").tag(voice.identifier)
                    }
                }
                .labelsHidden()
                .disabled(!ttsEnabled)
            }

            Text("Spoken text comes from the title configured on the Message Text tab. Reminders are silenced while Do Not Disturb or any other Focus mode is active.")
                .foregroundColor(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button(action: speakTest) {
                    Text(speaker.isSpeaking ? "Stop" : "Speak Test")
                }
                .disabled(!ttsEnabled)
            }
        }
    }

    private func speakTest() {
        if speaker.isSpeaking {
            speaker.stop()
        } else {
            speaker.speak(text: reminderTitle, voiceIdentifier: ttsVoiceIdentifier)
        }
    }

    private func requestFocusAuthorizationIfNeeded() {
        guard INFocusStatusCenter.default.authorizationStatus == .notDetermined else { return }
        Task {
            _ = await INFocusStatusCenter.default.requestAuthorization()
        }
    }
}

private final class TextToSpeechPreviewer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(text: String, voiceIdentifier: String) {
        let utterance = AVSpeechUtterance(string: text)
        if !voiceIdentifier.isEmpty, let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            utterance.voice = voice
        }
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }
}

struct TextToSpeechView_Previews: PreviewProvider {
    static var previews: some View {
        TextToSpeechView()
    }
}
