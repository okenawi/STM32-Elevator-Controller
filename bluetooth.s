		THUMB
        PRESERVE8

RCC_APB2ENR     EQU     0x40021018
GPIOA_CRH       EQU     0x40010804
USART1_SR       EQU     0x40013800
USART1_DR       EQU     0x40013804
USART1_BRR      EQU     0x40013808
USART1_CR1      EQU     0x4001380C

        AREA    |.text|, CODE, READONLY
        EXPORT  Bluetooth_Init
        EXPORT  Bluetooth_CheckForRequests
        IMPORT  request_floor

Bluetooth_Init
        PUSH    {R0-R2, LR}
        ; Enable Clock for GPIOA and USART1
        LDR     R0, =RCC_APB2ENR
        LDR     R1, [R0]
        LDR     R2, =0x4004     ; USART1 (Bit 14) + Port A (Bit 2)
        ORR     R1, R1, R2
        STR     R1, [R0]

        ; Config PA9 (TX) as AFPP, PA10 (RX) as Input Floating
        LDR     R0, =GPIOA_CRH
        LDR     R1, [R0]
        LDR     R2, =0xFFFFF00F
        AND     R1, R1, R2
        LDR     R2, =0x000004B0
        ORR     R1, R1, R2
        STR     R1, [R0]

        ; Baud Rate 9600 @ 72MHz
        LDR     R0, =USART1_BRR
        LDR     R1, =0x1D4C
        STR     R1, [R0]

        ; Enable USART, TX, RX
        LDR     R0, =USART1_CR1
        LDR     R1, =0x200C
        STR     R1, [R0]
        POP     {R0-R2, PC}

Bluetooth_CheckForRequests
        PUSH    {R0-R2, LR}
        LDR     R0, =USART1_SR
        LDR     R1, [R0]
        TST     R1, #0x20       ; RXNE?
        BEQ     bt_exit         ; No data, return immediately

        LDR     R2, =USART1_DR
        LDR     R0, [R2]        ; Read char from phone

        ; Direct call to your existing floor logic
        CMP     R0, #'0'
        BEQ     bt_go0
        CMP     R0, #'1'
        BEQ     bt_go1
        CMP     R0, #'2'
        BEQ     bt_go2
        B       bt_exit

bt_go0  MOVS    R0, #0
        BL      request_floor
        B       bt_exit
bt_go1  MOVS    R0, #1
        BL      request_floor
        B       bt_exit
bt_go2  MOVS    R0, #2
        BL      request_floor

bt_exit POP     {R0-R2, PC}
        END