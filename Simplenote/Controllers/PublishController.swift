import Foundation

@objc
class PublishController: NSObject {
    private var callbackMap = [String: PublishListenWrapper]()
    private let timerFactory: TimerFactory
    private let publishListenerFactory: PublishListenerFactory
    private var timer: Timer?

    init(timerFactory: TimerFactory = TimerFactory(), publishListenerFactory: PublishListenerFactory = PublishListenerFactory()) {
        self.timerFactory = timerFactory
        self.publishListenerFactory = publishListenerFactory
    }

    func updatePublishState(for note: Note, to published: Bool, completion: @escaping (Note) -> Void) {
        if note.published == published {
            return
        }

        callbackMap[note.simperiumKey] = publishListenerFactory.publishListenerWrapper(note: note, block: completion)

        changePublishState(for: note, to: published)

        prepareTimerIfNeeded()
    }

    @objc(didReceiveUpdateFromSimperiumForKey:)
    func didReceiveUpdateFromSimperium(for key: String) {
        guard var wrapper = callbackMap[key] else {
            return
        }

        wrapper.update()
        removeCallbackFor(key: key)
    }

    private func changePublishState(for note: Note, to published: Bool) {
        note.published = published
        note.modificationDate = Date()
        SPAppDelegate.shared().save()
    }

    private func removeExpiredCallbacks() {
        for callback in callbackMap {
            if callback.value.isExpired {
                removeCallbackFor(key: callback.key)
            }
        }
    }

    private func removeCallbackFor(key: String) {
        callbackMap.removeValue(forKey: key)
    }

    private func prepareTimerIfNeeded() {
        guard let currentTimer = timer else {
            timer = timeOutTimer()
            return
        }

        if !currentTimer.isValid {
            timer = timeOutTimer()
        }
    }

    private func timeOutTimer() -> Timer {
        return timerFactory.repeatingTimer(with: Constants.timeOut) { (timer) in
            if self.callbackMap.isEmpty {
                timer.invalidate()
            } else {
                self.removeExpiredCallbacks()
            }
        }
    }
}

struct PublishListenWrapper {
    let note: Note
    let block: (Note) -> Void
    let expiration = Date()

    var isExpired: Bool {
        return expiration.timeIntervalSinceNow < -Constants.timeOut
    }

    mutating func update() {
        block(note)
    }
}

class PublishListenerFactory {
    func publishListenerWrapper(note: Note, block: @escaping (Note) -> Void) -> PublishListenWrapper {
        return PublishListenWrapper(note: note, block: block)
    }
}

private struct Constants {
    static let timeOut = TimeInterval(5)
}
