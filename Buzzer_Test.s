		THUMB
        PRESERVE8

RCC_APB2ENR     EQU     0x40021018
GPIOA_CRL       EQU     0x40010800
GPIOA_CRH       EQU     0x40010804    ; Added CRH for Pins 8-15
GPIOA_BSRR      EQU     0x40010810
GPIOA_BRR       EQU     0x40010814

BUZZER_PIN      EQU     (1 << 12)   ; Updated to PA12

        AREA    |.text|, CODE, READONLY
        EXPORT  Buzzer_Init
        EXPORT  Buzzer_On
        EXPORT  Buzzer_Off
        EXPORT  Buzzer_UpdateFromKey

Buzzer_Init
        PUSH    {R0-R2, LR}

        ; Enable GPIOA clock
        LDR     R0, =RCC_APB2ENR
        LDR     R1, [R0]
        ORR     R1, R1, #0x04
        STR     R1, [R0]

        ; Configure PA12 as output push-pull, 2 MHz
        ; Pin 12 configuration is in CRH bits [19:16]
        LDR     R0, =GPIOA_CRH      ; Changed from CRL to CRH
        LDR     R1, [R0]
        LDR     R2, =0xFFF0FFFF     ; Mask to clear bits 16-19 (Pin 12)
        AND     R1, R1, R2
        LDR     R2, =0x00020000     ; Set Mode 0x2 (Output 2MHz) and CNF 0x0 (Push-Pull)
        ORR     R1, R1, R2
        STR     R1, [R0]

        BL      Buzzer_Off

        POP     {R0-R2, PC}

Buzzer_On
        LDR     R0, =GPIOA_BSRR
        LDR     R1, =BUZZER_PIN     ; Use LDR for 32-bit constants
        STR     R1, [R0]
        BX      LR

Buzzer_Off
        LDR     R0, =GPIOA_BRR
        LDR     R1, =BUZZER_PIN     ; Use LDR for 32-bit constants
        STR     R1, [R0]
        BX      LR

; R0 = keypad character
; '*' turns buzzer on, anything else turns it off
Buzzer_UpdateFromKey
        CMP     R0, #'*'
        BEQ     buzzer_key_on
        B       Buzzer_Off

buzzer_key_on
        B       Buzzer_On

        END