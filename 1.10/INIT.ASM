; Disk initialization routine for the IBM PC.
; Runs on 8086 under 86-DOS

; Translated from the Z80 on 12-19-80 and subsequently modified to init
; IBM PC disks.

SYSTEM:	EQU	5
SELDRV:	EQU	14

RESET:	EQU	0
TRKFMT:	EQU	5

	ORG	100H
	PUT	100H

	MOV	CL,9
	MOV	DX,HEADER
	CALL	SYSTEM
EACH:
	MOV	SP,STACK
	XOR	AX,AX
	PUSH	AX
	MOV	CL,9
	MOV	DX,DRVMES
	CALL	SYSTEM
	MOV	CL,1
	CALL	SYSTEM
	CMP	AL,13
	JZ	RET
	AND	AL,5FH
	SUB	AL,'A'
	JC	EACH
;Check if valid drive
	MOV	DH,AL
	MOV	DL,-1
	MOV	AH,SELDRV
	INT	33		;Get number of drives
	CMP	DH,AL
	JNC	EACH
	MOV	DL,DH		;Set DL to drive number
	CALL	FMTDSK		;Format disk
	JNC	EACH
	MOV	CL,9
	MOV	DX,ERRMES
	CALL	SYSTEM
	JP	EACH

;
; Format a 5.25" SSDD floppy disk with 8 SPT.
;
FMTDSK:
	MOV	BX,PATTERN
	XOR	AX,AX
	MOV	CX,40		;40 tracks
	MOV	DH,3		;Minimum 3 retries
FMTEACH:
	PUSH	CX
	MOV	CL,8		;8 sectors per track
	MOV	CH,2		;512-byte sectors
	CALL	FMTTRK
	JC	FMTERR
	INC	AL
	POP	CX
	LOOP	FMTEACH
	RET
FMTERR:
	POP	CX
	JP	RET

;
; Format a track.
;
;     AL    - track number
;     AH    - head number
;     CL    - sectors per track
;     CH    - sector size (0 = 128, 1 = 256, 2 = 512, 3 = 1024)
;     DL    - drive number
;     DH    - number of retries on error
;     ES:BX - buffer with 4 * CL bytes
;
; On return:
;     CF = 0 <= success
;     CF = 1 <= error
;
FMTTRK:
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	SI
	PUSHF
;Build address field list
	PUSH	CX		;CX - SPT+SIZE, now use as loop counter
	PUSH	DX		;DX - DRV+RETRIES, now use as sect counter
	MOV	DH,1		;Sect count starts at 1
	PUSH	BX		;BX - buffer ptr, will increment it
	PUSH	DI		;DI - unused, now use as TRK+HEAD
	MOV	DI,AX
	PUSH	AX		;AX - TRK+HEAD, now use as SIZE backup
	MOV	AH,CH
	XOR	CH,CH		;Clear high byte, only sect count left
BLDLIST:
	SEG	ES
	MOV	[BX],DI		;Set track and head number
	MOV	B,[BX+2],DH	;Set sector number
	MOV	B,[BX+3],AH	;Set sector size
	INC	DH
	ADD	BX,4
	LOOP	BLDLIST
	POP	AX		;List built, restore registers
	POP	DI
	POP	BX
	POP	DX
	POP	CX
;Setup variables for INT 19
	PUSH	BX
	MOV	BL,CL		;BL = sectors per track
	MOV	CH,AL		;CH = track number
	XOR	CL,CL		;Make some oddball clones happy
	MOV	SI,DX		;SI = DRV+RETRIES
	MOV	DH,AH		;DH = head number
	MOV	AL,BL		;AL = sectors per track
	MOV	BX,SI		;BX = SI
	XCHG	BL,BH		;Swap bytes
	XOR	BH,BH		;Clear high byte
	MOV	SI,BX		;SI = retries
	POP	BX
TRYFMT:
	MOV	AH,TRKFMT
	INT	19		;Format track
	JC	TRKERR
	JP	BAKFLAG
TRKERR:
	PUSH	AX
	MOV	AH,RESET
	INT	19		;Reset after error
	POP	AX
	DEC	SI
	JZ	SETERR		;No retries left
	CMP	AH,80H		;Check if error is time out
	JZ	SETERR		;Will take too long, just error out
	JP	TRYFMT
SETERR:
	POPF
	STC
	JP	TRKDONE
BAKFLAG:
	POPF
	CLC
TRKDONE:
	POP	SI
	POP	DX
	POP	CX
	POP	BX
	POP	AX
	RET

HEADER:	DB	13,10,"Diskette Initialization Routine",13,10
	DB	"Completely re-formats any bad disk--"
	DB	"destroying its contents, of course!",13,10,"$"
DRVMES:	DB	13,10,"Initialize disk in which drive? $"
ERRMES:	DB	13,10,13,10,"ERROR - Not ready or write protected",13,10,"$"

	DS	200H		;Should never overflow again
	ALIGN
STACK:	EQU	$

PATTERN:
