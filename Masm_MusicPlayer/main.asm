; main.asm
INCLUDE     custom.inc
INCLUDE     music_api.inc

.data
filename    BYTE            "1.wav", 0
hFile       DWORD           ?

.code
main PROC
    INVOKE  PlayMusic,  OFFSET filename
L1:
    INVOKE  Sleep, 12000
    INVOKE  BackwardMusicTime
    INVOKE  Sleep, 1000
    INVOKE  BackwardMusicTime
    jmp     L1
    INVOKE  ExitProcess, 0
main ENDP

END main
