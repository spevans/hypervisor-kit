//
//  linux.swift
//  
//
//  Created by Simon Evans on 01/12/2019.
//

#if os(Linux)

let KVM_DEVICE = "/dev/kvm"

enum HVError: Error {
    case vmSubsystemFail
    case badIOCTL(Int)
    case setRegisters
    case getRegisters
    case vmRunError
}

class VirtualMachine {

    final class VCPU {

        private let vcpu_fd: Int32
        private let kvmRun: KVM_RUN_PTR
        private let kvm_run_mmap_size: Int32

        struct SegmentRegister {
            var kvmSegment = kvm_segment()

            var selector: UInt16 {
                get { kvmSegment.selector }
                set { kvmSegment.selector = newValue }
            }

            var base: UInt {
                get { UInt(kvmSegment.base) }
                set { kvmSegment.base = UInt64(newValue) }
            }

            var limit: UInt32 {
                get { kvmSegment.limit }
                set { kvmSegment.limit = newValue }
            }

            var accessRights: UInt32 {
                get {
                    print("Addess rights: ")
                    var bitArray = BitArray32(0)
                    bitArray[0...3] = UInt32(kvmSegment.type)
                    bitArray[4] = Int(kvmSegment.s)
                    bitArray[5...6] = UInt32(kvmSegment.dpl)
                    bitArray[7] = Int(kvmSegment.present)
                    bitArray[8...11] = 0 // reserverd
                    bitArray[12] = Int(kvmSegment.avl)
                    bitArray[13] = Int(kvmSegment.l)
                    bitArray[14] = Int(kvmSegment.db)
                    bitArray[15] = Int(kvmSegment.g)
                    bitArray[16] = 0 // usable
                    return bitArray.rawValue
                }
                set {
                    let bitArray = BitArray32(newValue)
                    kvmSegment.type = UInt8(bitArray[0...3])
                    kvmSegment.s = UInt8(bitArray[4])
                    kvmSegment.dpl = UInt8(bitArray[5...6])
                    kvmSegment.present = UInt8(bitArray[7])
                    kvmSegment.avl = UInt8(bitArray[12])
                    kvmSegment.l = UInt8(bitArray[13])
                    kvmSegment.db = UInt8(bitArray[14])
                    kvmSegment.g = UInt8(bitArray[15])
                }
            }
        }


        struct Registers {
            fileprivate var regs = kvm_regs()
            fileprivate var sregs = kvm_sregs()

            var cs = SegmentRegister()
            var ss = SegmentRegister()
            var ds = SegmentRegister()
            var es = SegmentRegister()
            var fs = SegmentRegister()
            var gs = SegmentRegister()
            var tr = SegmentRegister()
            var ldtr = SegmentRegister()


            init(regs: kvm_regs, sregs: kvm_sregs) {
                self.regs = regs
                self.sregs = sregs
                self.cs = SegmentRegister(kvmSegment: sregs.cs)
                self.ss = SegmentRegister(kvmSegment: sregs.ss)
                self.ds = SegmentRegister(kvmSegment: sregs.ds)
                self.es = SegmentRegister(kvmSegment: sregs.es)
                self.fs = SegmentRegister(kvmSegment: sregs.fs)
                self.gs = SegmentRegister(kvmSegment: sregs.gs)
                self.tr = SegmentRegister(kvmSegment: sregs.tr)
                self.ldtr = SegmentRegister(kvmSegment: sregs.ldt)
            }

            init() {
            }


            mutating func updateSRegs() {
                sregs.cs = cs.kvmSegment
                sregs.ds = ds.kvmSegment
                sregs.es = es.kvmSegment
                sregs.fs = fs.kvmSegment
                sregs.gs = gs.kvmSegment
                sregs.ss = ss.kvmSegment
                sregs.tr = tr.kvmSegment
           //     sregs.cr0 = sregs.cr0
           //     sregs.cr2 = sregs.cr2
           //     sregs.cr3 = sregs.cr3
           //     sregs.cr4 = sregs.cr4
           //     sregs.cr8 = sregs.cr8
            }

            mutating func readSRegs() {
                cs.kvmSegment = sregs.cs
                ds.kvmSegment = sregs.ds
                es.kvmSegment = sregs.es
                fs.kvmSegment = sregs.fs
                gs.kvmSegment = sregs.gs
                ss.kvmSegment = sregs.ss

            }

            var rax: UInt64 {
                get { regs.rax }
                set { regs.rax = newValue }
            }

            var rbx: UInt64 {
                get { regs.rbx }
                set { regs.rbx = newValue }
            }

            var rcx: UInt64 {
                get { regs.rcx }
                set { regs.rcx = newValue }
            }

            var rdx: UInt64 {
                get { regs.rdx }
                set { regs.rdx = newValue }
            }

            var rsi: UInt64 {
                get { regs.rsi }
                set { regs.rsi = newValue }
            }

            var rdi: UInt64 {
                get { regs.rdi }
                set { regs.rdi = newValue }
            }

            var rsp: UInt64 {
                get { regs.rsp }
                set { regs.rsp = newValue }
            }

            var rbp: UInt64 {
                get { regs.rbp }
                set { regs.rbp = newValue }
            }

            var r8: UInt64 {
                get { regs.r8 }
                set { regs.r8 = newValue }
            }

            var r9: UInt64 {
                get { regs.r9 }
                set { regs.r9 = newValue }
            }

            var r10: UInt64 {
                get { regs.r10 }
                set { regs.r10 = newValue }
            }

            var r11: UInt64 {
                get { regs.r11 }
                set { regs.r11 = newValue }
            }

            var r12: UInt64 {
                get { regs.r12 }
                set { regs.r12 = newValue }
            }

            var r13: UInt64 {
                get { regs.r13 }
                set { regs.r13 = newValue }
            }

            var r14: UInt64 {
                get { regs.r14 }
                set { regs.r14 = newValue }
            }

            var r15: UInt64 {
                get { regs.r15 }
                set { regs.r15 = newValue }
            }

            var rip: UInt64 {
                get { regs.rip }
                set { regs.rip = newValue }
            }

            var rflags: CPU.RFLAGS {
                get { CPU.RFLAGS(regs.rflags) }
                set { regs.rflags = newValue.rawValue }
            }

            var cr0: UInt64 {
                get { sregs.cr0 }
                set { sregs.cr0 = newValue }
            }

            var cr2: UInt64 {
                get { sregs.cr2 }
                set { sregs.cr2 = newValue }
            }

            var cr3: UInt64 {
                get { sregs.cr3 }
                set { sregs.cr3 = newValue }
            }

            var cr4: UInt64 {
                get { sregs.cr4 }
                set { sregs.cr4 = newValue }
            }

            var cr8: UInt64 {
                get { sregs.cr8 }
                set { sregs.cr8 = newValue }
            }

            var efer: UInt64 {
                get { sregs.efer }
                set { sregs.efer = newValue }
            }

            var gdtrBase: UInt64 {
                get { sregs.gdt.base }
                set { sregs.gdt.base = newValue }
            }

            var gdtrLimit: UInt32 {
                get { UInt32(sregs.gdt.limit) }
                set { sregs.gdt.limit = UInt16(newValue) }
            }

            var idtrBase: UInt64  {
                get { sregs.idt.base }
                set { sregs.idt.base = newValue }
            }
            var idtrLimit:  UInt32 {
                get { UInt32(sregs.idt.limit) }
                set { sregs.idt.limit = UInt16(newValue) }
            }
        }

        var registers = Registers()

        init?(vm_fd: Int32) {

            guard let mmapSize = VirtualMachine.vcpuMmapSize else { return nil }
            kvm_run_mmap_size = mmapSize

            vcpu_fd = ioctl2arg(vm_fd, _IOCTL_KVM_CREATE_VCPU)
            guard vcpu_fd >= 0 else { return nil }

            guard let ptr = mmap(nil, Int(kvm_run_mmap_size), PROT_READ | PROT_WRITE, MAP_SHARED, vcpu_fd, 0),
                ptr != UnsafeMutableRawPointer(bitPattern: -1) else {
                    close(vcpu_fd)
                    print("cant mmap vcpu")
                    return nil
            }
            kvmRun = ptr.bindMemory(to: kvm_run.self, capacity: 1)

            guard ioctl3arg(vcpu_fd, _IOCTL_KVM_GET_REGS, &registers.regs) >= 0 else {
                fatalError("Cant get regs")
            }

            guard ioctl3arg(vcpu_fd, _IOCTL_KVM_GET_SREGS, &registers.sregs) >= 0 else {
                fatalError("Cant get sregs")
            }
        }


        func run() throws -> VMExit {

            registers.updateSRegs()
            guard ioctl3arg(vcpu_fd, _IOCTL_KVM_SET_REGS, &registers.regs) >= 0 else {
                throw HVError.setRegisters
            }

            guard ioctl3arg(vcpu_fd, _IOCTL_KVM_SET_SREGS, &registers.sregs) >= 0 else {
                throw HVError.setRegisters
            }

            let ret = ioctl2arg(vcpu_fd, _IOCTL_KVM_RUN)
            guard ret >= 0 else {
                throw HVError.vmRunError
            }

            guard ioctl3arg(vcpu_fd, _IOCTL_KVM_GET_REGS, &registers.regs) >= 0 else {
                throw HVError.getRegisters
            }

            guard ioctl3arg(vcpu_fd, _IOCTL_KVM_GET_SREGS, &registers.sregs) >= 0 else {
                throw HVError.getRegisters
            }

            registers.readSRegs()

            //print("kvmRun.pointee.exit_qualification:", kvmRun.pointee.exit_qualification)
            guard let exitReason = KVMExit(rawValue: kvmRun.pointee.exit_reason) else {
                fatalError("Invalid KVM exit reason: \(kvmRun.pointee.exit_reason)")
            }

            return exitReason.vmExit(kvmRunPtr: kvmRun)
        }

        func skipInstruction() throws {
//            let instrLen = try vmcs.vmExitInstructionLength()
//            print("instrLen:", instrLen)
//            registers.rip += UInt64(instrLen)
        }

        func shutdown() {
            munmap(kvmRun, Int(kvm_run_mmap_size))
            close(vcpu_fd)
        }
    }


    class MemoryRegion {
        internal let region: kvm_userspace_memory_region
        internal let pointer: UnsafeMutableRawPointer

        var guestAddress: PhysicalAddress { PhysicalAddress(region.guest_phys_addr) }
        var size: UInt64 { region.memory_size }
        var rawBuffer: UnsafeMutableRawBufferPointer { UnsafeMutableRawBufferPointer(start: pointer, count: Int(region.memory_size)) }

        init?(size: UInt64, at address: UInt64, slot: Int) {
            guard let ptr = mmap(nil, Int(size), PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS | MAP_NORESERVE, -1, 0),
                ptr != UnsafeMutableRawPointer(bitPattern: -1) else {
                    return nil
            }
            pointer = ptr

            region = kvm_userspace_memory_region(slot: UInt32(slot), flags: 0,
                                                 guest_phys_addr: address,
                                                 memory_size: UInt64(size),
                                                 userspace_addr: UInt64(UInt(bitPattern: ptr)))
        }

        deinit {
            munmap(pointer, Int(region.memory_size))
        }
    }


    private let vm_fd: Int32
    private(set) var vcpus: [VCPU] = []
    private(set) var memoryRegions: [MemoryRegion] = []


    static var apiVersion: Int32? = {
        return try? ioctl2arg(vmFD(), _IOCTL_KVM_GET_API_VERSION)
    }()


    static var vcpuMmapSize: Int32? = {
        return try? ioctl2arg(vmFD(), _IOCTL_KVM_GET_VCPU_MMAP_SIZE)
    }()

    static private var _vmfd: Int32 = -1
    static private func vmFD() throws -> Int32 {
        if _vmfd == -1 {
            _vmfd = open2arg(KVM_DEVICE, O_RDWR)
            guard _vmfd >= 0 else {
                throw HVError.vmSubsystemFail
            }
        }
        return _vmfd
    }


    init() throws {
        guard let dev_fd = try? Self.vmFD() else {
            throw HVError.vmSubsystemFail
        }
        guard let apiVersion =  VirtualMachine.apiVersion, apiVersion >= 0 else {
            fatalError("Bad API version")
        }
        vm_fd = ioctl2arg(dev_fd, _IOCTL_KVM_CREATE_VM)
        guard vm_fd >= 0 else {
            throw HVError.vmSubsystemFail

        }
    }

    func addMemory(at guestAddress: UInt64, size: Int) -> MemoryRegion? {
        print("Adding \(size) bytes at address \(String(guestAddress, radix: 16))")

        guard let memRegion = MemoryRegion(size: UInt64(size), at: guestAddress, slot: memoryRegions.count) else {
            return nil
        }

        var kvmRegion = memRegion.region
        guard ioctl3arg(vm_fd, _IOCTL_KVM_SET_USER_MEMORY_REGION, &kvmRegion) >= 0 else {
            return nil
        }
        memoryRegions.append(memRegion)
        print("Added memory")
        return memRegion
    }


    func createVCPU() throws -> VCPU {
        guard let vcpu = VCPU(vm_fd: vm_fd) else { throw HVError.vmSubsystemFail }
        vcpus.append(vcpu)
        return vcpu
    }
    
    func loadBinary(binary: String) -> Bool {
        guard memoryRegions.count > 0 else {
            print("No memory allocated to VM")
            return false
        }
        let fd = open2arg(binary, O_RDONLY)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        var statInfo = stat()
        guard fstat(fd, &statInfo) >= 0 else { return false }
        let size = statInfo.st_size
        guard size <= Int(memoryRegions[0].size) else { return false }
        guard read(fd, memoryRegions[0].pointer, size) == size else { return false }
        return true
    }


    deinit {
        print("Shutting down VM - deinit")
        for vcpu in vcpus {
            vcpu.shutdown()
        }
        for memRegion in memoryRegions {
            munmap(memRegion.pointer, Int(memRegion.size))
        }
        vcpus = []
        memoryRegions = []
        close(vm_fd)
    }
}

#endif
