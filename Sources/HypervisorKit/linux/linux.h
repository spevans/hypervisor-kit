//
//  linux.h
//  
//
//  Created by Simon Evans on 01/12/2019.
//

#include <fcntl.h>
#include <linux/kvm.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <unistd.h>


static unsigned long _IOCTL_KVM_GET_API_VERSION = KVM_GET_API_VERSION;
static unsigned long _IOCTL_KVM_GET_VCPU_MMAP_SIZE = KVM_GET_VCPU_MMAP_SIZE;
static unsigned long _IOCTL_KVM_SET_USER_MEMORY_REGION = KVM_SET_USER_MEMORY_REGION;
static unsigned long _IOCTL_KVM_GET_SREGS = KVM_GET_SREGS;
static unsigned long _IOCTL_KVM_SET_SREGS = KVM_SET_SREGS;
static unsigned long _IOCTL_KVM_GET_REGS = KVM_GET_REGS;
static unsigned long _IOCTL_KVM_SET_REGS = KVM_SET_REGS;
static unsigned long _IOCTL_KVM_RUN = KVM_RUN;
static unsigned long _IOCTL_KVM_CREATE_VM = KVM_CREATE_VM;
static unsigned long _IOCTL_KVM_CREATE_VCPU = KVM_CREATE_VCPU;


static inline int open2arg(const char *pathname, int flags) {
        return open(pathname, flags);
}

static inline int ioctl2arg(int fd, unsigned long request) {
        return ioctl(fd, request, 0);
}


static inline int ioctl3arg(int fd, unsigned long request, const void *ptr) {
        return ioctl(fd, request, ptr);
}
