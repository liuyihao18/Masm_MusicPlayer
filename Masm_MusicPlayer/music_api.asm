; music_api.asm 

INCLUDE custom.inc
INCLUDE music_api.inc
INCLUDE util.inc

.data
; 参数
WAV_HEAD_SIZE = 44

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

; 格式说明
; WAVEFORMATEX{
;     WORD  wFormatTag,  // 波形-音频格式类型：PCM
;     WORD  nChannels,  // 声道数
;     DWORD nSamplesPerSec,  // 采样频率
;     DWORD nAvgBytesPerSec,  // 平均数据传输速率 = 采样频率 * 块对齐
;     WORD  nBlockAlign,  // 块对齐 = 声道数 * 位数 / 8
;     WORD  wBitsPerSample,  // 位数
;     WORD  cbSize,  // 额外格式信息，PCM格式忽略即可
; };
GetWavFormat PROC USES ecx edx esi edi,
            hFile:                  HANDLE,                 ; 文件句柄
            format:                 PTR WAVEFORMATEX        ; 指向结构体的指针
    LOCAL   buffer[WAV_HEAD_SIZE]:  BYTE                    ; 读取文件的Buffer
            realRead:               DWORD                   ; 实际读取的字节数
;   RETURN: BOOL 
    lea     esi, buffer
    lea     edx, realRead
    INVOKE  ReadFile,
            hFile,
            esi,                                            ; 缓冲区地址
            WAV_HEAD_SIZE,
            edx,
            NULL
    cmp     eax, 0
    je      wrong
    mov     eax, realRead
    cmp     eax, WAV_HEAD_SIZE
    jb      wrong
    ; 结构体清空
    mov     al, 0
    mov     edi, format
    mov     ecx, SIZEOF WAVEFORMATEX
    cld
    rep     stob
    ; 结构体填充
    add     esi, 20
    mov     edi, format
    mov     ecx, 16
    cld
    rep     movsb
    jmp     right
wrong:
    mov     eax, FALSE
    ret
right:
    mov     eax, TRUE
    ret
GetWavFormat ENDP

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