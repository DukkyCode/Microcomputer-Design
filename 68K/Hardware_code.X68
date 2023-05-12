*-----------------------------------------------------------
* Title      : Main Program
* Written by : Duc Anh Nguyen
* Date       : 4.9.2022
* Description: Monitor Program for the 68k Microcontroller 
*-----------------------------------------------------------
               
*=======================================================================
*ASCII Control Characters
SPACE           EQU         $20
BS              EQU         $08
CR              EQU         $0D
LF              EQU         $0A
*=======================================================================
*Stack Pointer
STACK	        EQU	        $013000	                        ; Stack Pointer, must point to RAM (grows down)
OUTPUT          EQU         $016500
INPUT           EQU         $016000
SRECSTART       EQU         $015500
SRECADDR        EQU         $015000

*********************************
* 68681 Duart Register Addresses
DUART           EQU         $020000       * Base Addr of DUART
; DUART sub-addresses
MRA	            EQU	        $1	; Mode Register A	(if Reading)
SRA	            EQU	        $3	; Status Register A	(if Reading)
CSRA	        EQU	        $3	; Clock Select Register A	(if Writing)
CRA	            EQU	        $5	; Command Register A	(if Writing)
HRA	            EQU	        $7	; Holding Register A (Rx if Read, Tx if Write)
ACR	            EQU	        $9	; Auxiliary Control Register (if Writing)
; Other DUART definitions
MRA_rst	        EQU	        $10	; Reset MRA pointer to MR1A
RxA_rst	        EQU	        $20	; Software reset RxA
TxA_rst	        EQU	        $30	; Software reset TxA
CR_Enabl	    EQU	        $05	; Tx/Rx Enable
ACR_BAUD	    EQU	        $80	; Use 2nd baud rate table (for speed 19.2k)
CSR_BAUD	    EQU	        $CC	; Baud rate value = 19,200
MR1_Set	        EQU	        $13	; 8-bits, no parity, 1 stop bit
MR2_Norm	    EQU	        $07	; Normal mode, CTS/RTS disabled, stop bit length = 1
MR2_Echo	    EQU	        $47	; Auto-echo, CTS/RTS disabled, stop bit length = 1

Rx_ready	    EQU	        $0	; Recieve ready bit position
Tx_ready	    EQU	        $2	; Transmit ready bit position

*=======================================================================
*Set Stack Counter and Initial Program Counter                                                                               
*Starting of Monitor Program
                ORG         $00000
                DC.L        STACK                           ;Set up Stack
                DC.L        initDuart                       ;Set up PC
                
*Function Pointer                        
COMMAND_ADDRESS:
                DC.L        MENU
                DC.L        HELP            
                DC.L        RM 
                DC.L        WM
                DC.L        RR
                DC.L        WR
                DC.L        LS
                DC.L        RS

                ORG         $001F00                               
initDuart:
                LEA	        DUART, A6	; Put DUART address into A0
                ; Software_Reset
	            MOVE.B	    #MRA_rst, CRA(A6)	; Reset MRA pointer
	            MOVE.B	    #RxA_rst, CRA(A6)	; Reset RxA
	            MOVE.B	    #TxA_rst, CRA(A6)	; Reset TxA
                ; Initialization
	            MOVE.B	#ACR_BAUD,  ACR(A6)	; Selects baud rate set 2
	            MOVE.B	#CSR_BAUD, CSRA(A6)	; Set 19.2k baud Rx/Tx
	            MOVE.B	#MR1_Set,   MRA(A6)	; 8-bits, no parity, 1 stop bit
                ; MR2_Echo for auto-echo, swap for MR2_Norm to run normally
	            MOVE.B	#MR2_Norm, MRA(A6)	; Set Duart to normal mode
	            MOVE.B	#CR_Enabl, CRA(A6)	; Enable both Tx and Rx on channel A
                
                MOVE.L      A0, -(SP)                            ;Pushing A0 to the Stack
                
                MOVEA       #MONITOR, A0                         ;Print out menu
                BSR         OUTCHAR    
 
                MOVEA       #NEWLINE, A0                         ;Print new Line
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                            ;Popping A0 from the stack

*=======================================================================
*A0: Input Buffer
*A1: Output Buffer
*Main program
MAIN:            
                MOVE.L      #$010000, A0
                                               
                MOVE.L      A0, -(SP)                            ;Pushing A0 to the Stack

SPACE_LOOP0:                
                MOVE.B      #SPACE, (A0)+
                ADDI.B      #$01, D2
                CMPI.B      #$16, D2
                BNE         SPACE_LOOP0              

                MOVE.L      (SP)+, A0                            ;Popping A0 from the stack 

                MOVE.L      #$00, D2                             ;Reset D2

                MOVE.L      A4, -(SP)                            ;Push A4               
                
                LEA         OUTPUT, A4
SPACE_LOOP4:    
                MOVE.B      #SPACE, (A4)+
                ADDI.B      #$01, D2
                CMPI.B      #$24, D2
                BNE         SPACE_LOOP4

                MOVE.L      (SP)+, A4                            ;Pop A4     

                MOVE.L      #$00, D2
                               
                MOVE.L      A0, -(SP)                            ;Pushing A0 to the Stack
                
                MOVEA       #NEWLINE, A0                         ;Print new Line
                BSR         OUTCHAR
                    
                MOVEA       #PROMPT, A0                          ;Main Prompt
                BSR         OUTCHAR
                
                MOVE.L      (SP)+, A0                            ;Popping A1 from the stack
               
                BSR         INCHAR                               ;Getting input from the user

                MOVE.L      A2, -(SP)
                MOVE.L      A3, -(SP)                     
                       
                LEA         COMMAND_LIST, A2                     ;Load command table into A2
                LEA         COMMAND_ADDRESS, A3                  ;Load command address into A3              

*=======================================================================
*Input Handler
INPUT_HANDLER:

LOOP:
                CMPM.B       (A0)+, (A2)+
                BNE          POP
                
                CMPI.B       #SPACE, (A0)
                BNE          LOOP

                CMPI.B       #SPACE, (A2)
                BNE          ARGUMENT_ERROR
                               
                MOVE.L      (A3), A5
                
                MOVE.L      (SP)+, A3
                MOVE.L      (SP)+, A2
                
                JMP         (A5) 
                                                                                                                                                         
POP:
                MOVE.L      #$010000, A0                           ;Pop A0

FIND_NEXT:
                CMPI.B      #$00, (A2)+                         ;Find the next character in the list
                BNE         FIND_NEXT
                ADD         #$04, A3                            ;Find the location of the next command                
                CMPA        #MENU_HELP, A2                      ;Hardcode the end of your program
                BGT         ARGUMENT_ERROR                      ;If reach the argument length
                
                JMP         INPUT_HANDLER

*=======================================================================
*Argument Handler
GET_ARG:
                ADD         #$01, A0
                CMPI.B      #$24, (A0)
                BNE         ARGUMENT_ERROR
                MOVEQ       #$00, D7
                MOVEQ       #$00, D6
ADD_ARG:
                ADD         #$01, A0
                ROL.L       #4, D7
                ADD.L       D6, D7
                MOVE.B      (A0)+, D6
                CMPI.B      #$39, D6
                BLE         NUM
                SUBQ.B      #$07,D6

NUM:
                SUB.B       #$30, D6
                CMPI.B      #$00, -(A0)
                BEQ         GOT_ARG
                CMPI.B      #SPACE, (A0)
                BEQ         GOT_ARG
                CMPI.B      #$3B, (A0)
                BEQ         GOT_ARG
                BRA         ADD_ARG
                
GOT_ARG:
                RTS

*======================================================================
*======================================================================
*Subfunction of the main program                               
*Menu Sub-function
MENU:
                MOVE.L      A0, -(SP)                           ;Pushing A0 to the Stack               
                
                MOVEA       #MENU_LIST,A0                       ;Print Menu List
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                          ;Popping A0 to the Stack
                
                JMP         MAIN
                
*Help Sub-function
HELP:
                MOVE.L      A0, -(SP)                           ;Pushing A0 to the Stack               
              
                MOVEA       #MENU_HELP,A0                       ;Print Menu Help
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                           ;Popping A0 to the Stack
                
                JMP         MAIN


*======================================================================
*Read from Memory Sub-fucntion
RM:
                JSR         GET_ARG
                                
                MOVEQ       #$00, D1
                MOVE.L      #$010000, A0                        ;Reset A0
                
                MOVE.L      A0, -(SP)                           ;Pushing A0 to the Stack               
              
                MOVEA       #CONTENTS,A0                       ;Print Output
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                           ;Popping A0 to the Stack

                
                MOVE.L      D7, A0
                
                JSR         OUTHEX                              ;Print 1st byte
                
                ADD         #$01, A0                            ;Print 2nd byte                
                JSR         OUTHEX
                
                ADD         #$01, A0                            ;Print 3rd byte                
                JSR         OUTHEX
                
                ADD         #$01, A0                            ;Print 4 byte                
                JSR         OUTHEX
                                          
                MOVE.L      #$00, A0
                
                MOVE.L      A0, -(SP)                           ;Pushing A0 to the Stack               
              
                MOVEA       #NEWLINE,A0                         ;Print Output
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                           ;Popping A0 to the Stack
                             
                JMP         MAIN
                                                            
*======================================================================                
*Write from Memory Sub-fucntion
WM:                  
                JSR         GET_ARG
                
                MOVE.L      A1, -(SP)
                MOVE.L      A2, -(SP)
                
                LEA         INPUT, A2
                
                MOVE.L      D7, (A2)
                                
                JSR         GET_ARG
                
                MOVE.L      D7, A1
                
                MOVE.L      (A2), (A1)
                                          
                MOVEA       #OUTPUT_WM ,A0                      ;Print Output
                BSR         OUTCHAR

                MOVEA       #NEWLINE,A0                         ;Print New Line
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A2
                MOVE.L      (SP)+, A1
         
                JMP         MAIN

*======================================================================
*Read from Register Sub-fucntion
RR:
                ADD         #$01, A0                            ;Reset Addresss Register  
REGISTER_CHECK:                
                CMPI.B      #$41, (A0)
                BEQ         RR_A
                CMPI.B      #$44, (A0)
                BEQ         RR_D
                BRA         ARGUMENT_ERROR
               
RR_A:
                *Condition Checking
                ADD         #$01, A0
                CMPI.B      #$30, (A0)
                BLT         ARGUMENT_ERROR
                CMPI.B      #$37, (A0)
                BGT         ARGUMENT_ERROR
                
                *Address Register Checking
                CMPI.B      #$30, (A0)
                BEQ         READA0
                
                CMPI.B      #$31, (A0)
                BEQ         READA1
                
                CMPI.B      #$32, (A0)
                BEQ         READA2
                
                CMPI.B      #$33, (A0)
                BEQ         READA3
                
                CMPI.B      #$34, (A0)
                BEQ         READA4
                
                CMPI.B      #$35, (A0)
                BEQ         READA5
                
                CMPI.B      #$36, (A0)
                BEQ         READA6
                
                CMPI.B      #$37, (A0)
                BEQ         READA7
                
                JMP         MAIN                                 

RR_D:
                *Condition Checking
                ADD         #$01, A0
                CMPI.B      #$30, (A0)
                BLT         ARGUMENT_ERROR
                CMPI.B      #$37, (A0)
                BGT         ARGUMENT_ERROR
                
                *Data Register Checking               
                CMPI.B      #$30, (A0)
                BEQ         READD0
                
                CMPI.B      #$31, (A0)
                BEQ         READD1
                
                CMPI.B      #$32, (A0)
                BEQ         READD2
                
                CMPI.B      #$33, (A0)
                BEQ         READD3
                
                CMPI.B      #$34, (A0)
                BEQ         READD4
                
                CMPI.B      #$35, (A0)
                BEQ         READD5
                
                CMPI.B      #$36, (A0)
                BEQ         READD6
                
                CMPI.B      #$37, (A0)
                BEQ         READD7
                                      
*======================================================================
*Read from Register function
READD0:
                MOVE.L      D0, -(SP)                   ;Push D0
                
                LEA         INPUT, A2
                MOVE.L      #$010000, A0                 ;Reset A0
                
                MOVE.L      A0, -(SP)                   ;Pushing A0 to the Stack               
              
                MOVEA       #CONTENTS,A0                ;Print Output
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                   ;Popping A0 to the Stack
                

                MOVE.L      D0, (A2)                   
                
                MOVE.B      (A2)+, (A0)                 ;1st Byte                              
                JSR         OUTHEX

                MOVE.B      (A2)+, (A0)                 ;2nd Byte                              
                JSR         OUTHEX
                
                MOVE.B      (A2)+, (A0)                 ;3rd Byte                              
                JSR         OUTHEX
                
                MOVE.B      (A2), (A0)                  ;1st Byte                              
                JSR         OUTHEX
                         
                MOVE.L      (SP)+, D0                   ;Pop D0
                
                MOVE.L      A0, -(SP)                   ;Pushing A0 to the Stack               
              
                MOVEA       #NEWLINE,A0                 ;Print Output
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                   ;Popping A0 to the Stack


                JMP         MAIN

READD1:
                MOVE.L      D1, -(SP)                   ;Push D0
                
                LEA         INPUT, A2
                MOVE.L      #$010000, A0                    ;Reset A0
                
                MOVE.L      A0, -(SP)                   ;Pushing A0 to the Stack               
              
                MOVEA       #CONTENTS,A0                ;Print Output
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                   ;Popping A0 to the Stack
                

                MOVE.L      D1, (A2)                   
                
                MOVE.B      (A2)+, (A0)                 ;1st Byte                              
                JSR         OUTHEX

                MOVE.B      (A2)+, (A0)                 ;2nd Byte                              
                JSR         OUTHEX
                
                MOVE.B      (A2)+, (A0)                 ;3rd Byte                              
                JSR         OUTHEX
                
                MOVE.B      (A2), (A0)                  ;1st Byte                              
                JSR         OUTHEX
                         
                MOVE.L      (SP)+, D1                   ;Pop D0

                MOVE.L      A0, -(SP)                   ;Pushing A0 to the Stack               
              
                MOVEA       #NEWLINE,A0                 ;Print Output
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                   ;Popping A0 to the Stack

                
                JMP         MAIN

READD2:
                MOVE.L      D2, -(SP)                   ;Push D0
                
                LEA         INPUT, A2
                MOVE.L      #$010000, A0                    ;Reset A0
                
                MOVE.L      A0, -(SP)                   ;Pushing A0 to the Stack               
              
                MOVEA       #CONTENTS,A0                ;Print Output
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                   ;Popping A0 to the Stack
                

                MOVE.L      D2, (A2)                   
                
                MOVE.B      (A2)+, (A0)                 ;1st Byte                              
                JSR         OUTHEX

                MOVE.B      (A2)+, (A0)                 ;2nd Byte                              
                JSR         OUTHEX
                
                MOVE.B      (A2)+, (A0)                 ;3rd Byte                              
                JSR         OUTHEX
                
                MOVE.B      (A2), (A0)                  ;1st Byte                              
                JSR         OUTHEX
                         
                MOVE.L      (SP)+, D2                   ;Pop D0
                
                MOVE.L      A0, -(SP)                   ;Pushing A0 to the Stack               
              
                MOVEA       #NEWLINE,A0                 ;Print Output
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                   ;Popping A0 to the Stack
                                               
                JMP         MAIN

READD3:
                MOVE.L      D3, -(SP)                   ;Push D0
                
                LEA         INPUT, A2
                MOVE.L      #$010000, A0                    ;Reset A0
                
                MOVE.L      A0, -(SP)                   ;Pushing A0 to the Stack               
              
                MOVEA       #CONTENTS,A0                ;Print Output
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                   ;Popping A0 to the Stack
                

                MOVE.L      D3, (A2)                   
                
                MOVE.B      (A2)+, (A0)                 ;1st Byte                              
                JSR         OUTHEX

                MOVE.B      (A2)+, (A0)                 ;2nd Byte                              
                JSR         OUTHEX
                
                MOVE.B      (A2)+, (A0)                 ;3rd Byte                              
                JSR         OUTHEX
                
                MOVE.B      (A2), (A0)                  ;1st Byte                              
                JSR         OUTHEX
                         
                MOVE.L      (SP)+, D3                   ;Pop D0
                
                MOVE.L      A0, -(SP)                   ;Pushing A0 to the Stack               
              
                MOVEA       #NEWLINE,A0                 ;Print Output
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                   ;Popping A0 to the Stack
                
                JMP         MAIN

READD4:
                MOVE.L      D4, -(SP)                   ;Push D0
                
                LEA         INPUT, A2
                MOVE.L      #$010000, A0                    ;Reset A0
                
                MOVE.L      A0, -(SP)                   ;Pushing A0 to the Stack               
              
                MOVEA       #CONTENTS,A0                ;Print Output
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                   ;Popping A0 to the Stack
                

                MOVE.L      D4, (A2)                   
                
                MOVE.B      (A2)+, (A0)                 ;1st Byte                              
                JSR         OUTHEX

                MOVE.B      (A2)+, (A0)                 ;2nd Byte                              
                JSR         OUTHEX
                
                MOVE.B      (A2)+, (A0)                 ;3rd Byte                              
                JSR         OUTHEX
                
                MOVE.B      (A2), (A0)                  ;1st Byte                              
                JSR         OUTHEX
                         
                MOVE.L      (SP)+, D4                   ;Pop D0
                
                MOVE.L      A0, -(SP)                   ;Pushing A0 to the Stack               
              
                MOVEA       #NEWLINE,A0                 ;Print Output
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                   ;Popping A0 to the Stack

                
                
                JMP         MAIN

READD5:
                MOVE.L      D5, -(SP)                   ;Push D0
                
                LEA         INPUT, A2
                MOVE.L      #$010000, A0                    ;Reset A0
                
                MOVE.L      A0, -(SP)                   ;Pushing A0 to the Stack               
              
                MOVEA       #CONTENTS,A0                ;Print Output
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                   ;Popping A0 to the Stack
                

                MOVE.L      D5, (A2)                   
                
                MOVE.B      (A2)+, (A0)                 ;1st Byte                              
                JSR         OUTHEX

                MOVE.B      (A2)+, (A0)                 ;2nd Byte                              
                JSR         OUTHEX
                
                MOVE.B      (A2)+, (A0)                 ;3rd Byte                              
                JSR         OUTHEX
                
                MOVE.B      (A2), (A0)                  ;1st Byte                              
                JSR         OUTHEX
                         
                MOVE.L      (SP)+, D5                   ;Pop D0
                
                MOVE.L      A0, -(SP)                   ;Pushing A0 to the Stack               
              
                MOVEA       #NEWLINE,A0                 ;Print Output
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                    ;Popping A0 to the Stack

                
                JMP         MAIN

READD6:
                MOVE.L      D6, -(SP)                   ;Push D0
                
                LEA         INPUT, A2
                MOVE.L      #$010000, A0                    ;Reset A0
                
                MOVE.L      A0, -(SP)                   ;Pushing A0 to the Stack               
              
                MOVEA       #CONTENTS,A0                ;Print Output
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                   ;Popping A0 to the Stack
                

                MOVE.L      D6, (A2)                   
                
                MOVE.B      (A2)+, (A0)                 ;1st Byte                              
                JSR         OUTHEX

                MOVE.B      (A2)+, (A0)                 ;2nd Byte                              
                JSR         OUTHEX
                
                MOVE.B      (A2)+, (A0)                 ;3rd Byte                              
                JSR         OUTHEX
                
                MOVE.B      (A2), (A0)                  ;1st Byte                              
                JSR         OUTHEX
                         
                MOVE.L      (SP)+, D6                   ;Pop D0
                
                MOVE.L      A0, -(SP)                   ;Pushing A0 to the Stack               
              
                MOVEA       #NEWLINE,A0                 ;Print Output
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                   ;Popping A0 to the Stack

                
                JMP         MAIN

READD7:
                MOVE.L      D7, -(SP)                   ;Push D0
                
                LEA         INPUT, A2
                MOVE.L      #$010000, A0                    ;Reset A0
                
                MOVE.L      A0, -(SP)                   ;Pushing A0 to the Stack               
              
                MOVEA       #CONTENTS,A0                ;Print Output
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                   ;Popping A0 to the Stack
                

                MOVE.L      D7, (A2)                   
                
                MOVE.B      (A2)+, (A0)                 ;1st Byte                              
                JSR         OUTHEX

                MOVE.B      (A2)+, (A0)                 ;2nd Byte                              
                JSR         OUTHEX
                
                MOVE.B      (A2)+, (A0)                 ;3rd Byte                              
                JSR         OUTHEX
                
                MOVE.B      (A2), (A0)                  ;1st Byte                              
                JSR         OUTHEX
                         
                MOVE.L      (SP)+, D7                   ;Pop D0
                
                MOVE.L      A0, -(SP)                   ;Pushing A0 to the Stack               
              
                MOVEA       #NEWLINE,A0                 ;Print Output
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                   ;Popping A0 to the Stack

                JMP         MAIN

READA0:
                MOVE.L      A0, -(SP)
                
                MOVEA       #CONTENTS,A0                ;Print Output
                BSR         OUTCHAR 
                
                MOVE.L      (SP)+, A0
                
                MOVE.L      A0, -(SP)
                
                MOVE.L      A0, $010300
                
                MOVE.B      $010300, (A0)                 ;1st Byte                              
                JSR         OUTHEX

                MOVE.B      $010301, (A0)                 ;2nd Byte                              
                JSR         OUTHEX
                
                MOVE.B      $10302, (A0)                 ;3rd Byte                              
                JSR         OUTHEX
                
                MOVE.B      $10303, (A0)                  ;1st Byte                              
                JSR         OUTHEX
                         
                MOVE.L      (SP)+, A0                   ;Pop D0
                
                MOVE.L      A0, -(SP)                   ;Pushing A0 to the Stack               
              
                MOVEA       #NEWLINE,A0                 ;Print Output
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                   ;Popping A0 to the Stack
               
                JMP         MAIN

READA1:
                MOVE.L      A0, -(SP)
                
                MOVEA       #CONTENTS,A0                ;Print Output
                BSR         OUTCHAR 
                
                MOVE.L      (SP)+, A0
                
                MOVE.L      A1, -(SP)
                
                MOVE.L      A1, $010300
                
                MOVE.B      $010300, (A0)                 ;1st Byte                              
                JSR         OUTHEX

                MOVE.B      $010301, (A0)                 ;2nd Byte                              
                JSR         OUTHEX
                
                MOVE.B      $010302, (A0)                 ;3rd Byte                              
                JSR         OUTHEX
                
                MOVE.B      $010303, (A0)                  ;1st Byte                              
                JSR         OUTHEX
                         
                MOVE.L      (SP)+, A1                   ;Pop D0
                
                MOVE.L      A0, -(SP)                   ;Pushing A0 to the Stack               
              
                MOVEA       #NEWLINE,A0                 ;Print Output
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                   ;Popping A0 to the Stack
                               
                JMP         MAIN

READA2:
                MOVE.L      A0, -(SP)
                
                MOVEA       #CONTENTS,A0                ;Print Output
                BSR         OUTCHAR 
                
                MOVE.L      (SP)+, A0
                
                MOVE.L      A2, -(SP)
                                
                MOVE.L      A2, $010300
                
                MOVE.B      $010300, (A0)                 ;1st Byte                              
                JSR         OUTHEX

                MOVE.B      $010301, (A0)                 ;2nd Byte                              
                JSR         OUTHEX
                
                MOVE.B      $010302, (A0)                 ;3rd Byte                              
                JSR         OUTHEX
                
                MOVE.B      $010303, (A0)                  ;1st Byte                              
                JSR         OUTHEX
                         
                MOVE.L      (SP)+, A2                   ;Pop D0
                
                MOVE.L      A0, -(SP)                   ;Pushing A0 to the Stack               
              
                MOVEA       #NEWLINE,A0                 ;Print Output
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                   ;Popping A0 to the Stack
             
                JMP         MAIN

READA3:
                MOVE.L      A0, -(SP)
                
                MOVEA       #CONTENTS,A0                ;Print Output
                BSR         OUTCHAR 
                
                MOVE.L      (SP)+, A0
                
                MOVE.L      A3, -(SP)
                
                MOVE.L      A3, $010300
                
                MOVE.B      $010300, (A0)                 ;1st Byte                              
                JSR         OUTHEX

                MOVE.B      $010301, (A0)                 ;2nd Byte                              
                JSR         OUTHEX
                
                MOVE.B      $010302, (A0)                 ;3rd Byte                              
                JSR         OUTHEX
                
                MOVE.B      $010303, (A0)                  ;1st Byte                              
                JSR         OUTHEX
                         
                MOVE.L      (SP)+, A3                   ;Pop D0
                
                MOVE.L      A0, -(SP)                   ;Pushing A0 to the Stack               
              
                MOVEA       #NEWLINE,A0                 ;Print Output
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                   ;Popping A0 to the Stack

                JMP         MAIN

READA4:
                MOVE.L      A0, -(SP)
                
                MOVEA       #CONTENTS,A0                ;Print Output
                BSR         OUTCHAR 
                
                MOVE.L      (SP)+, A0
                
                MOVE.L      A4, -(SP)
                
                MOVE.L      A4, $010300
                
                MOVE.B      $010300, (A0)                 ;1st Byte                              
                JSR         OUTHEX

                MOVE.B      $010301, (A0)                 ;2nd Byte                              
                JSR         OUTHEX
                
                MOVE.B      $010302, (A0)                 ;3rd Byte                              
                JSR         OUTHEX
                
                MOVE.B      $010303, (A0)                  ;1st Byte                              
                JSR         OUTHEX
                         
                MOVE.L      (SP)+, A4                   ;Pop D0
                
                MOVE.L      A0, -(SP)                   ;Pushing A0 to the Stack               
              
                MOVEA       #NEWLINE,A0                 ;Print Output
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                   ;Popping A0 to the Stack

                JMP         MAIN

READA5:
                MOVE.L      A0, -(SP)
                
                MOVEA       #CONTENTS,A0                ;Print Output
                BSR         OUTCHAR 
                
                MOVE.L      (SP)+, A0
                
                MOVE.L      A5, -(SP)
                
                MOVE.L      A5, $010300
                
                MOVE.B      $010300, (A0)                 ;1st Byte                              
                JSR         OUTHEX

                MOVE.B      $010301, (A0)                 ;2nd Byte                              
                JSR         OUTHEX
                
                MOVE.B      $010302, (A0)                 ;3rd Byte                              
                JSR         OUTHEX
                
                MOVE.B      $010303, (A0)                  ;1st Byte                              
                JSR         OUTHEX
                         
                MOVE.L      (SP)+, A5                   ;Pop D0
                
                MOVE.L      A0, -(SP)                   ;Pushing A0 to the Stack               
              
                MOVEA       #NEWLINE,A0                 ;Print Output
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                   ;Popping A0 to the Stack

                JMP         MAIN

READA6:
                MOVE.L      A0, -(SP)
                
                MOVEA       #CONTENTS,A0                ;Print Output
                BSR         OUTCHAR 
                
                MOVE.L      (SP)+, A0
                
                MOVE.L      A6, -(SP)
                
                MOVE.L      A6, $010300
                
                MOVE.B      $010300, (A0)                 ;1st Byte                              
                JSR         OUTHEX

                MOVE.B      $010301, (A0)                 ;2nd Byte                              
                JSR         OUTHEX
                
                MOVE.B      $010302, (A0)                 ;3rd Byte                              
                JSR         OUTHEX
                
                MOVE.B      $010303, (A0)                  ;1st Byte                              
                JSR         OUTHEX
                         
                MOVE.L      (SP)+, A6                   ;Pop D0
                
                MOVE.L      A0, -(SP)                   ;Pushing A0 to the Stack               
              
                MOVEA       #NEWLINE,A0                 ;Print Output
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                   ;Popping A0 to the Stack
 
                JMP         MAIN

READA7:
                MOVE.L      A0, -(SP)
                
                MOVEA       #CONTENTS,A0                ;Print Output
                BSR         OUTCHAR 
                
                MOVE.L      (SP)+, A0
                
                MOVE.L      A7, -(SP)
                
                MOVE.L      A7, $010300
                
                MOVE.B      $010300, (A0)                 ;1st Byte                              
                JSR         OUTHEX

                MOVE.B      $010301, (A0)                 ;2nd Byte                              
                JSR         OUTHEX
                
                MOVE.B      $010302, (A0)                 ;3rd Byte                              
                JSR         OUTHEX
                
                MOVE.B      $010303, (A0)                  ;1st Byte                              
                JSR         OUTHEX
                         
                MOVE.L      (SP)+, A7                   ;Pop D0
                
                MOVE.L      A0, -(SP)                   ;Pushing A0 to the Stack               
              
                MOVEA       #NEWLINE,A0                 ;Print Output
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                   ;Popping A0 to the Stack

                JMP         MAIN
                           

*======================================================================
*Write to Register Sub-function
WR:
                JSR         GET_ARG
                
                LEA         INPUT, A2
                
                MOVE.L      D7, (A2)
                ADD         #$01, A0

WR_LOOP:                
                CMPI.B      #$41, (A0)
                BEQ         WR_A
                CMPI.B      #$44, (A0)
                BEQ         WR_D
                BRA         ARGUMENT_ERROR

*=======================================
*Address Register                
WR_A:
                *Condition Checking                
                ADD         #$01, A0
                CMPI.B      #$30, (A0)
                BLT         ARGUMENT_ERROR
                CMPI.B      #$37, (A0)
                BGT         ARGUMENT_ERROR
                
                *Address Register Checking
                CMPI.B      #$30, (A0)
                BEQ         WR_ADDR0                
                CMPI.B      #$31, (A0)
                BEQ         WR_ADDR1                
                CMPI.B      #$32, (A0)
                BEQ         WR_ADDR2               
                CMPI.B      #$33, (A0)
                BEQ         WR_ADDR3                
                CMPI.B      #$34, (A0)
                BEQ         WR_ADDR4                
                CMPI.B      #$35, (A0)
                BEQ         WR_ADDR5                
                CMPI.B      #$36, (A0)
                BEQ         WR_ADDR6                
                CMPI.B      #$37, (A0)
                BEQ         WR_ADDR7                

*Write to Addresss                
WR_ADDR0:
                MOVE.L      D7, A0
                JMP         WR_EXIT               
WR_ADDR1:
                MOVE.L      D7, A1
                JMP         WR_EXIT
WR_ADDR2:
                MOVE.L      D7, A2
                JMP         WR_EXIT
WR_ADDR3:
                MOVE.L      D7, A3
                JMP         WR_EXIT
WR_ADDR4:
                MOVE.L      D7, A4
                JMP         WR_EXIT
WR_ADDR5:
                MOVE.L      D7, A5
                JMP         WR_EXIT
WR_ADDR6:
                MOVE.L      D7, A6
                JMP         WR_EXIT
WR_ADDR7:
                MOVE.L      D7, A7
                JMP         WR_EXIT                
*=======================================
*Data Register
WR_D:
                *Condition Checking
                ADD         #$01, A0
                CMPI.B      #$30, (A0)
                BLT         ARGUMENT_ERROR
                CMPI.B      #$37, (A0)
                BGT         ARGUMENT_ERROR
                                
                *Data Register Checking
                CMPI.B      #$30, (A0)
                BEQ         WR_DATA0               
                CMPI.B      #$31, (A0)
                BEQ         WR_DATA1                
                CMPI.B      #$32, (A0)
                BEQ         WR_DATA2                
                CMPI.B      #$33, (A0)
                BEQ         WR_DATA3
                CMPI.B      #$34, (A0)
                BEQ         WR_DATA4                
                CMPI.B      #$35, (A0)
                BEQ         WR_DATA5               
                CMPI.B      #$36, (A0)
                BEQ         WR_DATA6                
                CMPI.B      #$37, (A0)
                BEQ         WR_DATA7

*Write to Data                 
WR_DATA0:
                MOVE.L      D7, D0                                
                JMP         WR_EXIT
WR_DATA1:                
                MOVE.L      D7, D1
                JMP         WR_EXIT
WR_DATA2:                
                MOVE.L      D7, D2
                JMP         WR_EXIT
WR_DATA3:                
                MOVE.L      D7, D3
                JMP         WR_EXIT
WR_DATA4:                
                MOVE.L      D7, D4
                JMP         WR_EXIT
WR_DATA5:                
                MOVE.L      D7, D5
                JMP         WR_EXIT
WR_DATA6:                
                MOVE.L      D7, D6
                JMP         WR_EXIT
WR_DATA7:                
                MOVE.L      D7, D7
                JMP         WR_EXIT                
                
WR_EXIT:
                MOVE.L      A0, -(SP)                           ;Pushing A0 to the Stack               
              
                MOVEA       #OUTPUT_WM ,A0                      ;Print Output
                BSR         OUTCHAR

                MOVEA       #NEWLINE,A0                         ;Print New Line
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                           ;Popping A0 to the Stack
                
                JMP         MAIN

    
*======================================================================
*Load S-Record Sub-function
LS:
                *Condition Check and Setup
                ADD         #$01, A0
                LEA         SRECADDR, A1
                LEA         SRECSTART, A2
                
                MOVEQ       #$00, D2                            ;D2 is Count Byte
                MOVEQ       #$00, D3
                MOVEQ       #$00, D7                            ;D7 is address
                MOVEQ       #$00, D6
               
                
                CMPI.B      #$53, (A0)                          ;Compare to "S"
                BEQ         SVALID             
                BRA         ARGUMENT_ERROR               

SVALID:
                ADD         #$01, A0                            ;Checking the next bytes of A0
                CMPI.B      #$30, (A0)
                BLT         ARGUMENT_ERROR
                CMPI.B      #$39, (A0)
                BGT         ARGUMENT_ERROR
                
                CMPI.B      #$31, (A0)
                BEQ         SCOUNT
                BRA         SRECLIM
                
SCOUNT:                
                JSR         READBYTES 
                MOVE.L      D7, D2                              ;Move S-Record Count to D2
                                                                
SADDR:
                JSR         READBYTES
                MOVE.B      D7, (A1)+
                
                JSR         READBYTES
                MOVE.B      D7, (A1)+
                
                SUB.B       #$02, D2
                    
SDATA:                
                JSR         READBYTES
                MOVE.B      D7, (A2)+
                SUB.B       #$01, D2
                CMPI.B      #$01, D2
                BNE         SDATA
                                     
LS_EXIT:
                MOVE.L      A0, -(SP)                           ;Pushing A0 to the Stack               
              
                MOVEA       #OUTPUT_LS ,A0                      ;Print Output
                BSR         OUTCHAR

                MOVEA       #NEWLINE,A0                         ;Print New Line
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                           ;Popping A0 to the Stack                
                
                JMP         MAIN

SRECLIM:
                MOVE.L      A0, -(SP)                           ;Pushing A0 to the Stack               
                
                MOVEA       #SRECLIM_MSG,A0
                BSR         OUTCHAR

                MOVEA       #NEWLINE,A0                         ;Print New Line
                BSR         OUTCHAR                
                
                MOVE.L      (SP)+, A0                           ;Popping A0 to the Stack

                JMP         MAIN


*======================================================================
*Run S-Record Sub-function
RS:
                JSR         SRECSTART
                
                JMP         MAIN        

*======================================================================
*Read Hex Byte
READBYTES:
                MOVEQ       #$00, D7                            ;D7 is address
                MOVEQ       #$00, D6
                MOVEQ       #$00, D4

READBYTES_LOOP:                
                ADD         #$01, A0

                MOVE.B      (A0), D6
                CMPI.B      #$39, D6
                BLE         READ_NUMBYTES
                SUBQ.B      #$07, D6

READ_NUMBYTES:
                SUB.B       #$30, D6
                ROL.L       #4, D7
                ADD.L       D6, D7
                
                                                               
                ADDI        #$01, D4
                CMPI.B      #$02, D4
                BEQ         GOT_BYTES
                BRA         READBYTES_LOOP        

GOT_BYTES:
                RTS

                 
*======================================================================
*Input character
INCHAR:
                MOVE.L      D1, -(SP)
                MOVE.L      D0, -(SP)

INCHAR_LOOP:                                               
*                MOVE.B      #5, D0
*                TRAP        #15
                BSR         in_Char
                
                CMPI.B      #CR, D1                               ;If input equals to Carriage Return
                BEQ.S       END_INCHAR_LOOP                       ;Exit getting input from Character
                
                CMPI.B      #BS, D1                               ;If input equals to backspace
                BEQ.S       INCHAR_BS                             ;Delete
                                                                                
                MOVE.B      D1, (A0)+                             ;Move Input Byte Value of D1 to A0 then
                                                                  ;increment the address
                BRA         INCHAR_LOOP    

INCHAR_SPACE:
                MOVE.B      #0, -(A0)
                BRA         INCHAR_LOOP

INCHAR_BS:
                MOVE.B      #0, -(A0)
                BRA         INCHAR_LOOP        

END_INCHAR_LOOP:
                MOVE.L      #$010000, A0
                MOVE.L      (SP)+, D0
                MOVE.L      (SP)+, D1
                RTS
                    
*Output Character
OUTCHAR:
                MOVE.L      D1, -(SP)
                MOVE.L      D0, -(SP)
                     
OUTCHAR_LOOP:                
                MOVE.B      (A0)+, D1
                CMPI.B      #0, D1
                BEQ.S       END_OUTCHAR_LOOP                                
*                MOVE.B      #6, D0
*                TRAP        #15
                BSR         out_Char
                BRA         OUTCHAR_LOOP
                                 
END_OUTCHAR_LOOP:
                MOVE.L      (SP)+, D0
                MOVE.L      (SP)+, D1
                RTS
                
*======================================================================                
*Output Address:
OUTADDR:
                MOVE.L      D1, -(SP)
                MOVE.L      D0, -(SP)
                LEA         OUTPUT, A4
                     
OUTADDR_LOOP:                
                MOVE.B      (A4)+, D1
                CMPI.B      #SPACE, D1
                BEQ.S       END_OUTCHAR_LOOP                                
*                MOVE.B      #6, D0
*                TRAP        #15
                BSR         out_Char                                
                BRA         OUTADDR_LOOP
                                 
END_OUTADDR_LOOP:
                MOVE.L      (SP)+, D0
                MOVE.L      (SP)+, D1
                RTS     
*====================================================================== 
* Writes a character to Port A, blocking if not ready (Full buffer)
*  - Takes a character in D0
out_Char:	
                BTST	    #Tx_ready, SRA(A6)	; Check if Tx ready 
	            BEQ	        out_char	; If not then wait
	            MOVE.B	    D1, HRA(A6)	; Put char from D1 into Tx Holding
	            RTS
*****
* Reads in a character from Port A, blocking if none available
*  - Returns character in D0
*    
in_Char:
                BTST	    #Rx_ready, SRA(A6)	                ; Check if Rx has input
	            BEQ	        in_Char	                            ; If not then wait
	            MOVE.B	    HRA(A6), D1
                BSR	        out_Char	                        ; Immediately display on screen	                        
	            RTS		    

*======================================================================                 
*Print Hex Byte
OUTHEX:
                MOVEQ       #$00, D4               
                MOVEQ       #$00, D5
                
                MOVE.B      (A0), D4              
                LSR.B       #$04, D4                ;D4 = Lower Bit
                
                ADD.B       #$30, D4
                CMP.B       #$39, D4
                
                BLE.S       OUTHEX_BYTE2
                ADD.B       #7, D4
                CMP.B       #$46, D4
                BGT         ERROR 
                
OUTHEX_BYTE2:
                MOVE.B      (A0), D5
                LSL.B       #$04, D5                ;D5 = Higher Bits
                ROL.B       #$04, D5
                
                ADD.B       #$30, D5
                CMP.B       #$39, D5
                BLE.S       OUTHEX_NEXT
                ADD.B       #7, D5
                CMP.B       #$46, D5
                BGT         ERROR

OUTHEX_NEXT:                
                LEA         OUTPUT, A4                 
                MOVE.B      D4, (A4)+
                MOVE.B      D5, (A4)
                JSR         OUTADDR                
                                                               
END_OUTHEX:
                RTS
                                             
*======================================================================
*Error Code
ERROR:
                MOVE.L      A0, -(SP)                           ;Pushing A0 to the Stack               
                
                MOVEA       #ERROR_MSG,A0
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                           ;Popping A0 to the Stack

                JMP         MAIN
                
*Error Code
ARGUMENT_ERROR:
                MOVE.L      A0, -(SP)                           ;Pushing A0 to the Stack               
                
                MOVEA       #ARG_ERR_MSG,A0
                BSR         OUTCHAR               
                
                MOVE.L      (SP)+, A0                           ;Popping A0 to the Stack

                JMP         MAIN
                        
*=======================================================================        
*String Variables
MONITOR:
                DC.B            '68000 Microcontroller Monitor Program [Version 1.0]', CR, LF
                DC.B            'Built Date: 4.13.2022', CR, LF
                DC.B            'Developer: Duc Anh Nguyen', CR, LF, 0
                
MENU_LIST:           
                DC.B            '  MEMORY MAP'           , CR, LF
                DC.B            '||  00000  ||'         , CR,LF
                DC.B            '||   ...   || ROM'     , CR,LF
                DC.B            '||  0FFFF  ||'         , CR,LF
                DC.B            '||  10000  ||'         , CR,LF
                DC.B            '||   ...   || RAM '    , CR,LF
                DC.B            '||  1FFFF  ||'         , CR,LF
                DC.B            '||  20000  ||'         , CR,LF
                DC.B            '||   ...   || DUART'   , CR,LF
                DC.B            '||  2000F  ||'         , CR,LF, 0                 

COMMAND_LIST:
                DC.B            'map ', 0
                DC.B            'help ', 0
                DC.B            'rm ', 0
                DC.B            'wm ', 0
                DC.B            'rr ', 0
                DC.B            'wr ', 0
                DC.B            'ls ', 0
                DC.B            'rs ', 0
              
*Help Display
MENU_HELP:
                DC.B            'map: display the memory map of the program ', CR, LF
                DC.B            'help: display instructions for commands ', CR, LF
                DC.B            'exit: terminate the monitor program ', CR, LF 
                DC.B             CR,LF                              
                
                DC.B            'rm: read from memory ', CR, LF
                DC.B            'e.g. rm $<ADDR> ', CR, LF
                DC.B             CR,LF 
                
                DC.B            'wm: write to memory. NOTE: You can only write to RAM location. type <MAP> for memory mapping', CR, LF
                DC.B            'e.g. wm $<CONTENT> $<LOCATION> ', CR, LF
                DC.B             CR,LF 
                
                DC.B            'rr: read from register ', CR, LF
                DC.B            'e.g. rr <REGISTER> ', CR, LF
                DC.B             CR,LF 
                
                DC.B            'wr: write to register. NOTE: A0, A5, A6, and A7 are preserved ', CR, LF
                DC.B            'e.g. wr $<CONTENT> <REGISTER> ', CR, LF
                DC.B             CR,LF 
                
                DC.B            'ls: load S-Record ', CR, LF
                DC.B            'e.g. ls <S-RECORD>', CR, LF
                DC.B             CR,LF 
                
                DC.B            'rs: run S-Record ', CR, LF 
                DC.B            'e.g. rs', CR, LF, 0

*Prompt
PROMPT:
                DC.B            '> ', 0
              
CONTENTS:
                DC.B            'Contents: ', CR, LF, 0 

OUTPUT_WM:
                DC.B            'Write Successfully', 0                

OUTPUT_LS:
                DC.B            'Load S-Record Successfully',0

SRECLIM_MSG:
                DC.B            'S-Record only accepts S1', 0

*Error Messgae
ERROR_MSG:
                DC.B            'Wrong Input', CR, LF, 0

ARG_ERR_MSG:
                DC.B            'Argument were incorrect, type <HELP> for formatting', CR,LF, 0            

*New Line
NEWLINE:        
                DC.B            CR, LF, 0

*End Program
*=======================================================================
                END             initDuart        ; last line of source



























































*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
