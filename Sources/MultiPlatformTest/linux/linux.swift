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
}
public struct VCPU {

    struct IO_OP {
        let outbound: Bool
        let size: UInt8
        let port: UInt16
        let count: UInt32
        let data: UInt64
    }

    private let vcpu_fd: Int32
    private let kvmRun: UnsafeMutablePointer<kvm_run>
    private let kvm_run_mmap_size: Int32


    struct Registers {
        fileprivate var regs = kvm_regs()
        fileprivate var sregs = kvm_sregs()

        var csSelector: UInt16 {
            get { sregs.cs.selector }
            set { sregs.cs.selector = newValue }
        }

        var csBase: UInt64 {
            get { sregs.cs.base }
            set { sregs.cs.base = newValue }
        }

        var csLimit: UInt32 {
            get { sregs.cs.limit }
            set { sregs.cs.limit = newValue }
        }

        var ssSelector: UInt16 {
            get { sregs.ss.selector }
            set { sregs.ss.selector = newValue }
        }

        var ssBase: UInt64 {
            get { sregs.ss.base }
            set { sregs.ss.base = newValue }
        }

        var ssLimit: UInt32 {
            get { sregs.ss.limit }
            set { sregs.ss.limit = newValue }
        }

        var dsSelector: UInt16 {
            get { sregs.ds.selector }
            set { sregs.ds.selector = newValue }
        }

        var dsBase: UInt64 {
            get { sregs.ds.base }
            set { sregs.ds.base = newValue }
        }

        var dsLimit: UInt32 {
            get { sregs.ds.limit }
            set { sregs.ds.limit = newValue }
        }

        var esSelector: UInt16 {
            get { sregs.es.selector }
            set { sregs.es.selector = newValue }
        }

        var esBase: UInt64 {
            get { sregs.es.base }
            set { sregs.es.base = newValue }
        }

        var esLimit: UInt32 {
            get { sregs.es.limit }
            set { sregs.es.limit = newValue }
        }

        var fsSelector: UInt16 {
            get { sregs.fs.selector }
            set { sregs.fs.selector = newValue }
        }

        var fsBase: UInt64 {
            get { sregs.fs.base }
            set { sregs.fs.base = newValue }
        }

        var fsLimit: UInt32 {
            get { sregs.fs.limit }
            set { sregs.fs.limit = newValue }
        }

        var gsSelector: UInt16 {
            get { sregs.gs.selector }
            set { sregs.gs.selector = newValue }
        }

        var gsBase: UInt64 {
            get { sregs.gs.base }
            set { sregs.gs.base = newValue }
        }

        var gsLimit: UInt32 {
            get { sregs.gs.limit }
            set { sregs.gs.limit = newValue }
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

        var rflags: UInt64 {
            get { regs.rflags }
            set { regs.rflags = newValue }
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

        init(regs: kvm_regs, sregs: kvm_sregs) {
            self.regs = regs
            self.sregs = sregs
        }

        init() {
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


    mutating func run() throws {

        guard ioctl3arg(vcpu_fd, _IOCTL_KVM_SET_REGS, &registers.regs) >= 0 else {
            fatalError("Cant set sregs")
        }

        guard ioctl3arg(vcpu_fd, _IOCTL_KVM_SET_SREGS, &registers.sregs) >= 0 else {
            fatalError("Cant set sregs")
        }

        let ret = ioctl2arg(vcpu_fd, _IOCTL_KVM_RUN)
        guard ret >= 0 else {
            fatalError("Cant run vcpu")
        }


        guard ioctl3arg(vcpu_fd, _IOCTL_KVM_GET_REGS, &registers.regs) >= 0 else {
            fatalError("Cant get regs")
        }

        guard ioctl3arg(vcpu_fd, _IOCTL_KVM_GET_SREGS, &registers.sregs) >= 0 else {
            fatalError("Cant get sregs")
        }
    }

    var exitReason: UInt32 { kvmRun.pointee.exit_reason }


    var io: IO_OP {
        let outbound = kvmRun.pointee.io.direction == 1
        let size = kvmRun.pointee.io.size
        let port = kvmRun.pointee.io.port
        let count = kvmRun.pointee.io.count

        let dataOffset = kvmRun.pointee.io.data_offset
        let dataPtr = UnsafeRawPointer(kvmRun).advanced(by: Int(dataOffset))
        let data: UInt64

        if outbound {
            switch size {
                case 1: data = UInt64(dataPtr.load(as: UInt8.self))
                case 2: data = UInt64(dataPtr.load(as: UInt16.self))
                case 4: data = UInt64(dataPtr.load(as: UInt32.self))
                case 8: data = UInt64(dataPtr.load(as: UInt64.self))
                default:
                    print("Bad data size:", size)
                    data = 0
            }
        } else {
            data = 0
        }

        return IO_OP(outbound: outbound, size: size, port: port, count: count, data: data)
    }

    func shutdown() {
        munmap(kvmRun, Int(kvm_run_mmap_size))
        close(vcpu_fd)
    }
}

class VirtualMachine {

    class MemRegion {
        internal let region: kvm_userspace_memory_region
        private let pointer: UnsafeMutableRawPointer

        var guestAddress: UInt64 { region.guest_phys_addr }
        var size: UInt64 { region.size }
        var rawBuffer: UnsafeMutableRawBufferPointer { UnsafeMutableRawBufferPointer(start: pointer, count: Int(region.size)) }

        init?(size: UInt64, at address: UInt64, slot: Int) {
            guard let ptr = mmap(nil, size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS | MAP_NORESERVE, -1, 0),
                ptr != UnsafeMutableRawPointer(bitPattern: -1) else {
                    return nil
            }
            pointer = ptr

            region = kvm_userspace_memory_region()
            region.slot = UInt32(slot)
            region.guest_phys_addr = address
            region.memory_size = UInt64(size)
            region.userspace_addr = UInt64(UInt(bitPattern: ptr))
        }

        deinit {
            munmap(pointer, size)
        }
    }


    private let vm_fd: Int32
    private var vcpus: [VCPU] = []
    private var memRegions: [kvm_userspace_memory_region] = []


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


    init?() {
        guard let dev_fd = try? Self.vmFD() else { return nil }
        guard let apiVersion =  VirtualMachine.apiVersion, apiVersion >= 0 else {
            fatalError("Bad API version")
        }
        vm_fd = ioctl2arg(dev_fd, _IOCTL_KVM_CREATE_VM)
        guard vm_fd >= 0 else {
            return nil
        }
    }

    func addMemory(at guestAddress: UInt64, size: Int) -> MemRegion? {
        print("Adding \(size) bytes at address \(String(guestAddress, radix: 16))")

        let memRegion = MemRegion(size: UInt64(size), at: guestAddress, slot: memRegions.count)

        guard ioctl3arg(vm_fd, _IOCTL_KVM_SET_USER_MEMORY_REGION, memRegion.region) >= 0 else {
            return nil
        }
        memRegions.append(memRegion)
        print("Added memory")
        return memRegion
    }


    func createVCPU() -> VCPU? {
        guard let vcpu = VCPU(vm_fd: vm_fd) else { return nil }
        vcpus.append(vcpu)
        return vcpu
    }
    
    func loadBinary(binary: String) -> Bool {
        guard memRegions.count > 0 else {
            print("No memory allocated to VM")
            return false
        }
        let fd = open2arg(binary, O_RDONLY)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        var statInfo = stat()
        guard fstat(fd, &statInfo) >= 0 else { return false }
        let size = statInfo.st_size
        guard size <= memRegions[0].memory_size else { return false }
        guard let buffer = UnsafeMutableRawPointer(bitPattern: UInt(memRegions[0].userspace_addr)) else { return false }
        guard read(fd, buffer, size) == size else { return false }
        return true
    }


    func runVCPU(vcpu: inout VCPU) throws {
    }

    func runVM() throws  {
        if let vcpu = vcpus.first {
            var vcpu = vcpu
            print("running vcpu")
            try runVCPU(vcpu: &vcpu)
        } else {
            print("have no vcpus!")
        }
    }

    deinit {
        print("Shutting down VM - deinit")
        for vcpu in vcpus {
            vcpu.shutdown()
        }
        for memRegion in memRegions {
            if let region = UnsafeMutableRawPointer(bitPattern: UInt(memRegions[0].userspace_addr)) {
                munmap(region, Int(memRegion.memory_size))
            }
        }
        vcpus = []
        memRegions = []
        close(vm_fd)
    }
}

#endif
