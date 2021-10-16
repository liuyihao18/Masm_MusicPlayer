; music_api.asm 

INCLUDE custom.inc
INCLUDE music_api.inc
INCLUDE util.inc

.data
; 状态量
Playing         BOOL        FALSE           ; 允许播放状态
isPlaying       BOOL        FALSE           ; 正在播放状态
hWaveOut        HANDLE      0               ; 音频输出设备句柄
volume          DWORD       30003000h       ; 音量大小
muted           BOOL        FALSE           ; 静音状态
totalTime       DWORD       0               ; 音乐总时长
playedTime      DWORD       0               ; 已经播放的时长
haveRead        DWORD       0               ; 已经读取的（数组）长度

; 信号量
mutexPlaying    HANDLE      0               ; 允许播放状态互斥量
mutexIsPlaying  HANDLE      0               ; 正在播放状态互斥量
canPlaying      HANDLE      0               ; 播放权

.code

_PlayMusic PROC USES ebx,
    filename: PTR BYTE,             ; 文件名
    musicType: DWORD                ; 音乐类型
    LOCAL hFile: HANDLE,            ; 文件句柄
        waveFormat: WAVEFORMATEX    ; 音乐格式
    INVOKE  CreateFile,
        ADDR filename,          ; LSCPTR: 指向文件名的指针
        GENERIC_READ,           ; DWORD: 访问模式
        FILE_SHARE_READ,        ; DWORD: 共享模式
        NULL,                   ; LPSECURITY_ATTRIBUTES: 指向安全属性的指针
        OPEN_EXISTING,          ; DWORD: 创建方式
        FILE_ATTRIBUTE_NORMAL,  ; DWORD: 文件属性
        NULL                    ; HANDLE: 用于复制文件句柄
    cmp     eax, INVALID_HANDLE_VALUE
    je      quit
    mov     hFile, eax
    INVOKE  GetMp3Format,
        ADDR filename, 
        ADDR waveFormat
    cmp     eax, FALSE
    je      quit
    mov     ebx, eax

quit:
    ret    
_PlayMusic ENDP

END