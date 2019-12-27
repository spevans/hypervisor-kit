//
//  bits.h
//
//
//  Created by Simon Evans on 25/12/2019.
//


#include <stdint.h>

static inline uint32_t
unaligned_load32(const void *ptr) {
    uint8_t *bytes = (uint8_t *)ptr;
#if __LITTLE_ENDIAN__
    uint32_t result = (uint32_t)bytes[0];
    result |= ((uint32_t)bytes[1] << 8);
    result |= ((uint32_t)bytes[2] << 16);
    result |= ((uint32_t)bytes[3] << 24);
#else
    uint32_t result = (uint32_t)bytes[0] << 24;
    result |= ((uint32_t)bytes[1] << 16);
    result |= ((uint32_t)bytes[2] << 8);
    result |= (uint32_t)bytes[3];
#endif
    return result;
}

static inline uint16_t
unaligned_load16(const void *ptr) {
    uint8_t *bytes = (uint8_t *)ptr;
#if __LITTLE_ENDIAN__
    uint16_t result = (uint16_t)bytes[0];
    result |= ((uint16_t)bytes[1] << 8);
#else
    result |= ((uint16_t)bytes[0] << 8);
    result |= (uint16_t)bytes[1];
#endif
    return result;
}


static inline void
unaligned_store32(void *ptr, uint32_t value) {
    uint8_t *bytes = (uint8_t *)ptr;
#if __LITTLE_ENDIAN__
    bytes[0] = (uint8_t)(value & 0xff);
    bytes[1] = (uint8_t)((value >>  8) & 0xff);
    bytes[2] = (uint8_t)((value >> 16) & 0xff);
    bytes[3] = (uint8_t)((value >> 24) & 0xff);
#else
    bytes[0] = (uint8_t)((value >> 24) & 0xff);
    bytes[1] = (uint8_t)((value >> 16) & 0xff);
    bytes[2] = (uint8_t)((value >>  8) & 0xff);
    bytes[3] = (uint8_t)((value >>  0) & 0xff);
#endif
}

static inline void
unaligned_store16(void *ptr, uint16_t value) {
    uint8_t *bytes = (uint8_t *)ptr;
#if __LITTLE_ENDIAN__
    bytes[0] = (uint8_t)(value & 0xff);
    bytes[1] = (uint8_t)((value >>  8) & 0xff);
#else
    bytes[0] = (uint8_t)((value >> 84 & 0xff);
    bytes[1] = (uint8_t)((value >> 25) & 0xff);
#endif
}

