; I/O System for 86-DOS version 1.10 and later. Revised 11-25-22.

SECSIZE	EQU	512		;Size of a sector
DOSSIZE	EQU	10000		;Max length of 86-DOS in bytes
BIOSSEG	EQU	60H		;BIOS segment for the IBM PC

	ORG	0

	JMP	INIT
	JMP	STATUS
	JMP	CONIN		;INP
	JMP	CONOUT		;OUTP
	JMP	PRINT
	JMP	AUXIN
	JMP	AUXOUT
	JMP	READ
	JMP	WRITE
	JMP	DSKCHG
	JMP	SETDATE
	JMP	SETTIME
	JMP	GETDATE

;
; Out of paper error message
;
NOPAPER:
	DB	13,10,"Out of paper",13,10,0

;
; Printer fault error message
;
PRNERR:
	DB	13,10,"Printer fault",13,10,0

;
; AUX I/O error message
;
AUXERR:
	DB	13,10,"Aux I/O error",13,10,0

;
; STATUS - Console input status
;
; AL contains the returned character, all other registers must be
; preserved. ZF set if character not ready, otherwise ZF is cleared.
;
STATUS:
	SEG	CS
	MOV	AL,[LASTCHAR]	;Fetch the last returned char
	OR	AL,AL		;Get flags for it
	JNZ	STATUSRET	;Last char is not 0, return it
	PUSH	DX		;Save DX
	XCHG	AX,DX		;Save value of AX to DX
	MOV	AH,1		;Function = get keystroke status
	INT	16H		;Call keyboard BIOS service
	JZ	NOKEYPRES	;No key pressed
	CMP	AX,7200H	;Check if key is CTRL + PRTSCR
	JNZ	STATUSDONE	;No, skip the next bit
	MOV	AL,10H		;Yes, set to CTRL + P
	OR	AL,AL		;Get ZF for the character
	JP	STATUSDONE	;Done

NOKEYPRES:	;Clear AL before returning
	MOV	AL,0

STATUSDONE:	;Restore registers for STATUS
	MOV	AH,DH		;Restore AH from value saved in DX
	POP	DX		;Restore saved DX

STATUSRET:
	RET	L

;
; BREAK handler
;
BREAK:
	SEG	CS
	MOV	B,[LASTCHAR],03H;Set char to CTRL + C
	IRET

;
; Dummy interrupt routine
;
INTSTUB:
	IRET			;Simply return

;
; CONIN - Console input
;
; AL contains the returned character, all other registers must be
; preserved.
;
INPRETRY:	;Restore registers and retry
	XCHG	AX,DX		;Put saved value back to AX
	POP	DX		;Restore DX

CONIN:
	MOV	AL,0		;Set AL to 0
	SEG	CS
	XCHG	AL,[LASTCHAR]	;Move last char to AL and zero last char
	OR	AL,AL		;Get flags for last char
	JNZ	INPRET		;Last char wasn't zero, done
	PUSH	DX		;Save DX
	XCHG	AX,DX		;Save value of AX to DX
	MOV	AH,0		;Function = wait and read char
	INT	16H		;Call keyboard BIOS service
	OR	AX,AX		;Get flags for AX
	JZ	INPRETRY	;Got 0, restore saved and read again
	CMP	AX,7200H	;Check for CTRL + PRTSCR
	JNZ	INPCHECK	;No, continue
	MOV	AL,10H		;Yes, change to CTRL + P

INPCHECK:	;Check if it is a special function key
	CMP	AL,0		;Check if char is 0
	JNZ	INPDONE		;No, we have a char
	SEG	CS
	MOV	[LASTCHAR],AH	;This is a function key, save scancode

INPDONE:	;Restore registers for CONIN
	MOV	AH,DH		;Restore AH from value in DX
	POP	DX		;Restore DX

INPRET:
	RET	L

;
; CONOUT - Console output
;
; AL contains the character to output to the console, all registers
; must be preserved.
;
CONOUT:
	PUSH	BP		;Save all necessary registers
	PUSH	AX
	PUSH	BX
	PUSH	SI
	PUSH	DI
	MOV	AH,0EH		;Function = write char
	MOV	BX,7		;Light gray and page number = 0
	INT	10H		;Call video BIOS service
	POP	DI		;Restore all saved registers
	POP	SI
	POP	BX
	POP	AX
	POP	BP
	RET	L

;
; PRINT - Printer output
;
; AL contains the character to output to the printer, all registers
; must be preserved.
;
PRINT:
	PUSH	AX		;Save AX
	PUSH	DX		;Save DX
	SEG	CS
	MOV	B,[PRNRETRY],0	;Clear retry flag

PRINTCHAR:
	MOV	DX,0		;Printer 0
	MOV	AH,0		;Function = print char
	INT	17H		;Call printer BIOS service
	MOV	DX,NOPAPER	;Load out of paper message
	TEST	AH,20H		;Test for out of paper bit
	JNZ	PRINTERR	;Bit is set, print error
	MOV	DX,PRNERR	;Load printer fault message
	TEST	AH,05H		;Test for time out and IO error
	JZ	PRINTDONE	;No error, done
	SEG	CS
	XOR	B,[PRNRETRY],1	;Set retry flag (to be cleared next time)
	JNZ	PRINTCHAR	;Try printing again

PRINTERR:
	CALL	OUTPSTR		;Print error message

PRINTDONE:
	POP	DX		;Restore DX
	POP	AX		;Restore AX
	RET	L

;
; Output string to console
;
OUTPSTR:
	XCHG	DX,SI		;Swap DX and SI (for LODB)

OUTPSLOOP:	;Character output loop
	SEG	CS
	LODB			;Load byte at SI to AL
	OR	AL,AL		;Check for zero
	JZ	OUTPSDONE	;Reached end of string, break out of loop
	CALL	CONOUT,BIOSSEG	;Call BIOS CONOUT function
	JP	OUTPSLOOP	;Back to loop beginning

OUTPSDONE:
	XCHG	DX,SI		;Swap DX and SI back
	RET

;
; AUXIN - Auxiliary input
;
; AL contains the returned character, all other registers must be
; preserved.
;
AUXIN:
	PUSH	DX		;Save DX
	PUSH	AX		;Save AX
	MOV	DX,0		;Port 0
	MOV	AH,2		;Function = receive char
	INT	14H		;Call serial I/O BIOS service
	MOV	DX,AUXERR	;Load AUX error message
	TEST	AH,0EH		;Test for overrun, parity and framing errors
	JZ	AUXINDONE	;No error, done
	CALL	OUTPSTR		;Print error message

AUXINDONE:
	POP	DX		;Put saved AX into DX
	MOV	AH,DH		;Restore the original AH
	POP	DX		;Restore DX
	RET	L

;
; AUXOUT - Auxiliary output
;
; AL contains the character to output to the auxiliary output device,
; all registers must be preserved.
;
AUXOUT:
	PUSH	AX		;Save AX
	PUSH	DX		;Save DX
	MOV	AH,1		;Function = send char
	MOV	DX,0		;Port 0
	INT	14H		;Call serial I/O BIOS service
	TEST	AH,80H		;Test error bit
	JZ	PRINTDONE	;No error, done
	MOV	DX,AUXERR	;Load error message
	JP	PRINTERR	;Print it out

;
; DSKCHG - Disk change test
;
; See Programer's Manual for details. AL used as input and AX contains
; the return value. CF set on error. This is a stub implementation.
;
DSKCHG:
	MOV	AH,0		;Clear AH
	RET	L

;
; SETDATE - Set date
;
; AX contains the number of days since January 1, 1980. AX may be
; destroyed by this function, all other registers must be preserved.
;
SETDATE:
	SEG	CS
	MOV	[DAYCNT],AX	;Number of days since Jan 1, 1980
	XOR	AX,AX		;Function = read system clock counter
	INT	1AH		;Call clock BIOS service
	RET	L

;
; SETTIME - Set time
;
; CH = hours, CL = minutes, DH = seconds, DL = 100ths of seconds.
; AX, BX and DX may be destroyed, all other registers must be preserved.
;
SETTIME:
	MOV	AL,60
	MUL	AX,CH		;Hours to minutes
	MOV	CH,0
	ADD	AX,CX		;Total minutes
	MOV	CX,6000		;60*100
	MOV	BX,DX		;Get out of the way of the multiply
	MUL	AX,CX		;Convert to 1/100 sec
	MOV	CX,AX
	MOV	AL,100
	MUL	AX,BH		;Convert seconds to 1/100 sec
	ADD	CX,AX		;Combine seconds with hours and min
	ADC	DX,0		;Ripple carry
	MOV	BH,0
	ADD	CX,BX		;Combine 1/100 sec
	ADC	DX,0
	XCHG	AX,DX
	XCHG	AX,CX		;Now time is in CX:AX
	MOV	BX,59659
	MUL	AX,BX		;Multiply low half
	XCHG	DX,CX
	XCHG	AX,DX		;CX->AX, AX->DX, DX->CX
	MUL	AX,BX		;Multiply high half
	ADD	AX,CX		;Combine overlapping products
	ADC	DX,0
	XCHG	AX,DX		;AX:DX = time * 59659
	MOV	BX,5
	DIV	AX,BL		;Divide high half by 5
	MOV	CL,AL
	MOV	CH,0
	MOV	AL,AH		;Remainder of divide-by-5
	CBW
	XCHG	AX,DX		;Use it to extend low half
	DIV	AX,BX		;Divide low half by 5
	MOV	DX,AX		;CX:DX is now number of ticks in time
	MOV	AH,1		;Function = set clock ticks
	INT	1AH		;Call clock BIOS service
	RET	L

;
; GETDATE - Read date and time
;
; Returns days since January 1, 1980 in AX, hours in CH, minutes in CL,
; seconds in DH and 100ths of seconds in DL. All other registers must be
; preserved.
;
GETDATE:
	PUSH	BX		;Save BX
	MOV	AX,0		;Function = get clock ticks
	INT	1AH		;Call clock BIOS service
	SEG	CS
	ADD	[DAYCNT],AX	;Catch rollover
; We now need to convert the time in tick to the time in 100th of
; seconds.  The relation between tick and seconds is:
;
;                65536 seconds
;              ----------------
;               1,193,180 tick
;
; To get to 100th of second we need to multiply by 100. The equation is:
;
;       Ticks from clock  * 65536 * 100
;      ---------------------------------  = time in 100th of seconds
;               1,193,180
;
; Fortunately this fromula simplifies to:
;
;       Ticks from clock * 5 * 65,536
;      --------------------------------- = time in 100th of seconds
;               59,659
;
; The calculation is done by first multipling tick by 5. Next we divide by
; 59,659.  In this division we multiply by 65,536 by shifting the dividend
; my 16 bits to the left.
;
; Start with ticks in CX:DX multiply by 5
	MOV	AX,CX
	MOV	BX,DX		;AX:BX = TICKS
	SHL	DX
	RCL	CX		;Times 2
	SHL	DX
	RCL	CX		;Times 4
	ADD	DX,BX
	ADC	AX,CX		;Times 5
	XCHG	AX,DX
	MOV	CX,59659	;Get divisor
	DIV	AX,CX		;DX now has remainder
				;AX has high word of final quotient
	MOV	BX,AX		;Put high word in safe place
	XOR	AX,AX		;This is the multiply by 65536
	DIV	AX,CX		;BX:AX now has time in 100th of seconds
;Rounding based on the remainder may be added here
;The result in BX:AX is time in 1/100 second
	MOV	DX,BX
	MOV	CX,200		;Extract 1/100's
;Division by 200 is necessary to ensure no overflow - max result
;is number of seconds in a day/2 = 43200
	DIV	AX,CX
	CMP	DL,100		;Remainder over 100?
	JB	NOADJ
	SUB	DL,100		;Keep 1/100's less than 100
NOADJ:
	CMC			;If we subtracted 100, carry is now set
	MOV	BL,DL		;Save 1/100's
;To compensate for dividing by 200 instead of 100, we now multiply
;by two, shifting a one in if the remainder had exceeded 100
	RCL	AX
	MOV	DL,0
	RCL	DX
	MOV	CX,60		;Divide out seconds
	DIV	AX,CX
	MOV	BH,DL		;Save the seconds
	DIV	AX,CL		;Break into hours and minutes
	XCHG	AL,AH
;Time is now in AX:BX (hours, minutes, seconds, 1/100 sec)
	MOV	DX,BX		;Seconds and 1/100's
	XCHG	CX,AX		;Hours and minutes
	SEG	CS
	MOV	AX,[DAYCNT]	;Days
	POP	BX		;Restore BX
	RET	L

;
; Init hardware and device info
;
INIT:
;Setup temp stack
	CLI			;Disable interrupts
	MOV	AX,CS
	MOV	DS,AX		;DS = CS
	MOV	SS,AX		;SS = CS
	MOV	SP,STACKAREA	;Set SP to temp area
	STI			;Enable interrupts
;Setup hardware
	XOR	AH,AH		;Function = reset disk system
	INT	13H		;Call disk BIOS service
	MOV	AL,0A3H		;Serial IO params = 2400 baud, 8N1
				;Disk init must succeed (AH = 0)
	INT	14H		;Call serial I/O BIOS service
	MOV	AH,1		;Function = init printer
	INT	17H		;Call printer BIOS service
	INT	11H		;Get BIOS equipment flags
	AND	AX,0C0H		;Get number of drives
	MOV	CX,5		;Bits to shift = 5
	SHR	AX,CL		;Shift by 5 = (drives - 1) * 2
	ADD	AX,2		;Plus 2 = drives * 2
	AND	AX,06H		;Set to 0 for 4 drives
	JZ 	FLPDONE		;We have 4 drives
	CMP	AL,2		;Do we have only 1 drive?
	JNZ	MULTIFLP	;No, we have multiple drives
	SHL	AX		;Set drive count to 2 (double AX)
	MOV	B,[SNGDRV],1	;Set single drive flag

MULTIFLP:
	MOV	BX,INITTAB+1	;Load drive list
	ADD	BX,AX		;Increment pointer (2 * drives)
	MOV	[BX],0		;Buffer space = 0
	MOV	[BX+TABSTK],0	;Stack space = 0
	SHR	AX		;Divide by 2 = (drives * 2) / 2
	MOV	[INITTAB],AL	;Save drive count

FLPDONE:
	PUSH	DS		;Save DS
	MOV	AX,0
	MOV	DS,AX		;DS = 0
	MOV	AX,BIOSSEG	;Load BIOS seg
;Set BREAK handler
	MOV	[1BH*4 + 2],AX	;Change INT 1BH seg
	MOV	[1BH*4],BREAK	;Change INT 1BH address
;Disable all interrupts used for debugging
	MOV	BX,INTSTUB	;Load stub interrupt address
	MOV	[01H*4],BX	;Change INT 01H address
	MOV	[01H*4 + 2],AX	;Change INT 01H seg
	MOV	[03H*4],BX	;Change INT 03H address
	MOV	[03H*4 + 2],AX	;Change INT 03H seg
	MOV	[04H*4],BX	;Change INT 04H address
	MOV	[04H*4 + 2],AX	;Change INT 04H seg
;Clear print screen status
	MOV	AX,50H
	MOV	DS,AX		;DS = 50H
	MOV	[00H],0		;Zero print screen flag
;Move DOS to the end of the BIOS
	PUSH	ES		;Save ES
	MOV	AX,DOSSEG
	MOV	ES,AX		;Set ES to DOS seg
	MOV	CX,DOSSIZE/2	;DOS size in words
	CLD			;Clear DF
	MOV	AX,OLDSEG
	MOV	DS,AX		;Set DS to current DOS seg
	XOR	DI,DI		;ES:DI = DOSSEG:0000
	MOV	SI,DI		;DS:SI = OLDSEG:0000
	REP
	MOVSW			;Copy DOS
	POP	ES		;Restore ES
	POP	DS		;Restore DS
;Load 86-DOS
	MOV	SI,INITTAB	;Load drive list pointer
	CALL	0,DOSSEG	;Call DOS init
	STI			;Enable interrupts
	MOV	DX,100H		;DTA = 100H
	MOV	AH,1AH		;Function = set disk transfer address
	INT	21H		;Call DOS interrupt
	MOV	CX,[6]		;Get size of segment
	SUB	CX,100H		;Minus PSP
	MOV	BX,DS		;Save DS to BX
;DS must be set to CS so we can point to the FCB
	MOV	AX,CS
	MOV	DS,AX		;DS = CS
	MOV	DX,FCB		;Load FCB for COMMAND.COM
	MOV	AH,0FH		;Function = open file
	INT	21H		;Call DOS interrupt
	OR	AL,AL		;Get flags for AL
	JNZ	COMERR		;File not found
	MOV	[FCB+21H],0	;Record number = 0
	MOV	[FCB+23H],0
	MOV	[FCB+0EH],1	;Record size = 1
	MOV	AH,27H		;Function = random block read
	INT	21H		;Call DOS interrupt
	JCXZ	COMERR		;Error if no records read
	CMP	AL,1		;Check for EOF
	JNZ	COMERR		;Error if not end-of-file
;Make all segment registers the same
        CLI                     ;Disable interrupts
	MOV	DS,BX
	MOV	ES,BX
	MOV	SS,BX
	MOV	SP,5CH		;Set stack to standard value
        STI                     ;Enable interrupts
	XOR	AX,AX
	PUSH	AX		;Put zero on top of stack for return
	MOV	DX,80H	        ;Transfer address
	MOV	AH,1AH		;Function = set disk transfer address
	INT	21H		;Call DOS interrupt
	PUSH	BX		;Put segment on stack
	MOV	AX,100H
	PUSH	AX		;Put address to execute within segment on stack
	RET	L		;Jump to COMMAND

COMERR:
	MOV	DX,BADCOM	;Load bad or missing message
	CALL	OUTPSTR		;Print it out

STALL:
	JP	STALL		;Do nothing forever

;
; COMMAND.COM FCB
;
FCB:
	DB	01H		;Drive A
	DB	"COMMAND COM"
	DS	25

;
; Bad or missing COMMAND.COM error message
;
BADCOM:
	DB	13,10,"Bad or missing Command Interpreter",13,10,0

;
; Explanation of tables below.
;
; INITTAB is the initialization table for 86-DOS as described in the
; 86-DOS Programer's Manual under "Customizing the I/O System."
;
; Each Drive Parameter Table (DPT) represent a different drive type,
; the only DPT for the IBM PC is SSSD8SPT (5.25" 160K SSDD). DPT has
; the following entries:
;
;       SECSIZ    2 bytes       sector size in bytes
;       CLUSSIZ   1 byte        sectors per allocation unit
;       RESSEC    2 bytes       reserved sectors
;       FATCNT    1 byte        number of allocation tables
;       MAXENT    2 bytes       number of directory entrys
;       DSKSIZ    2 bytes       number of sectors on the disk
;
INITTAB:
	DB	4		;4 I/O drivers
	DW	SSDD8SPT	;A: 8 SPT single sided double density
	DW	SSDD8SPT	;B: 8 SPT single sided double density
	DW	SSDD8SPT	;C: 8 SPT single sided double density
	DW	SSDD8SPT	;D: 8 SPT single sided double density
	DW	0		;Reserved buffer space
	DW	0		;Reserved stack space

TABBUF	EQU	0
TABSTK	EQU	2

SSDD8SPT:
	DW	512		;512 bytes/sector
	DB	1		;1 sector/allocation unit
	DW	1		;Reserve 1 boot sector
	DB	2		;2 FATs - one for backup
	DW	64		;4 directory sectors
	DW	40*8		;Tracks * sectors/track = disk size

;
; Init code and data will no longer be needed after BIOS init, so this
; area will be used as temp sector buffer. Pad it to the size of a sector
; so that useful code and data won't be overwritten.
;
	DS	INIT+SECSIZE-$

STACKAREA:
DAYCNT:
	DW	0
PRNRETRY:
	DB	0
LASTCHAR:
	DB	0
	DB	0
SNGDRV:
	DB	0

;
; READ - Disk read
; WRITE - Disk write
;
; AL contains the I/O driver number, AH contains the verify flag, CX
; contains the number of sectors to transfer, DX contains the logical
; sector number and DS:BX is the transfer address. CF is set on error,
; with error code in AL and CX will contain the number of sectors left.
; All registers except for segment registers may be destroyed.
;
READ:
	MOV	AH,2		;Function = read
	JP	DISKIO

WRITE:
	MOV	AH,3		;Function = write

DISKIO:		;Main disk transfer logic
	PUSH	ES		;Save ES
	PUSH	DS		;Save DS
	PUSH	DS
	POP	ES		;ES = DS
	PUSH	CS
	POP	DS		;DS = CS
	MOV	[SPSAVE],SP	;Save SP
	MOV	[DISKOP],AH	;Save function ID
	CMP	B,[SNGDRV],SNGFLG	;Do we have only one drive?
	JNZ	TRANSINIT	;No
	PUSH	DS		;Save DS
	XOR	SI,SI
	MOV	DS,SI		;DS = 0
	MOV	AH,AL
	XCHG	AH,[504H]	;Swap with single drive mode status byte
	POP	DS		;Restore DS
	CMP	AL,AH		;Check if they're the same
	JZ	SKIPSWAP	;Yes, no need to swap
	PUSH	DX		;Save DX
	ADD	AL,"A"		;Convert ID to ASCII
	MOV	[DRVLETTER],AL	;Drive letter
	MOV	DX,SWAPMSG	;Load swap disk message
	CALL	OUTPSTR		;Print it out
	PUSH	DS		;Save DS
	XOR	BP,BP
	MOV	DS,BP		;DS = 0
	MOV	B,[41AH],1EH	;Flush keyboard
	MOV	B,[41CH],1EH
	POP	DS		;Restore DS
	MOV	AH,0		;Function = wait and read
	INT	16H		;Call keyboard BIOS service
	POP	DX		;Restore DX

SKIPSWAP:	;Select drive 0
	MOV	AL,0		;The physical drive A

TRANSINIT:	;Setup variables and check for 64K limitation
	XCHG	AX,DX		;AX = logical sector number, DL = drive ID
	MOV	DH,SPT
	DIV	AX,DH		;Divide sect number by SPT (track ID in AL)
	INC	AH		;Increment sect ID (sect ID starts at 1)
	XCHG	AL,AH		;AL = sect ID, AH = track ID
	XCHG	AX,CX		;AX = count, CL = sect ID, CH = track ID
	MOV	[SECTLEFT],AX	;Save count (sectors to transfer)
	MOV	DH,0		;Head 0
	MOV	DI,ES		;Convert ES:BX to linear address
	SHL	DI
	SHL	DI
	SHL	DI
	SHL	DI
	ADD	DI,BX		;Result in DI
	ADD	DI,SECSIZE-1	;Last byte of the sector
	JC	WORKAROUND	;Overflows, first sect crosses 64K boundary
	XCHG	DI,BX		;BX = ptr to last byte, DI = trans address low
	SHR	BH		;Number of sectors
	MOV	AH,80H		;Number of sectors in 64K
	SUB	AH,BH		;AH = number of sectors until boundary
	MOV	BX,DI		;BX = transfer address low
	CMP	AH,AL		;Compare sectors left and sector ID
	JBE	UNTIL64K	;Not enough space left until 64K boundary
	MOV	AH,AL		;Can do it at once

UNTIL64K:	;Transfer AH sectors at once
	PUSH	AX		;Save AX
	MOV	AL,AH		;AL = sectors to transfer
	CALL	TRANSFER	;Transfer sectors
	POP	AX		;Restore AX
	SUB	AL,AH		;Subtract completed sectors
	JZ	DISKIODONE	;Got 0 left, all done

WORKAROUND:	;Workaround for DMA access across 64K boundary
	DEC	AL		;Decrement sectors to transfer
	PUSH	AX		;Save AX
	CLD			;Ensure incrementing operation
	PUSH	BX		;Save BX
	PUSH	ES		;Save ES
	CMP	B,[DISKOP],RSECT;Check if operation is read
	JZ	RACROSS64K	;Yes, perform read
	MOV	SI,BX		;Source = BX (transfer address low)
	PUSH	CX		;Save CX
	MOV	CX,SECSIZE/2	;Sector length in words
	PUSH	ES
	POP	DS		;DS = ES
	PUSH	CS
	POP	ES		;ES = CS
	MOV	DI,INIT		;ES:DI = CS:INIT
	MOV	BX,DI		;Preserve DI before copy
	REP
	MOVSW			;Copy sector to temp area in BIOS
	POP	CX		;Restore CX
	PUSH	CS
	POP	DS		;DS = CS
	CALL	SINGLETRANS	;Transfer this one sector
	POP	ES		;Restore ES
	POP	BX		;Restore BX
	JP	DOREMAINING	;Finish off the rest of the sectors

RACROSS64K:	;Read to address that crosses 64K boundaries
	MOV	BX,INIT		;Temp area in BIOS
	PUSH	CS
	POP	ES		;ES = CS
	CALL	SINGLETRANS	;Read this one sector to temp area
	MOV	SI,BX		;Temp area is now source
	POP	ES		;Restore ES
	POP	BX		;Restore BX
	MOV	DI,BX		;Destination is original BX
	PUSH	CX		;Save CX
	MOV	CX,SECSIZE/2	;Sector size in words
	REP
	MOVSW			;Copy sector from temp area to destination
	POP	CX		;Restore CX

DOREMAINING:	;Transfer sectors after the 64K boundary
	ADD	BH,SSIZEHI	;Increment by sector size
	POP	AX		;Restore AX
	CALL	TRANSFER	;Transfer the remaining sectors

DISKIODONE:
	POP	DS		;Restore DS
	POP	ES		;Restore ES
	CLC			;Clear CF (indicate success)
	RET	L

;
; Transfer AL number of sectors
;
TRANSFER:
	OR	AL,AL		;Get flags for sectors to transfer
	JZ	RWDONE		;0 left, read/write of sectors is done
	MOV	AH,SPT+1	;SPT + 1 (add 1 to include current sector)
	SUB	AH,CL		;Take away sect ID, left with remaining ones
	CMP	AH,AL		;Sects left in track against to transfer
	JBE	RWTRACK		;Sectors left <= sectors left in track
	MOV	AH,AL		;Transfer sectors that are left in this track

RWTRACK:	;Read/write sects in current track
	PUSH	AX		;Save AX
	MOV	AL,AH		;AL = sectors to transfer
	CALL	SECTTRANS	;Transfer sectors
	POP	AX		;Restore AX
	SUB	AL,AH		;Decrement sectors left
	SHL	AH		;AH = high byte of transferred bytes
	ADD	BH,AH		;Increment transfer address
	JP	TRANSFER	;Transfer sectors for next track

RWERROR:	;Disk read/write error handler
	XCHG	AX,DI		;Save error code in DI
	MOV	AH,0		;Function = reset disk system
	INT	13H		;Call disk BIOS service
	DEC	SI		;Decrement number of retries
	JZ	ERRLOOKUP	;No retries left, error out
	MOV	AX,DI		;Error code to AX
	CMP	AH,80H		;Check if error is time out
	JZ	ERRLOOKUP	;Yes, don't retry
	POP	AX		;Restore AX
	JP	RWSECT		;Retry reading/writing sectors

ERRLOOKUP:	;Convert to DOS error code and return
	PUSH	CS
	POP	ES		;ES = CS
	MOV	AX,DI		;Error code to AX
	MOV	AL,AH		;Error code to AL
	MOV	CX,10		;10 entries in the table
	MOV	DI,ERRTABLE	;ES:DI points to the error table
	REPNE
	SCASB			;Compare error code
	MOV	AL,[DI+ERRCNT-1];Convert to DOS error code
	MOV	CX,[SECTLEFT]	;Sectors left
	MOV	SP,[SPSAVE]	;Restore original SP
	POP	DS		;Restore original DS
	POP	ES		;Restore original ES
	STC			;Set carry flag (indicate error)
	RET	L

SINGLETRANS:	;Transfer a single sector
	MOV	AL,1		;Transfer 1 sector only

SECTTRANS:	;Transfer multiple sectors
	MOV	SI,5		;We want to retry 5 times
	MOV	AH,[DISKOP]	;Load operation (read/write)

RWSECT:		;Plain read/write sectors
	PUSH	AX		;Save AX
	INT	13H		;Call disk BIOS service
	JC	RWERROR		;Error happened
	POP	AX		;Restore AX
	SUB	[SECTLEFT],AL	;Take away the ones already read/written
	ADD	CL,AL		;Sector ID after read/write
	CMP	CL,SPT		;Compare against sectors per track
	JBE	RWDONE		;Below or equal, we are done
	INC	CH		;Next track
	MOV	CL,1		;Sector ID = 1

RWDONE:		;Read/write of sectors done
	RET

;
; Disk swap message
;

SWAPMSG:
	DB	13,10,"Insert diskette for drive "
DRVLETTER:
	DB	"A: and strike",13,10,"any key when ready",13,10,10,0

;
; BIOS and DOS disk I/O error conversion table
;

ERRTABLE:
	DB	80H		;Time out, not ready
	DB	40H		;Seek failure
	DB	20H		;Controller error
	DB	10H		;CRC error
	DB	09H		;DMA access across 64K boundary
	DB	08H		;DMA overrun
	DB	04H		;Sector not found
	DB	03H		;Write protected
	DB	02H		;Address mark not found or bad sector
	DB	01H		;Bad command
ERRCNT	EQU	$-ERRTABLE
	DB	02H		;Not ready
	DB	06H		;Seek error
	DB	0CH		;Disk error
	DB	04H		;Data error
	DB	0CH		;Disk error
	DB	04H		;Data error
	DB	08H		;Sector not found
	DB	00H		;Write protected
	DB	0CH		;Disk error
	DB	0CH		;Disk error

DISKOP:
	DB	RSECT		;Disk operation, default to read
SPSAVE:
	DW	0		;For saving SP
SECTLEFT:
	DW	0		;For number of sectors to read/write

;Compute segment to use for 86-DOS
DOSSEG	EQU	(($+15)/16)+BIOSSEG

;Compute segment 86-DOS is currently at
OLDSEG	EQU	((($+SECSIZE-1)/SECSIZE)*SECSIZE/16)+BIOSSEG

SPT	EQU	8		;Sectors per track
RSECT	EQU	2		;INT 13H command for read
WSECT	EQU	3		;INT 13H command for write
SNGFLG	EQU	1		;Flag for single drive
SSIZEHI	EQU	SECSIZE/256	;High byte of sector size
