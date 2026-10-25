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
        static let skipToday = "today.skipToday"
        static let undoSkipToday = "today.undoSkipToday"
        static let alreadyDone = "today.alreadyDone"
    }

    enum Workout {
        static let close = "workout.close"
        static let completeSet = "workout.completeSet"
        static let skipSet = "workout.skipSet"
        static let end = "workout.end"
        static let weeklyProgress = "workout.weeklyProgress"
        static let cues = "workout.cues"
        static let setCountdown = "workout.setCountdown"
        static let downgrade = "workout.downgrade"
        static let downgradeHalf = "workout.downgrade.half"
        static func bonusReps(_ value: Int) -> String { "workout.bonus.\(value)" }
        static func effort(_ level: Int) -> String { "workout.effort.\(level)" }
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
        static let voiceStart = "import.voice.start"
        static let voiceStop = "import.voice.stop"
        static let voiceCancel = "import.voice.cancel"
        static let voiceSettings = "import.voice.settings"
        static let voiceOnlineAccept = "import.voice.online.accept"
        static let voiceOnlineDecline = "import.voice.online.decline"
        static let voiceHint = "import.voice.hint"
        static let sorePart = "import.sorePart"
        static let safetyNotice = "import.safety.notice"
        static let safetyRelief = "import.safety.relief"
        static let medicalNotice = "import.medical.notice"
    }

    enum Plan {
        static let importPlan = "plan.import"
        static let title = "plan.title"
        static let dayRow = "plan.day"
        static let dayDetailDone = "plan.day.done"
        static let itemRow = "plan.item"
        static let aiEntry = "plan.ai.entry"
        static let safetyNotice = "plan.safety.notice"
        static let originNotice = "plan.origin.notice"
        static let originBadge = "plan.origin.badge"
        static let adjustEntry = "plan.adjust.entry"
        static let adjustApply = "plan.adjust.apply"
        static let adjustConfirm = "plan.adjust.confirm"
        static let adjustPreview = "plan.adjust.preview"
    }

    enum History {
        static let weekChart = "history.weekChart"
    }

    enum Settings {
        static let reminderToggle = "settings.reminderToggle"
        static let scheduledCount = "settings.scheduledCount"
        static let voiceToggle = "settings.voiceToggle"
        static let largeTextToggle = "settings.largeTextToggle"
        static let healthNotice = "settings.healthNotice"
        static let healthNoticeEntry = "settings.healthNotice.entry"
        static let done = "settings.done"
        static let erase = "settings.erase"
    }
}
