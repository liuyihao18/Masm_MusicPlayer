; main.asm
INCLUDE     custom.inc

.data
filename    BYTE            "1.mp3", 0
hFile       DWORD           ?

.code
main PROC
    INVOKE  ExitProcess, 0
main ENDP

END main
