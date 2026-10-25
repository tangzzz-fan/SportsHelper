import Testing
@testable import DongKeCore

@Suite("音频会话租约")
struct AudioSessionLeaseTests {
    @Test("两次借用只激活一次，归还一次仍保持")
    func borrowTwiceReleaseOnce() {
        var lease = AudioSessionLease()
        #expect(lease.borrow(.playback) == .activate(.playback))
        #expect(lease.borrow(.playback) == .none)
        #expect(lease.give(.playback) == .none)
        #expect(lease.count == 1)
    }

    @Test("全部归还后只释放一次")
    func lastReleaseDeactivates() {
        var lease = AudioSessionLease()
        _ = lease.borrow(.playback)
        _ = lease.borrow(.playback)
        #expect(lease.give(.playback) == .none)
        #expect(lease.give(.playback) == .deactivate)
        #expect(lease.give(.playback) == .none)
        #expect(lease.count == 0)
    }

    @Test("录音借用时切到 record，归还后回到 playback")
    func recordWinsWhileRecording() {
        var lease = AudioSessionLease()
        #expect(lease.borrow(.playback) == .activate(.playback))
        #expect(lease.borrow(.record) == .activate(.record))
        #expect(lease.give(.record) == .activate(.playback))
        #expect(lease.give(.playback) == .deactivate)
    }

    @Test("先录音后播报：播报不改类别，归还顺序不乱")
    func playbackDoesNotStealRecording() {
        var lease = AudioSessionLease()
        #expect(lease.borrow(.record) == .activate(.record))
        #expect(lease.borrow(.playback) == .none)
        #expect(lease.give(.playback) == .none)
        #expect(lease.give(.record) == .deactivate)
    }

    @Test("多归还不会把计数压成负数")
    func extraGiveIsIgnored() {
        var lease = AudioSessionLease()
        #expect(lease.give(.playback) == .none)
        #expect(lease.count == 0)
    }
}
