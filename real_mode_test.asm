    %macro OFFSET 1
    times %1 - ($ - $$)   db 0x90
    %endmacro
                BITS    16
                ORG     0x1000

                mov     bx, jump_table
                shl     ax, 1
                add     bx, ax
                jmp     [bx]

test1:  
                mov     ax, [0x1200]
                inc     ax
                hlt

io_out_test:  
;;                mov     al, 1
;;                mov     dx, 0x60
;;                out     dx, al
;;                mov     bx, 0x1234

                cld
                xor     ax, ax
                mov     es, ax
                mov     si, 0x1000
                mov     dword [si], 0x01020304
                mov     dword [si+4], 0x11121314
                mov     dx, 0x60
                mov     cx, 9
                rep     outsd
                hlt
test3:
                mov     ax, 0x100
                out     20, ax

bad_memory_read:
                mov     ax, [0x8000]

                OFFSET  0x100
instruction_prefixes:
                db  0xf0, 0xf2, 0xf3, 0xaa
                db  0xf0, 0xf2, 0x2e, 0x67, 0x46, 0x0f, 0x3a, 0x7a, 0x22, 0x8e, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f
                lock     es add word  [0x1200], ax



jump_table:
                dw      test1
                dw      io_out_test
                dw      test3
                dw      bad_memory_read
                dw      instruction_prefixes

