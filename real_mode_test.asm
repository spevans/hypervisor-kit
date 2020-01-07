    %macro OFFSET 1
    times %1 - ($ - $$)   db 0x90
    %endmacro
                BITS    16
                ORG     0x1000

                mov     bx, jump_table
                shl     ax, 1
                add     bx, ax
                jmp     [bx]

read_write_memory:
                mov     sp, 0x1ffe
                push    ds
                pop     es
                mov     ax, [0x1200]
                inc     ax
                mov     [0x1200], ax

                cld
                mov     bx, 0x200
                mov     es, bx
                mov     si, src_data
                mov     di, 0
                mov     cx, 2
                rep     movsw

                hlt

io_out_test:  
;;                mov     al, 1
;;                mov     dx, 0x60
;;                out     dx, al
;;                mov     bx, 0x1234

                cld
                xor     ax, ax
                mov     es, ax
                mov     si, 0x1300
                mov     dx, 0x60
                mov     cx, 24
                rep     outsb

                sub     si, 2
                std
                mov     cx, 12
                rep     outsw

                add     si, 2
                cld
                mov     cx, 6
                rep     outsd

                ;; Unaligned words and dwords
                mov     si, 0x1301
                mov     cx, 5
                rep     outsd

                std
                sub     si, 4
                mov     cx, 10
                rep     outsw


                ;; Test Segment Overrides
                jmp     0x100:next - 0x1000    ; Set CS to 0x1000
next:
                cld
                mov     si, 0x300
                mov     cx, 4
                rep     cs outsb

                mov     ax, 0x100
                mov     ds, ax
                mov     si, 0x304
                mov     cx, 4
                rep     ds outsb

                mov     ax, 0x110
                mov     es, ax
                mov     si, 0x208
                mov     cx, 4
                rep     es outsb

                mov     ax, 0x120
                mov     fs, ax
                mov     si, 0x10C
                mov     cx, 4
                rep     fs outsb

                mov     ax, 0x130
                mov     gs, ax
                mov     si, 0x10
                mov     cx, 4
                rep     gs outsb

                mov     ax, 0x30
                mov     ss, ax
                mov     si, 0x1014
                mov     cx, 4
                rep     ss outsb

                hlt


io_in_test:
                in      al, 0x60
                hlt
                in      ax, 0x60
                hlt
                in      eax, 0x60
                hlt

test3:
                mov     ax, 0x100
                out     20, ax

mmio_read:
                mov     ebx, 0x87654321
                mov     bl, [0x8008]
                mov     bx, [0x8008]
                mov     ebx, [0x8010]

                mov     [0x8000], bl
                mov     [0x8008], bx
                mov     [0x8010], ebx

                hlt
                hlt


                OFFSET  0x100
instruction_prefixes:
                db  0xf0, 0xf2, 0xf3, 0xaa
                db  0xf0, 0xf2, 0x2e, 0x67, 0x46, 0x0f, 0x3a, 0x7a, 0x22, 0x8e, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f
                lock     es add word  [0x1200], ax

                OFFSET  0x300
                db      0x12, 0x34, 0x56, 0x78
                db      0x11, 0x22, 0x33, 0x44
                db      0x00, 0x00, 0x00, 0x01
                db      0xaa, 0xbb, 0xcc, 0xdd
                db      0xfe, 0xdc, 0xba, 0x98
                db      0x55, 0xaa, 0xcc, 0xdd

                OFFSET  0x320
src_data:       db      0xaa, 0xbb, 0xcc, 0xdd
dest_data       db      0, 0, 0, 0


jump_table:
                dw      read_write_memory
                dw      io_out_test
                dw      test3
                dw      mmio_read
                dw      instruction_prefixes
                dw      io_in_test

