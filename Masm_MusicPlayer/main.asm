; main.asm
INCLUDE     custom.inc
INCLUDE     music_api.inc
INCLUDE     my_music.inc
INCLUDE     comdlg32.inc


.data
CLASS_NAME      BYTE    "MUSICPLAYER", 0
WINDOW_TEXT     BYTE    "MusicPlayer", 0

MainWin WNDCLASSA <NULL,WindowProc,NULL,NULL,NULL,NULL,NULL, \
    COLOR_WINDOW,NULL,CLASS_NAME>
hInstance   HINSTANCE   ?
hMainwnd    DWORD    ?
buttonClass     BYTE      "Button", 0
trackBarClass   BYTE      "msctls_trackbar32", 0
scrollClass     BYTE      "msctls_progress32", 0
stopText        BYTE      "停止", 0
openText        BYTE      "打开文件", 0
backText        BYTE      "快退", 0
pauseText       BYTE      "暂停", 0
frontText       BYTE      "快进", 0
zeroText        BYTE      "静音", 0
volumeText      BYTE      "音量", 0
scrollText      BYTE      "滚动条", 0
ErrorTitle      BYTE      "ERROR", 0
ofn             OPENFILENAMEA   <>
strFileName     BYTE       255 dup(?), 0
TotalTime       DWORD      ?

fileFilter      BYTE      "音频(*.wav,*.mp3)",0, "*.wav;*.mp3", 0
ps PAINTSTRUCT <>
msg MSG <>
hdc HDC ?
wmID                WORD    ?
wmEvent             WORD    ?
m_button_stop       DWORD    ?
m_button_open       DWORD    ?
m_button_back       DWORD    ?
m_button_pause      DWORD    ?
m_button_front      DWORD    ?
m_button_zero       DWORD    ?
m_volume            DWORD    ?
m_scrollbar         DWORD    ?

.code

WinMain PROC
    INVOKE GetModuleHandle, NULL
    mov MainWin.hInstance, eax
    mov hInstance,    eax
    ;INVOKE LoadIcon, NULL, IDI_APPLICATION
    ;mov MainWin.hIcon, eax
    ;INVOKE LoadCursor, NULL, IDC_ARROW
    ;mov MainWin.hCursor, eax
    ;wcStyle     EQU         CS_HREDRAW  OR  CS_VREDRAW
    ;mov MainWin.style,           wcStyle
    INVOKE RegisterClass, ADDR MainWin
    .IF eax == 0
        call ErrorHandler
        jmp Exit_Program
    .ENDIF
    INVOKE CreateWindowEx,0,  ADDR CLASS_NAME,
      ADDR WINDOW_TEXT, WS_OVERLAPPEDWINDOW,
      CW_USEDEFAULT,CW_USEDEFAULT,CW_USEDEFAULT,
      CW_USEDEFAULT,NULL,NULL,MainWin.hInstance,NULL
    mov hMainwnd,   eax
    .IF hMainwnd == 0
        call ErrorHandler
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

;--------------------------------------------------------
;事件处理函数
;--------------------------------------------------------
WindowProc PROC,
    hwnd:       DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
    LOCAL wScrollNotify:    WORD
    LOCAL new_volume:       DWORD
    LOCAL PlayedTime:       DWORD
    mov eax,    uMsg
    .IF eax == WM_CREATE
        INVOKE CreateWindowExA, 0, ADDR buttonClass,ADDR stopText,
                WS_CHILD OR WS_VISIBLE OR WS_BORDER, 50, 350, 80, 30,
                hwnd, 2, MainWin.hInstance, NULL
        mov     m_button_stop,  eax

        INVOKE CreateWindowExA, 0,ADDR buttonClass,ADDR openText,
                WS_CHILD OR WS_VISIBLE OR WS_BORDER, 
                150, 350, 80, 30,
                hwnd, 3, MainWin.hInstance, NULL
        mov     m_button_open,  eax

        INVOKE CreateWindowExA, 0,ADDR buttonClass,ADDR backText,
                WS_CHILD OR WS_VISIBLE OR WS_BORDER, 
                350, 350, 80, 30,
                hwnd, 4, MainWin.hInstance, NULL
        mov     m_button_back,  eax

        INVOKE CreateWindowExA, 0,ADDR buttonClass,ADDR pauseText,
                WS_CHILD OR WS_VISIBLE OR WS_BORDER, 
                450, 350, 80, 30,
                hwnd, 5, MainWin.hInstance, NULL
        mov     m_button_pause,  eax

        INVOKE CreateWindowExA, 0,ADDR buttonClass,ADDR frontText,
                WS_CHILD OR WS_VISIBLE OR WS_BORDER, 
                550, 350, 80, 30,
                hwnd, 6, MainWin.hInstance, NULL
        mov     m_button_front,  eax


        INVOKE CreateWindowExA, 0,ADDR buttonClass,ADDR zeroText,
                WS_CHILD OR WS_VISIBLE OR WS_BORDER, 
                720, 360, 80, 30,
                hwnd, 8, MainWin.hInstance, NULL
        mov     m_button_zero,  eax

        INVOKE CreateWindowExA, 0,ADDR trackBarClass,ADDR volumeText,
                WS_CHILD OR WS_VISIBLE OR TBS_ENABLESELRANGE OR TBS_VERT OR TBS_RIGHT,
                750, 50, 30, 300,
                hwnd, 9, MainWin.hInstance, NULL
        mov     m_volume,  eax

        INVOKE SendMessageA, m_volume, TBM_SETRANGE, 1, 0F0000h
        INVOKE SendMessageA, m_volume, TBM_SETPOS, 1, 12

        INVOKE CreateWindowExA, 0,ADDR scrollClass,ADDR scrollText,
                WS_CHILD OR WS_VISIBLE,
                300, 300, 400, 10,
                hwnd, 10, MainWin.hInstance, NULL
        mov     m_scrollbar,  eax

        INVOKE SendMessageA, m_scrollbar, PBM_SETRANGE, 1, 27100000h
        INVOKE SendMessageA, m_scrollbar, PBM_SETPOS, 0, 1
        mov eax, 0
        jmp WinProc_Exit
     .ELSEIF eax == WM_TIMER
        INVOKE GetTotalTime
        mov TotalTime, eax
        INVOKE GetPlayedTime
        .IF eax >= TotalTime - 1
            INVOKE KillTimer, hwnd, 114
            INVOKE StopMusic
            jmp WinProc_Exit
        .ELSEIF TotalTime == 0
            INVOKE KillTimer, hwnd, 114
            INVOKE StopMusic
            jmp WinProc_Exit
        .ENDIF
        push edx
        push ebx
        mov ebx, 10000
        MUL ebx
        pop ebx
        pop edx
        DIV TotalTime
        INVOKE SendMessage, m_scrollbar, PBM_SETPOS, eax, 1
        mov eax, 0
        jmp WinProc_Exit
     .ELSEIF eax == WM_COMMAND
        mov     eax, wParam
        mov     wmID, ax
        shrd    eax, eax, 16
        mov     wmEvent, ax
        
        .IF wmID ==3
           push ecx
           push esi
           mov ecx, 256
           mov esi, OFFSET strFileName
           mov eax, 0
        mem_loop:
           mov [esi], al
           inc esi
           LOOPZ mem_loop
           pop esi
           pop ecx

           mov ofn.lStructSize, SIZEOF OPENFILENAMEA
           mov ofn.lpstrFilter, OFFSET fileFilter
           mov ofn.lpstrFile, OFFSET strFileName
           mov ofn.nMaxFile, 256
           mov ofn.Flags, OFN_FILEMUSTEXIST
           INVOKE GetOpenFileNameA, ADDR ofn
           .IF eax != 0
                INVOKE PlayMusic,ADDR strFileName
                .IF eax == 0
                    call ErrorHandler
                    jmp WinProc_Exit
                .ENDIF
                INVOKE GetTotalTime
                mov TotalTime, eax
                INVOKE SetTimer, hwnd, 114, 1000, NULL
            INVOKE SetFocus, hwnd 
            .ENDIF
        .ELSEIF wmID == 2
            INVOKE StopMusic
            INVOKE SendMessage, m_scrollbar, PBM_SETPOS, 0, 1
            INVOKE KillTimer, hwnd, 114
            INVOKE SetFocus, hwnd
        .ELSEIF wmID == 4
            INVOKE BackwardMusicTime
            INVOKE SetFocus, hwnd
        .ELSEIF wmID == 5
            INVOKE GetIsPlaying
            .IF eax == 1
                INVOKE PauseMusic
                INVOKE KillTimer, hwnd, 114
            .ELSE
                INVOKE ContinueMusic
                INVOKE SetTimer, hwnd, 114, 1000, 0
            .ENDIF
            INVOKE SetFocus, hwnd
        .ELSEIF wmID == 6
            INVOKE ForwardMusicTime
            INVOKE SetFocus, hwnd
        .ELSEIF wmID == 8
            INVOKE GetMuted
            .IF eax == 0
                INVOKE Mute
            .ELSE
                INVOKE unMute
            .ENDIF
        .ENDIF
        mov     eax, 0
        jmp WinProc_Exit
     .ELSEIF eax == WM_KEYDOWN
        mov wScrollNotify,  0FFFFh
        .IF wParam == VK_UP
            mov wScrollNotify,  TB_LINEUP
            INVOKE  IncreaseVolume
        .ELSEIF wParam == VK_DOWN
            mov wScrollNotify,  TB_LINEDOWN
            INVOKE  DecreaseVolume
        .ENDIF
        .IF wScrollNotify != 0FFFFh
            INVOKE  SetFocus,    m_volume
            INVOKE  SendMessage, m_volume,  WM_VSCROLL, wScrollNotify, 0
            INVOKE  UpdateWindow,   m_volume
        .ENDIF
        mov     eax, 0
        jmp WinProc_Exit
     .ELSEIF    eax == WM_VSCROLL
        mov eax, wParam
        mov wmEvent, ax
        .IF wmEvent == TB_LINEUP
            INVOKE IncreaseVolume
        .ELSEIF wmEvent == TB_LINEDOWN
            INVOKE  DecreaseVolume
        .ELSEIF wmEvent == TB_THUMBTRACK
            shrd eax, eax, 16
            mov wmID, ax ;当前音量条位置
            mov eax,  0
            mov ax,   wmID
            neg eax
            add eax,  0Fh
            shld eax, eax, 12  
            push edx
            mov edx, eax
            shld edx, edx, 16
            add eax, edx
            pop edx
            INVOKE SetVolume,  eax
        .ENDIF
        
        mov     eax, 0
        jmp WinProc_Exit


     .ELSEIF eax == WM_PAINT
        INVOKE BeginPaint, hwnd, ADDR ps
        mov hdc,    eax
        INVOKE  FillRect, hdc, ADDR ps.rcPaint, 6
        INVOKE  EndPaint, hwnd, ADDR ps
        mov eax, 0
        jmp WinProc_Exit
    .ELSEIF eax == WM_DESTROY
        INVOKE StopMusic
        INVOKE PostQuitMessage, 0
        mov eax, 0
        jmp WinProc_Exit
    .ELSE
        INVOKE DefWindowProcA, hwnd, uMsg, wParam, lParam
        jmp WinProc_Exit
    .ENDIF
WinProc_Exit:
    ret
WindowProc ENDP

;------------------------------------
;错误处理函数
;------------------------------------
ErrorHandler PROC
.data
pErrorMsg  DWORD ?         ; 错误消息指针
messageID  DWORD ?
.code
    INVOKE GetLastError    ; 用EAX返回消息ID
    mov messageID,eax

    ; 获取相应的消息字符串
    INVOKE FormatMessage, FORMAT_MESSAGE_ALLOCATE_BUFFER + \
      FORMAT_MESSAGE_FROM_SYSTEM,NULL,messageID,NULL,
      ADDR pErrorMsg,NULL,NULL

    ; 显示错误消息
    INVOKE MessageBox,NULL, pErrorMsg, ADDR ErrorTitle,
      MB_ICONERROR+MB_OK

    ; 释放错误消息字符串
    INVOKE LocalFree, pErrorMsg
    ret
ErrorHandler ENDP

END WinMain