;Source code for drive tables used by RDCPM

	ORG	0
	PUT	100H

	DW	END		;Address of first free byte

;Table of addresses of the parameter block for each of 16 drives.
;Note that 16 entries are ALWAYS required, with unused drives 0.

	DW	IBM,IBM,IBM,IBM
	DW	0,0,0,0
	DW	0,0,0,0
	DW	0,0,0,0

;Below is the definition for standard double-density 5.25" drives

IBM:
	DW	32	;Sectors per track
	DB	3	;Block shift
	DB	7	;Block mask
	DB	0	;Extent mask
	DW	155	;Disk size - 1
	DW	63	;Directory entries - 1
	DS	4	;Not used
	DW	1	;Tracks to skip
	DW	MOD32	;Modulo-32 sector translate table

MOD32:
	DB	00,01,02,03,04,05,06,07
	DB	08,09,10,11,12,13,14,15
	DB	16,17,18,19,20,21,22,23
	DB	24,25,26,27,28,29,30,31

END:
