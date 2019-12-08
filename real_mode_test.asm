
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
                mov     al, 1
                mov     dx, 0x60
                out     dx, al

test3:
                mov     ax, 0x100
                out     20, ax
                

jump_table:
                dw      test1
                dw      io_out_test
                dw      test3
                
