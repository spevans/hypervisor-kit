//
//  NSLockExtrans.swift
//  VMMKit
//
//  Created by Simon Evans on 25/12/2019.
//  Copyright © 2019 Simon Evans. All rights reserved.
//

import Foundation

extension NSLock {
    internal func performLocked<T>(_ closure: () throws -> T) rethrows -> T {
        self.lock()
        defer { self.unlock() }
        return try closure()
    }
}