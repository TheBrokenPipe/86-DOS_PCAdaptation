; I/O System for 86-DOS.

; Select whether to use buffered I/O. Better performance can be achieved
; using buffered I/O, at the cost of reduced safety.
DOBUFIO	EQU	0
NOBUFIO	EQU	1

DOSSIZE	EQU	1600H		;Max length of 86-DOS in bytes
BIOSSEG	EQU	60H		;BIOS segment for the IBM PC
OLDSEG	EQU	0E0H		;Original 86-DOS segment

SPT	EQU	8		;Sectors per track
STKSIZE	EQU	256		;Stack size for BIOS

	ORG	0

; Remove the "J" to use the default stack. This will improve speed, at the
; cost of possible stack overflow. Whether stack overflow will happen depends
; on the PC BIOS ROM revision. It is suggested that you experiment with these
; to work out the most suitable combination for your PC.
	JMP	INIT
	JMP	JSTATUS
	JMP	JCONIN
	JMP	JCONOUT
	JMP	JPRINT
	JMP	JAUXIN
	JMP	JAUXOUT
	JMP	JREAD
	JMP	JWRITE
	JMP	JFLUSH

;
; These are wrappers around actual BIOS calls to ensure that they
; have enough stack space.
;
JSTATUS:
	SEG	CS
	MOV	[BIOSCALL],STATUS
	JMP	CALLFUNC

JCONIN:
	SEG	CS
	MOV	[BIOSCALL],CONIN
	JMP	CALLFUNC

JCONOUT:
	SEG	CS
	MOV	[BIOSCALL],CONOUT
	JMP	CALLFUNC

JPRINT:
	SEG	CS
	MOV	[BIOSCALL],PRINT
	JMP	CALLFUNC

JAUXIN:
	SEG	CS
	MOV	[BIOSCALL],AUXIN
	JMP	CALLFUNC

JAUXOUT:
	SEG	CS
	MOV	[BIOSCALL],AUXOUT
	JMP	CALLFUNC

JREAD:
	SEG	CS
	MOV	[BIOSCALL],READ
	JMP	CALLFUNC

JWRITE:
	SEG	CS
	MOV	[BIOSCALL],WRITE
	JMP	CALLFUNC

JFLUSH:
	SEG	CS
	MOV	[BIOSCALL],FLUSH
	JMP	CALLFUNC

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
; Divide overflow handler
;
DIVZERO:
	STI			;Turn interrupts on
	PUSH	AX		;Save AX
	PUSH	DX		;Save DX
	MOV	DX,DIVOVER	;Load divide overflow message
	CALL	OUTPSTR		;Print it out
	POP	DX		;Restore DX
	POP	AX		;Restore AX
	INT	23H		;Call CTRL + C handler

;
; Dummy interrupt routine
;
INTSTUB:
	IRET			;Simply return

;
; Divide overflow error message
;
DIVOVER:
	DB	13,10,"Divide overflow",13,10,0

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
; FLUSH - Flush buffers
;
; AL contains the I/O driver number to have buffers flushed, or -1 to
; indicate that all buffers should be flushed. All registers except for
; segment registers may be destroyed. Not required if memory buffering
; is not used.
;
FLUSH:
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
	SHR	AX		;Divide by 2 = (drives * 2) / 2
	MOV	[INITTAB],AL	;Save drive count

FLPDONE:
	PUSH	DS		;Save DS
	MOV	AX,0
	MOV	DS,AX		;DS = 0
	MOV	AX,BIOSSEG	;Load BIOS seg
;Set BREAK handler
	MOV	[6CH+2],AX	;Change INT 1BH seg
	MOV	[6CH],BREAK	;Change INT 1BH address
;Set divide overflow handler
	MOV	[00H],DIVZERO	;Change INT 00H address
	MOV	[00H+2],AX	;Change INT 00H seg
;Disable all interrupts used for debugging
	MOV	BX,INTSTUB	;Load stub interrupt address
	MOV	[04H],BX	;Change INT 01H address
	MOV	[04H+2],AX	;Change INT 01H seg
	MOV	[0CH],BX	;Change INT 03H address
	MOV	[0CH+2],AX	;Change INT 03H seg
	MOV	[10H],BX	;Change INT 04H address
	MOV	[10H+2],AX	;Change INT 04H seg
;Clear print screen status
	MOV	AX,50H
	MOV	DS,AX		;DS = 50H
	MOV	[00H],0		;Zero print screen flag
;Move DOS to the end of the BIOS
	PUSH	ES		;Save ES
	MOV	AX,BIOEND
	ADD	AX,15
	SHR	AX
	SHR	AX
	SHR	AX
	SHR	AX
	ADD	AX,BIOSSEG
	SEG	CS
	MOV	[DOSSEG],AX	;Compute new DOS segment
	MOV	CX,OLDSEG
	CMP	AX,CX		;Which direction to move
	JA	MOVEUP		;Move to higher location
	CLD			;Move down, copy normally
	XOR	DI,DI		;ES:DI = DOSSEG:0000
	MOV	SI,DI		;DS:SI = OLDSEG:0000
	MOV	ES,AX		;Set ES to DOS seg
	JP	MOVEDOS

MOVEUP:
	STD			;Copy backwards
	MOV	SI,DOSSIZE-2	;SI = OLDSEG:DOSSIZE
	MOV	ES,CX		;ES = OLDSEG
	SUB	AX,CX
	SHL	AX
	SHL	AX
	SHL	AX
	SHL	AX		;AX = (DOSSEG - OLDSEG) * 16
	MOV	DI,SI
	ADD	DI,AX		;DI = AX + DOSSIZE

MOVEDOS:
	MOV	DS,CX		;Set DS to current DOS seg
	MOV	CX,DOSSIZE
	SHR	CX		;Copy DOSSIZE/2 words
	REP
	MOVW			;Copy DOS
	CLD			;Clear DF no matter what
	POP	ES		;Restore ES
	POP	DS		;Restore DS
;Load 86-DOS
	MOV	SI,INITTAB	;Load drive list pointer
	SEG	CS
	CALL	L,[DOSADR]	;Call DOS init
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
	CLI			;Disable interrupts
	MOV	DS,BX
	MOV	ES,BX
	MOV	SS,BX
	MOV	SP,40H		;Set stack to standard value
	STI			;Enable interrupts
	XOR	AX,AX
	PUSH	AX		;Put zero on top of stack for return
	MOV	DX,80H		;Transfer address
	MOV	AH,1AH		;Function = set disk transfer address
	INT	21H		;Call DOS interrupt
	PUSH	BX		;Put segment on stack
	MOV	AX,100H
	PUSH	AX		;Put address on stack
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
; Initialization table for 86-DOS
;
INITTAB:
	DB	4		;4 I/O drivers
	DW	SSDD8SPT	;A: 8 SPT single sided double density
	DW	FAT0
	DW	SSDD8SPT	;B: 8 SPT single sided double density
	DW	FAT1
	DW	SSDD8SPT	;C: 8 SPT single sided double density
	DW	FAT2
	DW	SSDD8SPT	;D: 8 SPT single sided double density
	DW	FAT3

SSDD8SPT:
	DB	4		;Records/sector
	DB	4		;Records/cluster
	DW	64		;Reserved records
	DB	4		;FAT size (records)
	DB	2		;Number of FATs
	DB	8		;Number of directory records
	DW	300		;Number of clusters on drive

;
; Init code and data will no longer be needed after BIOS init, so this
; area will be used as temp sector buffer. Pad it to the size of a sector
; so that useful code and data won't be overwritten.
;
	DS	INIT+512-$
	ALIGN
STACKAREA:

PRNRETRY:
	DB	0
LASTCHAR:
	DB	0
	DB	0
SNGDRV:
	DB	0
DOSADR:
	DW	0
DOSSEG:
	DS	2		;Final 86-DOS segment

;
; Convert logical record number to logical sector number
;
; Record number in AX, returns sector number in AX and index into sector
; in DX.
;
RECTOSEC:
	PUSH	BX
	PUSH	AX		;Save original
	SHR	AX
	SHR	AX		;AX /= 4
	MOV	BX,AX
	SHL	BX
	SHL	BX		;BX = AX * 4
	POP	DX
	SUB	DX,BX		;DX = Original - BX
	POP	BX
	RET

;
; Copy memory around
;
; Source pointer in SI, destination pointer in DI and words to copy
; in AX. SI and DI will be incremented.
;

MEMCPY:
	PUSH	CX
	MOV	CX,AX
	CLD			;Normal direction
	REP
	MOVW			;Perform copy
	POP	CX
	RET

SECNUM:
	DS	2		;The logical sector number
RECIDX:
	DS	2		;Index into the buffered sector
RECTORW:
	DS	2		;The number of records left to be transferred

	IF	DOBUFIO
BUFSEC:
	DW	0FFFFH		;The logical index of the sector in memory
BUFDSK:
	DB	0FFH		;The disk which the buffered sector belong to
TEMPDSK:
	DS	1		;Temp disk ID
TEMPBUF:
	DS	2		;Temp sector number

;
; Buffered disk read
;
; Same as READRAW, but with buffering support.
;
BUFREAD:
	CMP	AL,[BUFDSK]	;Check if disk matches
	JZ	CHECKSEC	;Yes, go check sector number

READNEW:
	MOV	[TEMPDSK],AL	;Save current disk about to be read
	MOV	[TEMPBUF],DX	;Save current sector about to be read
	CALL	READRAW		;Read sector
	JNC	UPDATEBUF	;Update the buffer information
	MOV	[BUFDSK],0FFH	;Error, invalidate buffered sector
	STC
	RET

CHECKSEC:
	CMP	DX,[BUFSEC]	;Is the sector currently in memory
	JZ	BUFRET		;Yes, all done
	JP	READNEW		;No, go read new sector and update buffer info

UPDATEBUF:
	MOV	BX,[TEMPBUF]
	MOV	[BUFSEC],BX	;Update current buffered sector
	MOV	BL,[TEMPDSK]
	MOV	[BUFDSK],BL	;Update current disk

BUFRET:
	CLC
	RET
	ENDIF

READ:
	SEG	CS
	MOV	[AXSAV],AX	;Save AX
	MOV	AX,DS
	SEG	CS
	MOV	[DSSAV],AX	;Save DS
	MOV	AX,CS
	MOV	DS,AX		;DS = CS
	MOV	AX,ES
	MOV	[ESSAV],AX	;Save ES
	MOV	AX,DX		;AX = logical record number
	CALL	RECTOSEC	;Convert to logical sector number and index
	MOV	[SECNUM],AX	;Save sector number
	MOV	[RECIDX],DX	;Save record index

EACHSECT:
	OR	CX,CX		;Check for remaining records
	JZ	DONE		;Nothing left, all done
	MOV	AX,[AXSAV]	;Restore AX
	MOV	DX,[SECNUM]	;Logical sector number for READRAW
	MOV	[CXSAV],CX	;Save CX
	MOV	CX,1		;Read 1 sector
	MOV	[BXSAV],BX	;Save BX
	MOV	BX,SECBUF	;Use the internal sector buffer
	IF	DOBUFIO
	CALL	BUFREAD		;Perform BUFREAD
	ENDIF
	IF	NOBUFIO
	CALL	READRAW		;Perform READRAW
	ENDIF
	JC	ERRBUF		;Handle error
	MOV	BX,[BXSAV]	;Restore BX
	MOV	CX,[CXSAV]	;Restore CX
	MOV	AX,4
	MOV	DX,[RECIDX]
	SUB	AX,DX		;AX = 4 - RECIDX
	CMP	AX,CX		;See which one is smaller
	JA	USECX
	JP	USEAX

USECX:
	MOV	AX,CX

USEAX:
	MOV	[RECTORW],AX	;RECTORW = MIN(AX,CX)
	SHL	AX
	SHL	AX
	SHL	AX
	SHL	AX
	SHL	AX
	SHL	AX		;AX = RECTORW * 128 (/2 for MOVW)
	SHL	DX
	SHL	DX
	SHL	DX
	SHL	DX
	SHL	DX
	SHL	DX
	SHL	DX		;DX = RECIDX * 128
	MOV	SI,SECBUF
	ADD	SI,DX		;SI = SECBUF + RECIDX * 128
	MOV	DI,[DSSAV]
	MOV	ES,DI
	MOV	DI,BX		;ES:DI = DSSAV:BX
	CALL	MEMCPY		;Copy the records
	MOV	BX,DI		;Increment DSSAV:BX
	MOV	AX,[RECTORW]
	SUB	CX,AX		;Take away records transferred this time
	MOV	AX,[SECNUM]
	INC	AX
	MOV	[SECNUM],AX	;Increment SECNUM
	JP	EACHSECT

DONE:
	MOV	AX,[ESSAV]
	MOV	ES,AX		;Restore ES
	MOV	AX,[DSSAV]
	MOV	DS,AX		;Restore DS
	CLC			;Clear CF for success
	JP	READDONE

ERRBUF:
	MOV	CX,[CXSAV]	;Restore CX (sectors left)
	PUSH	AX		;Save AX
	MOV	AX,[ESSAV]
	MOV	ES,AX		;Restore ES
	MOV	AX,[DSSAV]
	MOV	DS,AX		;Restore DS
	POP	AX		;Restore AX (error code)
	STC			;Set CF for error

READDONE:
	RET	L

WRITE:
	SEG	CS
	MOV	[AXSAV],AX	;Save AX
	MOV	AX,DS
	SEG	CS
	MOV	[DSSAV],AX	;Save DS
	MOV	AX,CS
	MOV	DS,AX		;DS = CS
	MOV	AX,ES
	MOV	[ESSAV],AX	;Save ES
	MOV	AX,DX		;AX = logical record number
	CALL	RECTOSEC	;Convert to logical sector number and index
	MOV	[SECNUM],AX	;Save sector number
	MOV	[RECIDX],DX	;Save record index

WEACHSECT:
	OR	CX,CX		;Check for remaining records
	JZ	DONE		;Nothing left, all done
	MOV	AX,[AXSAV]	;Restore AX
	MOV	DX,[SECNUM]	;Logical sector number for READRAW
	MOV	[CXSAV],CX	;Save CX
	MOV	CX,1		;Read 1 sector
	MOV	[BXSAV],BX	;Save BX
	MOV	BX,SECBUF	;Use the internal sector buffer
	IF	DOBUFIO
	CALL	BUFREAD		;Perform BUFREAD
	ENDIF
	IF	NOBUFIO
	CALL	READRAW		;Perform READRAW
	ENDIF
	JC	ERRBUF		;Handle error
	MOV	BX,[BXSAV]	;Restore BX
	MOV	CX,[CXSAV]	;Restore CX
	MOV	AX,4
	MOV	DX,[RECIDX]
	SUB	AX,DX		;AX = 4 - RECIDX
	CMP	AX,CX		;See which one is smaller
	JA	WUSECX
	JP	WUSEAX

WUSECX:
	MOV	AX,CX

WUSEAX:
	MOV	[RECTORW],AX	;RECTORW = MIN(AX,CX)
	SHL	AX
	SHL	AX
	SHL	AX
	SHL	AX
	SHL	AX
	SHL	AX		;AX = RECTORW * 128 (/2 for MOVW)
	SHL	DX
	SHL	DX
	SHL	DX
	SHL	DX
	SHL	DX
	SHL	DX
	SHL	DX		;DX = RECIDX * 128
	MOV	DI,SECBUF
	ADD	DI,DX
	MOV	SI,DS
	MOV	ES,SI		;ES:DI = SECBUF + RECIDX * 128
	MOV	DS,[DSSAV]
	MOV	SI,BX		;Source = DSSAV:BX
	CALL	MEMCPY		;Copy the records
	MOV	BX,CS
	MOV	DS,BX
	MOV	BX,SI		;Increment DSSAV:BX
	MOV	AX,[AXSAV]	;Restore AX
	MOV	DX,[SECNUM]	;Logical sector number for WRITERAW
	MOV	[CXSAV],CX	;Save CX
	MOV	CX,1		;Read 1 sector
	MOV	[BXSAV],BX	;Save BX
	MOV	BX,SECBUF	;Use the internal sector buffer
	CALL	WRITERAW	;Perform WRITERAW
	JNC	TEMP
	IF	DOBUFIO
	MOV	[BUFDSK],0FFH	;Invalidate buffered sector
	ENDIF
	JMP	ERRBUF		;Handle error

TEMP:
	MOV	AX,[RECTORW]
	MOV	BX,[BXSAV]
	MOV	CX,[CXSAV]
	SUB	CX,AX		;Take away records transferred this time
	MOV	AX,[SECNUM]
	INC	AX
	MOV	[SECNUM],AX	;Increment SECNUM
	JMP	WEACHSECT

;
; READRAW - Disk read (RAW)
; WRITERAW - Disk write (RAW)
;
; AL contains the I/O driver number, AH contains the directory flag, CX
; contains the number of sectors to transfer, DX contains the logical
; sector number and DS:BX is the transfer address. CF is set on error,
; with error code in AL and CX will contain the number of sectors left.
; All registers except for segment registers may be destroyed.
;
READRAW:
	MOV	AH,2		;Function = read
	JP	DISKIO

WRITERAW:
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
	CMP	B,[SNGDRV],1	;Do we have only one drive?
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
	ADD	DI,512-1	;Last byte of the sector
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
	CMP	B,[DISKOP],2	;Check if operation is read
	JZ	RACROSS64K	;Yes, perform read
	MOV	SI,BX		;Source = BX (transfer address low)
	PUSH	CX		;Save CX
	MOV	CX,256		;Sector length in words
	PUSH	ES
	POP	DS		;DS = ES
	PUSH	CS
	POP	ES		;ES = CS
	MOV	DI,INIT		;ES:DI = CS:INIT
	MOV	BX,DI		;Preserve DI before copy
	REP
	MOVW			;Copy sector to temp area in BIOS
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
	MOV	CX,256		;Sector size in words
	REP
	MOVW			;Copy sector from temp area to destination
	POP	CX		;Restore CX

DOREMAINING:	;Transfer sectors after the 64K boundary
	ADD	BH,2		;Increment by sector size
	POP	AX		;Restore AX
	CALL	TRANSFER	;Transfer the remaining sectors

DISKIODONE:
	POP	DS		;Restore DS
	POP	ES		;Restore ES
	CLC			;Clear CF (indicate success)
	RET

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
	SCAB			;Compare error code
	MOV	AL,[DI+ERRCNT-1];Convert to DOS error code
	MOV	CX,[SECTLEFT]	;Sectors left
	MOV	SP,[SPSAVE]	;Restore original SP
	POP	DS		;Restore original DS
	POP	ES		;Restore original ES
	STC			;Set carry flag (indicate error)
	RET

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
	DB	2		;Disk operation, default to read
SPSAVE:
	DW	0		;For saving SP
SECTLEFT:
	DW	0		;For number of sectors to read/write

;
; BIOS function call helper
;
; Move pointer to the BIOS function to BIOSCALL and jump here to perfrom the
; exact same BIOS call but with a stack of STKSIZE bytes. Use this if there
; is not enough stack space left.
;
CALLFUNC:
;-------------------- SWITCH TO TEMP STACK --------------------
	SEG	CS
	MOV	[AXSAV],AX	;Save AX
	PUSHF
	POP	AX		;AX = FLAGS
	SEG	CS
	MOV	[FLSAV],AX	;Save flags
	SEG	CS
	MOV	[SSSAV],SS	;Save SS
	SEG	CS
	MOV	[SPSAV],SP	;Save SP
	CLI			;Disable interrupts
	MOV	AX,CS
	MOV	SS,AX
	MOV	SP,BIOSSTK	;SS:SP = BIOSSEG:BIOSSTK
	SEG	CS
	MOV	AX,[FLSAV]	;AX = FLAGS
	PUSH	AX
	POPF			;Restore flags
	SEG	CS
	MOV	AX,[AXSAV]	;Restore AX
;--------------------------------------------------------------
	PUSH	CS		;Simulate inter-segment call
	SEG	CS
	CALL	[BIOSCALL]	;Perform normal call
;-------------------- SWITCH TO ORIG STACK --------------------
	SEG	CS
	MOV	[AXSAV],AX	;Save AX
	PUSHF
	POP	AX		;AX = FLAGS
	SEG	CS
	MOV	[FLSAV],AX	;Save flags
	CLI			;Disable interrupts
	SEG	CS
	MOV	AX,[SSSAV]
	MOV	SS,AX		;SS = SSSAV
	SEG	CS
	MOV	AX,[SPSAV]
	MOV	SP,AX		;SP = SPSAV
	SEG	CS
	MOV	AX,[FLSAV]	;AX = FLAGS
	PUSH	AX
	POPF			;Restore flags
	SEG	CS
	MOV	AX,[AXSAV]	;Restore AX
;--------------------------------------------------------------
	RET	L

;-------------- END OF INITIALIZED CODE AND DATA --------------
;--------------    ASSEMBLED BINARY ENDS HERE    --------------

BIOSCALL:
	DS	2		;For storing BIOS call pointers

;
; Register save area
;
AXSAV:	DS	2
BXSAV:	DS	2
CXSAV:	DS	2
DXSAV:	DS	2
SISAV:	DS	2
DISAV:	DS	2
DSSAV:	DS	2
ESSAV:	DS	2
SSSAV:	DS	2
SPSAV:	DS	2
FLSAV:	DS	2

SECBUF:
	DS	512		;Buffered physical sector

	DS	STKSIZE		;Stack for BIOS calls
	ALIGN
BIOSSTK:

BIOEND	EQU	$

	ORG	0
FAT0:
	DS	512
FAT1:
	DS	512
FAT2:
	DS	512
FAT3:
	DS	512
