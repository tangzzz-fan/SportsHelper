import Foundation

enum A11y {
    enum Onboarding {
        static let next = "onboarding.next"
        static let skip = "onboarding.skip"
    }

    enum Today {
        static let start = "today.start"
        static let resume = "today.resume"
        static let settings = "today.settings"
        static let title = "today.title"
        static let reminderBanner = "today.reminderBanner"
    }

    enum Workout {
        static let close = "workout.close"
        static let completeSet = "workout.completeSet"
        static let skipSet = "workout.skipSet"
        static let end = "workout.end"
        static let cues = "workout.cues"
        static let downgrade = "workout.downgrade"
        static let downgradeHalf = "workout.downgrade.half"
        static let skipReasonNoTime = "workout.skipReason.noTime"
        static let skipRest = "workout.rest.skip"
        static let summaryTitle = "workout.summary.title"
    }

    enum Summary {
        static let done = "summary.done"
        static let completion = "summary.completion"
    }

    enum Import {
        static let editor = "import.editor"
        static let parse = "import.parse"
        static let save = "import.save"
        static let aiSentence = "import.ai.sentence"
        static let aiGenerate = "import.ai.generate"
        static let briefConfirm = "import.brief.confirm"
        static let briefCancel = "import.brief.cancel"
    }

    enum Plan {
        static let importPlan = "plan.import"
        static let title = "plan.title"
    }

    enum History {
        static let weekChart = "history.weekChart"
    }

    enum Settings {
        static let reminderToggle = "settings.reminderToggle"
        static let scheduledCount = "settings.scheduledCount"
        static let voiceToggle = "settings.voiceToggle"
        static let done = "settings.done"
        static let erase = "settings.erase"
    }
}
