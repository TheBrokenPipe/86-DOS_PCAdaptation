; Boot sector for 86-DOS version 1.10 and later. Revised 11-25-22.

	ORG	7C00H

	JMP	INIT		;Intra-segment long jump

;
; Disk layout (BIOS Parameter Block)
;
	DB	"86DOS1.1"	;OEM identifier
	DW	512		;Sector size
	DB	1		;Sectors per block
	DW	1		;Reserved sectors
	DB	2		;Number of FATs
	DW	64		;Number of directory entries
	DW	320		;Total number of sectors
	DB	0FEH		;Media type
	DW	1		;Sectors per FAT
	DW	8		;Sectors per track
	DW	1		;Number of heads
	DW	0		;Number of hidden sectors
	DS	8		;Reserved
	DB	29H		;Extended BPB
	DS	4		;Volume serial number
	DB	"NO NAME    "	;Volume label
	DB	"FAT12   "	;File system ID

;
; Checks whether the current disk is a system disk
;
CHECKSYS:
	MOV	BX,0		;ES:BX = 0060:0000
	MOV	CX,4		;Track 0, sector 4
	MOV	AX,201H		;Function = disk read, sectors = 1
	INT	13H		;Call disk BIOS service
	PUSH	DS		;Save DS
	JC	NOSYS		;Read error
	MOV	AX,CS
	MOV	DS,AX		;DS = CS
;Compare first 2 directory entries
	MOV	DI,0		;Point to first entry
	MOV	SI,BIOENTRY	;BIOS name
	MOV	CX,11		;11 chars to compare
	CLD			;Clear direction flag
	REPE
	CMPSB			;Compare the chars
	JNZ	NOSYS		;Not IO.SYS
	MOV	DI,20H		;Point to second entry
	MOV	SI,DOSENTRY	;DOS name
	MOV	CX,11		;Compare 11 chars
	REPE
	CMPSB			;Compare the chars
	JNZ	NOSYS		;Not 86DOS.SYS
	POP	DS		;Restore DS
	RET

NOSYS:		;Not a system disk, prompt user to retry
	MOV	SI,NOSYSMSG	;Load not system disk message
	CALL	PRINT		;Print it
	MOV	AH,0		;Function = wait and read
	INT	16H		;Call keyboard BIOS service
	POP	DS		;Restore DS
	STC			;Set CF (indicate error)
	RET

;
; Increments the BX pointer by SI sectors
;
INCDSTPTR:
	PUSH	AX		;Save AX
	PUSH	DX		;Save DX
	MOV	AX,SI		;Sectors read
	MOV	DI,200H		;Size of each sector
	MUL	AX,DI		;Bytes read
	ADD	BX,AX		;Add bytes read to BX
	POP	DX		;Restore DX
	POP	AX		;Restore AX
	RET

;
; Init boot loader
;
INIT:
;Setup temp stack
	CLI			;Disable interrupts
	MOV	AX,CS
	MOV	DS,AX		;DS = CS
	MOV	DX,0
	MOV	SS,DX		;SS = 0
	MOV	SP,7C00H	;SP = 7C00H
	STI			;Enable interrupts
;Setup segment registers
	MOV	AX,60H
	MOV	DS,AX		;DS = 60H
	MOV	ES,AX		;ES = 60H
	MOV	DX,0		;Drive 0
	MOV	AX,DX		;Function = reset disk system
	INT	13H		;Call disk BIOS service
	JC	DSKERR

CHKSYSLOOP:	;Wait until a system disk is inserted
	CALL	CHECKSYS
	JC	CHKSYSLOOP
;Load the first sector of the BIOS
	MOV	CX,20		;Sectors to load
	PUSH	CX		;Save it
	MOV	BX,0		;ES:BX = 0060:0000
	XOR	DX,DX		;Drive 0, head 0
	MOV	CX,8		;Track 0, sector 8
	MOV	SI,1		;1 sector will be read the first time
	PUSH	SI		;Save it
	MOV	AL,1		;Read 1 sector

READ:		;Reads some sectors to memory
	MOV	AH,2		;Function = disk read
	INT	13H		;Call disk BIOS service
	JC	DSKERR
	POP	SI		;Sectors read
	POP	AX		;Sectors to read
	CALL	INCDSTPTR	;Increment dest pointer
	SUB	AX,SI		;Decrement sectors to read
	JZ	BOOT		;All sectors read, boot it
	INC	CH		;Next track
	MOV	CL,1		;Back to first sector
	MOV	SI,8		;8 sectors to read
	CMP	AX,SI		;Compare sectors left with sectors to read
	JNB	MORELEFT	;Sectors left >= sectors to read
	MOV	SI,AX		;Just read the remaining ones
	JP	READAGAIN

MORELEFT:	;More sectors left than to read
	XCHG	SI,AX		;Swap them

READAGAIN:	;Reads the next group of sectors
	PUSH	SI		;Save sectors left
	PUSH	AX		;Save sectors to read
	JP	READ

BOOT:		;Finished loading, jump to BIOS
	JMP	0,60H		;Long jump to BIOS

DSKERR:		;Disk read error, boot to ROM BASIC
	MOV	SI,BOOTERRMSG	;Load boot error message
	MOV	AX,LDBASIC	;Offset of INT 18H
	PUSH	AX		;RET will return to BASIC

PRINT:	;Prints a string
	LODSB			;Fetch char
	OR	AL,AL		;Check for zero
	JZ	PRINTDONE	;Yes, end of string
	PUSH	SI		;Save SI
	MOV	AH,0EH		;Function = write char
	MOV	BX,7		;Light gray and page number = 0
	INT	10H		;Call video BIOS service
	POP	SI		;Restore SI
	JP	PRINT

PRINTDONE:
	RET

;
; Code for loading ROM BASIC
;
LDBASIC:
	INT	18H

;
; Not a system disk error message
;
NOSYSMSG:
	DB	13,10,"Non-System disk or disk error",13,10
	DB	"Replace and strike any key when ready",13,10,0

;
; Boot failure message
;
BOOTERRMSG:
	DB	13,10,"Disk Boot failure",13,10,0

;
; BIOS name
;
BIOENTRY:
	DB	"IO      SYS"

;
; DOS name
;
DOSENTRY:
	DB	"86DOS   SYS"

	DS	7C00H+512-$-2
	DB	055H,0AAH	;Boot sector signature
