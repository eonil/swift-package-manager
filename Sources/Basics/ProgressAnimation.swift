//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import _Concurrency
import protocol TSCUtility.ProgressAnimationProtocol

/// A progress animation wrapper that throttles updates to a given interval.
@_spi(SwiftPMInternal)
public class ThrottledProgressAnimation: ProgressAnimationProtocol {
    private let animation: ProgressAnimationProtocol
    private let shouldUpdate: () -> Bool
    private var pendingUpdate: (Int, Int, String)?

    public convenience init(_ animation: ProgressAnimationProtocol, interval: ContinuousClock.Duration) {
        self.init(animation, clock: ContinuousClock(), interval: interval)
    }

    public convenience init<C: Clock>(_ animation: ProgressAnimationProtocol, clock: C, interval: C.Duration) {
        self.init(animation, now: { clock.now }, interval: interval, clock: C.self)
    }

    init<C: Clock>(
      _ animation: ProgressAnimationProtocol,
      now: @escaping () -> C.Instant, interval: C.Duration, clock: C.Type = C.self
    ) {
        self.animation = animation
        var lastUpdate: C.Instant?
        self.shouldUpdate = {
            let now = now()
            if let lastUpdate = lastUpdate, now < lastUpdate.advanced(by: interval) {
                return false
            }
            // If we're over the interval or it's the first update, should update.
            lastUpdate = now
            return true
        }
    }

    public func update(step: Int, total: Int, text: String) {
        guard shouldUpdate() else {
            pendingUpdate = (step, total, text)
            return
        }
        pendingUpdate = nil
        animation.update(step: step, total: total, text: text)
    }

    public func complete(success: Bool) {
        if let (step, total, text) = pendingUpdate {
            animation.update(step: step, total: total, text: text)
        }
        animation.complete(success: success)
    }

    public func clear() {
        animation.clear()
    }
}
