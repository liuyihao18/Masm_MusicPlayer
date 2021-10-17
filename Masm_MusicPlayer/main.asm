; main.asm
INCLUDE     custom.inc
INCLUDE     music_api.inc

.data
filename    BYTE            "1.wav", 0
hFile       DWORD           ?

.code
main PROC
    INVOKE  PlayMusic,  OFFSET filename
    INVOKE  ExitProcess, 0
main ENDP

END main
