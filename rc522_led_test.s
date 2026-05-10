				THUMB
                PRESERVE8

; ================= REGISTERS =================
RCC_APB2ENR     EQU     0x40021018
RCC_APB1ENR     EQU     0x4002101C  ; Needed for SPI2 Clock

GPIOA_CRL       EQU     0x40010800
GPIOA_BSRR      EQU     0x40010810

GPIOB_CRH       EQU     0x40010C04  ; For PB12-PB15
GPIOB_BSRR      EQU     0x40010C10
GPIOB_BRR       EQU     0x40010C14

GPIOC_CRH       EQU     0x40011004
GPIOC_BSRR      EQU     0x40011010
GPIOC_BRR       EQU     0x40011014

SPI2_CR1        EQU     0x40003800  ; SPI2 Base
SPI2_SR         EQU     0x40003808
SPI2_DR         EQU     0x4000380C

; ================= CODE =================
                AREA    MYCODE, CODE, READONLY
                EXPORT  __main
                ALIGN

__main
                ; 1. Enable Clocks: GPIOA (Bit 2), GPIOC (Bit 4), SPI1 (Bit 12)
                LDR     R0, =RCC_APB2ENR
                LDR     R1, [R0]
                LDR     R2, =0x00001014
                ORR     R1, R1, R2
                STR     R1, [R0]

                ; 2. Configure PC13 as Output Push-Pull (LED)
                LDR     R0, =GPIOC_CRH
                LDR     R1, [R0]
                LDR     R2, =0xFF0FFFFF     ; Clear PC13 bits
                AND     R1, R1, R2
                LDR     R2, =0x00300000     ; Output Mode, Max speed 50MHz
                ORR     R1, R1, R2
                STR     R1, [R0]

                ; Turn LED OFF initially (PC13 High = OFF on Blue Pill)
                LDR     R0, =GPIOC_BSRR
                MOV     R1, #(1<<13)
                STR     R1, [R0]

                ; 3. Initialize RC522 over SPI
                BL      RC522_Init

; --- MAIN SCANNER LOOP ---
poll_rfid
                BL      RC522_ScanCard
                
                CMP     R0, #0              ; 0 = No Card Found
                BEQ     access_denied_or_no_card
                
                ; If we get here, it means R0 was 1 or 2 (ANY card was detected!)
access_granted
                ; Turn LED ON (PC13 Low = ON)
                LDR     R0, =GPIOC_BRR
                MOV     R1, #(1<<13)
                STR     R1, [R0]
                
                BL      Delay_Short         
                B       poll_rfid

access_denied_or_no_card
                ; Turn LED OFF (PC13 High = OFF)
                LDR     R0, =GPIOC_BSRR
                MOV     R1, #(1<<13)
                STR     R1, [R0]
                
                BL      Delay_Short         
                B       poll_rfid

; =========================================================
; DELAY
; =========================================================
Delay_Large
                PUSH    {R0, LR}
                LDR     R0, =4000000
delay_loop
                SUBS    R0, R0, #1
                BNE     delay_loop
                POP     {R0, PC}

Delay_Short
                PUSH    {R0, LR}
                LDR     R0, =5000
delay_s_loop
                SUBS    R0, R0, #1
                BNE     delay_s_loop
                POP     {R0, PC}

; =========================================================
; RC522 DRIVER
; =========================================================
RC522_Init
                PUSH    {R0-R2, LR}
                ; 1. Enable Clocks: GPIOB (Bit 3) and SPI2 (Bit 14 on APB1)
                LDR     R0, =RCC_APB2ENR
                LDR     R1, [R0]
                ORR     R1, R1, #(1<<3)   ; Enable GPIOB
                STR     R1, [R0]
                
                LDR     R0, =RCC_APB1ENR
                LDR     R1, [R0]
                ORR     R1, R1, #(1<<14)  ; Enable SPI2
                STR     R1, [R0]

                ; 2. Configure RST on PA3 (Out-PP)
                LDR     R0, =GPIOA_CRL
                LDR     R1, [R0]
                LDR     R2, =0xFFFF0FFF
                AND     R1, R1, R2
                ORR     R1, R1, #0x00003000
                STR     R1, [R0]

                ; 3. Configure PB12(CS), PB13(SCK), PB14(MISO), PB15(MOSI)
                LDR     R0, =GPIOB_CRH
                LDR     R1, [R0]
                LDR     R2, =0x0000FFFF
                AND     R1, R1, R2
                LDR     R2, =0xB4B30000   ; SCK/MOSI Alt-PP, MISO Float, CS Out-PP
                ORR     R1, R1, R2
                STR     R1, [R0]

                ; 4. Deselect SPI (PB12 High) & Release Reset (PA3 High)
                LDR     R0, =GPIOB_BSRR
                MOV     R1, #(1<<12)
                STR     R1, [R0]
                LDR     R0, =GPIOA_BSRR
                MOV     R1, #(1<<3)
                STR     R1, [R0]

                ; 5. Configure SPI2 (Master, BR=f/16, CPOL=0, CPHA=0)
                LDR     R0, =SPI2_CR1
                LDR     R1, =0x031C       ; SPI2 is slower by default, use f/16
                STR     R1, [R0]
                ORR     R1, R1, #(1<<6)   ; Enable SPI2
                STR     R1, [R0]

                ; Soft Reset RC522
                MOV     R0, #0x01
                MOV     R1, #0x0F
                BL      RC522_WriteReg
                BL      Delay_Large

                ; Turn Antenna On
                MOV     R0, #0x14
                MOV     R1, #0x83
                BL      RC522_WriteReg
                POP     {R0-R2, PC}
RC522_ScanCard
                PUSH    {R1-R5, LR}

                ; --- REQA (Find Card) ---
                MOV     R0, #0x0A
                MOV     R1, #0x80
                BL      RC522_WriteReg
                MOV     R0, #0x09
                MOV     R1, #0x26
                BL      RC522_WriteReg
                MOV     R0, #0x01
                MOV     R1, #0x0C
                BL      RC522_WriteReg
                MOV     R0, #0x0D
                MOV     R1, #0x87
                BL      RC522_WriteReg
                BL      Delay_Short

                MOV     R0, #0x0A
                BL      RC522_ReadReg
                CMP     R0, #2
                BLT     scan_no_card

                ; --- Anticollision (Read UID) ---
                MOV     R0, #0x0A
                MOV     R1, #0x80
                BL      RC522_WriteReg
                MOV     R0, #0x09
                MOV     R1, #0x93
                BL      RC522_WriteReg
                MOV     R0, #0x09
                MOV     R1, #0x20
                BL      RC522_WriteReg
                MOV     R0, #0x01
                MOV     R1, #0x0C
                BL      RC522_WriteReg
                MOV     R0, #0x0D
                MOV     R1, #0x80
                BL      RC522_WriteReg
                BL      Delay_Short
                BL      Delay_Short

                MOV     R0, #0x0A
                BL      RC522_ReadReg
                CMP     R0, #5
                BLT     scan_no_card

                ; --- Compare UID ---
                LDR     R4, =auth_uid
                MOVS    R5, #1            ; Assume Granted

                MOV     R0, #0x09
                BL      RC522_ReadReg
                LDRB    R2, [R4, #0]
                CMP     R0, R2
                BEQ     check_b2
                MOVS    R5, #2            ; Denied!
check_b2        
                MOV     R0, #0x09
                BL      RC522_ReadReg
                LDRB    R2, [R4, #1]
                CMP     R0, R2
                BEQ     check_b3
                MOVS    R5, #2
check_b3        
                MOV     R0, #0x09
                BL      RC522_ReadReg
                LDRB    R2, [R4, #2]
                CMP     R0, R2
                BEQ     check_b4
                MOVS    R5, #2
check_b4        
                MOV     R0, #0x09
                BL      RC522_ReadReg
                LDRB    R2, [R4, #3]
                CMP     R0, R2
                BEQ     scan_done
                MOVS    R5, #2

scan_done
                MOV     R0, #0x01
                MOV     R1, #0x0F         ; Stop crypto/Halt
                BL      RC522_WriteReg
                MOV     R0, R5
                POP     {R1-R5, PC}

scan_no_card
                MOV     R0, #0
                POP     {R1-R5, PC}

RC522_WriteReg
                PUSH    {R0-R2, LR}
                LSL     R0, R0, #1
                AND     R0, R0, #0x7E
                LDR     R2, =GPIOB_BRR
                MOV     R3, #(1<<12)
                STR     R3, [R2]          ; CS Low (PB12)
                BL      SPI_TxRx
                MOV     R0, R1
                BL      SPI_TxRx
                LDR     R2, =GPIOB_BSRR
                STR     R3, [R2]          ; CS High
                POP     {R0-R2, PC}

RC522_ReadReg
                PUSH    {R1-R3, LR}
                LSL     R0, R0, #1
                AND     R0, R0, #0x7E
                ORR     R0, R0, #0x80
                LDR     R2, =GPIOB_BRR
                MOV     R3, #(1<<12)
                STR     R3, [R2]          ; CS Low (PB12)
                BL      SPI_TxRx
                MOV     R0, #0x00
                BL      SPI_TxRx
                LDR     R2, =GPIOB_BSRR
                STR     R3, [R2]          ; CS High
                POP     {R1-R3, PC}

SPI_TxRx
                PUSH    {R1, R2}
                LDR     R1, =SPI2_SR
                LDR     R2, =SPI2_DR
wait_txe
                LDR     R3, [R1]
                TST     R3, #(1<<1)
                BEQ     wait_txe
                STR     R0, [R2]
wait_rxne
                LDR     R3, [R1]
                TST     R3, #(1<<0)
                BEQ     wait_rxne
                LDR     R0, [R2]
                POP     {R1, R2}
                BX      LR
				
                LTORG

; YOUR AUTHORIZED CARD UID GOES HERE
auth_uid        DCB     0x67, 0x35, 0xFB, 0x00

                ALIGN
                END