                THUMB
                PRESERVE8

RCC_APB2ENR     EQU     0x40021018
AFIO_MAPR       EQU     0x40010004

GPIOA_CRL       EQU     0x40010800
GPIOA_CRH       EQU     0x40010804
GPIOA_IDR       EQU     0x40010808
GPIOA_ODR       EQU     0x4001080C
GPIOA_BSRR      EQU     0x40010810
GPIOA_BRR       EQU     0x40010814

GPIOB_CRH       EQU     0x40010C04
GPIOB_CRL       EQU     0x40010C00
GPIOB_IDR       EQU     0x40010C08
GPIOB_ODR       EQU     0x40010C0C
GPIOB_BSRR      EQU     0x40010C10
GPIOB_BRR       EQU     0x40010C14

GPIOC_CRL       EQU     0x40011000
GPIOC_CRH       EQU     0x40011004
GPIOC_IDR       EQU     0x40011008
GPIOC_BSRR      EQU     0x40011010
GPIOC_BRR       EQU     0x40011014

SCL_PIN         EQU     0x40
SDA_PIN         EQU     0x80

LCD_ADDR        EQU     0x4E
LCD_BL          EQU     0x08
LCD_EN          EQU     0x04
LCD_RS          EQU     0x01

HX711_DOUT_PIN  EQU     (1<<13)    ; PC13
HX711_SCK_PIN   EQU     (1<<14)    ; PC14
HX711_THRESHOLD EQU     50000      ; raw counts above tare, adjust after testing
STOP_SWITCH_PIN EQU     (1<<15)    ; PA15, switch to GND

; 0 is bottom, 2 is top
FLOOR0_POS      EQU     0
FLOOR1_POS      EQU     1150
FLOOR2_POS      EQU     2500

DIR_IDLE        EQU     0
	
DIR_UP          EQU     1
DIR_DOWN        EQU     0xFF

BUTTON0_PIN     EQU     (1<<8)     ; PA8 calls floor 0
BUTTON1_PIN     EQU     (1<<5)     ; PA5 calls floor 1
BUTTON2_PIN     EQU     (1<<7)    ; PA10 calls floor 2

                AREA    MYDATA, DATA, READWRITE

current_pos     SPACE   4
target_pos      SPACE   4
last_key        SPACE   1
last_buttons    SPACE   1
direction       SPACE   1
display_state   SPACE   1
requests        SPACE   4
floor_tbl       SPACE   12
hx711_baseline  SPACE   4
hx711_tick      SPACE   4
hx711_alarm     SPACE   1
hx711_tared     SPACE   1
hx711_over_cnt  SPACE   1
switch_stop     SPACE   1
switch_last     SPACE   1
keypad_unlocked SPACE 	1
                AREA    MYCODE, CODE, READONLY
                EXPORT  main
				EXPORT 	request_floor
                IMPORT  Buzzer_Init
                IMPORT  Buzzer_UpdateFromKey
                IMPORT  Buzzer_On
                IMPORT  Buzzer_Off
				IMPORT  Bluetooth_Init
				IMPORT  Bluetooth_CheckForRequests
                IMPORT  FloorServos_Init
                IMPORT  FloorServos_RunForFloor
				IMPORT  DFPlayer_Init
				IMPORT  Announce_Floor
				IMPORT Announce_Up
				IMPORT Announce_Down
				IMPORT Announce_Denied
				IMPORT Announce_Granted
					
				LTORG

main
                LDR     R0, =RCC_APB2ENR
                LDR     R1, [R0]
                LDR     R2, =0x0000001C
                ORR     R1, R1, R2
                STR     R1, [R0]
	

                LDR     R0, =GPIOA_CRL
                LDR     R1, [R0]
                LDR     R2, =0x0FFFF000    ; Clear bits for PA0-PA2, PA5, AND PA7
                AND     R1, R1, R2
                LDR     R2, =0x80800222    ; PA7=8, PA5=8, PA0-2=2
                ORR     R1, R1, R2
                STR     R1, [R0]

                LDR     R0, =GPIOB_CRH
                LDR     R1, =0x22228888
                STR     R1, [R0]

                LDR     R0, =GPIOB_ODR
                LDR     R1, [R0]
                LDR     R2, =0xFF00
                ORR     R1, R1, R2
                STR     R1, [R0]

                BL      stepper_disable
                BL      Buttons_Init

                MOVS    R1, #0
                LDR     R0, =current_pos
                STR     R1, [R0]
                LDR     R0, =target_pos
                STR     R1, [R0]
                LDR     R0, =direction
                STRB    R1, [R0]
                LDR     R0, =display_state
                STRB    R1, [R0]
                LDR     R0, =requests
                STR     R1, [R0]
                LDR     R0, =hx711_tick
                STR     R1, [R0]
                LDR     R0, =hx711_alarm
                STRB    R1, [R0]
                LDR     R0, =hx711_tared
                STRB    R1, [R0]
                LDR     R0, =switch_stop
                STRB    R1, [R0]
                LDR     R0, =switch_last
                STRB    R1, [R0]
				LDR     R0, =keypad_unlocked
				STRB 	R1,[R0]
                LDR     R0, =last_key
                MOVS    R1, #0xFF
                STRB    R1, [R0]
                LDR     R0, =last_buttons
                MOVS    R1, #0
                STRB    R1, [R0]

                LDR     R0, =floor_tbl
                MOVS    R1, #0
                STR     R1, [R0, #0]
                LDR     R1, =FLOOR1_POS
                STR     R1, [R0, #4]
                LDR     R1, =FLOOR2_POS
                STR     R1, [R0, #8]
				BL      Delay_Long      ; Wait for LCD hardware to stabilize
				BL      Delay_Long
                BL      StopSwitch_Init
                BL      HX711_Init
                BL      Buzzer_Init
                BL      FloorServos_Init
                BL      LCD_Init
				BL		Bluetooth_Init
				BL      DFPlayer_Init
				BL 		RC522_Init
                BL      show_current_floor

main_loop
                ; === RFID SCAN (ONE COMMAND UNLOCK) ===
                BL      RC522_ScanCard
                CMP     R0, #1
                BNE     rfid_poll_done
                
                ; Card Detected! Check if already unlocked
                LDR     R0, =keypad_unlocked
                LDRB    R1, [R0]
                CMP     R1, #1
                BEQ     rfid_poll_done      ; Already unlocked, skip
                
                ; Unlock it!
                MOVS    R1, #1
                STRB    R1, [R0]
                
                ; Show Success for 3 Seconds!
                LDR     R0, =msg_granted
                BL      LCD_PrintString_Clear
				BL		Announce_Granted
                BL      one_second_pause
                BL      one_second_pause
                BL      one_second_pause
                BL      show_current_floor  ; Go back to normal screen
rfid_poll_done
                ; ======================================			
				
				; 1. Safety Checks (High Priority)
                BL      StopSwitch_Update
                BL      StopSwitch_IsStopped
                CMP     R0, #0
                BNE     main_switch_stop

                BL      HX711_UpdateBuzzer
                BL      HX711_IsOverweight
                CMP     R0, #0
                BNE     main_overweight_lock

                ; 2. Input Scanners (Check for requests)
                BL      Bluetooth_CheckForRequests   ; Checks the MIT App
                BL      read_and_store_key           ; Checks the Keypad
				BL      read_and_store_buttons       ; Checks the Floor Buttons (New Name)
				
                ; 3. Navigation & Motion Logic
                BL      maybe_intercept_target
                BL      maybe_pick_next_target
                BL      update_motion_one_step
                
                B       main_loop

main_overweight_lock
                BL      overweight_lockout
                B       main_loop

main_switch_stop
                BL      switch_stop_lockout
                BL      read_resume_command
                B       main_loop

read_and_store_key
                PUSH    {R1-R4, LR}
                BL      keypad_scan_nonblocking
                MOV     R4, R0
                BL      Buzzer_UpdateFromKey

                CMP     R4, #0xFF
                BEQ     rask_no_key

                ; === 1. IS KEYPAD UNLOCKED? ===
                LDR     R0, =keypad_unlocked
                LDRB    R1, [R0]
                CMP     R1, #1
                BEQ     rask_allowed
                
                ; === 2. KEYPAD IS LOCKED! ===
                LDR     R0, =last_key
                LDRB    R1, [R0]
                CMP     R4, R1
                BEQ     rask_done       ; Ignore if holding button down

                STRB    R4, [R0]        ; Store it so it doesn't spam LCD

                ; Show Denied for 3 Seconds!
                LDR     R0, =msg_denied
                BL      LCD_PrintString_Clear
				BL		Announce_Denied
                BL      one_second_pause
                BL      one_second_pause
                BL      one_second_pause
                BL      show_current_floor
                B       rask_done

rask_allowed
                ; === 3. ACCESS GRANTED, PROCESS KEY ===
                LDR     R0, =last_key
                LDRB    R1, [R0]
                CMP     R4, R1
                BEQ     rask_done

                STRB    R4, [R0]
                
                ; RELOCK THE KEYPAD IMMEDIATELY AFTER USE! (One command only)
                LDR     R0, =keypad_unlocked
                MOVS    R1, #0
                STRB    R1, [R0]

                CMP     R4, #'0'
                BEQ     rask_f0
                CMP     R4, #'1'
                BEQ     rask_f1
                CMP     R4, #'2'
                BEQ     rask_f2
                B       rask_done

rask_f0
                MOVS    R0, #0
                BL      request_floor
                B       rask_done
rask_f1
                MOVS    R0, #1
                BL      request_floor
                B       rask_done
rask_f2
                MOVS    R0, #2
                BL      request_floor
                B       rask_done

rask_no_key
                LDR     R0, =last_key
                MOVS    R1, #0xFF
                STRB    R1, [R0]
rask_done
                POP     {R1-R4, LR}
                BX      LR

                LTORG

Buttons_Init
                PUSH    {R0-R2, LR}

                ; PA5 button input with pull-up
                LDR     R0, =GPIOA_CRL
                LDR     R1, [R0]
                LDR     R2, =0xFF0FFFFF
                AND     R1, R1, R2
                LDR     R2, =0x00800000
                ORR     R1, R1, R2
                STR     R1, [R0]

                ; PA8 and PA10 button inputs with pull-ups
                LDR     R0, =GPIOA_CRH
                LDR     R1, [R0]
                LDR     R2, =0xFFFFF0F0
                AND     R1, R1, R2
                LDR     R2, =0x00000808
                ORR     R1, R1, R2
                STR     R1, [R0]

                LDR     R0, =GPIOA_ODR
                LDR     R1, [R0]
                LDR     R2, =(BUTTON0_PIN + BUTTON1_PIN + BUTTON2_PIN)
                ORR     R1, R1, R2
                STR     R1, [R0]

                POP     {R0-R2, PC}

StopSwitch_Init
                PUSH    {R0-R2, LR}

                ; PA15 input with pull-up. Wire switch between PA15 and GND.
                ; Disable JTAG but keep SWD so PA15 works as GPIO.
                LDR     R0, =RCC_APB2ENR
                LDR     R1, [R0]
                ORR     R1, R1, #0x01
                STR     R1, [R0]

                LDR     R0, =AFIO_MAPR
                LDR     R1, [R0]
                LDR     R2, =0xF8FFFFFF
                AND     R1, R1, R2
                LDR     R2, =0x02000000
                ORR     R1, R1, R2
                STR     R1, [R0]

                LDR     R0, =GPIOA_CRH
                LDR     R1, [R0]
                LDR     R2, =0x0FFFFFFF
                AND     R1, R1, R2
                LDR     R2, =0x80000000
                ORR     R1, R1, R2
                STR     R1, [R0]

                LDR     R0, =GPIOA_ODR
                LDR     R1, [R0]
                LDR     R2, =STOP_SWITCH_PIN
                ORR     R1, R1, R2
                STR     R1, [R0]

                BL      StopSwitch_ReadActive
                LDR     R1, =switch_last
                STRB    R0, [R1]

                POP     {R0-R2, PC}

StopSwitch_ReadActive
                LDR     R0, =GPIOA_IDR
                LDR     R0, [R0]
                LDR     R1, =STOP_SWITCH_PIN
                TST     R0, R1
                BEQ     ssra_active
                MOVS    R0, #0
                BX      LR

ssra_active
                MOVS    R0, #1
                BX      LR

StopSwitch_Update
                PUSH    {R1-R3, LR}

                BL      StopSwitch_ReadActive
                MOV     R2, R0

                LDR     R1, =switch_last
                LDRB    R3, [R1]
                STRB    R2, [R1]

                CMP     R2, R3
                BEQ     ssu_done

                LDR     R1, =switch_stop
                MOVS    R2, #1
                STRB    R2, [R1]

ssu_done
                POP     {R1-R3, PC}

StopSwitch_IsStopped
                LDR     R0, =switch_stop
                LDRB    R0, [R0]
                BX      LR

StopSwitch_ClearStop
                PUSH    {R0-R1, LR}
                LDR     R0, =switch_stop
                MOVS    R1, #0
                STRB    R1, [R0]
                POP     {R0-R1, PC}

read_and_store_buttons
                PUSH    {R1-R5, LR}

                LDR     R0, =GPIOA_IDR
                LDR     R1, [R0]
                MOVS    R4, #0

                LDR     R2, =BUTTON0_PIN
                TST     R1, R2
                BNE     rasb_check_b1
                ORR     R4, R4, #0x01

rasb_check_b1
                MOVS    R2, #BUTTON1_PIN
                TST     R1, R2
                BNE     rasb_check_b2
                ORR     R4, R4, #0x02

rasb_check_b2
                LDR     R2, =BUTTON2_PIN
                TST     R1, R2
                BNE     rasb_compare
                ORR     R4, R4, #0x04

rasb_compare
                LDR     R5, =last_buttons
                LDRB    R3, [R5]
                CMP     R4, R3
                BEQ     rasb_done

                MOVS    R2, #0x01
                TST     R4, R2
                BEQ     rasb_check_req1
                TST     R3, R2
                BNE     rasb_check_req1
                MOVS    R0, #0
                BL      request_floor

rasb_check_req1
                MOVS    R2, #0x02
                TST     R4, R2
                BEQ     rasb_check_req2
                TST     R3, R2
                BNE     rasb_check_req2
                MOVS    R0, #1
                BL      request_floor

rasb_check_req2
                MOVS    R2, #0x04
                TST     R4, R2
                BEQ     rasb_store
                TST     R3, R2
                BNE     rasb_store
                MOVS    R0, #2
                BL      request_floor

rasb_store
                STRB    R4, [R5]

rasb_done
                POP     {R1-R5, LR}
                BX      LR

read_resume_command
                PUSH    {R1-R5, LR}

                BL      keypad_scan_nonblocking
                CMP     R0, #'0'
                BEQ     rrc_key0
                CMP     R0, #'1'
                BEQ     rrc_key1
                CMP     R0, #'2'
                BEQ     rrc_key2

                LDR     R0, =GPIOA_IDR
                LDR     R1, [R0]

                LDR     R2, =BUTTON0_PIN
                TST     R1, R2
                BEQ     rrc_floor0

                MOVS    R2, #BUTTON1_PIN
                TST     R1, R2
                BEQ     rrc_floor1

                LDR     R2, =BUTTON2_PIN
                TST     R1, R2
                BEQ     rrc_floor2

                POP     {R1-R5, LR}
                BX      LR

rrc_key0
rrc_floor0
                MOVS    R4, #0
                B       rrc_resume

rrc_key1
rrc_floor1
                MOVS    R4, #1
                B       rrc_resume

rrc_key2
rrc_floor2
                MOVS    R4, #2

rrc_resume
                BL      StopSwitch_ClearStop
                MOV     R0, R4
                BL      request_floor
                POP     {R1-R5, LR}
                BX      LR

request_floor
                PUSH    {R1-R3, LR}
                MOV     R3, R0

                BL      get_current_floor_index
                CMP     R0, R3
                BNE     rf_new_request      ; If not at the floor, go to normal request logic

                ; --- NEW LOGIC: Already at the floor ---
                MOV     R0, R3              ; Pass the floor index
                BL      FloorServos_RunForFloor ; Open the door for this floor
                B       rf_done             ; Exit

rf_new_request
                LDR     R0, =requests
                MOVS    R1, #1
                STRB    R1, [R0, R3]
                BL      maybe_intercept_target

rf_done
                POP     {R1-R3, LR}
                BX      LR

maybe_pick_next_target
                PUSH    {R1-R6, LR}

                LDR     R0, =current_pos
                LDR     R1, [R0]
                LDR     R0, =target_pos
                LDR     R2, [R0]
                CMP     R1, R2
                BNE     mpnt_done

                BL      choose_next_floor
                CMP     R0, #0xFF
                BEQ     mpnt_done

                MOV     R4, R0
                LDR     R1, =floor_tbl
                LSL     R2, R4, #2
                LDR     R3, [R1, R2]

                LDR     R1, =target_pos
                STR     R3, [R1]

                LDR     R1, =current_pos
                LDR     R5, [R1]
                CMP     R3, R5
                BEQ     mpnt_done
                BGT     mpnt_up

                LDR     R0, =direction
                MOVS    R1, #DIR_DOWN
                STRB    R1, [R0]
                B       mpnt_done

mpnt_up
                LDR     R0, =direction
                MOVS    R1, #DIR_UP
                STRB    R1, [R0]

mpnt_done
                POP     {R1-R6, LR}
                BX      LR

choose_next_floor
                PUSH    {R1-R7, LR}

                LDR     R6, =0x000F4240
                MOVS    R7, #0xFF
                MOVS    R1, #0
                LDR     R2, =requests
                LDR     R3, =floor_tbl
                LDR     R0, =current_pos
                LDR     R5, [R0]

cnf_loop
                CMP     R1, #3
                BGE     cnf_done

                LDRB    R0, [R2, R1]
                CMP     R0, #0
                BEQ     cnf_next

                LSL     R0, R1, #2
                LDR     R0, [R3, R0]
                SUBS    R0, R0, R5
                IT      MI
                NEGMI   R0, R0

                CMP     R0, R6
                BGE     cnf_next

                MOV     R6, R0
                MOV     R7, R1

cnf_next
                ADDS    R1, R1, #1
                B       cnf_loop

cnf_done
                MOV     R0, R7
                POP     {R1-R7, LR}
                BX      LR

                LTORG

maybe_intercept_target
                PUSH    {R1-R7, LR}

                LDR     R0, =current_pos
                LDR     R2, [R0]
                LDR     R0, =target_pos
                LDR     R4, [R0]
                CMP     R2, R4
                BEQ     mit_done

                LDR     R0, =direction
                LDRB    R1, [R0]
                CMP     R1, #DIR_UP
                BEQ     mit_up
                CMP     R1, #DIR_DOWN
                BEQ     mit_down
                B       mit_done

mit_up
                LDR     R0, =target_pos
                LDR     R5, =requests
                LDR     R6, =floor_tbl
                MOVS    R7, #0

mit_up_loop
                CMP     R7, #3
                BGE     mit_done

                LDRB    R1, [R5, R7]
                CMP     R1, #0
                BEQ     mit_up_next

                LSL     R1, R7, #2
                LDR     R3, [R6, R1]

                CMP     R3, R2
                BLE     mit_up_next
                CMP     R3, R4
                BGE     mit_up_next

                STR     R3, [R0]
                MOV     R4, R3

mit_up_next
                ADDS    R7, R7, #1
                B       mit_up_loop

mit_down
                LDR     R0, =target_pos
                LDR     R5, =requests
                LDR     R6, =floor_tbl
                MOVS    R7, #0

mit_down_loop
                CMP     R7, #3
                BGE     mit_done

                LDRB    R1, [R5, R7]
                CMP     R1, #0
                BEQ     mit_down_next

                LSL     R1, R7, #2
                LDR     R3, [R6, R1]

                CMP     R3, R2
                BGE     mit_down_next
                CMP     R3, R4
                BLE     mit_down_next

                STR     R3, [R0]
                MOV     R4, R3

mit_down_next
                ADDS    R7, R7, #1
                B       mit_down_loop

mit_done
                POP     {R1-R7, LR}
                BX      LR

                LTORG

update_motion_one_step
                PUSH    {R1-R6, LR}

                BL      StopSwitch_Update
                BL      StopSwitch_IsStopped
                CMP     R0, #0
                BEQ     umos_switch_ok
                POP     {R1-R6, LR}
                B       switch_stop_lockout

umos_switch_ok

                LDR     R0, =current_pos
                LDR     R1, [R0]
                LDR     R0, =target_pos
                LDR     R2, [R0]

                CMP     R1, R2
                BEQ     umos_idle
                BGT     umos_down

                BL      stepper_enable
                BL      show_moving_up
                BL      stepper_dir_up
                BL      stepper_pulse_working

                LDR     R0, =current_pos
                LDR     R1, [R0]
                ADDS    R1, R1, #1
                STR     R1, [R0]
                B       umos_check_arrival

umos_down
                BL      stepper_enable
                BL      show_moving_down
                BL      stepper_dir_down
                BL      stepper_pulse_working

                LDR     R0, =current_pos
                LDR     R1, [R0]
                SUBS    R1, R1, #1
                STR     R1, [R0]

umos_check_arrival
                LDR     R0, =current_pos
                LDR     R1, [R0]
                LDR     R0, =target_pos
                LDR     R2, [R0]
                CMP     R1, R2
                BNE     umos_done

                BL      stepper_disable

                BL      get_current_floor_index
                CMP     R0, #0xFF
                BEQ     umos_after_clear

                LDR     R1, =requests
                MOVS    R2, #0
                STRB    R2, [R1, R0]

umos_after_clear
                PUSH    {R0, LR}
                BL      show_current_floor
                BL      get_current_floor_index
                CMP     R0, #0xFF
                BEQ     umos_skip_floor_servo
				BL 		Announce_Floor
                BL      FloorServos_RunForFloor
umos_skip_floor_servo
                POP     {R0, LR}
                BL      one_second_pause
                BL      one_second_pause

                LDR     R0, =current_pos
                LDR     R1, [R0]
                LDR     R0, =target_pos
                STR     R1, [R0]

                BL      any_requests_pending
                CMP     R0, #0
                BNE     umos_done

                LDR     R0, =direction
                MOVS    R1, #DIR_IDLE
                STRB    R1, [R0]
                B       umos_done

umos_idle
                BL      stepper_disable

umos_done
                POP     {R1-R6, LR}
                BX      LR

                LTORG

show_current_floor
                PUSH    {R1, LR}

                LDR     R1, =display_state
                MOVS    R0, #0
                STRB    R0, [R1]

                BL      get_current_floor_index
                CMP     R0, #0xFF
                BEQ     scf_done

                BL      LCD_ShowFloor
				

scf_done
                POP     {R1, LR}
                BX      LR

show_moving_up
                PUSH    {R0-R1, LR}

                LDR     R0, =display_state
                LDRB    R1, [R0]
                CMP     R1, #1
                BEQ     smu_done

                MOVS    R1, #1
                STRB    R1, [R0]
                BL      LCD_ShowMovingUp
				BL      Announce_Up

smu_done
                POP     {R0-R1, LR}
                BX      LR

show_moving_down
                PUSH    {R0-R1, LR}

                LDR     R0, =display_state
                LDRB    R1, [R0]
                CMP     R1, #2
                BEQ     smd_done

                MOVS    R1, #2
                STRB    R1, [R0]
                BL      LCD_ShowMovingDown
				BL      Announce_Down

smd_done
                POP     {R0-R1, LR}
                BX      LR

                LTORG

HX711_Init
                PUSH    {R0-R2, LR}

                LDR     R0, =RCC_APB2ENR
                LDR     R1, [R0]
                ORR     R1, R1, #0x10
                STR     R1, [R0]

                ; PC13 = HX711 DOUT input floating, PC14 = HX711 SCK output.
                LDR     R0, =GPIOC_CRH
                LDR     R1, [R0]
                LDR     R2, =0xF00FFFFF
                AND     R1, R1, R2
                LDR     R2, =0x02400000
                ORR     R1, R1, R2
                STR     R1, [R0]

                LDR     R0, =GPIOC_BRR
                LDR     R1, =HX711_SCK_PIN
                STR     R1, [R0]

                BL      HX711_ReadRaw
                CMP     R1, #0
                BNE     hx711_store_tare_good
                MOVS    R0, #0
                LDR     R1, =hx711_baseline
                STR     R0, [R1]
                LDR     R1, =hx711_alarm
                STRB    R0, [R1]
                LDR     R1, =hx711_tared
                STRB    R0, [R1]
                POP     {R0-R2, PC}

hx711_store_tare_good
                LDR     R1, =hx711_baseline
                STR     R0, [R1]
                LDR     R1, =hx711_alarm
                MOVS    R0, #0
                STRB    R0, [R1]
                LDR     R0, =hx711_tared
                MOVS    R1, #1
                STRB    R1, [R0]

                POP     {R0-R2, PC}

HX711_UpdateBuzzer
                PUSH    {R0-R4, LR}

                LDR     R0, =hx711_tick
                LDR     R1, [R0]
                ADDS    R1, R1, #1
                CMP     R1, #1
                BLO     hx711_update_keep_alarm

                MOVS    R1, #0
                STR     R1, [R0]

                BL      HX711_ReadRaw
                CMP     R1, #0
                BEQ     hx711_no_new_reading

                LDR     R1, =hx711_tared
                LDRB    R2, [R1]
                CMP     R2, #0
                BNE     hx711_have_tare

                LDR     R2, =hx711_baseline
                STR     R0, [R2]
                MOVS    R2, #1
                STRB    R2, [R1]
                B       hx711_buzzer_off

hx711_have_tare
                LDR     R2, =hx711_baseline
                LDR     R2, [R2]
                SUBS    R2, R0, R2
                CMP     R2, #0
                BGE     hx711_delta_ready
                NEGS    R2, R2

hx711_delta_ready
                LDR     R3, =HX711_THRESHOLD
                CMP     R2, R3
                BGT     hx711_buzzer_on

hx711_buzzer_off
                LDR     R0, =hx711_alarm
                MOVS    R1, #0
                STRB    R1, [R0]
                POP     {R0-R4, PC}

hx711_buzzer_on
                LDR     R0, =hx711_alarm
                MOVS    R1, #1
                STRB    R1, [R0]
                BL      Buzzer_On
                POP     {R0-R4, PC}

hx711_no_new_reading
                LDR     R0, =hx711_alarm
                LDRB    R1, [R0]
                CMP     R1, #0
                BEQ     hx711_no_new_off
                BL      Buzzer_On
                POP     {R0-R4, PC}

hx711_no_new_off
                POP     {R0-R4, PC}

hx711_update_keep_alarm
                STR     R1, [R0]
                LDR     R0, =hx711_alarm
                LDRB    R1, [R0]
                CMP     R1, #0
                BEQ     hx711_keep_off
                BL      Buzzer_On
                POP     {R0-R4, PC}

hx711_keep_off
                POP     {R0-R4, PC}

HX711_IsOverweight
                LDR     R0, =hx711_alarm
                LDRB    R0, [R0]
                BX      LR

overweight_lockout
                PUSH    {R0-R2, LR}

                BL      stepper_disable

                LDR     R0, =current_pos
                LDR     R1, [R0]
                LDR     R0, =target_pos
                STR     R1, [R0]

                MOVS    R1, #0
                LDR     R0, =direction
                STRB    R1, [R0]

                LDR     R0, =requests
                STR     R1, [R0]

                LDR     R0, =last_key
                MOVS    R1, #0xFF
                STRB    R1, [R0]

                LDR     R0, =last_buttons
                MOVS    R1, #0
                STRB    R1, [R0]

                POP     {R0-R2, PC}

switch_stop_lockout
                PUSH    {R0-R2, LR}

                BL      stepper_disable

                LDR     R0, =current_pos
                LDR     R1, [R0]
                LDR     R0, =target_pos
                STR     R1, [R0]

                MOVS    R1, #0
                LDR     R0, =direction
                STRB    R1, [R0]

                LDR     R0, =requests
                STR     R1, [R0]

                LDR     R0, =last_key
                MOVS    R1, #0xFF
                STRB    R1, [R0]

                LDR     R0, =last_buttons
                MOVS    R1, #0
                STRB    R1, [R0]

                POP     {R0-R2, PC}

HX711_ReadRaw
                PUSH    {R2-R7, LR}

                LDR     R0, =GPIOC_IDR
                LDR     R1, [R0]
                LDR     R2, =HX711_DOUT_PIN
                TST     R1, R2
                BEQ     hx711_ready

                MOVS    R0, #0
                MOVS    R1, #0
                POP     {R2-R7, PC}

hx711_ready
                MOVS    R3, #0
                MOVS    R4, #24

hx711_bit_loop
                LDR     R0, =GPIOC_BSRR
                LDR     R1, =HX711_SCK_PIN
                STR     R1, [R0]
                BL      HX711_ShortDelay

                LSLS    R3, R3, #1
                LDR     R0, =GPIOC_IDR
                LDR     R1, [R0]
                LDR     R2, =HX711_DOUT_PIN
                TST     R1, R2
                BEQ     hx711_bit_zero
                ORR     R3, R3, #1

hx711_bit_zero
                LDR     R0, =GPIOC_BRR
                LDR     R1, =HX711_SCK_PIN
                STR     R1, [R0]
                BL      HX711_ShortDelay

                SUBS    R4, R4, #1
                BNE     hx711_bit_loop

                ; 25th clock selects channel A, gain 128 for next conversion.
                LDR     R0, =GPIOC_BSRR
                LDR     R1, =HX711_SCK_PIN
                STR     R1, [R0]
                BL      HX711_ShortDelay
                LDR     R0, =GPIOC_BRR
                LDR     R1, =HX711_SCK_PIN
                STR     R1, [R0]
                BL      HX711_ShortDelay

                LSLS    R0, R3, #8
                ASRS    R0, R0, #8
                MOVS    R1, #1
                POP     {R2-R7, PC}

HX711_ShortDelay
                PUSH    {R0, LR}
                MOVS    R0, #30

hx711_delay_loop
                SUBS    R0, R0, #1
                BNE     hx711_delay_loop
                POP     {R0, PC}

                LTORG

any_requests_pending
                LDR     R1, =requests

                LDRB    R0, [R1, #0]
                CMP     R0, #0
                BNE     arp_yes

                LDRB    R0, [R1, #1]
                CMP     R0, #0
                BNE     arp_yes

                LDRB    R0, [R1, #2]
                CMP     R0, #0
                BNE     arp_yes

                MOVS    R0, #0
                BX      LR

arp_yes
                MOVS    R0, #1
                BX      LR

get_current_floor_index
                PUSH    {R1-R3, LR}

                LDR     R0, =current_pos
                LDR     R0, [R0]
                LDR     R1, =floor_tbl

                LDR     R2, [R1, #0]
                CMP     R0, R2
                BEQ     gcf0

                LDR     R2, [R1, #4]
                CMP     R0, R2
                BEQ     gcf1

                LDR     R2, [R1, #8]
                CMP     R0, R2
                BEQ     gcf2

                MOVS    R0, #0xFF
                POP     {R1-R3, LR}
                BX      LR

gcf0
                MOVS    R0, #0
                POP     {R1-R3, LR}
                BX      LR

gcf1
                MOVS    R0, #1
                POP     {R1-R3, LR}
                BX      LR

gcf2
                MOVS    R0, #2
                POP     {R1-R3, LR}
                BX      LR

                LTORG

stepper_enable
                LDR     R0, =GPIOA_BRR
                MOVS    R1, #(1<<2)
                STR     R1, [R0]
                BX      LR

stepper_disable
                LDR     R0, =GPIOA_BSRR
                MOVS    R1, #(1<<2)
                STR     R1, [R0]
                BX      LR

; flipped so floor 0 is bottom
stepper_dir_up
                LDR     R0, =GPIOA_BSRR
                MOVS    R1, #(1<<1)
                STR     R1, [R0]
                BX      LR

stepper_dir_down
                LDR     R0, =GPIOA_BRR
                MOVS    R1, #(1<<1)
                STR     R1, [R0]
                BX      LR

stepper_pulse_working
                PUSH    {R0-R2, LR}

                LDR     R0, =GPIOA_BSRR
                MOVS    R1, #(1<<0)
                STR     R1, [R0]
                BL      pulse_delay

                LDR     R0, =GPIOA_BRR
                MOVS    R1, #(1<<0)
                STR     R1, [R0]
                BL      pulse_delay

                POP     {R0-R2, LR}
                BX      LR

pulse_delay
                LDR     R2, =10000

pulse_delay_loop
                SUBS    R2, R2, #1
                BNE     pulse_delay_loop
                BX      LR

one_second_pause
                PUSH    {R4, LR}
                LDR     R4, =100

osp_loop
                BL      pulse_delay
                SUBS    R4, R4, #1
                BNE     osp_loop

                POP     {R4, LR}
                BX      LR

                LTORG

keypad_scan_nonblocking
                PUSH    {R1-R7, LR}
                LDR     R7, =keymap
                MOVS    R2, #0

ks_row_loop
                CMP     R2, #4
                BGE     ks_none

                LDR     R0, =GPIOB_ODR
                LDR     R1, [R0]
                LDR     R3, =0xF000
                ORR     R1, R1, R3
                STR     R1, [R0]

                MOVS    R3, #1
                LSLS    R3, R3, #12
                LSL     R3, R3, R2
                LDR     R1, [R0]
                BIC     R1, R1, R3
                STR     R1, [R0]

                BL      short_delay

                LDR     R0, =GPIOB_IDR
                LDR     R4, [R0]
                LSRS    R4, R4, #8
                AND     R4, R4, #0x0F

                MOVS    R5, #0

ks_col_loop
                CMP     R5, #4
                BGE     ks_next_row

                MOVS    R6, #1
                LSL     R6, R6, R5
                TST     R4, R6
                BNE     ks_next_col

                LDR     R0, =GPIOB_ODR
                LDR     R1, [R0]
                LDR     R3, =0xF000
                ORR     R1, R1, R3
                STR     R1, [R0]

                MOV     R0, R2
                LSLS    R0, R0, #2
                ADDS    R0, R0, R5
                LDRB    R0, [R7, R0]

                POP     {R1-R7, LR}
                BX      LR

ks_next_col
                ADDS    R5, R5, #1
                B       ks_col_loop

ks_next_row
                ADDS    R2, R2, #1
                B       ks_row_loop

ks_none
                LDR     R0, =GPIOB_ODR
                LDR     R1, [R0]
                LDR     R3, =0xF000
                ORR     R1, R1, R3
                STR     R1, [R0]

                MOVS    R0, #0xFF
                POP     {R1-R7, LR}
                BX      LR

short_delay
                LDR     R5, =3000

sd_loop
                SUBS    R5, R5, #1
                BNE     sd_loop
                BX      LR

                LTORG

LCD_GPIO_Init
                PUSH    {R0-R2, LR}

                LDR     R0, =RCC_APB2ENR
                LDR     R1, [R0]
                ORR     R1, R1, #0x08
                STR     R1, [R0]

                LDR     R0, =GPIOB_CRL
                LDR     R1, [R0]
                LDR     R2, =0x00FFFFFF
                AND     R1, R1, R2
                LDR     R2, =0x77000000
                ORR     R1, R1, R2
                STR     R1, [R0]

                LDR     R0, =GPIOB_BSRR
                MOV     R1, #(SCL_PIN + SDA_PIN)
                STR     R1, [R0]

                POP     {R0-R2, PC}

LCD_Init
                PUSH    {R0-R1, LR}

                BL      LCD_GPIO_Init
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

                MOV     R0, #0x20
                MOV     R1, #0
                BL      LCD_SendNibble
                BL      Delay_Long

                MOV     R0, #0x28
                MOV     R1, #0
                BL      LCD_SendByte

                MOV     R0, #0x0C
                MOV     R1, #0
                BL      LCD_SendByte

                BL      LCD_Clear

                MOV     R0, #0x06
                MOV     R1, #0
                BL      LCD_SendByte

                MOV     R0, #0x80
                MOV     R1, #0
                BL      LCD_SendByte

                POP     {R0-R1, PC}

                LTORG

LCD_Clear
                PUSH    {R0-R1, LR}

                MOV     R0, #0x01
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

                LTORG

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

                ORR     R3, R2, #LCD_EN
                MOV     R0, R3
                BL      I2C_WriteByteToLCD
                BL      Delay_Short

                MOV     R0, R2
                BL      I2C_WriteByteToLCD
                BL      Delay_Short

                POP     {R0-R3, PC}

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

                BL      SDA_High
                BL      I2C_Delay
                BL      SCL_High
                BL      I2C_Delay
                BL      SCL_Low

                POP     {R1-R3, PC}

                LTORG

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
	
                AREA    MYCONST, DATA, READONLY

keymap          DCB     '1','2','3','A'
                DCB     '4','5','6','B'
                DCB     '7','8','9','C'
                DCB     '*','0','#','D'
; ======================================================================
; LCD STRING HELPERS
; ======================================================================
				AREA    RFID_CODE, CODE, READONLY   ; <--- ADD THIS LINE
                ALIGN                               ; <--- ADD THIS LINE
LCD_PrintString_Clear
                PUSH    {R4, LR}
                MOV     R4, R0          ; Save string pointer safely
                BL      LCD_Clear
                MOV     R0, R4          ; Restore string pointer
                BL      LCD_PrintString
                POP     {R4, PC}

LCD_PrintString
                PUSH    {R0-R2, LR}
                MOV     R2, R0
lps_loop
                LDRB    R0, [R2], #1
                CMP     R0, #0
                BEQ     lps_done
                MOV     R1, #LCD_RS     ; Send as Data
                BL      LCD_SendByte
                B       lps_loop
lps_done
                POP     {R0-R2, PC}

                LTORG
msg_granted     DCB     "Access Granted!", 0
msg_denied      DCB     "Access Denied! ", 0
msg_timeout		DCB     "Timeout....    ", 0
                ALIGN

; ======================================================================
; RC522 RFID DRIVER (BIT-BANGED)
; Pins: PB1(CS), PB4(RST), PB5(MOSI), PA3(SCK), PA4(MISO)
; ======================================================================
				AREA    RFID_SPI, CODE, READONLY    ; <--- ADD THIS LINE
                ALIGN                               ; <--- ADD THIS LINE
RC522_Init
                PUSH    {R0-R2, LR}
                LDR     R0, =GPIOB_CRL
                LDR     R1, [R0]
                LDR     R2, =0x00FF00F0
                BIC     R1, R1, R2
                LDR     R2, =0x00220020
                ORR     R1, R1, R2
                STR     R1, [R0]

                LDR     R0, =GPIOA_CRL
                LDR     R1, [R0]
                LDR     R2, =0x000FF000
                BIC     R1, R1, R2
                LDR     R2, =0x00042000
                ORR     R1, R1, R2
                STR     R1, [R0]

                LDR     R0, =GPIOB_BRR
                MOV     R1, #(1<<4)
                STR     R1, [R0]
                BL      Delay_RFID
                LDR     R0, =GPIOB_BSRR
                STR     R1, [R0]
                BL      Delay_RFID

                MOV     R0, #0x01
                MOV     R1, #0x0F
                BL      RC522_WriteReg
                BL      Delay_RFID

                MOV     R0, #0x2A
                MOV     R1, #0x8D
                BL      RC522_WriteReg
                MOV     R0, #0x2B
                MOV     R1, #0x3E
                BL      RC522_WriteReg
                MOV     R0, #0x2C
                MOV     R1, #0x00
                BL      RC522_WriteReg
                MOV     R0, #0x15
                MOV     R1, #0x40
                BL      RC522_WriteReg
                MOV     R0, #0x11
                MOV     R1, #0x3D
                BL      RC522_WriteReg
                MOV     R0, #0x26
                MOV     R1, #0x70
                BL      RC522_WriteReg

                MOV     R0, #0x14
                BL      RC522_ReadReg
                ORR     R1, R0, #0x03
                MOV     R0, #0x14
                BL      RC522_WriteReg
                POP     {R0-R2, PC}

RC522_ScanCard
                PUSH    {R1-R4, LR}
                MOV     R0, #0x01
                MOV     R1, #0x00
                BL      RC522_WriteReg
                MOV     R0, #0x06
                MOV     R1, #0x00
                BL      RC522_WriteReg
                MOV     R0, #0x0A
                MOV     R1, #0x80
                BL      RC522_WriteReg

                MOV     R0, #0x0D
                MOV     R1, #0x07
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

                BL      Delay_RFID

                MOV     R0, #0x0A
                BL      RC522_ReadReg
                CMP     R0, #0
                BEQ     rsc_no_card

                MOV     R0, #0x01
                MOV     R1, #0x00
                BL      RC522_WriteReg
                MOV     R0, #1
                POP     {R1-R4, PC}

rsc_no_card
                MOV     R0, #0x01
                MOV     R1, #0x00
                BL      RC522_WriteReg
                MOV     R0, #0
                POP     {R1-R4, PC}

Delay_RFID
                PUSH    {R0, LR}
                LDR     R0, =60000
delay_rfid_loop
                SUBS    R0, R0, #1
                BNE     delay_rfid_loop
                POP     {R0, PC}

RC522_WriteReg
                PUSH    {R0, R1, LR}
                LSL     R0, R0, #1
                AND     R0, R0, #0x7E
                PUSH    {R1}
                BL      SPI_Start
                BL      SPI_SendByte
                POP     {R0}
                BL      SPI_SendByte
                BL      SPI_End
                POP     {R0, R1, PC}

RC522_ReadReg
                PUSH    {R1, LR}
                LSL     R0, R0, #1
                AND     R0, R0, #0x7E
                ORR     R0, R0, #0x80
                BL      SPI_Start
                BL      SPI_SendByte
                MOVS    R0, #0x00
                BL      SPI_ReadByte
                PUSH    {R0}
                BL      SPI_End
                POP     {R0}
                POP     {R1, PC}

SPI_Start
                PUSH    {R0-R1, LR}
                LDR     R0, =GPIOB_BRR
                MOV     R1, #(1<<1)
                STR     R1, [R0]
                POP     {R0-R1, PC}

SPI_End
                PUSH    {R0-R1, LR}
                LDR     R0, =GPIOB_BSRR
                MOV     R1, #(1<<1)
                STR     R1, [R0]
                POP     {R0-R1, PC}

SPI_SendByte
                PUSH    {R4-R6, LR}
                MOV     R4, R0
                MOV     R5, #8
spi_send_loop
                LDR     R0, =GPIOA_BRR
                MOV     R1, #(1<<3)
                STR     R1, [R0]

                TST     R4, #0x80
                BEQ     spi_mosi_low
                LDR     R0, =GPIOB_BSRR
                B       spi_mosi_set
spi_mosi_low
                LDR     R0, =GPIOB_BRR
spi_mosi_set
                MOV     R1, #(1<<5)
                STR     R1, [R0]

                LDR     R0, =GPIOA_BSRR
                MOV     R1, #(1<<3)
                STR     R1, [R0]

                LSL     R4, R4, #1
                SUBS    R5, R5, #1
                BNE     spi_send_loop
                POP     {R4-R6, PC}

SPI_ReadByte
                PUSH    {R4-R6, LR}
                MOV     R4, #0
                MOV     R5, #8
spi_read_loop
                LDR     R0, =GPIOA_BRR
                MOV     R1, #(1<<3)
                STR     R1, [R0]

                LDR     R0, =GPIOA_BSRR
                MOV     R1, #(1<<3)
                STR     R1, [R0]

                LSL     R4, R4, #1
                LDR     R0, =GPIOA_IDR
                LDR     R1, [R0]
                TST     R1, #(1<<4)
                BEQ     spi_read_next
                ORR     R4, R4, #1
spi_read_next
                SUBS    R5, R5, #1
                BNE     spi_read_loop
                MOV     R0, R4
                POP     {R4-R6, PC}
                END
