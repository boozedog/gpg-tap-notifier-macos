// Copyright 2026 Palantir Technologies, Inc. All rights reserved.
// Licensed under the Apache License, Version 2.0.

import Foundation

/// Fans a reminder out to two underlying delivery mechanisms. Used when the
/// user has enabled an additive mechanism (e.g. text-to-speech) on top of a
/// visual one (alert / notification). The primary's PresentStopReason is the
/// authoritative result; the secondary runs concurrently and its result is
/// discarded.
final class CompositeDeliveryMechanism: DeliveryMechanism {
    private var primary: DeliveryMechanism
    private var secondary: DeliveryMechanism

    init(primary: DeliveryMechanism, secondary: DeliveryMechanism) {
        self.primary = primary
        self.secondary = secondary
    }

    func present(title: String, body: String) async -> PresentStopReason {
        // Run the secondary's present in a detached task so we don't block on
        // it. Capturing `secondary` by reference is fine here because both
        // mechanisms are class types in practice.
        Task { [secondary] in
            var sec = secondary
            _ = await sec.present(title: title, body: body)
        }
        return await primary.present(title: title, body: body)
    }

    func dismiss() {
        primary.dismiss()
        secondary.dismiss()
    }

    func setupForReminderTest() async {
        await primary.setupForReminderTest()
        await secondary.setupForReminderTest()
    }
}
