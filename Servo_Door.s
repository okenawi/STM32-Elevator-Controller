        THUMB
        PRESERVE8

RCC_APB2ENR         EQU     0x40021018
RCC_APB1ENR         EQU     0x4002101C
GPIOA_CRL           EQU     0x40010800

TIM3_CR1            EQU     0x40000400
TIM3_EGR            EQU     0x40000414
TIM3_CCMR1          EQU     0x40000418
TIM3_CCER           EQU     0x40000420
TIM3_PSC            EQU     0x40000428
TIM3_ARR            EQU     0x4000042C
TIM3_CCR1           EQU     0x40000434

SERVO_STOP_PULSE    EQU     1500        ; neutral / stop
SERVO_CLOSED_PULSE  EQU     900         ; close direction
SERVO_OPEN_PULSE    EQU     2100        ; open direction

        AREA    |.text|, CODE, READONLY
        EXPORT  Servo_Init
        EXPORT  Servo_Open
        EXPORT  Servo_Close
        EXPORT  Servo_Stop
        EXPORT  Servo_DoorCycle

Servo_Init
        PUSH    {R0-R2, LR}

        ; Enable GPIOA and AFIO clocks
        LDR     R0, =RCC_APB2ENR
        LDR     R1, [R0]
        ORR     R1, R1, #0x05
        STR     R1, [R0]

        ; Enable TIM3 clock
        LDR     R0, =RCC_APB1ENR
        LDR     R1, [R0]
        ORR     R1, R1, #0x02
        STR     R1, [R0]

        ; PA6 = alternate function push-pull, 2 MHz (TIM3_CH1)
        LDR     R0, =GPIOA_CRL
        LDR     R1, [R0]
        LDR     R2, =0xF0FFFFFF
        AND     R1, R1, R2
        LDR     R2, =0x0A000000
        ORR     R1, R1, R2
        STR     R1, [R0]

        ; Timer clock assumed 72 MHz:
        ; PSC = 71 => 1 MHz timer tick (1 us)
        ; ARR = 19999 => 20 ms period (50 Hz)
        LDR     R0, =TIM3_PSC
        LDR     R1, =71
        STR     R1, [R0]

        LDR     R0, =TIM3_ARR
        LDR     R1, =19999
        STR     R1, [R0]

        ; PWM mode 1 on CH1, preload enable
        LDR     R0, =TIM3_CCMR1
        LDR     R1, =0x0068
        STR     R1, [R0]

        ; Enable CH1 output
        LDR     R0, =TIM3_CCER
        MOVS    R1, #0x01
        STR     R1, [R0]

        BL      Servo_Stop

        ; Update registers and start timer with ARPE
        LDR     R0, =TIM3_EGR
        MOVS    R1, #0x01
        STR     R1, [R0]

        LDR     R0, =TIM3_CR1
        MOVS    R1, #0x81
        STR     R1, [R0]

        POP     {R0-R2, PC}

Servo_DoorCycle
        PUSH    {LR}

        BL      Servo_Open
        BL      Servo_MoveDelay
        BL      Servo_Stop
        BL      Servo_Delay2s
        BL      Servo_Close
        BL      Servo_MoveDelay
        BL      Servo_Stop

        POP     {PC}

Servo_Open
        LDR     R0, =TIM3_CCR1
        LDR     R1, =SERVO_OPEN_PULSE
        STR     R1, [R0]
        BX      LR

Servo_Close
        LDR     R0, =TIM3_CCR1
        LDR     R1, =SERVO_CLOSED_PULSE
        STR     R1, [R0]
        BX      LR

Servo_Stop
        LDR     R0, =TIM3_CCR1
        LDR     R1, =SERVO_STOP_PULSE
        STR     R1, [R0]
        BX      LR

Servo_MoveDelay
        PUSH    {R0, LR}
        LDR     R0, =20000000
servo_move_delay_loop
        SUBS    R0, R0, #1
        BNE     servo_move_delay_loop
        POP     {R0, PC}

Servo_Delay500ms
        PUSH    {R0, LR}
        LDR     R0, =10000000
servo_delay_500_loop
        SUBS    R0, R0, #1
        BNE     servo_delay_500_loop
        POP     {R0, PC}

Servo_Delay2s
        PUSH    {R4, LR}
        MOVS    R4, #4
servo_delay_2s_loop
        BL      Servo_Delay500ms
        SUBS    R4, R4, #1
        BNE     servo_delay_2s_loop
        POP     {R4, PC}

        END
