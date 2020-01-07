//
//  File.swift
//  
//
//  Created by Simon Evans on 01/12/2019.
//


extension Bool {
    init<T: BinaryInteger>(_ bit: T) {
        precondition(bit == 0 || bit == 1)
        self = (bit == 1) ? true : false
    }
}



public struct CPU {

    public struct RFLAGS: CustomStringConvertible {

        private(set) var bits: BitArray64
        public var rawValue: UInt64 { bits.rawValue }
        public var description: String {
            var flags = ""
            if carry { flags += "C " }
            if parity { flags += "P " }
            if auxiliary { flags += "A " }
            if zero { flags += "Z " }
            if sign { flags += "S " }
            if trap { flags += "T " }
            if interruptEnable { flags += "I " }
            if direction { flags += "D " }
            if overflow { flags += "O" }
            return flags
        }

        init() {
            bits = BitArray64(2)    // bit 1 always set
        }

        init(_ value: UInt64) {
            bits = BitArray64(value)
        }

        public var carry: Bool {
            get { bits[0] == 1 }
            set { bits[0] = newValue ? 1 : 0 }
        }

        public var parity: Bool {
            get { bits[2] == 1 }
            set { bits[2] = newValue ? 1: 0 }
        }

        public var auxiliary: Bool {
            get { bits[4] == 1 }
            set { bits[4] = newValue ? 1 : 0 }
        }

        public var zero: Bool {
            get { bits[6] == 1 }
            set { bits[6] = newValue ? 1 : 0 }
        }

        public var sign: Bool {
            get { bits[7] == 1 }
            set { bits[7] = newValue ? 1 : 0 }
        }

        public var trap: Bool {
            get { bits[8] == 1 }
            set { bits[8] = newValue ? 1 : 0 }
        }

        public var interruptEnable: Bool {
            get { bits[9] == 1 }
            set { bits[9] = newValue ? 1 : 0 }
        }

        public var direction: Bool {
            get { bits[10] == 1 }
            set { bits[10] = newValue ? 1 : 0 }
        }

        public var overflow: Bool {
            get { bits[11] == 1 }
            set { bits[11] = newValue ? 1 : 0 }
        }

        public var iopl: Int {
            get { Int(bits[12...13]) }
            set { bits[12...13] = UInt64(newValue) }
        }

        public var nestedTask: Bool {
            get { bits[14] == 1 }
            set { bits[14] = newValue ? 1 : 0 }
        }

        public var resume: Bool {
            get { bits[16] == 1 }
            set { bits[16] = newValue ? 1 : 0 }
        }

        public var v8086Mode: Bool {
            get { bits[17] == 1 }
            set { bits[17] = newValue ? 1 : 0 }
        }

        public var alignmentCheck: Bool {
            get { bits[18] == 1 }
            set { bits[18] = newValue ? 1 : 0 }
        }

        public var virtualInterrupt: Bool {
            get { bits[19] == 1 }
            set { bits[19] = newValue ? 1 : 0 }
        }

        public var virtualInterruptPending: Bool {
            get { bits[20] == 1 }
            set { bits[20] = newValue ? 1 : 0 }
        }

        public var identification: Bool {
            get { bits[21] == 1 }
            set { bits[21] = newValue ? 1 : 0 }
        }
    }


    public struct CR0Register: CustomStringConvertible {
        private(set) var bits: BitArray64
        var value: UInt64 { bits.toUInt64() }

        init(_ value: UInt64) {
            bits = BitArray64(value)
        }

        //    init() {
        //        bits = BitArray64(getCR0())
        //    }

        public var protectionEnable: Bool {
            get { Bool(bits[0]) }
            set { bits[0] = newValue ? 1 : 0 }
        }

        public var monitorCoprocessor: Bool {
            get { Bool(bits[1]) }
            set { bits[1] = newValue ? 1 : 0 }
        }

        public var fpuEmulation: Bool {
            get { Bool(bits[2]) }
            set { bits[2] = newValue ? 1 : 0 }
        }

        public var taskSwitched: Bool {
            get { Bool(bits[3]) }
            set { bits[3] = newValue ? 1 : 0 }
        }

        public var extensionType: Bool {
            get { Bool(bits[4]) }
            set { bits[4] = newValue ? 1 : 0 }
        }

        public var numericError: Bool {
            get { Bool(bits[5]) }
            set { bits[5] = newValue ? 1 : 0 }
        }

        public var writeProtect: Bool {
            get { Bool(bits[16]) }
            set { bits[16] = newValue ? 1 : 0 }
        }

        public var alignmentMask: Bool {
            get { Bool(bits[18]) }
            set { bits[18] = newValue ? 1 : 0 }
        }

        public var notWriteThrough: Bool {
            get { Bool(bits[29]) }
            set { bits[29] = newValue ? 1 : 0 }
        }

        public var cacheDisable: Bool {
            get { Bool(bits[30]) }
            set { bits[30] = newValue ? 1 : 0 }
        }

        public var paging: Bool {
            get { Bool(bits[31]) }
            set { bits[31] = newValue ? 1 : 0 }
        }

        public var description: String {
            var result = "PE: " + (protectionEnable ? "1" : "0")
            result += " MC: " + (monitorCoprocessor ? "1" : "0")
            result += " FE: " + (fpuEmulation ? "1" : "0")
            result += " TS: " + (taskSwitched ? "1" : "0")
            result += " ET: " + (extensionType ? "1" : "0")
            result += " NE: " + (numericError ? "1" : "0")
            result += " WP: " + (writeProtect ? "1" : "0")
            result += " AM: " + (alignmentMask ? "1" : "0")
            result += " WT: " + (notWriteThrough ? "1" : "0")
            result += " CD: " + (cacheDisable ? "1" : "0")
            result += " PG: " + (paging ? "1" : "0")

            return result
        }
    }


    struct CR3Register {
        private(set) var bits: BitArray64
        var value: UInt64 { bits.toUInt64() }

        init(_ value: UInt64) {
            bits = BitArray64(value)
        }

        //    init() {
        //        bits = BitArray64(getCR3())
        //    }

        var pagelevelWriteThrough: Bool {
            get { Bool(bits[3]) }
            set { bits[3] = newValue ? 1 : 0 }
        }

        var pagelevelCacheDisable: Bool {
            get { Bool(bits[4]) }
            set { bits[4] = newValue ? 1 : 0 }
        }
        /*
         var pageDirectoryBase: PhysAddress {
         get { PhysAddress(UInt(value) & ~PAGE_MASK) }
         set {
         precondition(newValue.isPageAligned)
         bits[12...63] = 0  // clear current address
         bits = BitArray64(UInt64(newValue.value) | value)
         }
         }*/
    }


    struct CR4Register: CustomStringConvertible {
        private(set) var bits: BitArray64
        var value: UInt64 { bits.toUInt64() }

        init(_ value: UInt64) {
            bits = BitArray64(value)
        }

        //   init() {
        //       bits = BitArray64(getCR4())
        //   }

        var vme: Bool {
            get { Bool(bits[0]) }
            set { bits[0] = newValue ? 1 : 0 }
        }

        var pvi: Bool {
            get { Bool(bits[1]) }
            set { bits[1] = newValue ? 1 : 0 }
        }

        var tsd: Bool {
            get { Bool(bits[2]) }
            set { bits[2] = newValue ? 1 : 0 }
        }

        var de: Bool {
            get { Bool(bits[3]) }
            set { bits[3] = newValue ? 1 : 0 }
        }

        var pse: Bool {
            get { Bool(bits[4]) }
            set { bits[4] = newValue ? 1 : 0 }
        }

        var pae: Bool {
            get { Bool(bits[5]) }
            set { bits[5] = newValue ? 1 : 0 }
        }

        var mce: Bool {
            get { Bool(bits[6]) }
            set { bits[6] = newValue ? 1 : 0 }
        }

        var pge: Bool {
            get { Bool(bits[7]) }
            set { bits[7] = newValue ? 1 : 0 }
        }

        var pce: Bool {
            get { Bool(bits[8]) }
            set { bits[8] = newValue ? 1 : 0 }
        }

        var osfxsr: Bool {
            get { Bool(bits[9]) }
            set { bits[9] = newValue ? 1 : 0 }
        }

        var osxmmxcpt: Bool {
            get { Bool(bits[10]) }
            set { bits[10] = newValue ? 1 : 0 }
        }

        var umip: Bool {
            get { Bool(bits[11]) }
            set { bits[11] = newValue ? 1 : 0 }
        }

        var vmxe: Bool {
            get { Bool(bits[13]) }
            set { bits[13] = newValue ? 1 : 0 }
        }

        var smxe: Bool {
            get { Bool(bits[14]) }
            set { bits[14] = newValue ? 1 : 0 }
        }

        var fsgsbase: Bool {
            get { Bool(bits[16]) }
            set { bits[16] = newValue ? 1 : 0 }
        }

        var pcide: Bool {
            get { Bool(bits[17]) }
            set { bits[17] = newValue ? 1 : 0 }
        }

        var osxsave: Bool {
            get { Bool(bits[18]) }
            set { bits[18] = newValue ? 1 : 0 }
        }

        var smep: Bool {
            get { Bool(bits[20]) }
            set { bits[20] = newValue ? 1 : 0 }
        }

        var smap: Bool {
            get { Bool(bits[21]) }
            set { bits[21] = newValue ? 1 : 0 }
        }

        var pke: Bool {
            get { Bool(bits[22]) }
            set { bits[22] = newValue ? 1 : 0 }
        }

        var description: String {
            var result = "VME: " + (vme ? "1" : "0")
            result += " PVI: " + (pvi ? "1" : "0")
            result += " TSD: " + (tsd ? "1" : "0")
            result += " DE: " + (tsd ? "1" : "0")
            result += " PSE: " + (pse ? "1" : "0")
            result += " PAE: " + (pae ? "1" : "0")
            result += " MCE: " + (mce ? "1" : "0")
            result += " PGE: " + (pge ? "1" : "0")
            result += " PCE: " + (pce ? "1" : "0")
            result += " OSFXSR: " + (osfxsr ? "1" : "0")
            result += " OSXMMXCPT: " + (osxmmxcpt ? "1" : "0")
            result += " UMIP: " + (umip ? "1" : "0")
            result += " VMXE: " + (vmxe ? "1" : "0")
            result += " SMXE: " + (smxe ? "1" : "0")
            result += " FSGSBASE: " + (fsgsbase ? "1" : "0")
            result += " PCIDE: " + (pcide ? "1" : "0")
            result += " OSXSAVE: " + (osxsave ? "1" : "0")
            result += " SMEP: " + (smep ? "1" : "0")
            result += " SMAP: " + (smap ? "1" : "0")
            result += " PKE: " + (pke ? "1" : "0")

            return result
        }
    }

}

extension UInt16 {
    init(bytes: (UInt8, UInt8)) {
        self = UInt16(bytes.1) << 8 | UInt16(bytes.1)
    }
}

extension UInt32 {
    init(bytes: (UInt8, UInt8, UInt8, UInt8)) {
        self = UInt32(bytes.3) << 24 | UInt32(bytes.2) << 16 | UInt32(bytes.1) << 8 | UInt32(bytes.0)
    }
}

extension UInt64 {
    init(bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)) {
        self = UInt64(bytes.7) << 56 | UInt64(bytes.6) << 48 | UInt64(bytes.5) << 40 | UInt64(bytes.4) << 32 |
            UInt64(bytes.3) << 24 | UInt64(bytes.2) << 16 | UInt64(bytes.1) << 8 | UInt64(bytes.0)
    }
}
