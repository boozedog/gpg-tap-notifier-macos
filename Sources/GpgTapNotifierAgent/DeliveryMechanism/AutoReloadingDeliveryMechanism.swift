// Copyright 2022 Palantir Technologies, Inc. All rights reserved.
// Licensed under the Apache License, Version 2.0.

import Foundation
import GpgTapNotifierUserDefaults

class AutoReloadingDeliveryMechanism {
    private var cachedDeliveryMechanism: CachedDeliveryMechansim?

    func get() -> DeliveryMechanism {
        let cacheKey = readCurrentCacheKey()
        if let cached = cachedDeliveryMechanism, cached.cacheKey == cacheKey {
            return cached.deliveryMechanism
        }

        // If the user changes the config value while a reminder notification is
        // still shown, we should take care to close it and not leave it on the
        // the screen forever.
        cachedDeliveryMechanism?.deliveryMechanism.dismiss()

        let visual = mapReminderToDeliveryMechanism(cacheKey.visual)
        let mechanism: DeliveryMechanism = cacheKey.ttsEnabled
            ? CompositeDeliveryMechanism(primary: visual, secondary: DeliveryMechanismTTS())
            : visual

        cachedDeliveryMechanism = CachedDeliveryMechansim(
            deliveryMechanism: mechanism,
            cacheKey: cacheKey)

        return mechanism
    }
}

private struct CachedDeliveryMechansim  {
    var deliveryMechanism: DeliveryMechanism
    let cacheKey: DeliveryMechanismCacheKey
}

private struct DeliveryMechanismCacheKey: Equatable {
    let visual: ReminderDeliveryMechanismOption
    let ttsEnabled: Bool
}

private func mapReminderToDeliveryMechanism(_ option: ReminderDeliveryMechanismOption) -> DeliveryMechanism {
    switch option {
    case .notificationCenter: return DeliveryMechanismNotification()
    case .alert: return DeliveryMechanismAlert()
    }
}

private func readCurrentCacheKey() -> DeliveryMechanismCacheKey {
    let visualStored = AppUserDefaults.suite?.integer(forKey: AppUserDefaults.reminderDeliveryMechanism.key)
    let visual = visualStored
        .flatMap { ReminderDeliveryMechanismOption(rawValue: $0) }
        ?? AppUserDefaults.reminderDeliveryMechanism.getDefault()

    let ttsEnabled = AppUserDefaults.ttsSuite?.bool(forKey: AppUserDefaults.ttsEnabled.key)
        ?? AppUserDefaults.ttsEnabled.getDefault()

    return DeliveryMechanismCacheKey(visual: visual, ttsEnabled: ttsEnabled)
}
