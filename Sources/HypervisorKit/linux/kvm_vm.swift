//
//  kvm_vm.swift
//  
//
//  Created by Simon Evans on 01/12/2019.
//

#if os(Linux)
import OnceC

private let KVM_DEVICE = "/dev/kvm"

enum HVError: Error {
    case vmSubsystemFail
    case badIOCTL(Int)
    case setRegisters
    case getRegisters
    case vmRunError
}

final class VirtualMachine {

    final class MemoryRegion {
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
