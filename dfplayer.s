				THUMB
                PRESERVE8

; ================= REGISTERS =================
RCC_APB2ENR     EQU     0x40021018
RCC_APB1ENR     EQU     0x4002101C
GPIOB_CRH       EQU     0x40010C04
USART3_SR       EQU     0x40004800
USART3_DR       EQU     0x40004804
USART3_BRR      EQU     0x40004808
USART3_CR1      EQU     0x4000480C

                AREA    DF_CODE, CODE, READONLY
                EXPORT  DFPlayer_Init
                EXPORT  Announce_Floor
                EXPORT  Announce_Up         ; <--- NEW EXPORT
                EXPORT  Announce_Down       ; <--- NEW EXPORT
				EXPORT Announce_Denied
				EXPORT Announce_Granted
					
; ================= INITIALIZATION =================
DFPlayer_Init
                PUSH    {R0, R1, LR}
                
                LDR     R0, =RCC_APB2ENR
                LDR     R1, [R0]
                ORR     R1, R1, #(1<<3)     
                STR     R1, [R0]

                LDR     R0, =RCC_APB1ENR
                LDR     R1, [R0]
                ORR     R1, R1, #(1<<18)    
                STR     R1, [R0]

                LDR     R0, =GPIOB_CRH
                LDR     R1, [R0]
                BIC     R1, R1, #(0xFF << 8)
                ORR     R1, R1, #(0x4B << 8)
                STR     R1, [R0]

                LDR     R0, =USART3_BRR
                LDR     R1, =0x0EA6
                STR     R1, [R0]

                LDR     R0, =USART3_CR1
                MOV     R1, #0x2008         
                STR     R1, [R0]

                BL      DF_Delay
                BL      DF_Delay
                BL      DF_Delay

                LDR     R0, =cmd_vol
                BL      Send_Command
                BL      DF_Delay

                POP     {R0, R1, PC}

; ================= ANNOUNCE DIRECTION =================
Announce_Up
                PUSH    {R0, LR}
                LDR     R0, =cmd_play4      ; Play 0004.mp3
                BL      Send_Command
                POP     {R0, PC}

Announce_Down
                PUSH    {R0, LR}
                LDR     R0, =cmd_play4     ; Play 0005.mp3
                BL      Send_Command
                POP     {R0, PC}
; ================= ANNOUNCE RFID =================
Announce_Granted
                PUSH    {R0, LR}
                LDR     R0, =cmd_play5      ; Play 0005.mp3 (Access Granted)
                BL      Send_Command
                POP     {R0, PC}

Announce_Denied
                PUSH    {R0, LR}
                LDR     R0, =cmd_play6      ; Play 0006.mp3 (Access Denied)
                BL      Send_Command
                POP     {R0, PC}
; ================= ANNOUNCE FLOOR =================
Announce_Floor
                PUSH    {R0, LR}            
                
                CMP     R0, #0
                BEQ     play_f0
                CMP     R0, #1
                BEQ     play_f1
                CMP     R0, #2
                BEQ     play_f2
                B       announce_done

play_f0
                LDR     R0, =cmd_play1
                BL      Send_Command
                B       announce_done
play_f1
                LDR     R0, =cmd_play2
                BL      Send_Command
                B       announce_done
play_f2
                LDR     R0, =cmd_play3
                BL      Send_Command

announce_done
                POP     {R0, PC}

; ================= UART TRANSMIT =================
Send_Command
                PUSH    {R4, R5, LR}
                MOVS    R1, #10
send_loop
                LDRB    R2, [R0], #1
                BL      USART3_Send
                SUBS    R1, R1, #1
                BNE     send_loop
                POP     {R4, R5, PC}

USART3_Send
                PUSH    {R3, R4}
wait_tx
                LDR     R3, =USART3_SR
                LDR     R4, [R3]
                TST     R4, #(1<<7)
                BEQ     wait_tx

                LDR     R3, =USART3_DR
                STR     R2, [R3]
                POP     {R3, R4}
                BX      LR

; ================= STANDALONE DELAY =================
DF_Delay
                PUSH    {R0, LR}
                LDR     R0, =4000000        
df_delay_loop
                SUBS    R0, R0, #1
                BNE     df_delay_loop
                POP     {R0, PC}

                ALIGN
                LTORG

; ================= COMMAND HEX ARRAYS =================
cmd_vol         DCB 0x7E, 0xFF, 0x06, 0x06, 0x00, 0x00, 0x1E, 0xFE, 0xDD, 0xEF
cmd_play1       DCB 0x7E, 0xFF, 0x06, 0x03, 0x00, 0x00, 0x01, 0xFE, 0xF7, 0xEF  ; Floor 0
cmd_play2       DCB 0x7E, 0xFF, 0x06, 0x03, 0x00, 0x00, 0x02, 0xFE, 0xF6, 0xEF  ; Floor 1
cmd_play3       DCB 0x7E, 0xFF, 0x06, 0x03, 0x00, 0x00, 0x03, 0xFE, 0xF5, 0xEF  ; Floor 2
cmd_play4       DCB 0x7E, 0xFF, 0x06, 0x03, 0x00, 0x00, 0x04, 0xFE, 0xF4, 0xEF  ; Moving Up/Down
cmd_play5       DCB 0x7E, 0xFF, 0x06, 0x03, 0x00, 0x00, 0x05, 0xFE, 0xF3, 0xEF  ; Access Granted
cmd_play6       DCB 0x7E, 0xFF, 0x06, 0x03, 0x00, 0x00, 0x06, 0xFE, 0xF2, 0xEF  ; Access Denied

                ALIGN
                END

                ALIGN
                END