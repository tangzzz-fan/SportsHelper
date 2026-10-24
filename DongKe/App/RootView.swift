import SwiftUI
import DongKeCore

struct RootView: View {
    @Environment(ProfileStore.self) private var profiles
    @Environment(PlanStore.self) private var planStore
    @Environment(NotificationService.self) private var notifications

    @Bindable private var largeText = LargeTextStore.shared

    var body: some View {
        Group {
            if showsOnboarding {
                OnboardingView(initialStep: initialStep) { profile in
                    finish(with: profile)
                }
            } else {
                AppShell()
            }
        }
        .largeTextFloor(largeText)
    }

    private var showsOnboarding: Bool {
        if profiles.hasOnboarded == false { return true }
        #if DEBUG
        return ProcessInfo.processInfo.environment["DK_PREVIEW"] == "onboarding"
        #else
        return false
        #endif
    }

    private var initialStep: OnboardingStep {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["DK_ONBOARD_STEP"], let value = Int(raw) {
            return OnboardingStep(rawValue: value) ?? .basics
        }
        #endif
        return .basics
    }

    private func finish(with profile: UserProfile) {
        profiles.save(profile)
        let generated = PlanGenerator.makePlan(profile: profile)
        planStore.save(generated)
        guard profile.reminderEnabled else { return }
        Task {
            await notifications.requestAuthorization()
            await notifications.reschedule(
                plan: generated,
                settings: ReminderSettingsStore.shared.settings
            )
        }
    }
}
