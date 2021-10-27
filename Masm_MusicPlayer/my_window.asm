;my_window.asm

INCLUDE     custom.inc
INCLUDE     music_api.inc
INCLUDE     my_music.inc
INCLUDE     my_window.inc
INCLUDE     comdlg32.inc
PUBLIC CLASS_NAME 
PUBLIC WINDOW_TEXT
PUBLIC MainWin
.data
CLASS_NAME      BYTE    "MUSICPLAYER", 0
WINDOW_TEXT     BYTE    "MusicPlayer", 0
ErrorTitle      BYTE      "ERROR", 0
MainWin WNDCLASSA <NULL,WindowProc,NULL,NULL,NULL,NULL,NULL, \
    COLOR_WINDOW,NULL,CLASS_NAME>
buttonClass     BYTE      "Button", 0
editClass       BYTE      "EDIT", 0
trackBarClass   BYTE      "msctls_trackbar32", 0
scrollClass     BYTE      "msctls_progress32", 0
stopText        BYTE      "停止", 0
openText        BYTE      "打开文件", 0
playText        BYTE      "播放", 0
backText        BYTE      "快退", 0
pauseText       BYTE      "暂停", 0
continueText    BYTE      "继续", 0
frontText       BYTE      "快进", 0
zeroText        BYTE      "静音", 0
nonezeroText    BYTE      "取消静音",0
volumeText      BYTE      "音量", 0
scrollText      BYTE      "滚动条", 0
hasPlayed       DWORD      0
ofn             OPENFILENAMEA   <>
strFileName     BYTE       255 dup(?), 0
PerFileName     BYTE       255 dup(?), 0
TotalTime       DWORD      ?
HDefaultTimeStr BYTE       "00:00/00:00",0
HTimeStr        BYTE       20 dup(?), 0
HTotalTimeStr   BYTE       10  dup(?), 0
imagePath       BYTE       "back.bmp",0
fileFilter      BYTE      "音频(*.wav,*.mp3,*.flac)",0, "*.wav;*.mp3;*.flac", 0
ps PAINTSTRUCT <>
hdc HDC ?
wmID                WORD    ?
wmEvent             WORD    ?
m_button_stop       DWORD   ?
m_button_open       DWORD   ?
m_button_back       DWORD   ?
m_button_pause      DWORD   ?
m_button_front      DWORD   ?
m_button_zero       DWORD   ?
m_volume            DWORD   ?
m_scrollbar         DWORD   ?
m_time_edit         DWORD   ?
hFont               DWORD   ?
hBrush              DWORD   ?
hBitmap             DWORD   ?
hh                  DWORD   ?
rect                DWORD   ?
.code
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
        
        INVOKE GetStockObject, 17
        mov hFont, eax
        
        INVOKE  CreateCompatibleDC, NULL
        mov hh, eax

        INVOKE CreateWindowExA, 0, ADDR buttonClass,ADDR stopText,
                WS_CHILD OR WS_VISIBLE OR WS_BORDER, 100, 380, 80, 30,
                hwnd, 2, MainWin.hInstance, NULL
        mov     m_button_stop,  eax

        INVOKE SendMessage, m_button_stop, WM_SETFONT, hFont, 1

        INVOKE CreateWindowExA, 0,ADDR buttonClass,ADDR openText,
                WS_CHILD OR WS_VISIBLE OR WS_BORDER, 
                200, 380, 80, 30,
                hwnd, 3, MainWin.hInstance, NULL
        mov     m_button_open,  eax

        INVOKE SendMessage, m_button_open, WM_SETFONT, hFont, 1

        INVOKE CreateWindowExA, 0,ADDR buttonClass,ADDR backText,
                WS_CHILD OR WS_VISIBLE OR WS_BORDER, 
                350, 380, 80, 30,
                hwnd, 4, MainWin.hInstance, NULL
        mov     m_button_back,  eax

        INVOKE SendMessage, m_button_back, WM_SETFONT, hFont, 1

        INVOKE CreateWindowExA, 0,ADDR buttonClass,ADDR pauseText,
                WS_CHILD OR WS_VISIBLE OR WS_BORDER, 
                450, 380, 80, 30,
                hwnd, 5, MainWin.hInstance, NULL
        mov     m_button_pause,  eax

        INVOKE SendMessage, m_button_pause, WM_SETFONT, hFont, 1

        INVOKE CreateWindowExA, 0,ADDR buttonClass,ADDR frontText,
                WS_CHILD OR WS_VISIBLE OR WS_BORDER, 
                550, 380, 80, 30,
                hwnd, 6, MainWin.hInstance, NULL
        mov     m_button_front,  eax

        INVOKE SendMessage, m_button_front, WM_SETFONT, hFont, 1

        INVOKE CreateWindowExA, 0,ADDR buttonClass,ADDR zeroText,
                WS_CHILD OR WS_VISIBLE OR WS_BORDER, 
                720, 380, 80, 30,
                hwnd, 8, MainWin.hInstance, NULL
        mov     m_button_zero,  eax

        INVOKE SendMessage, m_button_zero, WM_SETFONT, hFont, 1

        INVOKE CreateWindowExA, 0,ADDR trackBarClass,ADDR volumeText,
                WS_CHILD OR WS_VISIBLE OR TBS_ENABLESELRANGE OR TBS_VERT OR TBS_RIGHT,
                750, 30, 30, 340,
                hwnd, 9, MainWin.hInstance, NULL
        mov     m_volume,  eax

        INVOKE SendMessageA, m_volume, TBM_SETRANGE, 1, 0F0000h
        INVOKE SendMessageA, m_volume, TBM_SETPOS, 1, 12

        INVOKE CreateWindowExA, 0,ADDR scrollClass,ADDR scrollText,
                WS_CHILD OR WS_VISIBLE,
                100, 330, 600, 10,
                hwnd, 10, MainWin.hInstance, NULL
        mov     m_scrollbar,  eax

        INVOKE CreateWindowExA, 0,ADDR editClass,ADDR scrollText,
                WS_CHILD OR WS_VISIBLE OR ES_READONLY OR ES_CENTER,
                500, 340, 180, 30,
                hwnd, 11, MainWin.hInstance, NULL
        mov     m_time_edit,  eax

        INVOKE SetWindowText, m_time_edit, ADDR HDefaultTimeStr


        INVOKE SendMessageA, m_scrollbar, PBM_SETRANGE, 1, 27100000h
        INVOKE SendMessageA, m_scrollbar, PBM_SETPOS, 0, 1
        mov eax, 0
        jmp WinProc_Exit
     
     .ELSEIF eax == WM_CTLCOLORSTATIC
        INVOKE GetStockObject, 0
        jmp WinProc_Exit
     .ELSEIF eax == WM_TIMER
        INVOKE GetPlaying
        .IF eax == 0
            INVOKE SetWindowTextA, m_button_stop, ADDR playText
            jmp WinProc_Exit
        .ELSE
            INVOKE SetWindowTextA, m_button_stop, ADDR stopText
        .ENDIF
        INVOKE GetTotalTime
        mov TotalTime, eax
        INVOKE GetPlayedTime
        mov PlayedTime, eax
        .IF TotalTime == 0
            INVOKE KillTimer, hwnd, 114
            INVOKE StopMusic
            INVOKE SetWindowTextA, m_button_stop, ADDR playText
            jmp WinProc_Exit
        .ENDIF
        push edx
        push ebx
        mov ebx, 10000
        MUL ebx
        pop ebx
        DIV TotalTime
        pop edx
        INVOKE SendMessage, m_scrollbar, PBM_SETPOS, eax, 1

        INVOKE TimeToString, PlayedTime, ADDR HTimeStr
        ;push esi
        mov esi, OFFSET HTimeStr
        add esi, 5
        mov ebx, 2Fh
        mov [esi], ebx
        inc esi
        mov ebx, 0
        mov [esi], ebx
        ;pop esi
        INVOKE TimeToString, TotalTime, ADDR HTotalTimeStr
        INVOKE Str_concat, ADDR HTimeStr, ADDR HTotalTimeStr
        INVOKE SetWindowText, m_time_edit, ADDR HTimeStr
        mov eax, 0
        jmp WinProc_Exit
     .ELSEIF eax == WM_COMMAND
        mov     eax, wParam
        mov     wmID, ax
        shrd    eax, eax, 16
        mov     wmEvent, ax
        
        .IF wmID ==3    ;打开文件
           push ecx
           push esi
           push edi
           mov ecx, 256
           mov esi, OFFSET strFileName
           mov eax, 0
        mem_loop:
           mov [esi], al
           inc esi
           LOOPNZ mem_loop
           mov ofn.lStructSize, SIZEOF OPENFILENAMEA
           mov ofn.lpstrFilter, OFFSET fileFilter
           mov ofn.lpstrFile, OFFSET strFileName
           mov ofn.nMaxFile, 256
           mov ofn.Flags, OFN_FILEMUSTEXIST
           INVOKE GetOpenFileNameA, ADDR ofn
           .IF eax != 0
                mov eax,    0
                mov esi,    OFFSET strFileName
                mov edi,    OFFSET PerFileName
                mov ecx,    256
                mem_cpy:
                    mov al,     [esi]
                    mov [edi],  al
                    inc esi
                    inc edi
                    LOOPNZ   mem_cpy
                pop edi
                pop esi
                pop ecx
                INVOKE PlayMusic,ADDR strFileName
                .IF eax == 0
                    call ErrorHandler
                    jmp WinProc_Exit
                .ENDIF
                mov hasPlayed, 1
                INVOKE SetTimer, hwnd, 114, 500, NULL
                INVOKE SetWindowTextA, m_button_stop, ADDR stopText
            INVOKE SetFocus, hwnd 
            .ENDIF
        .ELSEIF wmID == 2           ;停止/播放
            .IF hasPlayed == 1
                INVOKE  GetPlaying
                .IF    eax == 1
                    INVOKE StopMusic
                    INVOKE SendMessage, m_scrollbar, PBM_SETPOS, 0, 1
                    INVOKE KillTimer, hwnd, 114
                    INVOKE SetFocus, hwnd
                    INVOKE SetWindowTextA, m_button_pause, ADDR pauseText
                    INVOKE SetWindowTextA, m_button_stop, ADDR playText
                .ELSE
                    INVOKE PlayMusic,ADDR PerFileName
                    .IF eax == 0
                        call ErrorHandler
                        jmp WinProc_Exit
                    .ENDIF
                    INVOKE SetTimer, hwnd, 114, 500, NULL
                    INVOKE SetWindowTextA, m_button_stop, ADDR stopText
                .ENDIF
            .ELSE
                jmp WinProc_Exit
            .ENDIF
            INVOKE SetFocus, hwnd
        .ELSEIF wmID == 4
            INVOKE BackwardMusicTime
            INVOKE SetFocus, hwnd
        .ELSEIF wmID == 5
            INVOKE GetPlaying
            .IF eax == 1            ;不处于播放状态时，不做任何响应
            INVOKE GetIsPlaying
            .IF eax == 1
                INVOKE PauseMusic
                ;INVOKE KillTimer, hwnd, 114
                INVOKE SetWindowText, m_button_pause, ADDR continueText
            .ELSE
                INVOKE ContinueMusic
                ;INVOKE SetTimer, hwnd, 114, 500, 0
                INVOKE SetWindowText, m_button_pause, ADDR pauseText
            .ENDIF
            .ENDIF
            INVOKE SetFocus, hwnd
        .ELSEIF wmID == 6
            INVOKE ForwardMusicTime
            INVOKE SetFocus, hwnd
        .ELSEIF wmID == 8
            INVOKE GetMuted
            .IF eax == 0
                INVOKE Mute
                INVOKE SetWindowText, m_button_zero, ADDR nonezeroText
            .ELSE
                INVOKE unMute
                INVOKE SetWindowText, m_button_zero, ADDR zeroText
            .ENDIF
            INVOKE SetFocus, hwnd
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
        .ELSEIF wmEvent == TB_THUMBPOSITION
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
        mov hdc, eax
        INVOKE  FillRect, hdc, ADDR ps.rcPaint, 6
        INVOKE  GetClientRect, hwnd, ADDR rect
        INVOKE  LoadImage, NULL, ADDR imagePath,
                               IMAGE_BITMAP, 800, 598, 
                               LR_LOADFROMFILE
        mov  hBitmap, eax
        INVOKE  CreateCompatibleBitmap, hdc, 800, 598
        ;INVOKE  CreateCompatibleDC, NULL
        ;mov hh, eax
        INVOKE  SelectObject, hh, hBitmap
        INVOKE  BitBlt, hdc, 100, 40, 600, 280, hh, 0, 0, SRCCOPY
        ;INVOKE  FillRect, hdc, ADDR ps.rcPaint, 6
        INVOKE  EndPaint, hwnd, ADDR ps
        ;INVOKE  ReleaseDC, hwnd, hh
        mov eax, 0
        jmp WinProc_Exit
    .ELSEIF eax == WM_DESTROY
        INVOKE StopMusic
        INVOKE  ReleaseDC, hwnd, hh
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
;将秒数转化成易读的字符串
;------------------------------------

TimeToString PROC USES esi edx ebx,
    time: DWORD, pstr: PTR BYTE 
    LOCAL minutes:  DWORD
    LOCAL seconds:  DWORD
    mov esi, pstr
    mov edx, 0
    mov eax, time
    mov ebx, 60
    div ebx
    mov minutes,    eax
    mov seconds,    edx
    mov edx, 0
    mov ebx, 10
    div ebx
    or  eax, 30h
    or  edx, 30h
    mov [esi], eax
    add esi, 1
    mov [esi], edx
    add esi, 1
    mov ebx, 3Ah
    mov [esi], ebx
    add esi, 1
    mov edx, 0
    mov eax, seconds
    mov ebx, 10
    div ebx
    or eax, 30h
    or edx, 30h
    mov [esi], eax
    add esi, 1
    mov [esi], edx
    mov eax, 0
    ret
TimeToString ENDP

;------------------------------------
;字符串拼接函数，用于时间的正确显示
;------------------------------------
Str_concat  PROC    target: PTR  BYTE,   source:  PTR BYTE
    mov esi,    target
    mov edi,    source
    dec esi
    end_loop:
        inc esi
        mov eax,  [esi]
        cmp eax,  0
        jnz end_loop
    mov ecx,    SIZEOF  source
    cpy_loop:
        mov eax,    [edi]
        mov [esi],  eax
        inc esi
        inc edi
        LOOPNE cpy_loop
ret
Str_concat  ENDP

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

END 