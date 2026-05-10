				THUMB
                PRESERVE8

RCC_APB2ENR         EQU     0x40021018
RCC_APB1ENR         EQU     0x4002101C
GPIOA_CRL           EQU     0x40010800
GPIOA_CRH           EQU     0x40010804
GPIOB_CRL           EQU     0x40010C00
GPIOC_CRH           EQU     0x40011004      ; <--- ADDED FOR C15
GPIOC_IDR           EQU     0x40011008      ; <--- ADDED FOR C15

TIM1_CR1            EQU     0x40012C00
TIM1_EGR            EQU     0x40012C14
TIM1_CCMR2          EQU     0x40012C1C
TIM1_CCER           EQU     0x40012C20
TIM1_BDTR           EQU     0x40012C44
TIM1_PSC            EQU     0x40012C28
TIM1_ARR            EQU     0x40012C2C
TIM1_CCR4           EQU     0x40012C40      ; PA11 floor 1

TIM3_CR1            EQU     0x40000400
TIM3_EGR            EQU     0x40000414
TIM3_CCMR1          EQU     0x40000418
TIM3_CCMR2          EQU     0x4000041C
TIM3_CCER           EQU     0x40000420
TIM3_PSC            EQU     0x40000428
TIM3_ARR            EQU     0x4000042C
TIM3_CCR1           EQU     0x40000434      ; PA6 floor 0
TIM3_CCR3           EQU     0x4000043C      ; PB0 floor 2

SERVO_STOP_PULSE    EQU     1500
SERVO_CLOSED_PULSE  EQU     900
SERVO_OPEN_PULSE    EQU     2100

        AREA    |.text|, CODE, READONLY
        EXPORT  FloorServos_Init
        EXPORT  FloorServos_RunForFloor

FloorServos_Init
        PUSH    {R0-R2, LR}

        ; Enable GPIOA, GPIOB, GPIOC, AFIO, TIM1 clocks
        LDR     R0, =RCC_APB2ENR
        LDR     R1, [R0]
        LDR     R2, =0x081D         ; <--- CHANGED: 0x10 added to enable GPIOC clock!
        ORR     R1, R1, R2
        STR     R1, [R0]

        ; Enable TIM3 clock
        LDR     R0, =RCC_APB1ENR
        LDR     R1, [R0]
        ORR     R1, R1, #0x02
        STR     R1, [R0]

        ; PA6 = AF push-pull 2 MHz (TIM3_CH1)
        LDR     R0, =GPIOA_CRL
        LDR     R1, [R0]
        LDR     R2, =0xF0FFFFFF
        AND     R1, R1, R2
        LDR     R2, =0x0A000000
        ORR     R1, R1, R2
        STR     R1, [R0]

        ; PA11 = AF Output (Floor 1 Servo)
        LDR     R0, =GPIOA_CRH
        LDR     R1, [R0]
        LDR     R2, =0xFFFF0FFF
        AND     R1, R1, R2
        LDR     R2, =0x0000A000
        ORR     R1, R1, R2
        STR     R1, [R0]

        ; PC15 = Input Floating (IR Sensor)
        LDR     R0, =GPIOC_CRH
        LDR     R1, [R0]
        LDR     R2, =0x0FFFFFFF     ; Clear bits for PC15
        AND     R1, R1, R2
        LDR     R2, =0x40000000     ; Set PC15 to Input Floating (4)
        ORR     R1, R1, R2
        STR     R1, [R0]

        ; PB0 = AF push-pull 2 MHz (TIM3_CH3)
        LDR     R0, =GPIOB_CRL
        LDR     R1, [R0]
        LDR     R2, =0xFFFFFF00
        AND     R1, R1, R2
        LDR     R2, =0x0000000A
        ORR     R1, R1, R2
        STR     R1, [R0]

        ; 1 MHz timer tick, 20 ms period => 50 Hz servo signal
        LDR     R0, =TIM3_PSC
        LDR     R1, =71
        STR     R1, [R0]

        LDR     R0, =TIM3_ARR
        LDR     R1, =19999
        STR     R1, [R0]

        ; PWM mode 1 + preload on CH1
        LDR     R0, =TIM3_CCMR1
        LDR     R1, =0x0068
        STR     R1, [R0]

        ; PWM mode 1 + preload on CH3
        LDR     R0, =TIM3_CCMR2
        LDR     R1, =0x0068
        STR     R1, [R0]

        ; Enable CH1, CH3 outputs
        LDR     R0, =TIM3_CCER
        LDR     R1, =0x101
        STR     R1, [R0]

        ; TIM1 uses same 50 Hz base for floor 1 on PA11
        LDR     R0, =TIM1_PSC
        LDR     R1, =71
        STR     R1, [R0]

        LDR     R0, =TIM1_ARR
        LDR     R1, =19999
        STR     R1, [R0]

        ; PWM mode 1 + preload on CH4
        LDR     R0, =TIM1_CCMR2
        LDR     R1, =0x6800
        STR     R1, [R0]

        ; Enable CH4 output
        LDR     R0, =TIM1_CCER
        LDR     R1, =0x1000
        STR     R1, [R0]

        ; Advanced timer main output enable
        LDR     R0, =TIM1_BDTR
        LDR     R1, =0x8000
        STR     R1, [R0]

        ; Neutra	l pulse on all three servos at startup
        MOVS    R0, #0
        BL      Servo_StopByIndex
        MOVS    R0, #1
        BL      Servo_StopByIndex
        MOVS    R0, #2
        BL      Servo_StopByIndex

        ; Load registers and start timer
        LDR     R0, =TIM3_EGR
        MOVS    R1, #0x01
        STR     R1, [R0]

        LDR     R0, =TIM3_CR1
        MOVS    R1, #0x81
        STR     R1, [R0]

        LDR     R0, =TIM1_EGR
        MOVS    R1, #0x01
        STR     R1, [R0]

        LDR     R0, =TIM1_CR1
        MOVS    R1, #0x81
        STR     R1, [R0]

        POP     {R0-R2, PC}

; =================================================================
; DOORS OPEN, WAIT, CHECK IR SENSOR, THEN CLOSE
; =================================================================
; =================================================================
; SIMPLE IR LOGIC: FREEZE WHILE BLOCKED, CLOSE WHEN CLEAR
; =================================================================
FloorServos_RunForFloor
        PUSH    {R4, LR}
        MOV     R4, R0

        ; 1. OPEN THE DOOR 
        MOV     R0, R4
        BL      Servo_CloseByIndex
        BL      Servo_MoveDelay
        MOV     R0, R4
        BL      Servo_StopByIndex

        ; Wait 2 seconds just so the door doesn't instantly slam 
        ; shut before anyone has a chance to walk towards it!
        BL      Servo_Delay2s

check_ir_simple
        ; 2. CONSTANTLY CHECK IR SENSOR (PC15)
        LDR     R0, =GPIOC_IDR
        LDR     R1, [R0]
        TST     R1, #(1<<15)
        BEQ     check_ir_simple   ; <--- If blocked (0), loop back and check again IMMEDIATELY!

        ; 3. SENSOR IS NOT LIT (CLEAR) -> CLOSE THE DOOR!
        MOV     R0, R4
		 BL      Servo_Delay2s

        BL      Servo_OpenByIndex
        BL      Servo_MoveDelay
        MOV     R0, R4
        BL      Servo_StopByIndex

        POP     {R4, PC}
; =================================================================
; HELPER FUNCTIONS
; =================================================================
Servo_OpenByIndex
        PUSH    {LR}
        LDR     R1, =SERVO_OPEN_PULSE
        BL      SetServoPulseByIndex
        POP     {PC}

Servo_CloseByIndex
        PUSH    {LR}
        LDR     R1, =SERVO_CLOSED_PULSE
        BL      SetServoPulseByIndex
        POP     {PC}

Servo_StopByIndex
        PUSH    {LR}
        LDR     R1, =SERVO_STOP_PULSE
        BL      SetServoPulseByIndex
        POP     {PC}

SetServoPulseByIndex
        CMP     R0, #0
        BEQ     set_servo_0
        CMP     R0, #1
        BEQ     set_servo_1

        LDR     R0, =TIM3_CCR3
        STR     R1, [R0]
        BX      LR

set_servo_0
        LDR     R0, =TIM3_CCR1
        STR     R1, [R0]
        BX      LR

set_servo_1
        LDR     R0, =TIM1_CCR4
        STR     R1, [R0]
        BX      LR

Servo_MoveDelay
        PUSH    {R0, LR}
        LDR     R0, =39900000
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