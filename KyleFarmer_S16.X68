*-----------------------------------------------------------
* Title      : 68k Disassembler
* Written by : Kyle Farmer
* Date       : 5/11/2016
* Description:
*-----------------------------------------------------------
start_input DS.B       20   * address used to store user input for start address
start_flag  DS.B       1    * used to determine if the start address has been entered
EA_FLAG     DS.B       80   * set if an error in the instruction caused A4 to move beyond next instruction
lines_flag  DS.B       10   * number of lines until the halt display needs to be called
end_input   DS.B       20   * address used to store user input for end address
printCode   DS.B       40   * starting address to print each line of code
restart_in  DS.B       30   * get the user input for restart

minStart    EQU        $00000000
maxEnd      EQU        $00FFFFE0
CR          EQU        $0D
LF          EQU        $0A

    ORG    $1000
    
START  
            
            MOVE.B  #$0,lines_flag  * initialize lines to 0
            MOVE.B  #$0,start_flag  *initialize start flag to 0
            MOVE.B  #$0,EA_FLAG     * initialize ea flag to 0        
* gather user input for starting address *
GET_LOWER   LEA     startAddr,A1
            MOVE.L  #14,D0
            TRAP    #15
            LEA     start_input,A1
            MOVE.L  #2,D0
            TRAP    #15
            CLR     D4
            JSR     CHECK_INPUT
            JSR     CHK_BOUNDS
            MOVE.L  D4,A4
* gather user input for upper address            
GET_UPPER   LEA     endAddr,A1
            MOVE.L  #14,D0
            TRAP    #15
            LEA     end_input,A1
            MOVE.L  #2,D0
            TRAP    #15
            CLR     D4
            JSR     CHECK_INPUT
            JSR     CHK_BOUNDS
            MOVE.L  D4,A5
            BRA     MAIN
            
****************************************************************
* CHECK_INPUT:                                               *
* Checks input for the entered string and convert ascii to hex *
* and determines if the address entered was valid              *
****************************************************************

CHECK_INPUT
            MOVE.B  #$0,D4   * D4 will be register to hold resultant address
            CMP.B   #$0,D1
            BEQ     noInput  * check for no address entered
            CMPI    #$8,D1  
            BGT     boundsErr  * check for too many chars entered
       
readNext    MOVE.B  (A1)+,D2    
            CMPI.B   #$0,D2       * check for NULL, indicating finished
            BEQ     readDone
            * check upper and lower ASCII bounds: 0-f
            CMPI.B   #$30,D2     * entered an ASCII less than 0
            BLT     charError
            CMPI.B   #$66,D2     * entered an ASCII greater than 'f'
            BGT     charError
            * within bounds so check for valid inputs
            CMPI.B   #$39,D2     
            BGT     upHex       * entered an ASCII greater than 0-9
            
            * value is between 0-9, convert to decimal
            SUBI.B  #$30,D2     * subtract $30 to get its dec representation
            LSL.L   #4,D4       * shift resultant left 4 bits
            ADD.B   D2,D4       * add the next 4 bits to resultant
            BRA     readNext
            
            * value is larger than decimal number, but within range
upHex       CMPI.B  #$46,D2     * cmp value to 'F'
            BGT     loHex       * value is larger than uppercase hex
            CMP.B   #$40,D2     * cmp value to 'A'
            BLT     charError       * value is an unsupported character
            
            * value is not below A or above F, convert to hex and add to D6
            SUBI.B  #$37,D2
            LSL.L   #4,D4       * shift left 4 bits
            ADD.B   D2,D4       * add the next 4 bits
            BRA     readNext
            
loHex       * value is within bounds, but greater than 0-9 & A-F
            CMPI.B  #$61,D2     * cmp value to '`', 1 place below 'a'
            BLT     charError       * branch to error if this occurred 
            * value is valid and is between a-f
            SUBI.B  #$57,D2
            LSL.L   #4,D4
            ADD.B   D2,D4
            BRA     readNext

readDone    RTS

noInput     LEA     no_Input,A1     * load error message
            MOVE.L  #14,D0
            TRAP    #15
            MOVE.B  start_flag,D6   * load start flag to D6
            CMP.B   #$0,D6          * check if the start addr has been entered correctly
            BLT     GET_LOWER       * get lower addr if not
            BRA     GET_UPPER       * get upper
            
boundsErr   LEA     addrBoundErr,A1 * load error message
            MOVE.L  #14,D0
            TRAP    #15
            MOVE.B  start_flag,D6
            CMP.B   #$0,D6
            BLT     GET_LOWER
            BRA     GET_UPPER
            
charError   LEA     badChar,A1      * load error message
            MOVE.L  #14,D0
            TRAP    #15
            MOVE.B  start_flag,D6
            CMP.B   #$0,D6

            BLT     GET_LOWER
            BRA     GET_UPPER 
            
* CHECK_BOUNDS

CHK_BOUNDS  CLR     D6              * clear D6
            MOVE.W  D4,D6           * move user input address to D6
            ANDI.B  #$1,D6          * bit check if it is odd
            CMPI.B  #$1,D6
            BEQ     OddError        * odd, break and print error message
            MOVE.B  start_flag,D6   * move byte start flag to D6
            CMPI.B  #$0,D6          * if starting address, check lower bounds
            BEQ     lowerBound
            BRA     upperBound      * else check upper bounds

lowerBound  CMPI.L  #minStart,D4    * is the lower bound less than the start address bound?
            BLT     lowError
            CMPI.L  #maxEnd,D4      * is the lower bound greater than the end address bound?
            BGT     hiError
            MOVE.B  #$1,start_flag  * move 1 to starting flag, indicating the starting 
                                    * address has been successfully entered
            RTS 


upperBound  CMPI.L  #minStart,D4    * end address is smaller than starting bounds
            BLT     lowError
            CMPI.L  #maxEnd,D4      * ending address goes beyond bounds
            BGT     hiError
            CMP.L   A4,D4           * compare start address to end address
            BLT     endError        * branch to error if they are the same or end is lower
            RTS 

            
OddError    LEA     oddErr,A1   * load error message
            MOVE.L  #14,D0
            TRAP    #15
            MOVE.B  start_flag,D6   * check if the starting address is valid
            CMP.B   #$0,D6          * if flag has not been set to 1, return to starting address
            BEQ     GET_LOWER       
            BRA     GET_UPPER 
            
lowError    ASL.L   #1,D4    * this covers the case of FFFFFFFE without this, 
            * it will interpret FFFFFFFE as smaller than 00000000 and print low error
            BCS     hiError
            CMPI.L  #$1000000,D4 * covers the case of D4>00ffffe0
            BGE     hiError         
            LEA     loErr,A1    * load error message
            MOVE.L  #14,D0
            TRAP    #15
            MOVE.B  start_flag,D6   * check if the starting address is valid
            CMP.B   #$0,D6
            BEQ     GET_LOWER       
            BRA     GET_UPPER 
    
hiError     LEA     hiErr,A1        * load high error message
            MOVE.L  #14,D0
            TRAP    #15
            MOVE.B  start_flag,D6   * check if the starting address is valid
            CMP.B   #$0,D6
            BEQ     GET_LOWER       
            BRA     GET_UPPER 

endError    LEA     endErr,A1       * load starting larger than ending address error
            MOVE.L  #14,D0
            TRAP    #15
            BRA     GET_UPPER       * branch back to getting ending address
            
startAddr   DC.B    'Enter a starting address from $00000000 to $00FFFFE0: ',CR,LF,0
endAddr     DC.B    'Enter an ending address greater or equal to the starting address: ',CR,LF,0
no_Input    DC.B    CR,LF,'No input, please enter a valid address',CR,LF,0
badChar     DC.B    CR,LF,'Bad character entered in address, please re-enter the address',CR,LF,0
addrBoundErr DC.B CR,LF,'The address entered contained too many characters, please re-enter address',CR,LF,0
oddErr      DC.B    CR,LF,'The address entered was odd, please re-enter a valid address',CR,LF,0 
endErr      DC.B    CR,LF,'Ending address is lower than starting address, please re-enter address',CR,LF,0
loErr       DC.B    CR,LF,'Address is smaller than specified bounds, please re-enter address',CR,LF,0
hiErr       DC.B    CR,LF,'Address is larger than the specified bounds, please re-enter address',CR,LF,0
halt        DC.B    'Press Enter to continue',0 
repeat     DC.B    'Would you like to load another program? (Y/N): ',0
ending      DC.B    CR,LF,'Thank you for using this disassembler',0

MAIN        LEA     printCode,A2
            
MAINLOOP    * IF start >= end, disassemble done
            CMPA.L   A5,A4
            BGT     DONE
            * if screen full, halt display and continue
            MOVE.B  lines_flag,D0
            CMPI.W  #30,D0      * 30 lines reached?
            BEQ     haltDisplay * halt display
            * reset EA_FLAG
_Cont       MOVE.B  #$0,EA_FLAG
            CLR.L   D5
            CLR.B   D7
            JSR GetPC    * get PC

            JSR GetInstr * get instruction
 
            JSR printLine * print the line
            
            MOVE.B  lines_flag,D0   * increment the number of lines
            ADDQ    #1,D0
            MOVE.B  D0,lines_flag
            BRA     MAINLOOP  * branch back to beginning of loop
            
haltDisplay
            LEA     halt,A1
            MOVE.L  #14,D0
            TRAP    #15
            LEA     start_input,A1
            MOVE.L  #2,D0
            TRAP    #15
            
            BRA _Cont
            
******************************************************************
* GetPC
******************************************************************            
GetPC       LEA     printCode,A2
            LEA     numTable,A6
            CLR.L   D6
            CLR.L   D2
            MOVE.L  A4,D3      * move address into data r3
            * given since no address can be bigger than 00ffffe0
            MOVE.B  #'0',(A2)+ * add two zeros to the string
            MOVE.B  #'0',(A2)+
            LSL.L   #4,D3      * shift leading zeros out
            
GetPClp     LSL.L   #4,D3   * shift 4 bits out   
            CMPI.B  #6,D2   * if the loop has gone thru 6 times,
            BEQ     GetPCDn * finish 
            JSR     BITTEST * get leading 4 bits hex representation
            MULU.W  #8,D6   * mult by 8 for jump offset
            JSR     (A6,D6) * jump to the table to add to string
            ADDQ    #1,D2   * increment loop counter
            BRA     GetPClp
GetPCDn     RTS

**************************************************************
* BITTEST-
* Bit Test check for the leading 4 bits in D3. If a bit is 
* marked, it is added to the resultant number held in D6.
**************************************************************   
BITTEST     CLR.L   D6
            BTST.L  #$1F,D3
            BNE.S   add1000
eTst        BTST.L  #$1E,D3
            BNE.S   add0100
dTst        BTST.L  #$1D,D3
            BNE.S   add0010
cTst        BTST.L  #$1C,D3
            BNE.S   add0001
            RTS
                 
add1000     ADDI.B  #%1000,D6
            BRA     eTst
            
add0100     ADDI.B  #%0100,D6
            BRA     dTst

add0010     ADDI.B  #%0010,D6
            BRA     cTst

add0001     ADDI.B  #%0001,D6
            RTS  

**************************************************************
* BitTst3- a variation of BITTEST -> used primarily for EA
* Bit Test check for the leading 3 bits in D3. If a bit is 
* marked, it is added to the resultant number held in D6.
**************************************************************             
            
BitTst3     CLR.L   D6
            BTST.L  #$1F,D3
            BNE.S   add100
Bit1        BTST.L  #$1E,D3
            BNE.S   add010
Bit0        BTST.L  #$1D,D3
            BNE.S   add001
            RTS
                 
add100      ADDI.B  #%100,D6
            BRA     Bit1
            
add010      ADDI.B  #%010,D6
            BRA     Bit0

add001      ADDI.B  #%001,D6
            RTS

**************************************************************
* BitTst2- a variation of BITTEST 
* Bit Test check for the leading 2 bits in D3. If a bit is 
* marked, it is added to the resultant number held in D6.
************************************************************** 
            
BitTst2     CLR.L   D6
            BTST.L  #$1F,D3
            BNE.S   add10
Bt1         BTST.L  #$1E,D3
            BNE.S   add01
            RTS
            
add10       ADDI.B  #%10,D6
            BRA Bt1
            
add01       ADDI.B  #%01,D6
            RTS
            
*******************************************************************************
* getSize - 
* Subroutine used to get the size bits of a given instruction
*******************************************************************************
getSize   
            MOVE.L  D4,D3       * reset D3
            SWAP    D3          * push D3 to front
            LSL.L   #8,D3       * move front 8 bits out
            JSR     BitTst2     * test two size bits, hold result in d6
            MOVE.L  D4,D3       * Reset d3
            SWAP    D3          * push d3 to front
            RTS                 * return
            
**********************************************************************
* PrintByte, PrintWord, PrintLong -  
* print functions for immediate/absolute numbers categorized by size
**********************************************************************            
printByte   
            CLR     D2          * clear d2 for counter
            LEA     numTable,A6 
            MOVE.L  A4,D5       * save current address in case of error
            MOVE.W  (A4)+,D3    * get the immediate word data
            SWAP    D3          * swap to front
            LSL.L   #8,D3       * shift out leading 8 bits, dealing with 1 byte
            MOVE.B  #1,EA_FLAG  * set ea flag
            
printBLoop  
            CMPI.B  #2,D2       * loop through twice,
            BEQ     printDn     * print done
            JSR     BITTEST     * get leading 4 bits
            MULU    #8,D6       * multiply by 8 for jump offset 
            JSR     (A6,D6)     * get number from table and add to A2 string
            LSL.L   #4,D3       * shift out the 4 bits were done with
            ADDQ    #1,D2       * increment loop counter
            BRA     printBLoop
            

printWord
            CLR     D2      * clear d2 for counter
            LEA     numTable,A6
            MOVE.L  A4,D5       * save current address in case of error
            MOVE.W  (A4)+,D3    * get the immediate word data
            SWAP    D3          * swap to front
            MOVE.B  #1,EA_FLAG  * set ea flag
            
printWLoop  
            CMPI.B  #4,D2       * loop through 4 times,
            BEQ     printDn     * print done
            JSR     BITTEST     * get leading 4 bits
            MULU    #8,D6       * multiply by 8 for jump offset
            JSR     (A6,D6)     * get number from table and add to A2 string
            LSL.L   #4,D3       * shift out 4 biths were done with
            ADDQ    #1,D2       * increment loop counter
            BRA     printWLoop  * branch back to loop

printLong
            CLR     D2      * clear d2 for counter
            LEA     numTable,A6
            MOVE.L  A4,D5       * save current address in case of error
            ADDI.L  #$2,D5      * increment D5 to the next instruction
            MOVE.L  (A4)+,D3    * get the immediate long data into D3
            * no swapping necessary, already longword
            MOVE.B  #1,EA_FLAG  * set ea flag
            
printLLoop
            CMPI.B  #8,D2       * loop through 8 times,
            BEQ     printDn     * finish
            JSR     BITTEST     * get leading 4 bits
            MULU    #8,D6       * multiply number by 8 for jump offset
            JSR     (A6,D6)     * get number from table and add to A2 string
            LSL.L   #4,D3       * shift out 4 bits already used
            ADDQ    #1,D2       * increment loop counter
            BRA     printLLoop  * branch back to loop beginning

printDn     RTS

*************************************************************
* getMode
*************************************************************
getMode     MOVE.L  D4,D3       * reset D3
            SWAP    D3
            LSL.L   #8,D3       * shift out leading 10 bits to check 3-5
            LSL.L   #2,D3
            JSR     BitTst3     * test 3 bits, hold result in D6
            RTS                 * return
            
**************************************************************
* printLine
**************************************************************
printLine       
                MOVE.B  #$00,(A2)   * add null terminator to string
                LEA     printCode,A1
                MOVEQ   #13,D0
                TRAP    #15
                
                RTS
            

**********************************************
* Get Instruction         
**********************************************

GetInstr    * print spaces before instruction
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVEA.L     A2,A3   * save current string location
            * clr current D3 contents
            CLR.L   D3
            MOVE.W (A4)+,D3 * move instruction word into d3
            MOVE.L  D3,D4   * save D3
            SWAP    D3      * swap d3 to upper 16 bits for BITTEST
            * bit test check for the op code
            JSR     BITTEST
            SWAP    D3      * swap d3 back for comparisons in op codes
            * begin comparisons with different op codes
            CMPI.B  #%0000,D6   * ADDI,ANDI,CMPI,ORI
            BEQ     op0000
            CMPI.B  #%0001,D6   * MOVE.B
            BEQ     op0001
            CMPI.B  #%0010,D6   * MOVE.L/MOVEA.L
            BEQ     op0010
            CMPI.B  #%0011,D6   * MOVE.W/MOVEA.W
            BEQ     op0011
            CMPI.B  #%0100,D6   * MOVEM/LEA/CLR/JSR/RTS/NOP
            BEQ     op0100
            CMPI.B  #%0101,D6   * ADDQ/SUBQ
            BEQ     op0101
            CMPI.B  #%0110,D6   * Bcc (BRA,BCC,BLT,BGE)
            BEQ     op0110
            CMPI.B  #%0111,D6   * MOVEQ
            BEQ     op0111
            CMPI.B  #%1000,D6   * DIVU/DIVS/OR
            BEQ     op1000
            CMPI.B  #%1001,D6   * SUB
            BEQ     op1001
            CMPI.B  #%1011,D6   * CMP
            BEQ     op1011
            CMPI.B  #%1100,D6   * MULS/MULU/AND
            BEQ     op1100
            CMPI.B  #%1101,D6   * ADD/ADDA
            BEQ     op1101
            CMPI.B  #%1110,D6   * LSL/LSR/ASL/ASR/ROL/ROR
            BEQ     op1110
            * if no op code found, print op error/not supported
            
            BRA     OPERROR

* ADDI, ANDI, CMPI, ORI, SUBI ------------------------------------
op0000
            SWAP    D3
            LSL.L   #4,D3   * shift out opcode
            JSR     BITTEST * test next four bits
            CMPI.B  #%0000,D6
            BEQ     _OrI    * go to ORI
            CMPI.B  #%0010,D6
            BEQ     _AndI   * go to ANDI
            CMPI.B  #%0100,D6
            BEQ     _SubI   * go to SUBI
            CMPI.B  #%0110,D6
            BEQ     _AddI   * go to ADDI
            CMPI.B  #%1100,D6
            BEQ     _CmpI   * go to CMPI
            
            * if none of these, unsupported/error
            BRA     OPERROR
            
* ORI --------------------------------------------------------------------------------

_OrI        LSL.L   #4,D3   * shift next 4 bits to check for size
            JSR     BitTst2 * check the size bits
            LSL.L   #5,D3   * shift 5 bits out for immediate destination data check
            CMPI.B  #%00,D6 * branch to appropriate size label
            BEQ     _OrIb   * ORI.B
            CMPI.B  #%01,D6
            BEQ     _OrIw   * ORI.W
            CMPI.B  #%10,D6
            BEQ     _OrIl   * ORI.L
            * something unexpected
            BRA     OPERROR
* ORI.B ---------------------            
_OrIb
            
            MOVE.B  #'O',(A2)+
            MOVE.B  #'R',(A2)+
            MOVE.B  #'I',(A2)+
            MOVE.B  #'.',(A2)+ 
            MOVE.B  #'B',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+
            MOVE.B  #'#',(A2)+
            MOVE.B  #'$',(A2)+
            JSR     printByte
            MOVE.B  #',',(A2)+
            
            JSR     getMode
            CMP.B   #%001,D6    * compare with Ar
            BEQ     OPERROR     * error
            
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            
            
            RTS            
* ORI.W ----------------------
_OrIw       
           
            MOVE.B  #'O',(A2)+
            MOVE.B  #'R',(A2)+
            MOVE.B  #'I',(A2)+
            MOVE.B  #'.',(A2)+ 
            MOVE.B  #'W',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+
            MOVE.B  #'#',(A2)+
            MOVE.B  #'$',(A2)+
            JSR     printWord
            MOVE.B  #',',(A2)+
            
            JSR     getMode
            CMP.B   #%001,D6    * compare with Ar
            BEQ     OPERROR     * error
            LEA     eaTable,A6   * load ea table
            MULU    #8,D6       * multiply for offset
            JSR     (A6,D6)     * jump to offset
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
             
            RTS  
* ORI.L ----------------------
_OrIl       
            MOVE.B  #'O',(A2)+
            MOVE.B  #'R',(A2)+
            MOVE.B  #'I',(A2)+
            MOVE.B  #'.',(A2)+ 
            MOVE.B  #'L',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+
            MOVE.B  #'#',(A2)+
            MOVE.B  #'$',(A2)+
            JSR     printLong
            MOVE.B  #',',(A2)+
            
            JSR     getMode
            CMP.B   #%001,D6    * compare with Ar
            BEQ     OPERROR     * error
            LEA     eaTable,A6   
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            
            RTS  
            
* ANDI ------------------------------------------------------------------------------
_AndI       LSL.L   #4,D3
            JSR     BitTst2
            LSL.L   #5,D3   * shift 5 bits out for immediate destination data check
            CMPI.B  #%00,D6 * branch to appropriate size label
            BEQ     _AndIb   * ANDI.B
            CMPI.B  #%01,D6
            BEQ     _AndIw  * ANDI.W
            CMPI.B  #%10,D6
            BEQ     _AndIl   * ANDI.L
            * something unexpected
            BRA     OPERROR
            
* ANDI.B ---------------------
_AndIb      
            MOVE.B  #'A',(A2)+
            MOVE.B  #'N',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.B  #'I',(A2)+ 
            MOVE.B  #'.',(A2)+ 
            MOVE.B  #'B',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+
            MOVE.B  #'#',(A2)+
            MOVE.B  #'$',(A2)+
            JSR     printByte
            MOVE.B  #',',(A2)+
            JSR     getMode
            CMP.B   #%001,D6    * compare with Ar
            BEQ     OPERROR     * error
            
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            
            RTS 

* ANDI.W ---------------------
_AndIw      
            MOVE.B  #'A',(A2)+
            MOVE.B  #'N',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.B  #'I',(A2)+ 
            MOVE.B  #'.',(A2)+ 
            MOVE.B  #'W',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+
            MOVE.B  #'#',(A2)+
            MOVE.B  #'$',(A2)+
            JSR     printWord
            MOVE.B  #',',(A2)+
            JSR     getMode
            CMP.B   #%001,D6    * compare with Ar
            BEQ     OPERROR     * error
            
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR

            RTS 
* ANDI.L ---------------------
_AndIl      
            MOVE.B  #'A',(A2)+
            MOVE.B  #'N',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.B  #'I',(A2)+ 
            MOVE.B  #'.',(A2)+ 
            MOVE.B  #'L',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+
            MOVE.B  #'#',(A2)+
            MOVE.B  #'$',(A2)+
            JSR     printLong
            MOVE.B  #',',(A2)+
            JSR     getMode
            CMP.B   #%001,D6    * compare with Ar
            BEQ     OPERROR     * error
            
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR

            RTS 

* SUBI ------------------------------------------------------------------------------
_SubI       LSL.L   #4,D3
            JSR     BitTst2
            LSL.L   #5,D3   * shift 5 bits out for immediate destination data check
            CMPI.B  #%00,D6 * branch to appropriate size label
            BEQ     _SubIb   * SUBI.B
            CMPI.B  #%01,D6
            BEQ     _SubIw   * SUBI.W
            CMPI.B  #%10,D6
            BEQ     _SubIl   * SUBI.L
            * something unexpected
            BRA     OPERROR

* SUBI.B ---------------------            
_SubIb      
            MOVE.B  #'S',(A2)+
            MOVE.B  #'U',(A2)+
            MOVE.B  #'B',(A2)+
            MOVE.B  #'I',(A2)+ 
            MOVE.B  #'.',(A2)+ 
            MOVE.B  #'B',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+
            MOVE.B  #'#',(A2)+
            MOVE.B  #'$',(A2)+
            JSR     printByte
            MOVE.B  #',',(A2)+
            JSR     getMode
            CMP.B   #%001,D6    * compare with Ar
            BEQ     OPERROR     * error
            
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR

            RTS 
* SUBI.W ---------------------
_SubIw      
            MOVE.B  #'S',(A2)+
            MOVE.B  #'U',(A2)+
            MOVE.B  #'B',(A2)+
            MOVE.B  #'I',(A2)+ 
            MOVE.B  #'.',(A2)+ 
            MOVE.B  #'W',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+
            MOVE.B  #'#',(A2)+
            MOVE.B  #'$',(A2)+
            JSR     printWord
            MOVE.B  #',',(A2)+
            JSR     getMode
            CMP.B   #%001,D6    * compare with Ar
            BEQ     OPERROR     * error
            
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR

            RTS 

* SUBI.L ---------------------
_SubIl      
            MOVE.B  #'S',(A2)+
            MOVE.B  #'U',(A2)+
            MOVE.B  #'B',(A2)+
            MOVE.B  #'I',(A2)+ 
            MOVE.B  #'.',(A2)+ 
            MOVE.B  #'L',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+
            MOVE.B  #'#',(A2)+
            MOVE.B  #'$',(A2)+
            JSR     printLong
            MOVE.B  #',',(A2)+
            JSR     getMode
            CMP.B   #%001,D6    * compare with Ar
            BEQ     OPERROR     * error
            
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR

            RTS 

* ADDI ------------------------------------------------------------------------------
_AddI       LSL.L   #4,D3
            JSR     BitTst2
            LSL.L   #5,D3   * shift 5 bits out for immediate destination data check
            CMPI.B  #%00,D6 * branch to appropriate size label
            BEQ     _AddIb   * ADDI.B
            CMPI.B  #%01,D6
            BEQ     _AddIw   * ADDI.W
            CMPI.B  #%10,D6
            BEQ     _AddIl   * ADDI.L
            * something unexpected
            BRA     OPERROR
            
* ADDI.B ---------------------            
_AddIb      
            MOVE.B  #'A',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.B  #'I',(A2)+ 
            MOVE.B  #'.',(A2)+ 
            MOVE.B  #'B',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+
            MOVE.B  #'#',(A2)+
            MOVE.B  #'$',(A2)+
            JSR     printByte
            MOVE.B  #',',(A2)+
            JSR     getMode
            CMP.B   #%001,D6    * compare with Ar
            BEQ     OPERROR     * error
            
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR

            RTS 

* ADDI.W ---------------------
_AddIw      
            MOVE.B  #'A',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.B  #'I',(A2)+ 
            MOVE.B  #'.',(A2)+ 
            MOVE.B  #'W',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+
            MOVE.B  #'#',(A2)+
            MOVE.B  #'$',(A2)+
            JSR     printWord
            MOVE.B  #',',(A2)+
            JSR     getMode
            CMP.B   #%001,D6    * compare with Ar
            BEQ     OPERROR     * error
            
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR

            RTS 
* ADDI.L ---------------------
_AddIl      
            MOVE.B  #'A',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.B  #'I',(A2)+ 
            MOVE.B  #'.',(A2)+ 
            MOVE.B  #'L',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+
            MOVE.B  #'#',(A2)+
            MOVE.B  #'$',(A2)+
            JSR     printLong
            MOVE.B  #',',(A2)+
            JSR     getMode
            CMP.B   #%001,D6    * compare with Ar
            BEQ     OPERROR     * error
            
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR

            RTS 

* CMPI ------------------------------------------------------------------------------
_CmpI       LSL.L   #4,D3
            JSR     BitTst2
            LSL.L   #5,D3   * shift 5 bits out for immediate destination data check
            CMPI.B  #%00,D6 * branch to appropriate size label
            BEQ     _CmpIb   * CMPI.B
            CMPI.B  #%01,D6
            BEQ     _CmpIw   * CMPI.W
            CMPI.B  #%10,D6
            BEQ     _CmpIl   * CMPI.L
            * something unexpected
            BRA     OPERROR
            
* CMPI.B --------------------            
_CmpIb      
            MOVE.B  #'C',(A2)+
            MOVE.B  #'M',(A2)+
            MOVE.B  #'P',(A2)+
            MOVE.B  #'I',(A2)+ 
            MOVE.B  #'.',(A2)+ 
            MOVE.B  #'B',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+
            MOVE.B  #'#',(A2)+
            MOVE.B  #'$',(A2)+
            JSR     printByte
            MOVE.B  #',',(A2)+
            JSR     getMode
            CMP.B   #%001,D6    * compare with Ar
            BEQ     OPERROR     * error
            
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR

            RTS 
* CMPI.W ---------------------
_CmpIw      
            MOVE.B  #'C',(A2)+
            MOVE.B  #'M',(A2)+
            MOVE.B  #'P',(A2)+
            MOVE.B  #'I',(A2)+ 
            MOVE.B  #'.',(A2)+ 
            MOVE.B  #'B',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+
            MOVE.B  #'#',(A2)+
            MOVE.B  #'$',(A2)+
            JSR     printWord
            MOVE.B  #',',(A2)+
            JSR     getMode
            CMP.B   #%001,D6    * compare with Ar
            BEQ     OPERROR     * error
            
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR

            RTS 
* CMPI.L ---------------------
_CmpIl      
            MOVE.B  #'C',(A2)+
            MOVE.B  #'M',(A2)+
            MOVE.B  #'P',(A2)+
            MOVE.B  #'I',(A2)+ 
            MOVE.B  #'.',(A2)+ 
            MOVE.B  #'B',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+
            MOVE.B  #'#',(A2)+
            MOVE.B  #'$',(A2)+
            JSR     printLong
            MOVE.B  #',',(A2)+
            JSR     getMode
            CMP.B   #%001,D6    * compare with Ar
            BEQ     OPERROR     * error
            
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR

            RTS 
            
            
            
* MOVE.B -------------------------------------------------
op0001          
   
            MOVE.B  #1,D7       * move 1 into d7 to indicate byte
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            * store MOVE.B into the A2 string
            MOVE.B  #'M',(A2)+
            MOVE.B  #'O',(A2)+
            MOVE.B  #'V',(A2)+
            MOVE.B  #'E',(A2)+ 
            MOVE.B  #'.',(A2)+ 
            MOVE.B  #'B',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+
            
            * get EA for source
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            
            MOVE.B  #',',(A2)+
            
            * look at destination
            MOVE.L  D4,D3   * reset D3
            SWAP    D3
            LSL.L   #7,D3   * shift 7 leading bits out
            JSR     BitTst3 * test destination mode
            CMPI.B  #%000,D6
            BEQ     moveDn          * move to data register
            CMPI.B  #%010,D6
            BEQ     moveInd         * move to indirect address
            CMPI.B  #%011,D6
            BEQ     movePost        * move to indirect address with post increment
            CMPI.B  #%100,D6
            BEQ     movePre         * move to indirect address with pre decrement
            CMPI.B  #%111,D6
            BEQ     moveAbs         * move to absolute address

            BRA     OPERROR 
            
            RTS

            
* MOVE.L/MOVEA.L ----------------------------------------
op0010   
            SWAP    D3          * swap D3 bits to top for bit checking subroutine
            LSL.L   #7,D3       * shift out op code and dest register
            MOVE.B  #3,D7       * move 3 into d7 to indicate long
            JSR     BitTst3     
            CMPI.B  #%001,D6    * if dest mode is address reg, branch to MOVEA
            BEQ     _MoveAl     * go to MOVEA.L
            
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            * store MOVE.B into the A2 string
            MOVE.B  #'M',(A2)+
            MOVE.B  #'O',(A2)+
            MOVE.B  #'V',(A2)+
            MOVE.B  #'E',(A2)+ 
            MOVE.B  #'.',(A2)+ 
            MOVE.B  #'L',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+
            
            * get EA for source
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            
            MOVE.B  #',',(A2)+
            * look at destination
            MOVE.L  D4,D3   * reset D3
            SWAP    D3
            LSL.L   #7,D3   * shift 7 leading bits out
            JSR     BitTst3 * test destination mode
            CMPI.B  #%000,D6
            BEQ     moveDn          * move to data register
            CMPI.B  #%010,D6
            BEQ     moveInd         * move to indirect address
            CMPI.B  #%011,D6
            BEQ     movePost        * move to indirect address with post increment
            CMPI.B  #%100,D6
            BEQ     movePre         * move to indirect address with pre decrement
            CMPI.B  #%111,D6
            BEQ     moveAbs         * move to absolute address

            BRA     OPERROR 
            
            RTS
            
_MoveAl     MOVEA.L A2,A3       * copy current address of A2 string to A3
            * store MOVE.B into the A2 string
            MOVE.B  #'M',(A2)+
            MOVE.B  #'O',(A2)+
            MOVE.B  #'V',(A2)+
            MOVE.B  #'E',(A2)+ 
            MOVE.B  #'A',(A2)+ 
            MOVE.B  #'.',(A2)+ 
            MOVE.B  #'L',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+
            

            * get EA for source
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            
            MOVE.B  #',',(A2)+
            * get destination register
            BRA     moveAddr
            
            RTS

* MOVE.W/MOVEA.W ----------------------------------------

op0011
            
            SWAP    D3
            LSL.L   #7,D3       * shift out op code and dest register
            MOVE.B  #2,D7       * move 2 into d7 to indicate word
            JSR     BitTst3     
            CMPI.B  #%001,D6    * if dest mode is address, branch to MOVEA
            BEQ     _MoveAw     * go to MOVEA.W
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            * store MOVE.B into the A2 string
            MOVE.B  #'M',(A2)+
            MOVE.B  #'O',(A2)+
            MOVE.B  #'V',(A2)+
            MOVE.B  #'E',(A2)+ 
            MOVE.B  #'.',(A2)+ 
            MOVE.B  #'W',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+
            
            * get EA for source
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            
            MOVE.B  #',',(A2)+
            * look at destination
            MOVE.L  D4,D3   * reset D3
            SWAP    D3
            LSL.L   #7,D3   * shift 7 leading bits out
            JSR     BitTst3 * test destination mode
            CMPI.B  #%000,D6
            BEQ     moveDn          * move to data register
            CMPI.B  #%010,D6
            BEQ     moveInd         * move to indirect address
            CMPI.B  #%011,D6
            BEQ     movePost        * move to indirect address with post increment
            CMPI.B  #%100,D6
            BEQ     movePre         * move to indirect address with pre decrement
            CMPI.B  #%111,D6
            BEQ     moveAbs         * move to absolute address

            BRA     OPERROR 

            RTS
            
_MoveAw     MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'M',(A2)+
            MOVE.B  #'O',(A2)+
            MOVE.B  #'V',(A2)+
            MOVE.B  #'E',(A2)+ 
            MOVE.B  #'A',(A2)+ 
            MOVE.B  #'.',(A2)+ 
            MOVE.B  #'W',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+ 
            MOVE.B  #' ',(A2)+
            
            * get EA for source
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            MOVE.B  #',',(A2)+
            BRA     moveAddr

            RTS

*********************************************************************************
* MOVE destination functions
*********************************************************************************

* Move to data register ----------------
moveDn
            MOVE.B  #'D',(A2)+      * print D
                
            MOVE.L  D4,D3           * reset D3
            SWAP    D3              * swap to front
            LSL.L   #4,D3           * shift out opcode
            JSR     BitTst3         * get register number
            
            LEA     numTable,A6     * load num table
            MULU    #8,D6           * offset for table
            JSR     (A6,D6)         * print the data
            
            RTS
            
* Move to address register -------------
moveAddr
            MOVE.B  #'A',(A2)+      * print A
            
            MOVE.L  D4,D3           * reset D3
            SWAP    D3              * swap to front
            LSL.L   #4,D3           * shift out opcode
            JSR     BitTst3         * get register number
            
            LEA     numTable,A6     * load num table
            MULU    #8,D6           * offset for table
            JSR     (A6,D6)         * add data to A2 string
            
            RTS
            
* Move to address register indirect ----
moveInd     
            MOVE.B  #'(',(A2)+  * print (A
            MOVE.B  #'A',(A2)+
            
            MOVE.L  D4,D3       * reset D3
            SWAP    D3          * swap to front
            LSL.L   #4,D3       * shift out opcode
            JSR     BitTst3     * get register number
            
            LEA     numTable,A6 * load num table
            MULU    #8,D6       * offset for table
            JSR     (A6,D6)     * print data
            
            MOVE.B  #')',(A2)+  * finish with )
            
            RTS
            
* Move to address post increment -------
movePost    
            MOVE.B  #'(',(A2)+
            MOVE.B  #'A',(A2)+
            
            MOVE.L  D4,D3
            SWAP    D3
            LSL.L   #4,D3
            JSR     BitTst3
            
            LEA     numTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            
            MOVE.B  #')',(A2)+
            MOVE.B  #'+',(A2)+
            
            RTS

* Move to address pre decrement --------
movePre
            MOVE.B  #'-',(A2)+
            MOVE.B  #'(',(A2)+
            MOVE.B  #'A',(A2)+
            
            MOVE.L  D4,D3
            SWAP    D3
            LSL.L   #4,D3
            JSR     BitTst3
            
            LEA     numTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            
            MOVE.B  #')',(A2)+
            
            RTS
* Move to absolute address -------------
moveAbs     
            MOVE.B  #'$',(A2)+  * add $ to A2 string
            MOVE.L  D4,D3
            SWAP    D3
            LSL.L   #4,D3   * shift out opcode
            JSR     BitTst3 * check next three bits
            
            CMPI.B  #%000,D6
            BEQ     printWord
            CMPI.B  #%001,D6
            BEQ     printLong

            JSR     OPERROR       
            
 * MOVEM, LEA, CLR, JSR, RTS, NOP ------------------------------------------------------
op0100 
            CMP.W   #$4EB9,D3   * compare to JSR code
            BEQ     jumpSR
            CMP.W   #$4E75,D3   * compare to RTS code
            BEQ     returnSR
            CMP.W   #$4E71,D3   * compare to NOP code
            BEQ     noOp
            SWAP    D3          * swap D3 to check for bits
            LSL.L   #7,D3       * shift 7 bits out to check for lea/movem instruction
            *LEA has the form |opcode|An|111|...
            JSR     BitTst3
            CMP.B   #%111,D6    * if the next 3 bits match 111,
            BEQ     _lea        * branch to lea
            
            MOVE.L  D4,D3   * reset D3
            SWAP    D3
            LSL.L   #4,D3   * shift out op code
            JSR     BITTEST
            *MOVEM has form |opcode|1D0|01S|.. where S = size
            CMP.B   #%1000,D6    * if next 4 bits match 1000, it is a MOVEM
            BEQ     _MoveM
            CMP.B   #%1100,D6    * if next 4 bits match 1100, it is a MOVEM
            BEQ     _MoveM
            
            CMP.B   #%0010,D6 * if 0010, it is a clear instruction,
            BEQ     _clr      * since lea/movem/jsr/rts have been handled
            
            BRA     OPERROR
            * if it isnt any of these == error/not supported           

* JSR ------------------------------------------------------------------------------
jumpSR
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #3,D7       * indicate long word instruction
            MOVE.B  #'J',(A2)+
            MOVE.B  #'S',(A2)+
            MOVE.B  #'R',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            
            JSR     getMode
            CMPI.B  #%110,D6    * addressing with index which isnt supported
            BEQ     OPERROR
            
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed for dest, error
            
            * no errors
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            
            RTS

* RTS ------------------------------------------------------------------------------            
returnSR    MOVE.B  #'R',(A2)+
            MOVE.B  #'T',(A2)+
            MOVE.B  #'S',(A2)+
            RTS
            
* NOP ------------------------------------------------------------------------------
noOp        MOVE.B  #'N',(A2)+
            MOVE.B  #'O',(A2)+
            MOVE.B  #'P',(A2)+
            RTS            
            
* LEA ------------------------------------------------------------------------------
_lea
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #3,D7       * indicate longword instruction
            MOVE.B  #'L',(A2)+
            MOVE.B  #'E',(A2)+
            MOVE.B  #'A',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            *get EA mode
            JSR     getMode
            * modes not allowed: Dn, An, (An)+, -(An), #<data>
            CMPI.B  #%000,D6
            BEQ     OPERROR     * Dn
            CMPI.B  #%001,D6
            BEQ     OPERROR     * An
            CMPI.B  #%011,D6
            BEQ     OPERROR     * (An)+
            CMPI.B  #%100,D6
            BEQ     OPERROR     * -(An)
            
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed for dest, error
            
            * no errors
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            
            MOVE.B  #',',(A2)+
            MOVE.B  #'A',(A2)+
            MOVE.L  D4,D3       * reset D3
            SWAP    D3          * set D3 to front
            LSL.L   #4,D3       * shift out opcode
            JSR     BitTst3     * check 3 bits for register number
            
            MULU    #8,D6       * offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * get the number from table and print
                       
            RTS
* MOVEM ------------------------------------------------------------------------------
_MoveM     
            JSR     BitTst3     * check bits 9-11 for mode of MOVEM
            MOVE.L  D4,D3       * reset D3
            CMPI.B  #%100,D6    * 100 indicates reg to mem
            BEQ     _MoveMDn
            CMPI.B  #%110,D6    * 110 indicates mem to reg
            BEQ     _MoveMAn

_MoveMDn
            * test the size bit of MOVEM
            BTST.L  #$06,D3
            BNE     _MoveMDnL  * default to word size
* MOVEM.W --------------------
            MOVE.B  #'M',(A2)+
            MOVE.B  #'O',(A2)+
            MOVE.B  #'V',(A2)+
            MOVE.B  #'E',(A2)+
            MOVE.B  #'M',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'W',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            
            JSR     PreDec  * print register list
                       
            MOVE.B  #',',(A2)+
            
            JSR     getMode
            CMPI.B  #%001,D6
            BLE     OPERROR     * Dn and An illegal
            CMPI.B  #%011,D6
            BEQ     OPERROR     * (An)+ illegal with this mode
            
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
         
            RTS

* MOVEM.L --------------------
_MoveMDnL   * it is long type
            MOVE.B  #'M',(A2)+
            MOVE.B  #'O',(A2)+
            MOVE.B  #'V',(A2)+
            MOVE.B  #'E',(A2)+
            MOVE.B  #'M',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
           
            JSR     PreDec   * print register list 
            
            MOVE.B  #',',(A2)+
            
            JSR     getMode
            CMPI.B  #%001,D6
            BLE     OPERROR     * Dn and An illegal
            CMPI.B  #%011,D6
            BEQ     OPERROR     * (An)+ illegal with this mode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR        
            RTS 

_MoveMAn    * test the size bit of MOVEM
            BTST.L  #$06,D3
            BNE     _MoveMAnL
            * default to word size
* MOVEM.W --------------------
            MOVE.B  #'M',(A2)+
            MOVE.B  #'O',(A2)+
            MOVE.B  #'V',(A2)+
            MOVE.B  #'E',(A2)+
            MOVE.B  #'M',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'W',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            
            JSR     PostInc     * print list
            
            MOVE.B  #',',(A2)+
            
            JSR     getMode
            CMPI.B  #%001,D6
            BLE     OPERROR     * Dn and An illegal
            CMPI.B  #%100,D6
            BEQ     OPERROR     * -(An) illegal with this mode
            
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            
            RTS
            
* MOVEM.L --------------------            
_MoveMAnL   
            MOVE.B  #'M',(A2)+
            MOVE.B  #'O',(A2)+
            MOVE.B  #'V',(A2)+
            MOVE.B  #'E',(A2)+
            MOVE.B  #'M',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            
            JSR     PostInc   * print list
            
            MOVE.B  #',',(A2)+
            JSR     getMode
            CMPI.B  #%001,D6
            BLE     OPERROR     * Dn and An illegal
            CMPI.B  #%100,D6
            BEQ     OPERROR     * -(An) illegal with this mode
            
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            
            RTS
            
PostInc
            MOVE.W  (A4),D3     * move the next word into D3
            
            BTST.L  #$00,D3     * D0
            BNE     _d0
            
Pi_d1       BTST.L  #$01,D3     * D1
            BNE     _d1
Pi_d2       BTST.L  #$02,D3     * D2
            BNE     _d2
Pi_d3       BTST.L  #$03,D3     * D3
            BNE     _d3
Pi_d4       BTST.L  #$04,D3     * D4
            BNE     _d4
Pi_d5       BTST.L  #$05,D3     * D5
            BNE     _d5
Pi_d6       BTST.L  #$06,D3     * D6
            BNE     _d6
Pi_d7       BTST.L  #$07,D3     * D7
            BNE     _d7
Pi_a0       BTST.L  #$08,D3     * A0
            BNE     _a0
Pi_a1       BTST.L  #$09,D3     * A1
            BNE     _a1
Pi_a2       BTST.L  #$0A,D3     * A2
            BNE     _a2
Pi_a3       BTST.L  #$0B,D3     * A3
            BNE     _a3
Pi_a4       BTST.L  #$0C,D3     * A4
            BNE     _a4
Pi_a5       BTST.L  #$0D,D3     * A5
            BNE     _a5
Pi_a6       BTST.L  #$0E,D3     * A6
            BNE     _a6
Pi_a7       BTST.L  #$0F,D3     * A7
            BNE     _a7

            RTS
            
_d0         MOVE.B  #'D',(A2)+
            MOVE.B  #'0',(A2)+
            MOVE.B  #1,D0        * move flag for first register
            BRA     Pi_d1

_d1         JSR     printSlash
            MOVE.B  #'D',(A2)+
            MOVE.B  #'1',(A2)+
            MOVE.B  #1,D0        * move flag for first register
            BRA     Pi_d2

_d2         JSR     printSlash
            MOVE.B  #'D',(A2)+
            MOVE.B  #'2',(A2)+
            MOVE.B  #1,D0        * move flag for first register
            BRA     Pi_d3

_d3         JSR     printSlash
            MOVE.B  #'D',(A2)+
            MOVE.B  #'3',(A2)+
            MOVE.B  #1,D0        * move flag for first register
            BRA     Pi_d4

_d4         JSR     printSlash
            MOVE.B  #'D',(A2)+
            MOVE.B  #'4',(A2)+
            MOVE.B  #1,D0        * move flag for first register
            BRA     Pi_d5

_d5         JSR     printSlash
            MOVE.B  #'D',(A2)+
            MOVE.B  #'5',(A2)+
            MOVE.B  #1,D0        * move flag for first register
            BRA     Pi_d6

_d6         JSR     printSlash
            MOVE.B  #'D',(A2)+
            MOVE.B  #'6',(A2)+
            MOVE.B  #1,D0        * move flag for first register
            BRA     Pi_d7

_d7         JSR     printSlash
            MOVE.B  #'D',(A2)+
            MOVE.B  #'7',(A2)+
            MOVE.B  #1,D0        * move flag for first register
            BRA     Pi_a0

_a0         JSR     printSlash
            MOVE.B  #'A',(A2)+
            MOVE.B  #'0',(A2)+
            MOVE.B  #1,D0        * move flag for first register
            BRA     Pi_a1

_a1         JSR     printSlash
            MOVE.B  #'A',(A2)+
            MOVE.B  #'1',(A2)+
            MOVE.B  #1,D0        * move flag for first register
            BRA     Pi_a2

_a2         JSR     printSlash
            MOVE.B  #'A',(A2)+
            MOVE.B  #'2',(A2)+
            MOVE.B  #1,D0        * move flag for first register
            BRA     Pi_a3

_a3         JSR     printSlash
            MOVE.B  #'A',(A2)+
            MOVE.B  #'3',(A2)+
            MOVE.B  #1,D0        * move flag for first register
            BRA     Pi_a4

_a4         JSR     printSlash
            MOVE.B  #'A',(A2)+
            MOVE.B  #'4',(A2)+
            MOVE.B  #1,D0        * move flag for first register
            BRA     Pi_a5

_a5         JSR     printSlash
            MOVE.B  #'A',(A2)+
            MOVE.B  #'5',(A2)+
            MOVE.B  #1,D0        * move flag for first register
            BRA     Pi_a6

_a6         JSR     printSlash
            MOVE.B  #'A',(A2)+
            MOVE.B  #'6',(A2)+
            MOVE.B  #1,D0        * move flag for first register
            BRA     Pi_a7

_a7         JSR     printSlash
            MOVE.B  #'A',(A2)+
            MOVE.B  #'7',(A2)+
            RTS
            
            
PreDec
            MOVE.W  (A4),D3     * move the next word into D3
            
            BTST.L  #$00,D3     * A0
            BNE     _PDa0
            
Pd_a1       BTST.L  #$01,D3     * A1
            BNE     _PDa1
Pd_a2       BTST.L  #$02,D3     * A2
            BNE     _PDa2
Pd_a3       BTST.L  #$03,D3     * A3
            BNE     _PDa3
Pd_a4       BTST.L  #$04,D3     * A4
            BNE     _PDa4
Pd_a5       BTST.L  #$05,D3     * A5
            BNE     _PDa5
Pd_a6       BTST.L  #$06,D3     * A6
            BNE     _PDa6
Pd_a7       BTST.L  #$07,D3     * A7
            BNE     _PDa7
Pd_d0       BTST.L  #$08,D3     * D0
            BNE     _PDd0
Pd_d1       BTST.L  #$09,D3     * D1
            BNE     _PDd1
Pd_d2       BTST.L  #$0A,D3     * D2
            BNE     _PDd2
Pd_d3       BTST.L  #$0B,D3     * D3
            BNE     _PDd3
Pd_d4       BTST.L  #$0C,D3     * D4
            BNE     _PDd4
Pd_d5       BTST.L  #$0D,D3     * D5
            BNE     _PDd5
Pd_d6       BTST.L  #$0E,D3     * D6
            BNE     _PDd6
Pd_d7       BTST.L  #$0F,D3     * D7
            BNE     _PDd7

            RTS
            
            
_PDd0         MOVE.B  #'D',(A2)+
            MOVE.B  #'0',(A2)+
            MOVE.B  #1,D0        * move flag for first register
            BRA     Pd_d1

_PDd1         JSR     printSlash
            MOVE.B  #'D',(A2)+
            MOVE.B  #'1',(A2)+
            MOVE.B  #1,D0        * move flag for first register
            BRA     Pd_d2

_PDd2         JSR     printSlash
            MOVE.B  #'D',(A2)+
            MOVE.B  #'2',(A2)+
            MOVE.B  #1,D0        * move flag for first register
            BRA     Pd_d3

_PDd3         JSR     printSlash
            MOVE.B  #'D',(A2)+
            MOVE.B  #'3',(A2)+
            MOVE.B  #1,D0        * move flag for first register
            BRA     Pd_d4

_PDd4         JSR     printSlash
            MOVE.B  #'D',(A2)+
            MOVE.B  #'4',(A2)+
            MOVE.B  #1,D0        * move flag for first register
            BRA     Pd_d5

_PDd5         JSR     printSlash
            MOVE.B  #'D',(A2)+
            MOVE.B  #'5',(A2)+
            MOVE.B  #1,D0        * move flag for first register
            BRA     Pd_d6

_PDd6         JSR     printSlash
            MOVE.B  #'D',(A2)+
            MOVE.B  #'6',(A2)+
            MOVE.B  #1,D0        * move flag for first register
            BRA     Pd_d7

_PDd7         JSR     printSlash
            MOVE.B  #'D',(A2)+
            MOVE.B  #'7',(A2)+
            MOVE.B  #1,D0        * move flag for first register
            

_PDa0         JSR     printSlash
            MOVE.B  #'A',(A2)+
            MOVE.B  #'0',(A2)+
            MOVE.B  #1,D0        * move flag for first register
            BRA     Pd_a1

_PDa1         JSR     printSlash
            MOVE.B  #'A',(A2)+
            MOVE.B  #'1',(A2)+
            MOVE.B  #1,D0        * move flag for first register
            BRA     Pd_a2

_PDa2         JSR     printSlash
            MOVE.B  #'A',(A2)+
            MOVE.B  #'2',(A2)+
            MOVE.B  #1,D0        * move flag for first register
            BRA     Pd_a3

_PDa3         JSR     printSlash
            MOVE.B  #'A',(A2)+
            MOVE.B  #'3',(A2)+
            MOVE.B  #1,D0        * move flag for first register
            BRA     Pd_a4

_PDa4         JSR     printSlash
            MOVE.B  #'A',(A2)+
            MOVE.B  #'4',(A2)+
            MOVE.B  #1,D0        * move flag for first register
            BRA     Pd_a5

_PDa5         JSR     printSlash
            MOVE.B  #'A',(A2)+
            MOVE.B  #'5',(A2)+
            MOVE.B  #1,D0        * move flag for first register
            BRA     Pd_a6

_PDa6         JSR     printSlash
            MOVE.B  #'A',(A2)+
            MOVE.B  #'6',(A2)+
            MOVE.B  #1,D0        * move flag for first register
            BRA     Pd_a7

_PDa7         JSR     printSlash
            MOVE.B  #'A',(A2)+
            MOVE.B  #'7',(A2)+
            BRA     Pd_d7
            RTS

       
printSlash
            CMPI.B  #1,D0       * see if a register has been added to the list
            BNE     prtSlashDn    * if not, do not add slash
            MOVE.B  #'/',(A2)+      * else add slash
prtSlashDn  RTS
            
            
            
                                               

* CLR ------------------------------------------------------------------------------
_clr        LSL.L   #4,D3   * shift out 4 bits to isolate size bit on the front
            JSR     BitTst2
            LSL.L   #2,D3   * shift out 2 size bits for error checking
            CMPI.B  #%00,D6
            BEQ     _clrB   * CLR.B
            CMPI.B  #%01,D6
            BEQ     _clrW   * CLR.W
            CMPI.B  #%10,D6
            BEQ     _clrL   * CLR.L
            
* CLR.B ----------------------
_clrB       
            MOVE.B  #1,D7       * indicate a byte instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'C',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #'R',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'B',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            
            * get EA 
            JSR     getMode
            CMPI.B  #%001,D6    * cant clear address registers
            BEQ     OPERROR     * branch to error
            
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
            
            * no errors so get the mode again and load the EA table
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            RTS
            
* CLR.W ----------------------            
_clrW       
            MOVE.B  #2,D7       * indicate a word instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'C',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #'R',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'W',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            * get EA 
            JSR     getMode
            CMPI.B  #%001,D6    * cant clear address registers
            BEQ     OPERROR     * branch to error
            
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
            
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            RTS
            
* CLR.L ----------------------            
_clrL      
            MOVE.B  #3,D7       * indicate a long instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'C',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #'R',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            * get EA 
            JSR     getMode
            CMPI.B  #%001,D6    * cant clear address registers
            BEQ     OPERROR     * branch to error
            
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
            
            * no errors so get the mode again and load the EA table
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            
            RTS

* ADDQ, SUBQ --------------------------------------------------------------------
op0101      
            BTST.L  #$08,D3 * test the 8th bit to check for ADDQ or SUBQ
            BNE   _SubQ   * if 8th bit == 1, it is SUBQ instruction
            * else proceed as if it is an ADDQ instruction
            SWAP    D3
            LSL.L   #8,D3   * shift out opcode & data to check for size
            JSR     BitTst2
            MOVE.L  D4,D3   * reset D3
            SWAP    D3      * send bits to front
            LSL.L   #4,D3   * shift out opcode
            CMPI.B  #%00,D6  * go to ADDQ.B
            BEQ     _AddQb
            CMPI.B  #%01,D6  * go to ADDQ.W
            BEQ     _AddQw
            CMPI.B  #%10,D6  * go to ADDQ.L
            BEQ     _AddQl
            
            * something unexpected/unsupported
            BRA     OPERROR
            
_AddQb      
            MOVE.B  #1,D7       * indicate a byte instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'A',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.B  #'Q',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'B',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #'#',(A2)+
            
            JSR     BitTst3     * get the data value
            CMPI.B  #%000,D6    * if it is 000, add 8
            BNE     AddQb       * if not, continue to next part
            JSR     Add8
AddQb       MULU    #8,D6       * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * jump to table
                
            MOVE.B  #',',(A2)+  * print comma
            
            JSR     getMode     * get EA mode
            
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error

            JSR     getMode
            MULU    #8,D6       * multiply for offset
            LEA     eaTable,A6  * load e table
            JSR     (A6,D6)     * jump to table
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            
            RTS

_AddQw      
            MOVE.B  #2,D7       * indicate a word instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'A',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.B  #'Q',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'W',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #'#',(A2)+
            
            JSR     BitTst3     * get the data value
            CMPI.B  #%000,D6    * if it is 000, add 8
            BNE     AddQw       * if not, continue to next part
            JSR     Add8
AddQw       MULU    #8,D6       * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * jump to table
                
            MOVE.B  #',',(A2)+  * print comma
            
            JSR     getMode     * get EA mode
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
            
            JSR     getMode
            MULU    #8,D6       * multiply for offset
            LEA     eaTable,A6  * load e table
            JSR     (A6,D6)     * jump to table
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            RTS
            
_AddQl      
            MOVE.B  #3,D7       * indicate a long instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'A',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.B  #'Q',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #'#',(A2)+
            
            JSR     BitTst3     * get the data value
            CMPI.B  #%000,D6    * if it is 000, add 8
            BNE     AddQl       * if not, continue to next part
            JSR     Add8
AddQl       MULU    #8,D6       * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * jump to table
                
            MOVE.B  #',',(A2)+  * print comma
            
            JSR     getMode     * get EA mode
            
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
            
            JSR     getMode
            MULU    #8,D6       * multiply for offset
            LEA     eaTable,A6  * load e table
            JSR     (A6,D6)     * jump to table
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            
            RTS
            
* SUBQ ------------------------------------------------------------------------------            
_SubQ       
            SWAP    D3
            LSL.L   #8,D3   * shift out opcode & data to check for size
            JSR     BitTst2
            MOVE.L  D4,D3   * reset D3
            SWAP    D3
            LSL.L   #4,D3   * shift out opcode
            CMPI.B  #%00,D6  * go to SUBQ.B
            BEQ     _SubQb
            CMPI.B  #%01,D6  * go to SUBQ.W
            BEQ     _SubQw
            CMPI.B  #%10,D6  * go to SUBQ.L
            BEQ     _SubQl
            
            * something unexpected/unsupported
            BRA     OPERROR
            
_SubQb      
            MOVE.B  #1,D7       * indicate a byte instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'S',(A2)+
            MOVE.B  #'U',(A2)+
            MOVE.B  #'B',(A2)+
            MOVE.B  #'Q',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'B',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #'#',(A2)+
            
            JSR     BitTst3     * get the data value
            CMPI.B  #%000,D6    * if it is 000, add 8
            BNE     SubQb       * if not, continue to next part
            JSR     Add8
SubQb       MULU    #8,D6       * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * jump to table
                
            MOVE.B  #',',(A2)+  * print comma
            
            JSR     getMode     * get EA mode
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
            
            JSR     getMode
            MULU    #8,D6       * multiply for offset
            LEA     eaTable,A6  * load e table
            JSR     (A6,D6)     * jump to table
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            RTS

_SubQw       
            MOVE.B  #2,D7       * indicate a word instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'S',(A2)+
            MOVE.B  #'U',(A2)+
            MOVE.B  #'B',(A2)+
            MOVE.B  #'Q',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'W',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #'#',(A2)+
            JSR     BitTst3     * get the data value
            CMPI.B  #%000,D6    * if it is 000, add 8
            BNE     SubQw       * if not, continue to next part
            JSR     Add8
SubQw       MULU    #8,D6       * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * jump to table
                
            MOVE.B  #',',(A2)+  * print comma
            
            JSR     getMode     * get EA mode
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
    
            JSR     getMode
            MULU    #8,D6       * multiply for offset
            LEA     eaTable,A6  * load e table
            JSR     (A6,D6)     * jump to table
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            
            RTS

_SubQl      
            MOVE.B  #3,D7       * indicate a long instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'S',(A2)+
            MOVE.B  #'U',(A2)+
            MOVE.B  #'B',(A2)+
            MOVE.B  #'Q',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #'#',(A2)+
            
            JSR     BitTst3     * get the data value
            CMPI.B  #%000,D6    * if it is 000, add 8
            BNE     SubQl       * if not, continue to next part
            JSR     Add8
SubQl       MULU    #8,D6       * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * jump to table
                
            MOVE.B  #',',(A2)+  * print comma
            
            JSR     getMode     * get EA mode
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
    
            JSR     getMode
            MULU    #8,D6       * multiply for offset
            LEA     eaTable,A6  * load e table
            JSR     (A6,D6)     * jump to table
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            
            RTS
**************************************************************************************
* Add 8 - subroutine that adds 8 if the data value in instruction code is 000.
* Used for SUBQ and ADDQ.
**************************************************************************************
Add8        
            ADDI.B  #8,D6   * add 8 to d6
            RTS             * return
 
* Bcc (BRA/BCC/BLT/BGE) --------------------------------------------------------------
op0110      
            SWAP    D3
            LSL.L   #4,D3        * shift out opcode
            JSR     BITTEST      * test next four bits for condition
            CMPI.B  #%0000,D6
            BEQ     _Bra         * check BRA condition
            CMPI.B  #%0100,D6
            BEQ     _Bcc         * check BCC condition
            CMPI.B  #%0101,D6
            BEQ     _Bcs         * check BCS condition
            CMPI.B  #%0110,D6
            BEQ     _Bne         * check BNE condition
            CMPI.B  #%1100,D6
            BEQ     _Bge         * check BGE condition
            CMPI.B  #%1101,D6
            BEQ     _Blt         * check BLT condition
            CMPI.B  #%1110,D6
            BEQ     _Bgt         * check BGT condition
            CMPI.B  #%1111,D6
            BEQ     _Ble         * check BLE condition
            
            * branch to unsupported/error
            BRA     OPERROR
            
* BRA ------------------------
_Bra        MOVE.B  #'B',(A2)+      * add BRA to A2 string
            MOVE.B  #'R',(A2)+
            MOVE.B  #'A',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #'$',(A2)+
            CLR     D3
            MOVE.B  D4,D3
            CMPI.B  #$00,D3     * branch of 16 bit offset
            BEQ     _WordDisp
            CMPI.B  #$FF,D3     * branch of 32 bit offset
            BEQ     _LongDisp
            BRA     _ByteDisp   * branch defaults to 8 bit offset
            
* BCC ------------------------
_Bcc        MOVE.B  #'B',(A2)+      * add BCC to A2 String
            MOVE.B  #'C',(A2)+
            MOVE.B  #'C',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #'$',(A2)+
            CLR     D3
            MOVE.B  D4,D3
            CMPI.B  #$00,D3     * branch of 16 bit offset
            BEQ     _WordDisp
            CMPI.B  #$FF,D3     * branch of 32 bit offset
            BEQ     _LongDisp
            BRA     _ByteDisp   * branch defaults to 8 bit offset
            
* BCS ------------------------
_Bcs
            MOVE.B  #'B',(A2)+      * add BCS to A2 string
            MOVE.B  #'C',(A2)+
            MOVE.B  #'S',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #'$',(A2)+
            CLR     D3
            MOVE.B  D4,D3
            CMPI.B  #$00,D3     * branch of 16 bit offset
            BEQ     _WordDisp
            CMPI.B  #$FF,D3     * branch of 32 bit offset
            BEQ     _LongDisp
            BRA     _ByteDisp   * branch defaults to 8 bit offset
            
* BNE ------------------------
_Bne  
            MOVE.B  #'B',(A2)+      * add BNE to A2 string
            MOVE.B  #'R',(A2)+
            MOVE.B  #'A',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #'$',(A2)+
            CLR     D3
            MOVE.B  D4,D3
            CMPI.B  #$00,D3     * branch of 16 bit offset
            BEQ     _WordDisp
            CMPI.B  #$FF,D3     * branch of 32 bit offset
            BEQ     _LongDisp
            BRA     _ByteDisp   * branch defaults to 8 bit offset 
            
* BGE ------------------------
_Bge        MOVE.B  #'B',(A2)+      * add BGE to A2 string
            MOVE.B  #'G',(A2)+
            MOVE.B  #'E',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #'$',(A2)+
            CLR     D3
            MOVE.B  D4,D3
            CMPI.B  #$00,D3     * branch of 16 bit offset
            BEQ     _WordDisp
            CMPI.B  #$FF,D3     * branch of 32 bit offset
            BEQ     _LongDisp
            BRA     _ByteDisp   * branch defaults to 8 bit offset
            
            
* BLT ------------------------
_Blt        MOVE.B  #'B',(A2)+      * add BLT to A2 String
            MOVE.B  #'L',(A2)+
            MOVE.B  #'T',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #'$',(A2)+
            CLR     D3
            MOVE.B  D4,D3
            CMPI.B  #$00,D3     * branch of 16 bit offset
            BEQ     _WordDisp
            CMPI.B  #$FF,D3     * branch of 32 bit offset
            BEQ     _LongDisp
            BRA     _ByteDisp   * branch defaults to 8 bit offset
            
* BGT -------------------------            
_Bgt
            MOVE.B  #'B',(A2)+      * add BGT to A2 string
            MOVE.B  #'R',(A2)+
            MOVE.B  #'A',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #'$',(A2)+
            CLR     D3
            MOVE.B  D4,D3
            CMPI.B  #$00,D3     * branch of 16 bit offset
            BEQ     _WordDisp
            CMPI.B  #$FF,D3     * branch of 32 bit offset
            BEQ     _LongDisp
            BRA     _ByteDisp   * branch defaults to 8 bit offset
* BLE -------------------------
_Ble
            MOVE.B  #'B',(A2)+      * add BLE to A2 string
            MOVE.B  #'L',(A2)+
            MOVE.B  #'E',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #'$',(A2)+
            CLR     D3
            MOVE.B  D4,D3
            CMPI.B  #$00,D3     * branch of 16 bit offset
            BEQ     _WordDisp
            CMPI.B  #$FF,D3     * branch of 32 bit offset
            BEQ     _LongDisp
            BRA     _ByteDisp   * branch defaults to 8 bit offset

**************************************************************************
* Functions that handle the different types of displacements for a branch
**************************************************************************
* Displacement is a word length
_WordDisp
            JSR     printWord
            RTS
* Displacement is long length
_LongDisp
            JSR     printLong
            RTS
* Displacement is byte length
_ByteDisp  
            CLR     D2
            LEA     numTable,A6
            SWAP    D3
            LSL.L   #8,D3
            
ByteDispLp  CMPI.B  #2,D2       * loop through twice,
            BEQ     dispDone    * print done
            JSR     BITTEST     * get leading 4 bits
            MULU    #8,D6       * multiply by 8 for jump offset 
            JSR     (A6,D6)     * get number from table and add to A2 string
            LSL.L   #4,D3       * shift out the 4 bits were done with
            ADDQ    #1,D2       * increment loop counter
            BRA     ByteDispLp  
            
dispDone    RTS
             
* MOVEQ ---------------------------------------------------------------------------
op0111      
            MOVE.B  #'M',(A2)+      * add MOVEQ to A2 String
            MOVE.B  #'O',(A2)+
            MOVE.B  #'V',(A2)+
            MOVE.B  #'E',(A2)+
            MOVE.B  #'Q',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #'#',(A2)+
            MOVE.B  #'$',(A2)+
            JSR     _ByteDisp       * print byte data of MOVEQ instruction
            MOVE.B  #',',(A2)+      * print comma
            MOVE.B  #'D',(A2)+      * print D
            MOVE.L  D4,D3
            SWAP    D3
            LSL.L   #4,D3           * shift out opcode
            JSR     BitTst3         * get bits 9->11 for data register
            MULU    #8,D6           * multiply for offset 
            LEA     numTable,A6     * load num table
            JSR     (A6,D6)         * get number and print
            RTS 
           
* DIVU, DIVS, OR ------------------------------------------------------------------
op1000      
            SWAP    D3  
            LSL.L   #7,D3   * shift out opcode & dest register
            JSR     BitTst3     * check the next three bits
            CMPI.B  #%011,D6    * they are fixed for divu/divs
            BEQ     _DivU       * branch to divu if 011
            CMPI.B  #%111,D6
            BEQ     _DivS       * branch to divs if 111
            
            BRA     _Or     * its either OR or an error
            
* DIVU -----------------------            
_DivU       
            MOVE.B  #2,D7       * indicate a word instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'D',(A2)+      * add DIVU to A2 String
            MOVE.B  #'I',(A2)+
            MOVE.B  #'V',(A2)+
            MOVE.B  #'U',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            * get EA
            JSR     getMode     * get mode bits
            LEA     eaTable,A6   * load e table
            MULU    #8,D6       * offset
            JSR     (A6,D6)     * get EA and print
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
    
            MOVE.B  #',',(A2)+  * print comma
            MOVE.B  #'D',(A2)+  * print D
            MOVE.L  D4,D3       * reset D3
            SWAP    D3          * push bits to front
            LSL.L   #4,D3       * shift out opcode
            JSR     BitTst3     * get next three bits
            
            MULU    #8,D6
            LEA     numTable,A6
            JSR     (A6,D6)
            
            RTS
            
* DIVS -----------------------
_DivS       
            MOVE.B  #2,D7       * indicate a word instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'D',(A2)+      * add DIVS to A2 String
            MOVE.B  #'I',(A2)+
            MOVE.B  #'V',(A2)+
            MOVE.B  #'S',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            * get EA
            JSR     getMode 
            MOVE.B  #',',(A2)+  * print comma
            MOVE.B  #'D',(A2)+  * print D
            MOVE.L  D4,D3       * reset D3
            SWAP    D3
            LSL.L   #4,D3       * shift out opcode
            JSR     BitTst3     * get next three bits
            
            MULU    #8,D6
            LEA     numTable,A6
            JSR     (A6,D6)
            RTS
            
* OR -------------------------------------------------------------------------------
_Or         
            MOVE.L  D4,D3       * reset D3
            BTST.L  #$08,D3     * check 8th bit for ea mode
            BNE     _OrEA
            SWAP    D3          * swap it forward
            LSL.L   #8,D3       * shift out 8 bits so leading 2 bits are the size
            JSR     BitTst2     * get size bits in D6
            CMPI.B  #%00,D6     * check the size bit of D6 from previous test
            BEQ     _OrB        * OR.B
            CMPI.B  #%01,D6
            BEQ     _OrW        * OR.W
            CMPI.B  #%10,D6
            BEQ     _OrL        * OR.L
            
            BRA     OPERROR

* OR.B -----------------------            
_OrB        
            MOVE.B  #1,D7       * indicate a byte instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'O',(A2)+      * add OR.B to A2 String
            MOVE.B  #'R',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'B',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            * get EA
            JSR     getMode
            CMPI.B  #%001,D6    * source cannot be An
            BEQ     OPERROR
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
           
            * no errors
            JSR     getMode 
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            * destination must be data register
            MOVE.B  #',',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.L  D4,D3   * reset D3
            SWAP    D3
            LSL.L   #4,D3   * shift out opcode
            JSR     BitTst3 * get data register number
            MULU    #8,D6   * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * get number from table and print
            RTS
            
* OR.W -----------------------
_OrW        
            MOVE.B  #2,D7       * indicate a word instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'O',(A2)+      * add OR.W to A2 String
            MOVE.B  #'R',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'W',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            * get EA
            JSR     getMode
            CMPI.B  #%001,D6    * source cannot be An
            BEQ     OPERROR
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
            * no errors
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            * destination must be data register
            MOVE.B  #',',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.L  D4,D3   * reset D3
            SWAP    D3
            LSL.L   #4,D3   * shift out opcode
            JSR     BitTst3 * get data register number
            MULU    #8,D6   * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * get number from table and print
            RTS
            
* OR.L -----------------------
_OrL        
            MOVE.B  #3,D7       * indicate a word instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'O',(A2)+      * add OR.L to A2 String
            MOVE.B  #'R',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            * get EA
            JSR     getMode
            CMPI.B  #%001,D6    * source cannot be An
            BEQ     OPERROR
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
            
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            * destination must be data register
            MOVE.B  #',',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.L  D4,D3   * reset D3
            SWAP    D3
            LSL.L   #4,D3   * shift out opcode
            JSR     BitTst3 * get data register number
            MULU    #8,D6   * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * get number from table and print
            RTS
     
* Or to effective address ----------------------------------------------------       
_OrEA
            SWAP    D3          * swap it forward
            LSL.L   #8,D3       * shift out 8 bits so leading 2 bits are the size
            JSR     BitTst2     * get size bits in D6
            MOVE.L  D4,D3       * reset D3
            SWAP    D3
            CMPI.B  #%00,D6     * check the size bit of D6 from previous test
            BEQ     _OrB_EA        * OR.B
            CMPI.B  #%01,D6
            BEQ     _OrW_EA      * OR.W
            CMPI.B  #%10,D6
            BEQ     _OrL_EA     * OR.L

_OrB_EA     
            MOVE.B  #1,D7       * indicate a byte instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'O',(A2)+      * add OR.B to A2 String
            MOVE.B  #'R',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'B',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #'D',(A2)+  * starting source must be data register
            LSL.L   #4,D3   * shift out opcode
            JSR     BitTst3 * get data register number
            MULU    #8,D6   * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * get number from table and print
            MOVE.B  #',',(A2)+
            
            * get EA mode and check for errors
            JSR     getMode
            CMPI.B  #%001,D6    * cant write to An
            BEQ     OPERROR
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
            
            * no errors
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            RTS

_OrW_EA     
            MOVE.B  #2,D7       * indicate a word instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'O',(A2)+      * add OR.W to A2 String
            MOVE.B  #'R',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'W',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #'D',(A2)+  * starting source must be data register
            LSL.L   #4,D3   * shift out opcode
            JSR     BitTst3 * get data register number
            MULU    #8,D6   * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * get number from table and print
            MOVE.B  #',',(A2)+
            
            * get EA mode and check for errors
            JSR     getMode
            CMPI.B  #%001,D6    * cant write to An
            BEQ     OPERROR
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
            
            * no errors
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            RTS

_OrL_EA
            MOVE.B  #3,D7       * indicate a long instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'O',(A2)+      * add OR.W to A2 String
            MOVE.B  #'R',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'W',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #'D',(A2)+  * starting source must be data register
            LSL.L   #4,D3   * shift out opcode
            JSR     BitTst3 * get data register number
            MULU    #8,D6   * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * get number from table and print
            MOVE.B  #',',(A2)+
            
            * get EA mode and check for errors
            JSR     getMode
            CMPI.B  #%001,D6    * cant write to An
            BEQ     OPERROR
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
            
            * no errors
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            
            RTS

* SUB ------------------------------------------------------------------------            
op1001      BTST.L  #$08,D3
            BNE     Sub_EA  * <ea>*Dn -> <ea>
            SWAP    D3
            LSL.L   #8,D3   * shift leading 8 bits out to check size
            JSR     BitTst2
            CMPI.B  #%00,D6
            BEQ     _SubB   * SUB.B
            CMPI.B  #%01,D6
            BEQ     _SubW   * SUB.W
            CMPI.B  #%10,D6
            BEQ     _SubL   * SUB.L
            
            BRA     OPERROR
            
_SubB       
            MOVE.B  #1,D7       * indicate a byte instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3            
            MOVE.B  #'S',(A2)+      * add SUB.B to A2 String
            MOVE.B  #'U',(A2)+
            MOVE.B  #'B',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'B',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            * get EA
            JSR     getMode
            CMPI.B  #%001,D6    * source cannot be An
            BEQ     OPERROR
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, this is not allowed, error
            * no errors
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            * destination must be data register
            MOVE.B  #',',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.L  D4,D3   * reset D3
            SWAP    D3
            LSL.L   #4,D3   * shift out opcode
            JSR     BitTst3 * get data register number
            MULU    #8,D6   * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * get number from table and print

            RTS  

_SubW       
            MOVE.B  #2,D7       * indicate a word instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'S',(A2)+      * add SUB.W to A2 String
            MOVE.B  #'U',(A2)+
            MOVE.B  #'B',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'W',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            * get EA
            JSR     getMode
            CMPI.B  #%001,D6    * source cannot be An
            BEQ     OPERROR
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
            * no errors
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            * destination must be data register
            MOVE.B  #',',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.L  D4,D3   * reset D3
            SWAP    D3
            LSL.L   #4,D3   * shift out opcode
            JSR     BitTst3 * get data register number
            MULU    #8,D6   * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * get number from table and print

            RTS

_SubL       
            MOVE.B  #3,D7       * indicate a long instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'S',(A2)+      * add SUB.L to A2 String
            MOVE.B  #'U',(A2)+
            MOVE.B  #'B',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            * get EA
            JSR     getMode
            CMPI.B  #%001,D6    * source cannot be An
            BEQ     OPERROR
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
            * no errors
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            * destination must be data register
            MOVE.B  #',',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.L  D4,D3   * reset D3
            SWAP    D3
            LSL.L   #4,D3   * shift out opcode
            JSR     BitTst3 * get data register number
            MULU    #8,D6   * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * get number from table and print

            RTS

Sub_EA      
            SWAP    D3
            LSL.L   #8,D3   * shift leading 8 bits out to check size
            JSR     BitTst2
            MOVE.L  D4,D3   * reset D3
            SWAP    D3
            CMPI.B  #%00,D6
            BEQ     _SubB_EA   * SUB.B
            CMPI.B  #%01,D6
            BEQ     _SubW_EA   * SUB.W
            CMPI.B  #%10,D6
            BEQ     _SubL_EA   * SUB.L
            
_SubB_EA
            MOVE.B  #1,D7       * indicate a byte instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'S',(A2)+      * add OR.W to A2 String
            MOVE.B  #'U',(A2)+
            MOVE.B  #'B',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'B',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #'D',(A2)+  * starting source must be data register
            LSL.L   #4,D3   * shift out opcode
            JSR     BitTst3 * get data register number
            MULU    #8,D6   * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * get number from table and print
            MOVE.B  #',',(A2)+
            
            * get EA mode and check for errors
            JSR     getMode
            CMPI.B  #%001,D6    * cant write to An
            BEQ     OPERROR
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
            
            * no errors
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            
            RTS


_SubW_EA    
            MOVE.B  #2,D7       * indicate a word instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'S',(A2)+      * add OR.W to A2 String
            MOVE.B  #'U',(A2)+
            MOVE.B  #'B',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'W',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #'D',(A2)+  * starting source must be data register
            LSL.L   #4,D3   * shift out opcode
            JSR     BitTst3 * get data register number
            MULU    #8,D6   * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * get number from table and print
            MOVE.B  #',',(A2)+
            
            * get EA mode and check for errors
            JSR     getMode
            CMPI.B  #%001,D6    * cant write to An
            BEQ     OPERROR
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
            
            * no errors
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            
            RTS


_SubL_EA
            MOVE.B  #3,D7       * indicate a long instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'S',(A2)+      * add OR.W to A2 String
            MOVE.B  #'U',(A2)+
            MOVE.B  #'B',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #'D',(A2)+  * starting source must be data register
            LSL.L   #4,D3   * shift out opcode
            JSR     BitTst3 * get data register number
            MULU    #8,D6   * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * get number from table and print
            MOVE.B  #',',(A2)+
            
            * get EA mode and check for errors
            JSR     getMode
            CMPI.B  #%001,D6    * cant write to An
            BEQ     OPERROR
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
            
            * no errors
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            
            RTS


* CMP ---------------------------------------------------------------------------------
op1011      
            BTST.L  #$08,D3      * if 8th bit is 1, it is not CMP/CMPA
            BNE     OPERROR     * branch to unsupported
            SWAP    D3      * move bits forward
            LSL.L   #4,D3   * shift out opcode
            LSL.L   #4,D3   * shift out dest register & 8th bit
            JSR     BitTst2
            CMPI.B  #%00,D6 * check size bits
            BEQ     _CmpB   * CMP.B
            CMPI.B  #%01,D6
            BEQ     _CmpW   * CMP.W
            CMPI.B  #%10,D6
            BEQ     _CmpL   * CMP.L
            
            * CMPA/unexpected input, branch to error
            BRA     OPERROR
            
* CMP.B ----------------------            
_CmpB       
            MOVE.B  #1,D7       * indicate a byte instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'C',(A2)+      * add CMP.B to A2 String
            MOVE.B  #'M',(A2)+
            MOVE.B  #'P',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'B',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            * get EA to check for errors
            JSR     getMode
            CMPI.B  #%001,D6    * mode cannot be An
            BEQ     OPERROR
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
            * no errors
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            
            MOVE.B  #',',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.L  D4,D3   * reset D3
            SWAP    D3
            LSL.L   #4,D3   * shift out opcode
            JSR     BitTst3 * get data register number
            MULU    #8,D6   * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * get number from table and print
            
            RTS 
            
* CMP.W ----------------------
_CmpW       
            MOVE.B  #2,D7       * indicate a long instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'C',(A2)+      * add CMP.W to A2 String
            MOVE.B  #'M',(A2)+
            MOVE.B  #'P',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'W',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            * get EA to check for errors
            JSR     getMode
            CMPI.B  #%001,D6    * mode cannot be An
            BEQ     OPERROR
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
            * no errors
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            
            MOVE.B  #',',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.L  D4,D3   * reset D3
            SWAP    D3
            LSL.L   #4,D3   * shift out opcode
            JSR     BitTst3 * get data register number
            MULU    #8,D6   * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * get number from table and print

            RTS
* CMP.L ----------------------
_CmpL       
            MOVE.B  #3,D7       * indicate a long instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'C',(A2)+      * add CMP.L to A2 String
            MOVE.B  #'M',(A2)+
            MOVE.B  #'P',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            * get EA to check for errors
            JSR     getMode
            CMPI.B  #%001,D6    * mode cannot be An
            BEQ     OPERROR
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
            * no errors
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            
            MOVE.B  #',',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.L  D4,D3   * reset D3
            SWAP    D3
            LSL.L   #4,D3   * shift out opcode
            JSR     BitTst3 * get data register number
            MULU    #8,D6   * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * get number from table and print

            RTS
            
* MULS, AND --------------------------------------------------------------
op1100      
            SWAP    D3
            LSL.L   #8,D3   * shift out op code and next four bits
            JSR     BitTst2 * check next two bits for size/MUL instruction
            CMPI.B  #%11,D6 * if bits 6-7 are not 11, it is not a MUL
            BNE     _And    * branch to AND
            MOVE.L  D4,D3   * reset D3
            BTST.L  #$08,D3 * if bit 8 is 0, it is not MULS, error
            BEQ     OPERROR
            * otherwise, it is a MULS instruction
            MOVE.B  #2,D7       * indicate a word instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'M',(A2)+      * add DIVS to A2 String
            MOVE.B  #'U',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #'S',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            * get EA
            JSR     getMode     * get mode
            LEA     eaTable,A6  * load ea table
            MULU    #8,D6       * offset
            JSR     (A6,D6)     * get EA and reg number
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
 
            MOVE.B  #',',(A2)+  * print comma
            MOVE.B  #'D',(A2)+  * print D
            MOVE.L  D4,D3
            SWAP    D3
            LSL.L   #4,D3       * shift out opcode
            JSR     BitTst3     * get next three bits
            
            MULU    #8,D6
            LEA     numTable,A6
            JSR     (A6,D6)
            
            RTS
* AND ---------------------------------------------------------------------
_And        
            MOVE.L  D4,D3   * reset D3
            BTST.L  #$08,D3 * if 8th bit is 1, <ea> * Dn -> <ea>
            BNE     _AndEA  * branch to AND to EA
            SWAP    D3
            LSL.L   #8,D3
            JSR     BitTst2     * test size bits
            * must be an AND instruction or error
            CMPI.B  #%00,D6 * use d6 to check size
            BEQ     _AndB   * AND.B
            CMPI.B  #%01,D6
            BEQ     _AndW   * AND.W
            CMPI.B  #%10,D6
            BEQ     _AndL   * AND.L
            
            BRA     OPERROR
            
* AND.B ----------------------            
_AndB       
            MOVE.B  #1,D7       * indicate a byte instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'A',(A2)+      * add AND.B to A2 String
            MOVE.B  #'N',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'B',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            * get EA
            JSR     getMode
            CMPI.B  #%001,D6    * source cannot be An
            BEQ     OPERROR
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
            * no errors
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            * destination must be data register
            MOVE.B  #',',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.L  D4,D3   * reset D3
            SWAP    D3
            LSL.L   #4,D3   * shift out opcode
            JSR     BitTst3 * get data register number
            MULU    #8,D6   * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * get number from table and print

            RTS
            
* AND.W ----------------------
_AndW       
            MOVE.B  #2,D7       * indicate a word instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'A',(A2)+      * add AND.W to A2 String
            MOVE.B  #'N',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'W',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            * get EA
            JSR     getMode
            CMPI.B  #%001,D6    * source cannot be An
            BEQ     OPERROR
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
            * no errors
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            * destination must be data register
            MOVE.B  #',',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.L  D4,D3   * reset D3
            SWAP    D3
            LSL.L   #4,D3   * shift out opcode
            JSR     BitTst3 * get data register number
            MULU    #8,D6   * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * get number from table and print

            RTS
            
* AND.L ----------------------
_AndL       
            MOVE.B  #3,D7       * indicate a long instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'A',(A2)+      * add AND.L to A2 String
            MOVE.B  #'N',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            * get EA
            JSR     getMode
            CMPI.B  #%001,D6    * source cannot be An
            BEQ     OPERROR
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
            * no errors
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            * destination must be data register
            MOVE.B  #',',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.L  D4,D3   * reset D3
            SWAP    D3
            LSL.L   #4,D3   * shift out opcode
            JSR     BitTst3 * get data register number
            MULU    #8,D6   * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * get number from table and print

            RTS

_AndEA  
            MOVE.L  D4,D3       * reset D3
            SWAP    D3          * swap to front
            LSL.L   #8,D3       * shift out 8 bits so leading 2 bits are the size
            JSR     BitTst2     * get size bits in D6
            MOVE.L  D4,D3       * reset D3
            SWAP    D3    
            * check for size
            CMPI.B  #%00,D6 
            BEQ     _AndBea   * AND.B
            CMPI.B  #%01,D6
            BEQ     _AndWea   * AND.W
            CMPI.B  #%10,D6
            BEQ     _AndLea   * AND.L
            
            BRA     OPERROR

* AND.B to EA ----------------
_AndBea     
            MOVE.B  #1,D7       * indicate a word instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'A',(A2)+      * add AND.L to A2 String
            MOVE.B  #'N',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #'D',(A2)+  * starting source must be data register
            LSL.L   #4,D3   * shift out opcode
            JSR     BitTst3 * get data register number
            MULU    #8,D6   * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * get number from table and print
            MOVE.B  #',',(A2)+
            
            * get EA mode and check for errors
            JSR     getMode
            CMPI.B  #%001,D6    * cant write to An
            BEQ     OPERROR
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
            
            * no errors
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR

            RTS
            
* AND.W to EA ----------------
_AndWea     
            MOVE.B  #2,D7       * indicate a word instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'A',(A2)+      * add AND.L to A2 String
            MOVE.B  #'N',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #'D',(A2)+  * starting source must be data register
            LSL.L   #4,D3   * shift out opcode
            JSR     BitTst3 * get data register number
            MULU    #8,D6   * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * get number from table and print
            MOVE.B  #',',(A2)+
            
            * get EA mode and check for errors
            JSR     getMode
            CMPI.B  #%001,D6    * cant write to An
            BEQ     OPERROR
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
            
            * no errors
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            RTS
            
* AND.L to EA ----------------
_AndLea     
            MOVE.B  #3,D7       * indicate a long instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'A',(A2)+      * add AND.L to A2 String
            MOVE.B  #'N',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #'D',(A2)+  * starting source must be data register
            LSL.L   #4,D3   * shift out opcode
            JSR     BitTst3 * get data register number
            MULU    #8,D6   * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * get number from table and print
            MOVE.B  #',',(A2)+
            
            * get EA mode and check for errors
            JSR     getMode
            CMPI.B  #%001,D6    * cant write to An
            BEQ     OPERROR
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
            
            * no errors
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            RTS               

* ADD, ADDA -------------------------------------------------------------------------
op1101      
            SWAP    D3
            LSL.L   #8,D3   * shift out op code and next four bits
            JSR     BitTst2 * check next two bits for size/MUL instruction
            MOVE.L  D4,D3   * reset D3
            CMPI.B  #%11,D6 * if bits 6-7 are 11, it is ADDA
            BEQ     _AddA
            
            * figure out direction of ADD
            BTST.L  #$08,D3 * if 8th bit is 1, <ea> * dn -> <ea>
            BNE     _AddEA  * branch to add to EA
            * it is basic ADD
            CMPI.B  #%00,D6
            BEQ     _AddB
            CMPI.B  #%01,D6
            BEQ     _AddW
            CMPI.B  #%10,D6
            BEQ     _AddL
            
            BRA     OPERROR
            
* ADD.B ----------------------
_AddB       
            MOVE.B  #1,D7       * indicate a byte instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'A',(A2)+      * add ADD.B to A2 String
            MOVE.B  #'D',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'B',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            * get EA
            JSR     getMode
            CMPI.B  #%001,D6    * source cannot be An
            BEQ     OPERROR
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
            * no errors
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            * destination must be data register
            MOVE.B  #',',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.L  D4,D3   * reset D3
            SWAP    D3
            LSL.L   #4,D3   * shift out opcode
            JSR     BitTst3 * get data register number
            MULU    #8,D6   * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * get number from table and print
            RTS 
            
* ADD.W ----------------------
_AddW       
            MOVE.B  #2,D7       * indicate a word instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'A',(A2)+      * add ADD.W to A2 String
            MOVE.B  #'D',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'W',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            * get EA
            JSR     getMode
            CMPI.B  #%001,D6    * source cannot be An
            BEQ     OPERROR
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
            * no errors
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            * destination must be data register
            MOVE.B  #',',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.L  D4,D3   * reset D3
            SWAP    D3
            LSL.L   #4,D3   * shift out opcode
            JSR     BitTst3 * get data register number
            MULU    #8,D6   * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * get number from table and print
            RTS 

* ADD.L ----------------------
_AddL       
            MOVE.B  #3,D7       * indicate a long instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'A',(A2)+      * add ADD.L to A2 String
            MOVE.B  #'D',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            * get EA
            JSR     getMode
            CMPI.B  #%001,D6    * source cannot be An
            BEQ     OPERROR
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
            * no errors
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            * destination must be data register
            MOVE.B  #',',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.L  D4,D3   * reset D3
            SWAP    D3
            LSL.L   #4,D3   * shift out opcode
            JSR     BitTst3 * get data register number
            MULU    #8,D6   * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * get number from table and print
            RTS 
      

_AddEA      
            MOVE.L  D4,D3       * reset D3
            SWAP    D3          * swap to front
            LSL.L   #8,D3       * shift out 8 bits so leading 2 bits are the size
            JSR     BitTst2     * get size bits in D6
            MOVE.L  D4,D3       * reset D3
            SWAP    D3  
            CMPI.B  #%00,D6
            BEQ     _AddBea
            CMPI.B  #%01,D6
            BEQ     _AddWea
            CMPI.B  #%10,D6
            BEQ     _AddLea
            
            BRA     OPERROR
            
* ADD.B to EA ----------------            
_AddBea     
            MOVE.B  #1,D7       * indicate a byte instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'A',(A2)+      * add ADD.B to A2 String
            MOVE.B  #'D',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'B',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #'D',(A2)+  * starting source must be data register
            LSL.L   #4,D3   * shift out opcode
            JSR     BitTst3 * get data register number
            MULU    #8,D6   * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * get number from table and print
            MOVE.B  #',',(A2)+
            
            * get EA mode and check for errors
            JSR     getMode
            CMPI.B  #%001,D6    * cant write to An
            BEQ     OPERROR
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
            
            * no errors
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            RTS
            
* ADD.W to EA ----------------
_AddWea     
            MOVE.B  #2,D7       * indicate a long instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'A',(A2)+      * add ADD.W to A2 String
            MOVE.B  #'D',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'W',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #'D',(A2)+  * starting source must be data register
            LSL.L   #4,D3   * shift out opcode
            JSR     BitTst3 * get data register number
            MULU    #8,D6   * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * get number from table and print
            MOVE.B  #',',(A2)+
            
            * get EA mode and check for errors
            JSR     getMode
            CMPI.B  #%001,D6    * cant write to An
            BEQ     OPERROR
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
            
            * no errors
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            RTS
            
* ADD.L to EA ----------------
_AddLea     
            MOVE.B  #3,D7       * indicate a long instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'A',(A2)+      * add ADD.L to A2 String
            MOVE.B  #'D',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #'D',(A2)+  * starting source must be data register
            LSL.L   #4,D3   * shift out opcode
            JSR     BitTst3 * get data register number
            MULU    #8,D6   * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * get number from table and print
            MOVE.B  #',',(A2)+
            
            * get EA mode and check for errors
            JSR     getMode
            CMPI.B  #%001,D6    * cant write to An
            BEQ     OPERROR
            LSL.W   #3,D6       * shift bits in D6 to make room for destination register
            MOVE.B  D6,D5       * hold destination mode bits in d5
            LSL.L   #3,D3       * shift destination mode bits out
            JSR     BitTst3     * test the destination register bits
            ADD.W   D6,D5       * add these to the mode bits
            CMPI.B  #%111100,D5 * if we encounter an immediate/absolute mode with
            BEQ     OPERROR     * immediate data, there is not allowed, error
            
            * no errors
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            RTS
            
* ADDA -------------------------------------------------------------------            
_AddA       BTST.L  #$08,D3     * check the size bit of ADDA
            BEQ     _AddAw      * if 0, go to ADDA.W
            
            * proceed as if ADDA.L
* ADDA.L ---------------------
            MOVE.B  #3,D7       * indicate a long instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'A',(A2)+      * add ADDA.L to A2 String
            MOVE.B  #'D',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.B  #'A',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            *get EA
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            * destination must be address register
            MOVE.B  #',',(A2)+
            MOVE.B  #'A',(A2)+
            MOVE.L  D4,D3   * reset D3
            SWAP    D3
            LSL.L   #4,D3   * shift out opcode
            JSR     BitTst3 * get data register number
            MULU    #8,D6   * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * get number from table and print
            RTS
            
* ADDA.W ---------------------    
_AddAw      
            MOVE.B  #2,D7       * indicate a word instruction
            MOVEA.L A2,A3       * copy current address of A2 string to A3
            MOVE.B  #'A',(A2)+      * add ADDA.W to A2 String
            MOVE.B  #'D',(A2)+
            MOVE.B  #'D',(A2)+
            MOVE.B  #'A',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'W',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            *get EA
            JSR     getMode
            LEA     eaTable,A6
            MULU    #8,D6
            JSR     (A6,D6)
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            * destination must be address register
            MOVE.B  #',',(A2)+
            MOVE.B  #'A',(A2)+
            MOVE.L  D4,D3   * reset D3
            SWAP    D3
            LSL.L   #4,D3   * shift out opcode
            JSR     BitTst3 * get data register number
            MULU    #8,D6   * multiply for offset
            LEA     numTable,A6 * load num table
            JSR     (A6,D6)     * get number from table and print
            RTS
            
* LSL, LSR, ASL, ASR, ROL, ROR, ROXL, ROXR ---------------------------------------            
op1110
            JSR     getSize     * get size bits
            CMPI.B  #%11,D6
            BNE     _ShiftReg   * if the size isnt 11, it is a reg shift
            * it is a mem shift
            * determine type of shift
            LSL.L   #5,D3
            JSR     BitTst2
            CMPI.B  #%00,D6
            BEQ     _As     * arithmetic shift
            CMPI.B  #%01,D6
            BEQ     _Ls     * logical shift
            CMPI.B  #%10,D6
            BEQ     _Rox    * roll extend
            * proceed as if it is a roll
            BTST.L  #$1D,D3 * test the 8th bit of the instruction
            BEQ     _Ror    * if 0, it is a roll right
            
* ROL ------------------------
            * it is a ROL instruction
            MOVE.B  #'R',(A2)+ * add "ROL" to A2 string
            MOVE.B  #'O',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _shftMemEA  * finish by branching to shift to mem EA
            
* ROR ------------------------                       
_Ror        
            MOVE.B  #'R',(A2)+ * add "ROR" to A2 string
            MOVE.B  #'O',(A2)+
            MOVE.B  #'R',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _shftMemEA * finish by branching to shift to mem EA
            
_As         BTST.L  #$1D,D3 * test the 8th bit of the instruction
            BEQ     _Asr    * if 1, it is right
            * not so it is left
* ASL ------------------------
            MOVE.B  #'A',(A2)+ * add "ASL" to A2 string
            MOVE.B  #'S',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _shftMemEA * finish by branching to shift to mem EA
            
* ASR ------------------------            
_Asr        MOVE.B  #'A',(A2)+ * add "ASR" to A2 string
            MOVE.B  #'S',(A2)+
            MOVE.B  #'R',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _shftMemEA * finish by branching to shift to mem EA
            
            
_Ls         BTST.L  #$1D,D3 * test the 8th bit of the instruction
            BEQ     _Lsr    * if 1, it is right
            * not so it is left
* LSL ------------------------
            MOVE.B  #'L',(A2)+ * add "LSL" to A2 string
            MOVE.B  #'S',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _shftMemEA * finish by branching to shift to mem EA
            
* LSR ------------------------            
_Lsr        MOVE.B  #'L',(A2)+ * add "LSR" to A2 string
            MOVE.B  #'S',(A2)+
            MOVE.B  #'R',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _shftMemEA * finish by branching to shift to mem EA
            
* ROXL -----------------------            
_Rox        BTST.L  #$1D,D3 * test the 8th bit of the instruction
            BEQ     _Roxr   * if 1, it is right
            * not, so it is left
            MOVE.B  #'R',(A2)+ * add "ROXL" to A2 string
            MOVE.B  #'O',(A2)+
            MOVE.B  #'X',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _shftMemEA * finish by branching to shift to mem EA
            
* ROXR -----------------------           
_Roxr       MOVE.B  #'R',(A2)+ * add "ROXR" to A2 string
            MOVE.B  #'O',(A2)+
            MOVE.B  #'X',(A2)+
            MOVE.B  #'R',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _shftMemEA * finish by branching to shift to mem EA
            
_shftMemEA  
            JSR     getMode     * get the mode
            CMPI.B  #%001,D6    * cant be Dn, or An
            BLE     OPERROR     * branch to error
            LEA     eaTable,A6   * load ea table
            MULU    #8,D6       * multiply by 8 for table jump
            JSR     (A6,D6)     * jump to ea
            * check for error in EA
            CMPI.B  #4,D7
            BEQ     OPERROR
            RTS                 * return
            
_ShiftReg   
            * determine size of shift
            CMPI.B  #%00,D6
            BEQ     _byteShift
            CMPI.B  #%01,D6
            BEQ     _wordShift
            CMPI.B  #%10,D6
            BEQ     _longShift
            
_byteShift  
            * determine type of shift
            LSL.L   #8,D3       * shift out 
            LSL.L   #3,D3
            JSR     BitTst2
            MOVE.L  D4,D3       * reset D3
            CMPI.B  #%00,D6
            BEQ     _AsB        * arithmetic shift
            CMPI.B  #%01,D6
            BEQ     _LsB        * logical shift
            CMPI.B  #%10,D6
            BEQ     _RoxB       * roll extend
            * roll 
            
            BTST.L  #$08,D3 * test 8th bit for direction
            BEQ     _RorB   * if bit is 0, it is right
            * it is left
* ROL.B ----------------------
            MOVE.B  #'R',(A2)+ * add "ROL.B" to A2 string
            MOVE.B  #'O',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'B',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _ShiftEA    * branch to shift EA to finish
            
* ROR.B ----------------------            
_RorB       MOVE.B  #'R',(A2)+ * add "ROR.B" to A2 string
            MOVE.B  #'O',(A2)+
            MOVE.B  #'R',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'B',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _ShiftEA    * branch to shift EA to finish

_AsB        BTST.L  #$08,D3 * test 8th bit for direction
            BEQ     _AsrB   * if bit is 0, it is right
            * it is left
* ASL.B ----------------------
            MOVE.B  #'A',(A2)+ * add "ASL.B" to A2 string
            MOVE.B  #'S',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'B',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _ShiftEA    * branch to shift EA to finish

* ASR.B ----------------------
_AsrB       MOVE.B  #'A',(A2)+ * add "ASR.B" to A2 string
            MOVE.B  #'S',(A2)+
            MOVE.B  #'R',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'B',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _ShiftEA    * branch to shift EA to finish

            
_LsB        BTST.L  #$08,D3 * test 8th bit for direction
            BEQ     _LsrB   * if bit is 0, it is right
            * it is left
* LSL.B ----------------------
            MOVE.B  #'L',(A2)+ * add "LSL.B" to A2 string
            MOVE.B  #'S',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'B',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _ShiftEA    * branch to shift EA to finish
            
* LSR.B ----------------------            
_LsrB       MOVE.B  #'L',(A2)+ * add "LSR.B" to A2 string
            MOVE.B  #'S',(A2)+
            MOVE.B  #'R',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'B',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _ShiftEA    * branch to shift EA to finish

_RoxB       BTST.L  #$08,D3 * test 8th bit for direction
            BEQ     _RoxrB  * if bit is 0, it is right
            * it is left
* ROXL.B ----------------------
            MOVE.B  #'R',(A2)+ * add "ROXL.B" to A2 string
            MOVE.B  #'O',(A2)+
            MOVE.B  #'X',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'B',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _ShiftEA    * branch to shift EA to finish
            
* ROXR.B ---------------------            
_RoxrB      MOVE.B  #'R',(A2)+ * add "ROXR.B" to A2 string
            MOVE.B  #'O',(A2)+
            MOVE.B  #'X',(A2)+
            MOVE.B  #'R',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'B',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _ShiftEA    * branch to shift EA to finish
            

_wordShift
            * determine type of shift
            LSL.L   #8,D3
            LSL.L   #3,D3
            JSR     BitTst2
            MOVE.L  D4,D3   * reset D3
            CMPI.B  #%00,D6
            BEQ     _AsW    * arithmetic shift
            CMPI.B  #%01,D6
            BEQ     _LsW    * logical shift
            CMPI.B  #%10,D6
            BEQ     _RoxW   * roll extend
            * roll
            BTST.L  #$08,D3 * test 8th bit for direction
            BEQ     _RorW   * if bit is 0, it is right
            * it is left
* ROL.W ----------------------
            MOVE.B  #'R',(A2)+ * add "ROL.W" to A2 string
            MOVE.B  #'O',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'W',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _ShiftEA    * branch to shift EA to finish
            
* ROR.W ----------------------            
_RorW       MOVE.B  #'R',(A2)+ * add "ROR.W" to A2 string
            MOVE.B  #'O',(A2)+
            MOVE.B  #'R',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'W',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _ShiftEA    * branch to shift EA to finish
            
_AsW        BTST.L  #$08,D3 * test 8th bit for direction
            BEQ     _AsrW   * if bit is 0, it is right
            * it is left
* ASL.W ----------------------
            MOVE.B  #'A',(A2)+ * add "ASL.W" to A2 string
            MOVE.B  #'S',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'W',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _ShiftEA    * branch to shift EA to finish
            
* ASR.W ----------------------            
_AsrW       MOVE.B  #'A',(A2)+ * add "ASR.W" to A2 string
            MOVE.B  #'S',(A2)+
            MOVE.B  #'R',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'W',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _ShiftEA    * branch to shift EA to finish

_LsW        BTST.L  #$08,D3 * test 8th bit for direction
            BEQ     _LsrW   * if bit is 0, it is right
            * it is left
* LSL.W ----------------------
            MOVE.B  #'L',(A2)+ * add "LSL.W" to A2 string
            MOVE.B  #'S',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'W',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _ShiftEA    * branch to shift EA to finish
            
* LSR.W ----------------------            
_LsrW       MOVE.B  #'L',(A2)+ * add "LSR.W" to A2 string
            MOVE.B  #'S',(A2)+
            MOVE.B  #'R',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'W',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _ShiftEA    * branch to shift EA to finish

_RoxW       BTST.L  #$08,D3 * test 8th bit for direction
            BEQ     _RoxrW  * if bit is 0, it is right
            * it is left
* ROXL.W ---------------------
            MOVE.B  #'R',(A2)+ * add "ROXL.W" to A2 string
            MOVE.B  #'O',(A2)+
            MOVE.B  #'X',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'W',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _ShiftEA    * branch to shift EA to finish
            
* ROXR.W ---------------------            
_RoxrW      MOVE.B  #'R',(A2)+ * add "ROXR.W" to A2 string
            MOVE.B  #'O',(A2)+
            MOVE.B  #'X',(A2)+
            MOVE.B  #'R',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'W',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _ShiftEA    * branch to shift EA to finish

_longShift
            * determine type of shift
            LSL.L   #8,D3
            LSL.L   #3,D3
            JSR     BitTst2
            MOVE.L  D4,D3       * reset D3
            CMPI.B  #%00,D6
            BEQ     _AsLong
            CMPI.B  #%01,D6
            BEQ     _LsLong
            CMPI.B  #%10,D6
            BEQ     _RoxLong
            * roll
            BTST.L  #$08,D3 * test 8th bit for direction
            BEQ     _RorLong   * if bit is 0, it is right
            * it is left
* ROL.L ----------------------
            MOVE.B  #'R',(A2)+ * add "ROL.L" to A2 string
            MOVE.B  #'O',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _ShiftEA    * branch to shift EA to finish
            
* ROR.L ----------------------            
_RorLong    MOVE.B  #'R',(A2)+ * add "ROR.L" to A2 string
            MOVE.B  #'O',(A2)+
            MOVE.B  #'R',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _ShiftEA    * branch to shift EA to finis
            
_AsLong     BTST.L  #$08,D3 * test 8th bit for direction
            BEQ     _AsrLong   * if bit is 0, it is right
            * it is left
* ASL.L ----------------------
            MOVE.B  #'A',(A2)+ * add "ASL.L" to A2 string
            MOVE.B  #'S',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _ShiftEA    * branch to shift EA to finish
            
* ASR.L ----------------------           
_AsrLong    MOVE.B  #'A',(A2)+ * add "ASR.L" to A2 string
            MOVE.B  #'S',(A2)+
            MOVE.B  #'R',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _ShiftEA    * branch to shift EA to finish

_LsLong     BTST.L  #$08,D3 * test 8th bit for direction
            BEQ     _LsrLong   * if bit is 0, it is right
            * it is left
* LSL.L ----------------------
            MOVE.B  #'L',(A2)+ * add "LSL.L" to A2 string
            MOVE.B  #'S',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _ShiftEA    * branch to shift EA to finish
            
* LSR.L ----------------------            
_LsrLong    MOVE.B  #'L',(A2)+ * add "LSR.L" to A2 string
            MOVE.B  #'S',(A2)+
            MOVE.B  #'R',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _ShiftEA    * branch to shift EA to finish
            

_RoxLong    BTST.L  #$08,D3 * test 8th bit for direction
            BEQ     _RoxrLong  * if bit is 0, it is right
            * it is left
* ROXL.L ---------------------
            MOVE.B  #'R',(A2)+ * add "ROXL.L" to A2 string
            MOVE.B  #'O',(A2)+
            MOVE.B  #'X',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _ShiftEA    * branch to shift EA to finish
            
* ROXR.L ---------------------            
_RoxrLong   MOVE.B  #'R',(A2)+ * add "ROXR.L" to A2 string
            MOVE.B  #'O',(A2)+
            MOVE.B  #'X',(A2)+
            MOVE.B  #'R',(A2)+
            MOVE.B  #'.',(A2)+
            MOVE.B  #'L',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            BRA     _ShiftEA    * branch to shift EA to finish
            
_ShiftEA    
            BTST.L  #$05,D3     * determine if it is a shift using a register
            BEQ     _shiftImm
            MOVE.B  #'D',(A2)+
            SWAP    D3
            LSL.L   #4,D3       * shift out opcode
            JSR     BitTst3     * get next three bits for source reg number
            LEA     numTable,A6 * load num table
            MULU    #8,D6       * multiply for offset
            JSR     (A6,D6)     * jump to get number
            
_shiftDest  MOVE.B  #',',(A2)+
            MOVE.B  #'D',(A2)+
            LSL.L   #8,D3       * shift out all bits but 0->2
            LSL.L   #1,D3
            JSR     BitTst3     * test for data register
            MULU    #8,D6       * multiply for offset
            JSR     (A6,D6)     * jump to get number
            RTS
_shiftImm
            MOVE.B  #'#',(A2)+
            SWAP    D3
            LSL.L   #4,D3       * shift out opcode
            JSR     BitTst3     * get next three bits for data value being shifted
            CMPI.B  #%000,D6    * if it is 000, add 8 to D6
            BNE     _shftIM     * if not, continue to next part
            JSR     Add8        * jump to subroutine to add 8 to D6
_shftIM     LEA     numTable,A6 * load num table
            MULU    #8,D6       * multiply for offset
            JSR     (A6,D6)     * jump to get number
            BRA     _shiftDest  * get destination register
                           
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
*                          END OF OP CODES                                    *
*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*
            
*******************************************************************************
* OPERROR - Used when data or an illegal instruction is encountered.
* Resets A2 to the end of the PC to overwrite the new string.
* Also could reset the current address, A4, if an EA has been read incorrectly.
*******************************************************************************
OPERROR     
            CMPI.B  #1,EA_FLAG  * see if the ea flag has been set
            BNE     Next
            MOVEA.L D5,A4       * reset A4
Next        MOVEA.L A3,A2       * reset A2 to overwrite current string
            MOVE.B  #'D',(A2)+  * add DATA to A2 String
            MOVE.B  #'A',(A2)+
            MOVE.B  #'T',(A2)+
            MOVE.B  #'A',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #' ',(A2)+
            MOVE.B  #'$',(A2)+
            JSR     printErrorData
            MOVE.B  #0,EA_FLAG  * reset ea flag for next instruction
            RTS

printErrorData
            
            CLR     D2      * clear d2 for counter
            LEA     numTable,A6
            MOVE.L  D4,D3
            SWAP    D3
            
printELoop  
            CMPI.B  #4,D2       * loop through 4 times,
            BEQ     loopDone    * print done
            JSR     BITTEST     * get leading 4 bits
            MULU    #8,D6       * multiply by 8 for jump offset
            JSR     (A6,D6)     * get number from table and add to A2 string
            LSL.L   #4,D3       * shift out 4 biths were done with
            ADDQ    #1,D2       * increment loop counter
            BRA     printELoop  * branch back to loop

loopDone    
            RTS
   

* EA Jump Table ------------------------------------------------------
eaTable     JSR     ea000    * data register
            RTS             
            JSR     ea001    * address register
            RTS             
            JSR     ea010    * indirect address register
            RTS             
            JSR     ea011    * post increment address
            RTS             
            JSR     ea100    * address pre decrement
            RTS             
            JSR     ea101    * unsupported
            RTS             
            JSR     ea110    * unsupported
            RTS             
            JSR     ea111     * immediate/absolute address
            RTS             
            
            
* Dn -----------------------------------------------------------------
ea000
            MOVE.B  #'D',(A2)+  * add D to A2 string
                
            MOVE.L  D4,D3       * copy data to D3
            SWAP    D3
            LSL.L   #5,D3       * clear bits until register number
            LSL.L   #8,D3       
            
            JSR     BitTst3
            
            LEA     numTable,A6 ;load table
            MULU    #8,D6       ;get jump table to work
            JSR     (A6,D6)    ;print number
            
            
            RTS

            
* An -----------------------------------------------------------------
ea001
            CMP.B   #1,D7       * cannot move Address with byte data
            BEQ     isByte     * error
             
            
            MOVE.B  #'A',(A2)+  * print A
            MOVE.L  D4,D3       * reset D3
            SWAP    D3          * move bits to front
            LSL.L   #8,D3       * shift all bits out but 0-2
            LSL.L   #5,D3
            JSR     BitTst3     * test these three bits
            
            LEA     numTable,A6 * load table
            MULU    #8,D6       * offset
            JSR     (A6,D6)     * print
            
            RTS
            
isByte      MOVE.B  #4,D7   * set error
            RTS

           
* (An) ---------------------------------------------------------------
ea010

            MOVE.B  #'(',(A2)+  * print (
            MOVE.B  #'A',(A2)+  * print A
            
            MOVE.L  D4,D3       * reset D3
            SWAP    D3          * move bits to front
            LSL.L   #8,D3       * shift all bits out but 0-2
            LSL.L   #5,D3
            JSR     BitTst3     * test these three bits
            LEA     numTable,A6 * load table
            MULU    #8,D6       * offset
            JSR     (A6,D6)     * print number
            
            MOVE.B  #')',(A2)+  * print )
            

            RTS

            
* (An)+ --------------------------------------------------------------
ea011

            MOVE.B  #'(',(A2)+  * print (
            MOVE.B  #'A',(A2)+  * print A
            
            MOVE.L  D4,D3       * reset D3
            SWAP    D3          * move bits to front
            LSL.L   #8,D3       * shift all bits out but 0-2
            LSL.L   #5,D3
            JSR     BitTst3     * test these three bits
            
            LEA     numTable,A6 * load table
            MULU    #8,D6       * offset
            JSR     (A6,D6)    * print number
            
            MOVE.B  #')',(A2)+  * print )
            MOVE.B  #'+',(A2)+  * print +
            

            RTS

            
* -(An) --------------------------------------------------------------
ea100

            MOVE.B  #'-',(A2)+  * print -
            MOVE.B  #'(',(A2)+  * print (
            MOVE.B  #'A',(A2)+  * print A
            MOVE.L  D4,D3       * reset D3
            SWAP    D3          * move bits to front
            LSL.L   #8,D3       * shift all bits out but 0-2
            LSL.L   #5,D3
            JSR     BitTst3     * test these three bits
            
            LEA     numTable,A6 ;load table
            MULU    #8,D6       ;get jump table to work
            JSR     (A6,D6)    ;print number
            
            MOVE.B  #')',(A2)+  ;print )
            

            RTS

            
* Subroutine not supported ---------------------------------------------
ea101

            MOVE.B  #4,D7
            RTS
            

            
* Subroutine not supported --------------------------------------------
ea110

            MOVE.B  #4,D7 * set error flag
            RTS      
            

           
* Immediate and Absolute -----------------------------------------------
ea111
            MOVE.L  D4,D3       * reset D3
            SWAP    D3          * move bits to front
            LSL.L   #8,D3       * shift all bits out but 0-2
            LSL.L   #5,D3
            JSR     BitTst3     * test these three bits
            CMPI.B  #%000,D6    * compare to absolute short
            BEQ     shortAbs
            CMPI.B  #%001,D6    * compare to absolute long
            BEQ     longAbs
            CMPI.B  #%100,D6    * compare to immediate
            BEQ     immediate

            MOVE.B  #4,D7   * set error
            RTS          
            
immediate
            CMP.B   #1,D7       * compare to byte
            BEQ     _ByteData      
            CMP.B   #2,D7       * compare to word
            BEQ     _WordData
            CMP.B   #3,D7       * compare to long
            BEQ     _LongData

            MOVE.B  #4,D7       * set error flag
            RTS
                             
            
_ByteData
            MOVE.B  #'#',(A2)+  * print #
            MOVE.B  #'$',(A2)+  * print $
            JSR     printByte
            RTS                 
            
_WordData
            MOVE.B  #'#',(A2)+  * print #
            MOVE.B  #'$',(A2)+  * print $
            JSR     printWord
            RTS                 
            
_LongData
            MOVE.B  #'#',(A2)+  * print #
            MOVE.B  #'$',(A2)+  * print $
            JSR     printLong
            RTS                 

shortAbs
            MOVE.B  #'$',(A2)+  * print $
            JSR     printWord   
            RTS                 
            
longAbs
            MOVE.B  #'$',(A2)+  * print $
            JSR     printLong
            RTS                 
            

* Number Jump Table ----------------------------------------
numTable    JSR     n0   * 0
            RTS             
            JSR     n1   * 1
            RTS             
            JSR     n2   * 2
            RTS             
            JSR     n3   * 3
            RTS             
            JSR     n4   * 4
            RTS             
            JSR     n5   * 5
            RTS             
            JSR     n6   * 6
            RTS             
            JSR     n7   * 7
            RTS             
            JSR     n8   * 8
            RTS             
            JSR     n9   * 9
            RTS             
            JSR     nA   * A
            RTS             
            JSR     nB   * B
            RTS             
            JSR     nC   * C
            RTS             
            JSR     nD   * D
            RTS             
            JSR     nE   * E
            RTS             
            JSR     nF   * F
            RTS             

            
* Print 0 ------------------------------------------
n0
            MOVE.B  #'0',(A2)+      * add 0 to string
            RTS

          
* Print 1 ------------------------------------------
n1
            MOVE.B  #'1',(A2)+      * add 1 to string
            RTS

           
* Print 2 ------------------------------------------
n2
            MOVE.B  #'2',(A2)+      * add 2 to string
            RTS
 
            
* Print 3 ------------------------------------------
n3
            MOVE.B  #'3',(A2)+      * add 3 to string
            RTS

            
* Print 4 ------------------------------------------
n4
            MOVE.B  #'4',(A2)+      * add 4 to string
            RTS

            
* Print 5 ------------------------------------------
n5
            MOVE.B  #'5',(A2)+      * add 5 to string
            RTS

            
* Print 6 ------------------------------------------
n6
            MOVE.B  #'6',(A2)+      * add 6 to string
            RTS
            
            
* Print 7 ------------------------------------------
n7
            MOVE.B  #'7',(A2)+      * add 7 to string
            RTS

 
* Print 8 ------------------------------------------
n8       
            MOVE.B  #'8',(A2)+      * add 8 to string
            RTS

            
* Print 9 ------------------------------------------
n9   
            MOVE.B  #'9',(A2)+      * add 9 to string
            RTS

            
* Print A ------------------------------------------
nA   
            MOVE.B  #'A',(A2)+      * add A to string
            RTS

            
* Print B ------------------------------------------
nB   
            MOVE.B  #'B',(A2)+      * add B to string
            RTS

            
* Print C ------------------------------------------
nC   
            MOVE.B  #'C',(A2)+      * add C to string
            RTS

           
* Print D ------------------------------------------
nD   
            MOVE.B  #'D',(A2)+      * add D to string
            RTS

           
* Print E ------------------------------------------
nE  
            MOVE.B  #'E',(A2)+      * add E to string
            RTS

            
* Print F ------------------------------------------
nF   
            MOVE.B  #'F',(A2)+      * add F to string
            RTS

restart

            MOVE.B  #$0,lines_flag  * initialize lines to 0
            MOVE.B  #$0,start_flag  *initialize start flag to 0
            MOVE.B  #$0,EA_FLAG     * initialize ea flag to 0 
            MOVEA.L #0,A4           * clear current address
            MOVEA.L #0,A5           * clear ending address
            
            BRA     GET_LOWER
            

DONE

        CLR     D0
        LEA     repeat,A1       * load message to ask if user wants to repeat
        MOVE.B  #14,D0
        TRAP    #15
        
        LEA     restart_in,A1   * capture the user input
        MOVE.L  #2,D0
        TRAP    #15
        
        MOVE.B  (A1),D1         * place answer in D1
        CMPI.B  #$59,D1         * compare with upper case Y
        BEQ     restart
        CMPI.B  #$79,D1         * compare with lower case y
        BEQ     restart
        
        LEA     ending,A1       * chose not to restart, ending message
        MOVE.B  #14,D0
        TRAP    #15

    END    START        ; last line of source










*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
