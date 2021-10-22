; main.asm
INCLUDE     custom.inc
;INCLUDE     error_handle.inc
.data
hInstance   HINSTANCE   ?
hMainwnd    DWORD    ?
msg MSG <>
extern MainWin:     WNDCLASSA
extern CLASS_NAME:  PTR BYTE
extern WINDOW_TEXT: PTR BYTE
.code

WinMain PROC
    INVOKE GetModuleHandle, NULL
    wcStyle     EQU         CS_HREDRAW  OR  CS_VREDRAW
    mov MainWin.style,           wcStyle
    INVOKE RegisterClass, ADDR MainWin
    .IF eax == 0
        jmp Exit_Program
    .ENDIF
    INVOKE CreateWindowEx,0,  ADDR CLASS_NAME,
      ADDR WINDOW_TEXT, WS_OVERLAPPEDWINDOW,
      CW_USEDEFAULT,CW_USEDEFAULT,CW_USEDEFAULT,
      CW_USEDEFAULT,NULL,NULL,MainWin.hInstance,NULL
    mov hMainwnd,   eax
    .IF hMainwnd == 0
        jmp Exit_Program
    .ENDIF
    INVOKE ShowWindow, hMainwnd, SW_SHOW
    INVOKE UpdateWindow, hMainwnd
Message_Loop:
    INVOKE GetMessage, ADDR msg, NULL, 0, 0
    .IF eax == 0
        jmp Exit_Program
    .ENDIF
    INVOKE TranslateMessage,    ADDR msg
    INVOKE DispatchMessage,     ADDR msg
    jmp Message_Loop
Exit_Program:
    INVOKE ExitProcess, 0
WinMain ENDP

END WinMain