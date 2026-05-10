                THUMB
                PRESERVE8

RCC_APB2ENR     EQU     0x40021018
GPIOA_CRL       EQU     0x40010800
GPIOA_IDR       EQU     0x40010808
GPIOA_ODR       EQU     0x4001080C
GPIOA_BRR       EQU     0x40010814
GPIOC_CRH       EQU     0x40011004
GPIOC_BSRR      EQU     0x40011010
GPIOC_BRR       EQU     0x40011014

                AREA    MYCODE, CODE, READONLY
                EXPORT  main

main
; Enable GPIOA + GPIOC
                LDR     R0, =RCC_APB2ENR
                LDR     R1, [R0]
                LDR     R2, =((1<<2) | (1<<4))
                ORR     R1, R1, R2
                STR     R1, [R0]

; PA0-PA3 output 2MHz push-pull, PA4-PA7 input pull-up/down
                LDR     R0, =GPIOA_CRL
                LDR     R1, =0x88882222
                STR     R1, [R0]

; enable pull-ups on PA4-PA7
                LDR     R0, =GPIOA_ODR
                LDR     R1, [R0]
                MOVS    R2, #0xF0
                ORR     R1, R1, R2
                STR     R1, [R0]

; PC13 output 2MHz push-pull
                LDR     R0, =GPIOC_CRH
                LDR     R1, [R0]
                LDR     R2, =0xFF0FFFFF
                AND     R1, R1, R2
                LDR     R2, =0x00200000
                ORR     R1, R1, R2
                STR     R1, [R0]

; LED off
                LDR     R0, =GPIOC_BSRR
                LDR     R1, =(1<<13)
                STR     R1, [R0]

main_loop
                BL      keypad_pressed
                CMP     R0, #0
                BEQ     no_key

; LED on
                LDR     R0, =GPIOC_BRR
                LDR     R1, =(1<<13)
                STR     R1, [R0]
                B       main_loop

no_key
; LED off
                LDR     R0, =GPIOC_BSRR
                LDR     R1, =(1<<13)
                STR     R1, [R0]
                B       main_loop

keypad_pressed
                PUSH    {R1-R7, LR}
                MOVS    R2, #0

row_loop
                CMP     R2, #4
                BGE     none

; all rows high
                LDR     R0, =GPIOA_ODR
                LDR     R1, [R0]
                ORR     R1, R1, #0x0F
                STR     R1, [R0]

; selected row low
                MOVS    R3, #1
                LSL     R3, R3, R2
                LDR     R1, [R0]
                BIC     R1, R1, R3
                STR     R1, [R0]

                BL      short_delay

; read columns
                LDR     R0, =GPIOA_IDR
                LDR     R4, [R0]
                LSRS    R4, R4, #4
                AND     R4, R4, #0x0F

; if not all ones, some key is pressed
                CMP     R4, #0x0F
                BNE     found

                ADDS    R2, R2, #1
                B       row_loop

found
                MOVS    R0, #1
                POP     {R1-R7, LR}
                BX      LR

none
                MOVS    R0, #0
                POP     {R1-R7, LR}
                BX      LR

short_delay
                LDR     R5, =3000
sd1
                SUBS    R5, R5, #1
                BNE     sd1
                BX      LR

                END