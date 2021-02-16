//
//  extensions.swift
//  
//
//  Created by Simon Evans on 25/12/2019.
//

import Foundation

extension NSLock {
    internal func performLocked<T>(_ closure: () throws -> T) rethrows -> T {
        self.lock()
        defer { self.unlock() }
        return try closure()
    }
}


func hexNum<T: BinaryInteger>(_ value: T, width: Int) -> String {
    let num = String(value, radix: 16)
    if num.count <= width {
        return String(repeating: "0", count: width - num.count) + num
    }
    return num
}
