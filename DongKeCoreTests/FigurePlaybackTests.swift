import Testing
import Foundation
@testable import DongKeCore

@Suite("FigurePlayback")
struct FigurePlaybackTests {

    @Test("a looping figure starts paused on the first frame")
    func startsPaused() {
        let playback = FigurePlayback(motion: .loop, frameCount: 3)
        #expect(playback.isPlaying == false)
        #expect(playback.displayedIndex == 0)
        #expect(playback.canPlay)
    }

    @Test("advance cycles through frames only while playing")
    func advanceCycles() {
        var playback = FigurePlayback(motion: .loop, frameCount: 3)
        playback.advance()
        #expect(playback.displayedIndex == 0)

        playback.toggle()
        #expect(playback.isPlaying)
        playback.advance()
        #expect(playback.displayedIndex == 1)
        playback.advance()
        #expect(playback.displayedIndex == 2)
        playback.advance()
        #expect(playback.displayedIndex == 0)
    }

    @Test("toggling off returns to the first frame")
    func stopResets() {
        var playback = FigurePlayback(motion: .loop, frameCount: 3)
        playback.toggle()
        playback.advance()
        playback.advance()
        #expect(playback.displayedIndex == 2)
        playback.toggle()
        #expect(playback.isPlaying == false)
        #expect(playback.displayedIndex == 0)
    }

    @Test("a hold figure cannot play and always shows the first frame")
    func holdNeverPlays() {
        var playback = FigurePlayback(motion: .hold, frameCount: 3)
        #expect(playback.canPlay == false)
        playback.toggle()
        #expect(playback.isPlaying == false)
        playback.advance()
        #expect(playback.displayedIndex == 0)
    }

    @Test("a single frame figure is not playable")
    func singleFrameNotPlayable() {
        let playback = FigurePlayback(motion: .loop, frameCount: 1)
        #expect(playback.canPlay == false)
    }
}

@Suite("FigurePlaybackCoordinator")
struct FigurePlaybackCoordinatorTests {

    @Test("only one figure is marked as playing at a time")
    func singlePlayingFigure() {
        var coordinator = FigurePlaybackCoordinator()
        coordinator.beganPlaying("squat")
        #expect(coordinator.isPlaying("squat"))
        coordinator.beganPlaying("plank")
        #expect(coordinator.isPlaying("plank"))
        #expect(coordinator.isPlaying("squat") == false)
    }

    @Test("stopping the active figure clears the slot, others are ignored")
    func stopSemantics() {
        var coordinator = FigurePlaybackCoordinator()
        coordinator.beganPlaying("squat")
        coordinator.stopped("plank")
        #expect(coordinator.isPlaying("squat"))
        coordinator.stopped("squat")
        #expect(coordinator.playingFigureID == nil)
    }
}
