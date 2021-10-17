; music_api.asm 

INCLUDE     custom.inc
INCLUDE     music_api.inc
INCLUDE     my_music.inc
INCLUDE     Winmm.inc
INCLUDELIB  Winmm.lib
INCLUDELIB  msvcrt.lib

malloc PROTO C: DWORD   ; 动态分配内存
free PROTO C: DWORD     ; 动态释放内存

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

; 字符串常量
eventDescript   BYTE        "PCM WRITE", 0  ; 消息描述

.code

; 格式说明
; WAVEFORMATEX {
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
    LOCAL   buffer[WAV_HEAD_SIZE]:  BYTE,                   ; 读取文件的Buffer
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
    rep     stosb
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

GetWavToBuffer PROC USES ecx edx edi,
            hFile:              HANDLE,         ; 文件句柄
            musicBufferSize:    PTR DWORD       ; 指向音乐缓冲区大小的指针
    LOCAL   musicSize:          DWORD,          ; 音乐文件大小
            musicBuffer:        PTR BYTE,       ; 指向音乐缓冲区的指针
            realRead:           DWORD           ; 实际读取的字节数
;   RETURN: PTR BYTE
    INVOKE  GetFileSize,
            hFile,
            NULL 
    cmp     eax, INVALID_FILE_SIZE
    je      wrong
    mov     musicSize, eax
    INVOKE  malloc, musicSize                   ; 动态申请内存
    cmp     eax, NULL
    je      wrong
    mov     musicBuffer, eax
    ; 内存清空
    mov     al, 0
    mov     edi, musicBuffer
    mov     ecx, musicSize
    cld
    rep     stosb
    ; 读取文件
    lea     edx, realRead
    sub     musicSize, WAV_HEAD_SIZE
    INVOKE  ReadFile,
            hFile,
            musicBuffer,
            musicSize,
            edx,
            NULL
    cmp     eax, 0
    je      freeMemory
    mov     eax, realRead
    cmp     eax, musicSize
    jb      freeMemory
    jmp     right
freeMemory:
    INVOKE  free, musicBuffer
wrong:
    mov     eax, NULL
    ret
right:
    mov     eax, realRead
    mov     edi, musicBufferSize
    mov     [edi], eax
    mov     eax, musicBuffer
    ret
GetWavToBuffer ENDP

GetMinBufferSize PROC USES ebx edx,
            format:     WAVEFORMATEX        ; 文件格式
;   RETURN: DWORD
    mov     eax, 64
    mul     format.nChannels
    mul     format.wBitsPerSample
    mul     format.nSamplesPerSec
    mov     edx, 0
    mov     ebx, 11025
    div     ebx
    ret
GetMinBufferSize ENDP

_PlayMusic PROC USES edx esi edi,
            filename:       PTR BYTE,           ; 文件名
            musicType:      DWORD               ; 音乐类型
    LOCAL   hFile:          HANDLE,             ; 文件句柄
            musicBuffer:    PTR BYTE,           ; 音乐缓冲区
            musicSize:      DWORD,              ; 音乐大小
            waveFormat:     WAVEFORMATEX,       ; 音乐格式
            hEvent:         HANDLE              ; 回调事件句柄
    LOCAL   buffer:         PTR BYTE,           ; 播放缓冲
            bufferSize:     DWORD,              ; 播放缓冲大小
            realRead:       DWORD,              ; 实际播放大小
            over:           DWORD,              ; 结束标志
            waveHdr:        WAVEHDR             ; 播放头
;   RETURN: BOOL

    ; 准备播放
    mov     Playing, FALSE

    ; 处理文件
    INVOKE  CreateFile,
            filename,               
            GENERIC_READ,           
            FILE_SHARE_READ,        
            NULL,                  
            OPEN_EXISTING,          
            FILE_ATTRIBUTE_NORMAL,  
            NULL                    
    cmp     eax, INVALID_HANDLE_VALUE
    je      wrong
    mov     hFile, eax

    ; 处理音频文件
    cmp     musicType, WAV
    je      wav
    cmp     musicType, MP3
    je      mp3
    jmp     closeFileHandle
wav:
    ; 获取音频你格式
    lea     edi, waveFormat
    INVOKE  GetWavFormat, hFile, edi
    cmp     eax, FALSE
    je      closeFileHandle
    ; 获取音频内容
    lea     edi, musicSize
    INVOKE  GetWavToBuffer, hFile, edi
    cmp     eax, NULL
    je      closeFileHandle
    mov     musicBuffer, eax
    jmp     next
mp3:
    ; 获取音频你格式
    lea     edi, waveFormat
    INVOKE  GetMp3Format, filename, edi
    cmp     eax, FALSE
    je      closeFileHandle
    ; 获取音频内容
    lea     edi, musicSize
    INVOKE  DecodeMp3ToBuffer, hFile, edi
    cmp     eax, NULL
    je      closeFileHandle
    mov     musicBuffer, eax     
next:
    mov     eax, musicSize
    mov     edx, 0
    div     waveFormat.nAvgBytesPerSec
    mov     totalTime, eax
    
    ; 创建回调事件
    INVOKE  CreateEvent,
            NULL,
            FALSE,
            FALSE,
            ADDR eventDescript
    cmp     eax, NULL
    je      freeMemory
    mov     hEvent, eax

    ; 打开音频
    lea     esi, waveFormat
    INVOKE  waveOutOpen,
            OFFSET hWaveOut,
            WAVE_MAPPER,
            esi,
            hEvent,
            NULL,
            CALLBACK_EVENT
    cmp     eax, MMSYSERR_NOERROR
    jne     closeEventHandle
    
    ; 设置音量
    INVOKE  waveOutSetVolume,
            hWaveOut,
            volume
    cmp     eax, MMSYSERR_NOERROR
    jne     closeEventHandle

    ; 计算缓存大小
    INVOKE  GetMinBufferSize, waveFormat
    mov     bufferSize, eax
    INVOKE  malloc, bufferSize
    cmp     eax, NULL
    je      closeEventHandle
    mov     buffer, eax

    ; 开始播放
    mov     Playing, TRUE

    ; 正在播放
    mov     isPlaying, TRUE

    mov     haveRead, 0
    ; 循环开始
L1:
    mov     eax, bufferSize
    mov     realRead, eax
    mov     over, FALSE
.if     isPlaying == TRUE
    mov     eax, realRead
    add     eax, haveRead
    cmp     eax, musicSize
    jb      L2
    mov     eax, musicSize
    sub     eax, haveRead
    dec     eax
    mov     realRead, eax
L2: 
    mov     esi, musicBuffer
    add     esi, haveRead
    mov     edi, buffer
    mov     ecx, realRead
    cld
    rep     movsb
    mov     eax, realRead
    add     haveRead, eax
    cmp     eax, bufferSize
    jae     L3
    mov     over, TRUE
L3:
.else
    mov     al, 0
    mov     edi, buffer
    mov     ecx, realRead
    cld
    rep     stosb
.endif
    ; 组装
    mov     eax, buffer
    mov     waveHdr.lpData, eax
    mov     eax, realRead
    mov     waveHdr.dwBufferLength, eax
    mov     waveHdr.dwBytesRecorded, 0
    mov     waveHdr.dwUser, NULL
    mov     waveHdr.dwFlags, 0
    mov     waveHdr.dwLoops, 1
    mov     waveHdr.lpNext, NULL
    mov     waveHdr.Reserved, NULL

    ; 送入音卡
    lea     esi, waveHdr
    INVOKE  waveOutPrepareHeader,
            hWaveOut,
            esi,
            SIZEOF WAVEHDR
    cmp     eax, MMSYSERR_NOERROR
    jne     L4
    INVOKE  waveOutWrite,
            hWaveOut,
            esi,
            SIZEOF WAVEHDR
    cmp     eax, MMSYSERR_NOERROR
    jne     L4
    INVOKE  WaitForSingleObject,
            hEvent,
            INFINITE
    mov     eax, haveRead
    mov     edx, 0
    mul     totalTime
    div     musicSize
    mov     playedTime, eax
    cmp     over, TRUE
    je      L4
    cmp     Playing, FALSE
    je      L4
    jmp     L1
L4:
    ; 循环结束
    mov     Playing, FALSE
    mov     playedTime, 0
    mov     totalTime, 0
    INVOKE  free, buffer    
    INVOKE  Sleep, 500
    INVOKE  waveOutClose,
            hWaveOut
    INVOKE  free, musicBuffer    
    INVOKE  CloseHandle, hEvent
    INVOKE  CloseHandle, hFile

; 正确
right:
    mov     eax, TRUE
    ret
; 错误
closeEventHandle:
    INVOKE  CloseHandle, hEvent
freeMemory:
    INVOKE  free, musicBuffer
closeFileHandle:
    INVOKE  CloseHandle, hFile
wrong:
    mov     eax, FALSE
    ret    
_PlayMusic ENDP

PlayMusic PROC USES ebx,
    filename: PTR BYTE
    INVOKE  _PlayMusic, filename, WAV
    ret
PlayMusic ENDP

END