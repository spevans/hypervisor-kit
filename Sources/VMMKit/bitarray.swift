/*
 * bitarray.swift
 *
 * Created by Simon Evans on 28/03/2017.
 * Copyright © 2015 - 2017 Simon Evans. All rights reserved.
 *
 * BitArray<x> types. Treat UInt8/UInt16/UInt32/UInt64 as arrays of bits.
 *
 */

typealias BitArray8 = BitArray<UInt8>
typealias BitArray16 = BitArray<UInt16>
typealias BitArray32 = BitArray<UInt32>
typealias BitArray64 = BitArray<UInt64>

struct BitArray<T: FixedWidthInteger & UnsignedInteger> : BidirectionalCollection, MutableCollection, CustomStringConvertible {

    typealias Index = Int
    typealias Element = Int
    typealias SubSequnce = Self

    private(set) var rawValue: T

    var startIndex: Self.Index { 0 }

    var endIndex: Self.Index { rawValue.bitWidth }
    var count: Int { rawValue.bitWidth }


    func index(before i: Self.Index) -> Self.Index {
        return i - 1
    }

    func index(after i: Self.Index) -> Self.Index {
        return i + 1
    }


    var description: String { return String(rawValue, radix: 2) }


    init() {
        rawValue = 0
    }

    init(_ rawValue: Int) {
        self.rawValue = T(rawValue)
    }

    init(_ rawValue: UInt) {
        self.rawValue = T(rawValue)
    }

    init(_ rawValue: T) {
        self.rawValue = rawValue
    }


    subscript(index: Int) -> Int {
        get {
            precondition(index >= 0)
            precondition(index < T.bitWidth)

            return (rawValue & (T(1) << index) == 0) ? 0 : 1
        }

        set(newValue) {
            precondition(index >= 0)
            precondition(index < T.bitWidth)
            precondition(newValue == 0 || newValue == 1)

            let mask: T = 1 << index
            if (newValue == 1) {
                rawValue |= mask
            } else {
                rawValue &= ~mask
            }
        }
    }


    subscript(index: ClosedRange<Int>) -> T {
        get {
            var ret: T = 0
            var bit: T = 1

            for i in index {
                let mask: T = 1 << i
                if rawValue & mask != 0 {
                    ret |= bit
                }
                bit <<= 1
            }
            return ret
        }
        set {
            var bit: T = 1
            for i in index {
                let mask: T = 1 << i
                if (newValue & bit) == 0 {
                    rawValue &= ~mask
                } else {
                    rawValue |= mask
                }
                bit <<= 1
            }
        }
    }


    func toInt() -> Int {
        return Int(rawValue)
    }
}
