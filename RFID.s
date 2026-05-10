		THUMB
        PRESERVE8

; --- Register Addresses ---
RCC_APB2ENR     EQU 0x40021018
GPIOA_CRL       EQU 0x40010800  ; Added for PA3/PA4 config
GPIOA_CRH       EQU 0x40010804
GPIOA_IDR       EQU 0x40010808  ; Added for PA4 read
GPIOA_BSRR      EQU 0x40010810
GPIOA_BRR       EQU 0x40010814
GPIOB_CRL       EQU 0x40010C00
GPIOB_CRH       EQU 0x40010C04
GPIOB_IDR       EQU 0x40010C08
GPIOB_BSRR      EQU 0x40010C10
GPIOB_BRR       EQU 0x40010C14
GPIOC_CRH       EQU 0x40011004
GPIOC_BSRR      EQU 0x40011010
GPIOC_BRR       EQU 0x40011014

; --- Pins (Updated from Image) ---
SDA_MSK         EQU (1<<1)  ; PB1 (CS)
SCK_MSK         EQU (1<<3)  ; PA3
MISO_MSK        EQU (1<<4)  ; PA4
MOSI_MSK        EQU (1<<5)  ; PB5
RST_MSK         EQU (1<<4)  ; PB4
LED_MSK         EQU (1<<13) ; PC13

; --- RC522 Registers ---
RC_COMMAND      EQU 0x01
RC_FIFODATA     EQU 0x09
RC_FIFOLEVEL    EQU 0x0A
RC_BITFRAME     EQU 0x0D
RC_TXCONTROL    EQU 0x14
RC_TXASK        EQU 0x15
RC_MODE         EQU 0x11
RC_RFCFG        EQU 0x26
RC_TPRESCALER   EQU 0x2A
RC_TRELOADH     EQU 0x2B
RC_TRELOADL     EQU 0x2C

CMD_IDLE        EQU 0x00
CMD_SOFTRESET   EQU 0x0F
CMD_TRANSCEIVE  EQU 0x0C
PICC_REQA       EQU 0x26

        AREA |.text|, CODE, READONLY
        EXPORT main

main
        ; 1. Enable Clocks for GPIO A, B, and C
        LDR R0, =RCC_APB2ENR
        LDR R1, [R0]
        ORR R1, R1, #0x1C
        STR R1, [R0]

        ; 2. Configure GPIOB: PB1 (CS), PB4 (RST), PB5 (MOSI) = Out (2MHz)
        LDR R0, =GPIOB_CRL
        LDR R1, [R0]
        LDR R2, =0x00FF00F0     ; Mask for PB5, PB4, PB1
        BIC R1, R1, R2
        LDR R2, =0x00220020     ; Output Push-Pull, 2MHz (0x2)
        ORR R1, R1, R2
        STR R1, [R0]

        ; 3. Configure GPIOA: PA3 (SCK) = Out (2MHz), PA4 (MISO) = In Floating
        LDR R0, =GPIOA_CRL
        LDR R1, [R0]
        LDR R2, =0x000FF000     ; Mask for PA4, PA3
        BIC R1, R1, R2
        LDR R2, =0x00042000     ; PA4=In Float (0x4), PA3=Out 2MHz (0x2)
        ORR R1, R1, R2
        STR R1, [R0]

        ; 4. Configure GPIOC: PC13 = Out (2MHz)
        LDR R0, =GPIOC_CRH
        LDR R1, [R0]
        BIC R1, R1, #0x00F00000
        ORR R1, R1, #0x00200000
        STR R1, [R0]

        ; 5. Hardware Reset (PB4)
        LDR R0, =GPIOB_BRR
        LDR R1, =RST_MSK
        STR R1, [R0]
        BL  LongDelay
        LDR R0, =GPIOB_BSRR
        STR R1, [R0]
        BL  LongDelay

        ; 6. PCD Initialization Sequence (Matches your C Code)
        MOVS R0, #RC_COMMAND
        MOVS R1, #CMD_SOFTRESET
        BL WriteReg
        BL LongDelay

        MOVS R0, #RC_TPRESCALER
        MOVS R1, #0x8D
        BL WriteReg

        MOVS R0, #RC_TRELOADH
        MOVS R1, #0x3E
        BL WriteReg

        MOVS R0, #RC_TRELOADL
        MOVS R1, #0x00
        BL WriteReg

        MOVS R0, #RC_TXASK
        MOVS R1, #0x40
        BL WriteReg

        MOVS R0, #RC_MODE
        MOVS R1, #0x3D
        BL WriteReg

        MOVS R0, #RC_RFCFG
        MOVS R1, #0x70
        BL WriteReg

        ; Activate Antenna (Read-Modify-Write)
        MOVS R0, #RC_TXCONTROL
        BL ReadReg
        ORR R1, R0, #0x03
        MOVS R0, #RC_TXCONTROL
        BL WriteReg

scan_loop
        ; Clear state for polling
        MOVS R0, #RC_COMMAND
        MOVS R1, #CMD_IDLE
        BL WriteReg
        MOVS R0, #0x06 ; ErrorReg
        MOVS R1, #0x00
        BL WriteReg
        MOVS R0, #RC_FIFOLEVEL
        MOVS R1, #0x80 ; Flush
        BL WriteReg

        ; REQA Handshake
        MOVS R0, #RC_BITFRAME
        MOVS R1, #0x07
        BL WriteReg
        MOVS R0, #RC_FIFODATA
        MOVS R1, #PICC_REQA
        BL WriteReg
        MOVS R0, #RC_COMMAND
        MOVS R1, #CMD_TRANSCEIVE
        BL WriteReg
        MOVS R0, #RC_BITFRAME
        MOVS R1, #0x87
        BL WriteReg

        ; Processing Delay
        LDR R4, =60000
wait_rx SUBS R4, R4, #1
        BNE wait_rx

        ; Check FIFO for response
        MOVS R0, #RC_FIFOLEVEL
        BL ReadReg
        CMP R0, #0
        BEQ scan_loop

        ; SUCCESS: Blink LED
        LDR R0, =GPIOC_BRR
        LDR R1, =LED_MSK
        STR R1, [R0]
        BL  LongDelay
        LDR R0, =GPIOC_BSRR
        STR R1, [R0]
        LDR R4, =1000000 ; Cooldown
cd      SUBS R4, R4, #1
        BNE cd
        B scan_loop

; --- SPI Bit-Bang Helpers ---

WriteReg
        PUSH {R0, R1, LR}
        LSL R0, R0, #1
        AND R0, R0, #0x7E ; Address format: (addr<<1)&0x7E
        PUSH {R1} ; Save Value
        BL SPI_Start
        BL SPI_SendByte ; Send Address
        POP {R0} ; Get Value back
        BL SPI_SendByte ; Send Value
        BL SPI_End
        POP {R0, R1, PC}

ReadReg
        PUSH {R1, LR}
        LSL R0, R0, #1
        AND R0, R0, #0x7E
        ORR R0, R0, #0x80 ; Address format: ((addr<<1)&0x7E)|0x80
        BL SPI_Start
        BL SPI_SendByte
        MOVS R0, #0x00 ; Dummy byte to read
        BL SPI_ReadByte
        PUSH {R0} ; Save result
        BL SPI_End
        POP {R0, R1, PC}

SPI_Start
        LDR R2, =GPIOB_BRR
        LDR R3, =SDA_MSK
        STR R3, [R2] ; CS Low
        BX LR

SPI_End
        LDR R2, =GPIOB_BSRR
        LDR R3, =SDA_MSK
        STR R3, [R2] ; CS High
        BX LR

SPI_SendByte
        PUSH {R4-R6, LR}
        MOV R4, R0
        MOV R5, #8
send_loop
        LDR R2, =GPIOA_BRR     ; SCK is PA3
        LDR R3, =SCK_MSK
        STR R3, [R2]           ; SCK Low
        
        TST R4, #0x80
        BEQ bit_low
        LDR R2, =GPIOB_BSRR    ; MOSI is PB5
        B bit_set
bit_low LDR R2, =GPIOB_BRR     ; MOSI is PB5
bit_set LDR R3, =MOSI_MSK
        STR R3, [R2]           ; Set MOSI

        LDR R2, =GPIOA_BSRR    ; SCK is PA3
        LDR R3, =SCK_MSK
        STR R3, [R2]           ; SCK High (Data sampled here)
        
        LSL R4, R4, #1
        SUBS R5, R5, #1
        BNE send_loop
        POP {R4-R6, PC}

SPI_ReadByte
        PUSH {R4-R6, LR}
        MOV R4, #0
        MOV R5, #8
read_loop
        LDR R2, =GPIOA_BRR     ; SCK is PA3
        LDR R3, =SCK_MSK
        STR R3, [R2]           ; SCK Low
        
        LDR R2, =GPIOA_BSRR    ; SCK is PA3
        LDR R3, =SCK_MSK
        STR R3, [R2]           ; SCK High

        LSL R4, R4, #1
        LDR R2, =GPIOA_IDR     ; MISO is PA4
        LDR R3, [R2]
        TST R3, #MISO_MSK
        BEQ read_next
        ORR R4, R4, #1
read_next
        SUBS R5, R5, #1
        BNE read_loop
        MOV R0, R4
        POP {R4-R6, PC}

LongDelay
        LDR R4, =1000000
ld_loop SUBS R4, R4, #1
        BNE ld_loop
        BX LR

        END