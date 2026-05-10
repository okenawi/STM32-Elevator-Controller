			THUMB
        PRESERVE8

RCC_APB2ENR         EQU     0x40021018
AFIO_MAPR           EQU     0x40010004
GPIOB_CRL           EQU     0x40010C00
GPIOB_IDR           EQU     0x40010C08
GPIOB_BSRR          EQU     0x40010C10
GPIOB_BRR           EQU     0x40010C14

RC522_SDA_PIN       EQU     (1 << 1)    ; PB1  (SS / SDA)
RC522_SCK_PIN       EQU     (1 << 2)    ; PB2  (SCK)
RC522_RST_PIN       EQU     (1 << 3)    ; PB3  (RST)
RC522_MISO_PIN      EQU     (1 << 4)    ; PB4  (MISO)
RC522_MOSI_PIN      EQU     (1 << 5)    ; PB5  (MOSI)

; RC522 registers
CommandReg          EQU     0x01
ComIEnReg           EQU     0x02
ComIrqReg           EQU     0x04
ErrorReg            EQU     0x06
FIFODataReg         EQU     0x09
FIFOLevelReg        EQU     0x0A
ControlReg          EQU     0x0C
BitFramingReg       EQU     0x0D
CollReg             EQU     0x0E
ModeReg             EQU     0x11
TxControlReg        EQU     0x14
TxASKReg            EQU     0x15
TModeReg            EQU     0x2A
TPrescalerReg       EQU     0x2B
TReloadRegH         EQU     0x2C
TReloadRegL         EQU     0x2D
VersionReg          EQU     0x37

; RC522 commands
PCD_Idle            EQU     0x00
PCD_Transceive      EQU     0x0C
PCD_SoftReset       EQU     0x0F
PICC_REQA           EQU     0x26

        AREA    MYDATA, DATA, READWRITE
card_seen        SPACE   1

        AREA    |.text|, CODE, READONLY
        EXPORT  RC522_Init
        EXPORT  RC522_CheckAlive
        EXPORT  RC522_RequestA

RC522_GPIO_Init
        PUSH    {R0-R2, LR}

        ; Enable GPIOB and AFIO clocks
        LDR     R0, =RCC_APB2ENR
        LDR     R1, [R0]
        ORR     R1, R1, #0x09
        STR     R1, [R0]

        ; Free PB3/PB4 from JTAG while keeping SWD enabled.
        LDR     R0, =AFIO_MAPR
        LDR     R1, [R0]
        LDR     R2, =0xF8FFFFFF
        AND     R1, R1, R2
        LDR     R2, =0x02000000
        ORR     R1, R1, R2
        STR     R1, [R0]

        ; PB1 SS, PB2 SCK, PB3 RST, PB5 MOSI outputs; PB4 MISO floating input.
        LDR     R0, =GPIOB_CRL
        LDR     R1, [R0]
        LDR     R2, =0xFF00000F
        AND     R1, R1, R2
        LDR     R2, =0x00242220
        ORR     R1, R1, R2
        STR     R1, [R0]

        ; Idle lines
        BL      RC522_SS_High
        BL      RC522_SCK_Low
        BL      RC522_MOSI_Low
        BL      RC522_RST_High

        POP     {R0-R2, PC}

RC522_Init
        PUSH    {R0-R1, LR}

        BL      RC522_GPIO_Init

        BL      RC522_RST_Low
        BL      RC522_Delay_Long
        BL      RC522_RST_High
        BL      RC522_Delay_Long

        MOVS    R0, #CommandReg
        MOVS    R1, #PCD_SoftReset
        BL      RC522_WriteReg
        BL      RC522_Delay_Long

        MOVS    R0, #TModeReg
        MOVS    R1, #0x8D
        BL      RC522_WriteReg

        MOVS    R0, #TPrescalerReg
        MOVS    R1, #0x3E
        BL      RC522_WriteReg

        MOVS    R0, #TReloadRegL
        MOVS    R1, #30
        BL      RC522_WriteReg

        MOVS    R0, #TReloadRegH
        MOVS    R1, #0
        BL      RC522_WriteReg

        MOVS    R0, #TxASKReg
        MOVS    R1, #0x40
        BL      RC522_WriteReg

        MOVS    R0, #ModeReg
        MOVS    R1, #0x3D
        BL      RC522_WriteReg

        BL      RC522_AntennaOn

        POP     {R0-R1, PC}

; Returns R0 = 1 if RC522 responds with a plausible version value, else 0
RC522_CheckAlive
        PUSH    {LR}

        MOVS    R0, #VersionReg
        BL      RC522_ReadReg
        CMP     R0, #0
        BEQ     rc522_not_alive
        CMP     R0, #0xFF
        BEQ     rc522_not_alive

        MOVS    R0, #1
        POP     {PC}

rc522_not_alive
        MOVS    R0, #0
        POP     {PC}

; Returns R0 = 1 if a tag/key is detected, else 0
RC522_RequestA
        PUSH    {R1-R4, LR}

        MOVS    R0, #ComIEnReg
        MOVS    R1, #0xF7
        BL      RC522_WriteReg

        MOVS    R0, #CommandReg
        MOVS    R1, #PCD_Idle
        BL      RC522_WriteReg

        MOVS    R0, #ComIrqReg
        MOVS    R1, #0x7F
        BL      RC522_WriteReg

        MOVS    R0, #FIFOLevelReg
        MOVS    R1, #0x80
        BL      RC522_WriteReg

        MOVS    R0, #BitFramingReg
        MOVS    R1, #0x07
        BL      RC522_WriteReg

        MOVS    R0, #FIFODataReg
        MOVS    R1, #PICC_REQA
        BL      RC522_WriteReg

        MOVS    R0, #CommandReg
        MOVS    R1, #PCD_Transceive
        BL      RC522_WriteReg

        MOVS    R0, #BitFramingReg
        MOVS    R1, #0x87
        BL      RC522_WriteReg

        LDR     R4, =12000
rc522_wait_irq
        MOVS    R0, #ComIrqReg
        BL      RC522_ReadReg
        TST     R0, #0x30
        BNE     rc522_irq_done
        TST     R0, #0x01
        BNE     rc522_req_fail
        SUBS    R4, R4, #1
        BNE     rc522_wait_irq

        MOVS    R0, #0
        B       rc522_req_done

rc522_irq_done
        MOVS    R0, #BitFramingReg
        MOVS    R1, #0x07
        BL      RC522_WriteReg

        MOVS    R0, #ErrorReg
        BL      RC522_ReadReg
        TST     R0, #0x1B
        BNE     rc522_req_fail

        MOVS    R0, #FIFOLevelReg
        BL      RC522_ReadReg
        CMP     R0, #2
        BLO     rc522_req_fail

        MOVS    R0, #1
        B       rc522_req_done

rc522_req_fail
        MOVS    R0, #0

rc522_req_done
        POP     {R1-R4, PC}

RC522_AntennaOn
        PUSH    {R1, LR}

        MOVS    R0, #TxControlReg
        BL      RC522_ReadReg
        TST     R0, #0x03
        BNE     antenna_done

        ORR     R1, R0, #0x03
        MOVS    R0, #TxControlReg
        BL      RC522_WriteReg

antenna_done
        POP     {R1, PC}

; R0 = reg, R1 = value
RC522_WriteReg
        PUSH    {R2, LR}

        BL      RC522_SS_Low
        LSLS    R0, R0, #1
        AND     R0, R0, #0x7E
        BL      RC522_SPI_Transfer
        MOV     R0, R1
        BL      RC522_SPI_Transfer
        BL      RC522_SS_High

        POP     {R2, PC}

; R0 = reg, returns R0 = value
RC522_ReadReg
        PUSH    {R1, LR}

        BL      RC522_SS_Low
        LSLS    R0, R0, #1
        AND     R0, R0, #0x7E
        ORR     R0, R0, #0x80
        BL      RC522_SPI_Transfer
        MOVS    R0, #0
        BL      RC522_SPI_Transfer
        BL      RC522_SS_High

        POP     {R1, PC}

; R0 in = byte to send, R0 out = byte read
RC522_SPI_Transfer
        PUSH    {R1-R4, LR}
        MOVS    R2, #0
        MOVS    R1, #8

spi_bit_loop
        TST     R0, #0x80
        BEQ     spi_zero
        BL      RC522_MOSI_High
        B       spi_clock

spi_zero
        BL      RC522_MOSI_Low

spi_clock
        BL      RC522_SPI_Delay
        BL      RC522_SCK_High
        BL      RC522_SPI_Delay

        LSL     R2, R2, #1
        LDR     R3, =GPIOB_IDR
        LDR     R4, [R3]
        TST     R4, #RC522_MISO_PIN
        BEQ     spi_no_miso
        ORR     R2, R2, #1

spi_no_miso
        BL      RC522_SCK_Low
        BL      RC522_SPI_Delay
        LSL     R0, R0, #1
        SUBS    R1, R1, #1
        BNE     spi_bit_loop

        MOV     R0, R2
        POP     {R1-R4, PC}

RC522_SS_High
        LDR     R0, =GPIOB_BSRR
        LDR     R1, =RC522_SDA_PIN
        STR     R1, [R0]
        BX      LR

RC522_SS_Low
        LDR     R0, =GPIOB_BRR
        LDR     R1, =RC522_SDA_PIN
        STR     R1, [R0]
        BX      LR

RC522_SCK_High
        LDR     R0, =GPIOB_BSRR
        MOVS    R1, #RC522_SCK_PIN
        STR     R1, [R0]
        BX      LR

RC522_SCK_Low
        LDR     R0, =GPIOB_BRR
        MOVS    R1, #RC522_SCK_PIN
        STR     R1, [R0]
        BX      LR

RC522_MOSI_High
        LDR     R0, =GPIOB_BSRR
        LDR     R1, =RC522_MOSI_PIN
        STR     R1, [R0]
        BX      LR

RC522_MOSI_Low
        LDR     R0, =GPIOB_BRR
        LDR     R1, =RC522_MOSI_PIN
        STR     R1, [R0]
        BX      LR

RC522_RST_High
        LDR     R0, =GPIOB_BSRR
        LDR     R1, =RC522_RST_PIN
        STR     R1, [R0]
        BX      LR

RC522_RST_Low
        LDR     R0, =GPIOB_BRR
        LDR     R1, =RC522_RST_PIN
        STR     R1, [R0]
        BX      LR

RC522_SPI_Delay
        PUSH    {R0, LR}
        MOVS    R0, #20
rc522_spi_delay_loop
        SUBS    R0, R0, #1
        BNE     rc522_spi_delay_loop
        POP     {R0, PC}

RC522_Delay_50ms
        PUSH    {R0, LR}
        LDR     R0, =120000
rc522_delay_50_loop
        SUBS    R0, R0, #1
        BNE     rc522_delay_50_loop
        POP     {R0, PC}

RC522_Delay_200ms
        PUSH    {R4, LR}
        MOVS    R4, #4
rc522_delay_200_outer
        BL      RC522_Delay_50ms
        SUBS    R4, R4, #1
        BNE     rc522_delay_200_outer
        POP     {R4, PC}

RC522_Delay_Long
        PUSH    {R0, LR}
        LDR     R0, =400000
rc522_delay_long_loop
        SUBS    R0, R0, #1
        BNE     rc522_delay_long_loop
        POP     {R0, PC}

        END
