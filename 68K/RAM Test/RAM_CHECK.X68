*-----------------------------------------------------------
* Title      : 68k Homebrew ROM Monitor
* Written by : Hayden Kroepfl (ChartreuseK)
* Date       : August 24th 2015
* Description: A simple ROM monitor for my homebrew 68k
*              breadboard computer.
*-----------------------------------------------------------
*
* To make this responsive to different terminal widths we need to change the number of bytes printed
* on a line from 16, which fits exactly on a 72 column screen, to an ammount based on a formula.
*  Sizes: 
*   Address:      "000000: " 8
*   Each Byte:    "00 "      3
*   Start ASCII:  "|"        1
*   Each ASCII:   "."        1
*   End ASCII:    "|"        1
*
*   Width = 8 + numBytes*(3 + 1) + 2
*   numBytes = (Width - 10)/4 = (Width - 10)>>2
*  Examples:
*    (80 - 10)/4 = 70/4 = 16 Bytes
*    (40 - 10)/4 = 30/4 =  7 Bytes
*    (32 - 10)/4 = 22/4 =  5 Bytes
* On small screens we should not show the start and end characters on the ASCII section
* 40 Characters wide or less
*    (40 - 8)/4  = 32/4 =  8 Bytes
*    (32 - 8)/4  = 24/4 =  6 Bytes

SIM                 EQU         0

                    MOVE.B      #$00, D1
                    MOVE.B      #12, D0
                    TRAP        #15

**********************************
* Defines
*
RAM_START           equ     $40000
RAM_END             equ     $44000
MAX_LINE_LENGTH     equ     80

*********************************
* 68681 Duart Register Addresses
*
DUART equ $1C0000       * Base Addr of DUART
MRA   equ DUART+0       * Mode Register A           (R/W)
SRA   equ DUART+2       * Status Register A         (r)
CSRA  equ DUART+2       * Clock Select Register A   (w)
CRA   equ DUART+4       * Commands Register A       (w)
RBA   equ DUART+6       * Receiver Buffer A         (r)
TBA   equ DUART+6       * Transmitter Buffer A      (w)
ACR   equ DUART+8       * Aux. Control Register     (R/W)
ISR   equ DUART+10      * Interrupt Status Register (R)
IMR   equ DUART+10      * Interrupt Mask Register   (W)
MRB   equ DUART+16      * Mode Register B           (R/W)
SRB   equ DUART+18      * Status Register B         (R)
CSRB  equ DUART+18      * Clock Select Register B   (W)
CRB   equ DUART+20      * Commands Register B       (W)
RBB   equ DUART+22      * Reciever Buffer B         (R)
TBB   equ DUART+22      * Transmitter Buffer B      (W)
IVR   equ DUART+24      * Interrupt Vector Register (R/W)

**********************************
* ASCII Control Characters
*
BEL   equ $07
BKSP  equ $08       * CTRL-H
TAB   equ $09
LF    equ $0A
CR    equ $0D
ESC   equ $1B

CTRLC	EQU	$03     
CTRLX	EQU	$18     * Line Clear


**********************************
* Variables
*
varCurAddr  equ     RAM_END-4                        * Last address accessed
varLineBuf  equ     varCurAddr-MAX_LINE_LENGTH-2     * Line buffer

varLast     equ     varLineBuf


**********************************
* Defines 2 
*
STACK_START         equ     varLast
SIM                 EQU     0
                    

                    

**** PROGRAM STARTS HERE ****
    
    ORG     $0000
    
**** FIRST 8 bytes loaded after reset ****
    DC.l    STACK_START  * Supervisor stack pointer
    DC.l    START        * Initial PC    
    
    
********************************************
* Cold start entry point
*
START:
    lea     STACK_START, SP     * Set our stack pointer to be sure
    jsr     initDuart           * Setup the serial port
 
********************************************
* Simple Ram Readback Test
*    
ramCheck:
    lea     msgRamCheck, A0
    bsr.w   printString
    lea     RAM_START, A2
 .loop:
    move.b  #$AA, (A2)   * First test with 10101010
    cmp.b   #$AA, (A2)
    bne.s   .fail
    move.b  #$55, (A2)   * Then with 01010101
    cmp.b   #$55, (A2)
    bne.s   .fail
    move.b  #$00, (A2)   * And finally clear the memory
    cmp.b   #$00, (A2)+  * And move to the next byte
    bne.s   .fail 
    cmp.l   #RAM_END, A2  
    blt.s   .loop        * While we're still below the end of ram to check
    bra.s   .succ
 .fail:                  * One of the bytes of RAM failed to readback test
    lea     msgRamFail, A0
    bsr.w   printString
    move.l  A2, D0
    bsr.w   printHexLong * Print out the address that failed
    bsr.w   printNewline
 .haltloop:              * Sit forever in the halt loop
    bra.s   .haltloop
 .succ:                  * All bytes passed the readback test
    lea     msgRamPass, A0
    bsr.w   printString
    
    
 ******
* Prints a newline (CR, LF)
printNewline:
    lea     msgNewline, a0
******
* Print a null terminated string
*
printString:
 .loop:
    move.b  (a0)+, d0    * Read in character
    beq.s   .end         * Check for the null
    
    bsr.s   outChar      * Otherwise write the character
    bra.s   .loop        * And continue
 .end:
    rts

** KEEP All printHex functions together **
******
* Print a hex word
printHexWord:
    move.l  d2, -(SP)    * Save D2
    move.l  d0, d2       * Save the address in d2
    
    rol.l   #8, d2       * 4321 -> 3214
    rol.l   #8, d2       * 3214 -> 2143 
    bra.s   printHex_wordentry  * Print out the last 16 bits
*****
* Print a hex 24-bit address
printHexAddr:
    move.l d2, -(SP)     * Save D2
    move.l d0, d2          * Save the address in d2
    
    rol.l   #8, d2       * 4321 -> 3214
    bra.s   printHex_addrentry  * Print out the last 24 bits
******
* Print a hex long
printHexLong:
    move.l  d2, -(SP)     * Save D2
    move.l  d0, d2        * Save the address in d2
    
    rol.l   #8, d2        * 4321 -> 3214 high byte in low
    move.l  d2, d0
    bsr.s   printHexByte  * Print the high byte (24-31)
printHex_addrentry:     
    rol.l   #8, d2        * 3214 -> 2143 middle-high byte in low
    move.l  d2, d0              
    bsr.s   printHexByte  * Print the high-middle byte (16-23)
printHex_wordentry:    
    rol.l   #8, d2        * 2143 -> 1432 Middle byte in low
    move.l  d2, d0
    bsr.s   printHexByte  * Print the middle byte (8-15)
    rol.l   #8, d2
    move.l  d2, d0
    bsr.s   printHexByte  * Print the low byte (0-7)
    
    move.l (SP)+, d2      * Restore D2
    RTS
    
******
* Print a hex byte
*  - Takes byte in D0
printHexByte:
    move.l  D2, -(SP)
    move.b  D0, D2
    lsr.b   #$4, D0
    add.b   #'0', D0
    cmp.b   #'9', D0     * Check if the hex number was from 0-9
    ble.s   .second
    add.b   #7, D0       * Shift 0xA-0xF from ':' to 'A'
.second:
    bsr.s   outChar      * Print the digit
    andi.b  #$0F, D2     * Now we want the lower digit Mask only the lower digit
    add.b   #'0', D2
    cmp.b   #'9', D2     * Same as before    
    ble.s   .end
    add.b   #7, D2
.end:
    move.b  D2, D0
    bsr.s   outChar      * Print the lower digit
    move.l  (SP)+, D2
    rts
    
    
    
    
    
    
*****
* Writes a character to Port A, blocking if not ready (Full buffer)
*  - Takes a character in D0
outChar:
    btst    #2, SRA      * Check if transmitter ready bit is set
    beq     outChar     
    move.b  d0, TBA      * Transmit Character
    rts

*****
* Reads in a character from Port A, blocking if none available
*  - Returns character in D0
*    
inChar:
    btst    #0,  SRA     * Check if receiver ready bit is set
    beq     inChar
    move.b  RBA, d0      * Read Character into D0
    rts
    
*****
* Initializes the 68681 DUART port A as 9600 8N1 
initDuart:
    move.b  #$30, CRA       * Reset Transmitter
    move.b  #$20, CRA       * Reset Reciever
    move.b  #$10, CRA       * Reset Mode Register Pointer
    
    move.b  #$80, ACR       * Baud Rate Set #2
    move.b  #$BB, CSRA      * Set Tx and Rx rates to 9600
    move.b  #$93, MRA       * 7-bit, No Parity ($93 for 8-bit, $92 for 7-bit)
    move.b  #$07, MRA       * Normal Mode, Not CTS/RTS, 1 stop bit
    
    move.b  #$05, CRA       * Enable Transmit/Recieve
    rts    






**********************************
* Strings
*
msgBanner:
    dc.b CR,LF,'Chartreuse''s 68000 ROM Monitor',CR,LF
    dc.b       '==============================',CR,LF,0
msgHelp:
    dc.b 'Available Commands: ',CR,LF
    dc.b ' (E)xamine    (D)eposit    (R)un     (H)elp',CR,LF,0
msgDepositPrompt:
    dc.b ': ',0
msgPrompt:
    dc.b '> ',0
msgInvalidCommand:
    dc.b 'Invalid Command',CR,LF,0
msgInvalidAddress:
    dc.b 'Invalid Address',CR,LF,0
msgInvalidValue:
    dc.b 'Invalid Value',CR,LF,0
msgRamCheck:
    dc.b 'Checking RAM...',CR,LF,0
msgRamFail:
    dc.b 'Failed at: ',0
msgRamPass:
    dc.b 'Passed.',CR,LF,0
msgNewline:
    dc.b CR,LF,0
msgColonSpace:
    dc.b ': ',0



    END    START            * last line of source


*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~



*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
