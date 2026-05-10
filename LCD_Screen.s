        THUMB
        PRESERVE8

RCC_APB2ENR     EQU     0x40021018

GPIOB_CRL       EQU     0x40010C00
GPIOB_BSRR      EQU     0x40010C10
GPIOB_BRR       EQU     0x40010C14

SCL_PIN         EQU     0x40        ; PB6
SDA_PIN         EQU     0x80        ; PB7

LCD_ADDR        EQU     0x4E        ; 0x27 << 1
; If it does not work, change to:
; LCD_ADDR      EQU     0x7E        ; 0x3F << 1

LCD_BL          EQU     0x08
LCD_EN          EQU     0x04
        LCD_RS          EQU     0x01

        AREA    |.text|, CODE, READONLY
        EXPORT  LCD_Init
        EXPORT  LCD_Clear
        EXPORT  LCD_ShowFloor
        EXPORT  LCD_ShowMovingUp
        EXPORT  LCD_ShowMovingDown

; ================= GPIO INIT =================

GPIO_Init
        PUSH    {R0-R2, LR}

        LDR     R0, =RCC_APB2ENR
        LDR     R1, [R0]
        ORR     R1, R1, #0x08        ; enable GPIOB clock
        STR     R1, [R0]

        ; PB6 and PB7 = output open-drain 50MHz
        LDR     R0, =GPIOB_CRL
        LDR     R1, [R0]
        LDR     R2, =0x00FFFFFF
        AND     R1, R1, R2
        LDR     R2, =0x77000000
        ORR     R1, R1, R2
        STR     R1, [R0]

        ; release SDA and SCL high
        LDR     R0, =GPIOB_BSRR
        MOV     R1, #(SCL_PIN + SDA_PIN)
        STR     R1, [R0]

        POP     {R0-R2, PC}

; ================= LCD =================

LCD_Init
        PUSH    {R0-R1, LR}

        BL      GPIO_Init
        BL      Delay_Long

        MOV     R0, #0x30
        MOV     R1, #0
        BL      LCD_SendNibble
        BL      Delay_Long

        MOV     R0, #0x30
        MOV     R1, #0
        BL      LCD_SendNibble
        BL      Delay_Long

        MOV     R0, #0x30
        MOV     R1, #0
        BL      LCD_SendNibble
        BL      Delay_Long

        MOV     R0, #0x20            ; 4-bit mode
        MOV     R1, #0
        BL      LCD_SendNibble
        BL      Delay_Long

        MOV     R0, #0x28            ; 4-bit, 2 lines
        MOV     R1, #0
        BL      LCD_SendByte

        MOV     R0, #0x0C            ; display ON, cursor OFF
        MOV     R1, #0
        BL      LCD_SendByte

        BL      LCD_Clear

        MOV     R0, #0x06            ; entry mode
        MOV     R1, #0
        BL      LCD_SendByte

        MOV     R0, #0x80            ; first line, first position
        MOV     R1, #0
        BL      LCD_SendByte

        POP     {R0-R1, PC}

LCD_Clear
        PUSH    {R0-R1, LR}

        MOV     R0, #0x01            ; clear screen
        MOV     R1, #0
        BL      LCD_SendByte
        BL      Delay_Long

        POP     {R0-R1, PC}

LCD_ShowFloor
        PUSH    {R0-R3, LR}

        MOV     R3, R0

        BL      LCD_Clear

        MOV     R0, #'C'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte
        MOV     R0, #'u'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte
        MOV     R0, #'r'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte
        MOV     R0, #'r'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte
        MOV     R0, #'e'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte
        MOV     R0, #'n'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte
        MOV     R0, #'t'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte
        MOV     R0, #' '
        MOV     R1, #LCD_RS
        BL      LCD_SendByte
        MOV     R0, #'F'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte
        MOV     R0, #'l'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte
        MOV     R0, #'o'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte
        MOV     R0, #'o'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte
        MOV     R0, #'r'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte
        MOV     R0, #':'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte

        MOV     R0, #0xC0
        MOV     R1, #0
        BL      LCD_SendByte

        ADD     R0, R3, #'0'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte

        POP     {R0-R3, PC}

LCD_ShowMovingUp
        PUSH    {R0-R1, LR}

        BL      LCD_Clear

        MOV     R0, #'M'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte
        MOV     R0, #'o'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte
        MOV     R0, #'v'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte
        MOV     R0, #'i'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte
        MOV     R0, #'n'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte
        MOV     R0, #'g'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte
        MOV     R0, #' '
        MOV     R1, #LCD_RS
        BL      LCD_SendByte
        MOV     R0, #'U'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte
        MOV     R0, #'p'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte

        POP     {R0-R1, PC}

LCD_ShowMovingDown
        PUSH    {R0-R1, LR}

        BL      LCD_Clear

        MOV     R0, #'M'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte
        MOV     R0, #'o'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte
        MOV     R0, #'v'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte
        MOV     R0, #'i'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte
        MOV     R0, #'n'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte
        MOV     R0, #'g'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte
        MOV     R0, #' '
        MOV     R1, #LCD_RS
        BL      LCD_SendByte
        MOV     R0, #'D'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte
        MOV     R0, #'o'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte
        MOV     R0, #'w'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte
        MOV     R0, #'n'
        MOV     R1, #LCD_RS
        BL      LCD_SendByte

        POP     {R0-R1, PC}

LCD_SendByte
        PUSH    {R0-R4, LR}

        MOV     R3, R0
        MOV     R4, R1

        AND     R0, R3, #0xF0
        MOV     R1, R4
        BL      LCD_SendNibble

        LSL     R0, R3, #4
        AND     R0, R0, #0xF0
        MOV     R1, R4
        BL      LCD_SendNibble

        BL      Delay_Short

        POP     {R0-R4, PC}

LCD_SendNibble
        PUSH    {R0-R3, LR}

        ORR     R2, R0, R1
        ORR     R2, R2, #LCD_BL

        ; send with E = 1
        ORR     R3, R2, #LCD_EN
        MOV     R0, R3
        BL      I2C_WriteByteToLCD
        BL      Delay_Short

        ; send with E = 0
        MOV     R0, R2
        BL      I2C_WriteByteToLCD
        BL      Delay_Short

        POP     {R0-R3, PC}

; ================= I2C BIT BANG =================

I2C_WriteByteToLCD
        PUSH    {R0-R2, LR}

        MOV     R2, R0

        BL      I2C_Start

        MOV     R0, #LCD_ADDR
        BL      I2C_WriteByte

        MOV     R0, R2
        BL      I2C_WriteByte

        BL      I2C_Stop

        POP     {R0-R2, PC}

I2C_Start
        PUSH    {LR}

        BL      SDA_High
        BL      SCL_High
        BL      I2C_Delay
        BL      SDA_Low
        BL      I2C_Delay
        BL      SCL_Low

        POP     {PC}

I2C_Stop
        PUSH    {LR}

        BL      SDA_Low
        BL      SCL_High
        BL      I2C_Delay
        BL      SDA_High
        BL      I2C_Delay

        POP     {PC}

I2C_WriteByte
        PUSH    {R1-R3, LR}

        MOV     R1, #8

i2c_bit_loop
        TST     R0, #0x80
        BEQ     send_zero

send_one
        BL      SDA_High
        B       clock_bit

send_zero
        BL      SDA_Low

clock_bit
        BL      I2C_Delay
        BL      SCL_High
        BL      I2C_Delay
        BL      SCL_Low
        LSL     R0, R0, #1
        SUBS    R1, R1, #1
        BNE     i2c_bit_loop

        ; ACK clock, ignored
        BL      SDA_High
        BL      I2C_Delay
        BL      SCL_High
        BL      I2C_Delay
        BL      SCL_Low

        POP     {R1-R3, PC}

SCL_High
        PUSH    {R0-R1, LR}
        LDR     R0, =GPIOB_BSRR
        MOV     R1, #SCL_PIN
        STR     R1, [R0]
        POP     {R0-R1, PC}

SCL_Low
        PUSH    {R0-R1, LR}
        LDR     R0, =GPIOB_BRR
        MOV     R1, #SCL_PIN
        STR     R1, [R0]
        POP     {R0-R1, PC}

SDA_High
        PUSH    {R0-R1, LR}
        LDR     R0, =GPIOB_BSRR
        MOV     R1, #SDA_PIN
        STR     R1, [R0]
        POP     {R0-R1, PC}

SDA_Low
        PUSH    {R0-R1, LR}
        LDR     R0, =GPIOB_BRR
        MOV     R1, #SDA_PIN
        STR     R1, [R0]
        POP     {R0-R1, PC}

; ================= DELAYS =================

I2C_Delay
        PUSH    {R0, LR}
        MOV     R0, #80
LCD_I2C_DELAY_LOOP
        SUBS    R0, R0, #1
        BNE     LCD_I2C_DELAY_LOOP
        POP     {R0, PC}

Delay_Short
        PUSH    {R0, LR}
        LDR     R0, =3000
LCD_SHORT_DELAY_LOOP
        SUBS    R0, R0, #1
        BNE     LCD_SHORT_DELAY_LOOP
        POP     {R0, PC}

Delay_Long
        PUSH    {R0, LR}
        LDR     R0, =80000
LCD_LONG_DELAY_LOOP
        SUBS    R0, R0, #1
        BNE     LCD_LONG_DELAY_LOOP
        POP     {R0, PC}

        LTORG
        END
