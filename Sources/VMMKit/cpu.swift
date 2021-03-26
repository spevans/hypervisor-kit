//
//  cpu.swift
//  VMMKit
//
//  Created by Simon Evans on 01/12/2019.
//  Copyright © 2019 Simon Evans. All rights reserved.
//

import CBits
import BABAB

let kb: UInt = 1024
let mb: UInt = 1048576
let gb = kb * mb

extension UnsignedInteger {
    typealias Byte = UInt8
    typealias Word = UInt16
    typealias DWord = UInt32


    func bit(_ bit: Int) -> Bool {
        precondition(bit >= 0 && bit < MemoryLayout<Self>.size * 8,
                     "Bit must be in range 0-\(MemoryLayout<Self>.size * 8 - 1)")
        return self & Self(1 << UInt(bit)) != 0
    }

}

extension Bool {
    init<T: BinaryInteger>(_ bit: T) {
        precondition(bit == 0 || bit == 1)
        self = (bit == 1) ? true : false
    }
}

struct CPUID: CustomStringConvertible {
    let maxBasicInput: UInt32
    let maxExtendedInput: UInt32
    let vendorName: String
    let processorBrandString: String

    let cpuid01: cpuid_result
    let cpuid07: cpuid_result
    let cpuid80000001: cpuid_result
    let cpuid80000008: cpuid_result

    var APICId:      UInt8 { return UInt8(cpuid01.regs.ebx >> 24) }
    var sse3:        Bool { return cpuid01.regs.ecx.bit(0) }
    var pclmulqdq:   Bool { return cpuid01.regs.ecx.bit(1) }
    var dtes64:      Bool { return cpuid01.regs.ecx.bit(2) }
    var monitor:     Bool { return cpuid01.regs.ecx.bit(3) }
    var dscpl:       Bool { return cpuid01.regs.ecx.bit(4) }
    var vmx:         Bool { return cpuid01.regs.ecx.bit(5) }
    var smx:         Bool { return cpuid01.regs.ecx.bit(6) }
    var eist:        Bool { return cpuid01.regs.ecx.bit(7) }
    var tm2:         Bool { return cpuid01.regs.ecx.bit(8) }
    var ssse3:       Bool { return cpuid01.regs.ecx.bit(9) }
    var cnxtid:      Bool { return cpuid01.regs.ecx.bit(10) }
    var sdbg:        Bool { return cpuid01.regs.ecx.bit(11) }
    var fma:         Bool { return cpuid01.regs.ecx.bit(12) }
    var cmpxchg16b:  Bool { return cpuid01.regs.ecx.bit(13) }
    var xptr:        Bool { return cpuid01.regs.ecx.bit(14) }
    var pdcm:        Bool { return cpuid01.regs.ecx.bit(15) }
    var pcid:        Bool { return cpuid01.regs.ecx.bit(17) }
    var dca:         Bool { return cpuid01.regs.ecx.bit(18) }
    var sse4_1:      Bool { return cpuid01.regs.ecx.bit(19) }
    var sse4_2:      Bool { return cpuid01.regs.ecx.bit(20) }
    var x2apic:      Bool { return cpuid01.regs.ecx.bit(21) }
    var movbe:       Bool { return cpuid01.regs.ecx.bit(22) }
    var popcnt:      Bool { return cpuid01.regs.ecx.bit(23) }
    var tscDeadline: Bool { return cpuid01.regs.ecx.bit(24) }
    var aesni:       Bool { return cpuid01.regs.ecx.bit(25) }
    var xsave:       Bool { return cpuid01.regs.ecx.bit(26) }
    var osxsave:     Bool { return cpuid01.regs.ecx.bit(27) }
    var avx:         Bool { return cpuid01.regs.ecx.bit(28) }
    var f16c:        Bool { return cpuid01.regs.ecx.bit(29) }
    var rdrand:      Bool { return cpuid01.regs.ecx.bit(30) }

    var fpu:         Bool { return cpuid01.regs.edx.bit(0) }
    var vme:         Bool { return cpuid01.regs.edx.bit(1) }
    var de:          Bool { return cpuid01.regs.edx.bit(2) }
    var pse:         Bool { return cpuid01.regs.edx.bit(3) }
    var tsc:         Bool { return cpuid01.regs.edx.bit(4) }
    var msr:         Bool { return cpuid01.regs.edx.bit(5) }
    var pae:         Bool { return cpuid01.regs.edx.bit(6) }
    var mce:         Bool { return cpuid01.regs.edx.bit(7) }
    var cx8:         Bool { return cpuid01.regs.edx.bit(8) }
    var apic:        Bool { return cpuid01.regs.edx.bit(9) }
    var sysenter:    Bool { return cpuid01.regs.edx.bit(11) }
    var mtrr:        Bool { return cpuid01.regs.edx.bit(12) }
    var pge:         Bool { return cpuid01.regs.edx.bit(13) }
    var mca:         Bool { return cpuid01.regs.edx.bit(14) }
    var cmov:        Bool { return cpuid01.regs.edx.bit(15) }
    var pat:         Bool { return cpuid01.regs.edx.bit(16) }
    var pse36:       Bool { return cpuid01.regs.edx.bit(17) }
    var psn:         Bool { return cpuid01.regs.edx.bit(18) }
    var clfsh:       Bool { return cpuid01.regs.edx.bit(19) }
    var ds:          Bool { return cpuid01.regs.edx.bit(21) }
    var acpi:        Bool { return cpuid01.regs.edx.bit(22) }
    var mmx:         Bool { return cpuid01.regs.edx.bit(23) }
    var fxsr:        Bool { return cpuid01.regs.edx.bit(24) }
    var sse:         Bool { return cpuid01.regs.edx.bit(25) }
    var sse2:        Bool { return cpuid01.regs.edx.bit(26) }
    var ss:          Bool { return cpuid01.regs.edx.bit(27) }
    var htt:         Bool { return cpuid01.regs.edx.bit(28) }
    var tm:          Bool { return cpuid01.regs.edx.bit(29) }
    var pbe:         Bool { return cpuid01.regs.edx.bit(31) }

    var sgx:         Bool { return cpuid07.regs.ebx.bit(2) }
    var rtm:         Bool { return cpuid07.regs.ebx.bit(11) }

    var lahfsahf:    Bool { return cpuid80000001.regs.ecx.bit(0) }
    var lzcnt:       Bool { return cpuid80000001.regs.ecx.bit(5) }
    var prefetchw:   Bool { return cpuid80000001.regs.ecx.bit(8) }

    var syscall:     Bool { return cpuid80000001.regs.edx.bit(11) }
    var nxe:         Bool { return cpuid80000001.regs.edx.bit(20) }

    // FIXME: 1G Pages seem to break using qemu on macos with hypervisor framework.
    // Not sure where bug is atm.
    //var pages1G:     Bool { return cpuid80000001.regs.edx.bit(26) }
    var pages1G: Bool { return false }
    var IA32_EFER:   Bool { return cpuid80000001.regs.edx.bit(29) }

    var maxPhyAddrBits: UInt {
        let max = UInt(cpuid80000008.regs.eax & 0xff)
        if max > 0 {
            return max
        } else {
            return 36
        }
    }
    var maxPhysicalAddress: UInt {
        let bits = maxPhyAddrBits
        if bits == UInt.bitWidth {
            return UInt.max
        }
        if bits == 0 { return 0 }
        return (1 << bits) - 1
    }

    var pageSizes: [UInt]

    var description: String {
        var str = "CPU: maxBI: \(String(maxBasicInput, radix: 16)) "
        str += "\(String(maxExtendedInput, radix: 16))\n"
        str += "CPU: [\(vendorName)] [\(processorBrandString)]\nCPU: "
        if pages1G     { str += "1GPages "     }
        if msr         { str += "msr "         }
        if IA32_EFER   { str += "IA32_EFER "   }
        if nxe         { str += "nxe "         }
        if apic        { str += "apic "        }
        if x2apic      { str += "x2apic "      }
        if rdrand      { str += "rdrand "      }
        if tsc         { str += "tsc "         }
        if tscDeadline { str += "tscDeadline " }
        if sysenter    { str += "sysenter "    }
        if syscall     { str += "syscall "     }
        if mtrr        { str += "mtrr "        }
        if pat         { str += "pat "         }
        if vmx         { str += "vmx "         }
        str += "\nCPU: APIDId: \(APICId)"

        return str
    }


    init() {
        var info = cpuid_result() //eax: 0, ebx: 0, ecx: 0, edx: 0)
        var ptr = UnsafePointer<CChar>(cpuid(0, &info) + 4)
        vendorName = String(cString: ptr)
        maxBasicInput = info.regs.eax

        cpuid(0x80000000, &info)
        maxExtendedInput = info.regs.eax

        if (maxBasicInput >= 1) {
            cpuid(0x1, &info)
            cpuid01 = info
        } else {
            cpuid01 = cpuid_result()
        }

        if (maxBasicInput >= 7) {
            cpuid(0x7, &info)
            cpuid07 = info
        } else {
            cpuid07 = cpuid_result()
        }

        if (maxExtendedInput >= 0x80000001) {
            cpuid(0x80000001, &info)
            cpuid80000001 = info
        } else {
            cpuid80000001 = cpuid_result()
        }

        // Physical & Virtual address size information
        if (maxExtendedInput >= 0x80000008) {
            cpuid(0x80000008, &info)
            cpuid80000008 = info
        } else {
            cpuid80000008 = cpuid_result()
        }

        if (maxExtendedInput >= 0x80000004) {
            ptr = UnsafePointer<CChar>(cpuid(0x80000002, &info))
            var brand = String(cString: ptr)
            ptr = UnsafePointer<CChar>(cpuid(0x80000003, &info))
            brand += String(cString: ptr)
            ptr = UnsafePointer<CChar>(cpuid(0x80000004, &info))
            brand += String(cString: ptr)
            processorBrandString = brand
        } else {
            processorBrandString = ""
        }
        pageSizes = [ 4096, 2 * mb ]
        if pages1G {
            pageSizes.append(1 * gb)
        }
    }
}


// Singleton that will be initialised by CPU.getInfo() or CPU.capabilities
private let cpuId = CPUID()


public struct CPU {

    static var capabilities: CPUID {
        return cpuId
    }

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
        var value: UInt64 { bits.rawValue }

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
        var value: UInt64 { bits.rawValue }

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

        var pageDirectoryBase: PhysicalAddress {
            get { PhysicalAddress(UInt(value) & ~UInt(PAGE_MASK)) }
            set {
                precondition(newValue.isAligned(to: PAGE_SIZE))
                bits[12...63] = 0  // clear current address
                bits = BitArray64(UInt64(newValue.value) | value)
            }
        }
    }


    struct CR4Register: CustomStringConvertible {
        private(set) var bits: BitArray64
        var value: UInt64 { bits.rawValue }

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
