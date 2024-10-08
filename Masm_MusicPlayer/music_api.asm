; music_api.asm 

INCLUDE     custom.inc
INCLUDE     music_api.inc
INCLUDE     my_music.inc
INCLUDE     Winmm.inc
INCLUDELIB  Winmm.lib

.data
; 参数
WAV_HEAD_SIZE = 44

; 音乐文件记录
MusicFile STRUCT
    filename    DWORD       ?                   ; 指向文件名的指针
    musicType   DWORD       ?                   ; 音乐类型
MusicFile ENDS
aMusicFile      MusicFile   <>

; 状态量
Playing         BOOL        FALSE               ; 允许播放状态
isPlaying       BOOL        FALSE               ; 正在播放状态
hWaveOut        HANDLE      0                   ; 音频输出设备句柄
volume          DWORD       30003000h           ; 音量大小0~F，高四位为右声道，低四位为左声道
muted           BOOL        FALSE               ; 静音状态
totalTime       DWORD       0                   ; 音乐总时长
playedTime      DWORD       0                   ; 已经播放的时长
totalRead       DWORD       0                   ; 音乐（数组）长度
haveRead        DWORD       0                   ; 已经读取的（数组）长度

; 信号量
mutexPlaying    HANDLE      0                   ; 允许播放状态互斥量
mutexIsPlaying  HANDLE      0                   ; 正在播放状态互斥量
canPlaying      HANDLE      0                   ; 播放权
mutexRead       HANDLE      0                   ; 播放进度互斥量

; 字符串常量
wavExtension    BYTE        ".wav", 0           ; wav文件扩展名
mp3Extension    BYTE        ".mp3", 0           ; mp3文件扩展名
flacExtension   BYTE        ".flac", 0          ; flac文件扩展名
tempFilename    BYTE        "__temp__.wav", 0   ; 临时文件名
eventDescript   BYTE        "PCM WRITE", 0      ; 消息描述
s1Descript      BYTE        "mutexPlaying", 0   ; 信号量1
s2Descript      BYTE        "mutexIsPlaying", 0 ; 信号量2
s3Descript      BYTE        "CanPlaying", 0     ; 信号量3
s4Descript      BYTE        "mutexRead", 0      ; 信号量4

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
GetWavFormat PROC PRIVATE USES ecx edx esi edi,
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
right:
    mov     eax, TRUE
    ret
wrong:
    mov     eax, FALSE
    ret
GetWavFormat ENDP

GetWavToBuffer PROC PRIVATE USES ecx edx edi,
            hFile:              HANDLE,         ; 文件句柄
            musicBufferSize:    PTR DWORD       ; 指向音乐缓冲区大小的指针
    LOCAL   heapHandle:         HANDLE,         ; 堆句柄
            musicSize:          DWORD,          ; 音乐文件大小
            musicBuffer:        PTR BYTE,       ; 指向音乐缓冲区的指针
            realRead:           DWORD           ; 实际读取的字节数
;   RETURN: PTR BYTE
    INVOKE  GetFileSize,
            hFile,
            NULL 
    cmp     eax, INVALID_FILE_SIZE
    je      wrong
    mov     musicSize, eax
    INVOKE  GetProcessHeap
    cmp     eax, NULL
    je      wrong
    mov     heapHandle, eax
    INVOKE  HeapAlloc, heapHandle, HEAP_ZERO_MEMORY, musicSize
    cmp     eax, NULL
    je      wrong
    mov     musicBuffer, eax
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
right:
    mov     eax, realRead
    mov     edi, musicBufferSize
    mov     [edi], eax
    mov     eax, musicBuffer
    ret
freeMemory:
    INVOKE  HeapFree, heapHandle, 0, musicBuffer
wrong:
    mov     eax, NULL
    ret
GetWavToBuffer ENDP

GetMinBufferSize PROC PRIVATE USES ebx edx,
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

_PlayMusic PROC PRIVATE USES edx esi edi
     LOCAL  filename:       PTR BYTE,           ; 文件名            
            musicType:      DWORD,              ; 音乐类型
            hFile:          HANDLE,             ; 文件句柄
            musicBuffer:    PTR BYTE,           ; 音乐缓冲区
            musicSize:      DWORD,              ; 音乐大小
            waveFormat:     WAVEFORMATEX,       ; 音乐格式
            hEvent:         HANDLE              ; 回调事件句柄
    LOCAL   heapHandle:     HANDLE,             ; 堆句柄
            buffer:         PTR BYTE,           ; 播放缓冲
            bufferSize:     DWORD,              ; 播放缓冲大小
            realRead:       DWORD,              ; 实际播放大小
            over:           DWORD,              ; 结束标志
            waveHdr:        WAVEHDR             ; 播放头
;   RETURN: BOOL
    
    ; 准备播放
    INVOKE  WaitForSingleObject,
            canPlaying,
            INFINITE

    mov     eax, aMusicFile.filename
    mov     filename, eax
    mov     eax, aMusicFile.musicType
    mov     musicType, eax

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
    je      release
    mov     hFile, eax

    ; 处理音频文件
    cmp     musicType, WAV
    je      wav
    cmp     musicType, MP3
    je      mp3
    cmp     musicType, FLAC
    je      flac
    jmp     closeFileHandle

mp3:
    ; 获取音频格式
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
    jmp     next
flac:
    ; 解码
    INVOKE  CloseHandle, hFile
    INVOKE  DecodeFlacToWav, filename, ADDR tempFilename
    cmp     eax, FALSE
    je      release
    ; 打开临时文件
    INVOKE  CreateFile,
            ADDR tempFilename,               
            GENERIC_READ,           
            FILE_SHARE_READ,        
            NULL,                  
            OPEN_EXISTING,          
            FILE_ATTRIBUTE_NORMAL,  
            NULL                    
    cmp     eax, INVALID_HANDLE_VALUE
    je      release
    mov     hFile, eax
    ; 以下过程共用
wav:
    ; 获取音频格式
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
next:
    mov     eax, musicSize
    mov     edx, 0
    cmp     waveFormat.nAvgBytesPerSec, 0
    je      freeMemory
    div     waveFormat.nAvgBytesPerSec
    mov     totalTime, eax
    mov     eax, musicSize
    mov     totalRead, eax
    
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
            ADDR hWaveOut,
            WAVE_MAPPER,
            esi,
            hEvent,
            NULL,
            CALLBACK_EVENT
    cmp     eax, MMSYSERR_NOERROR
    jne     closeEventHandle
    
    ; 设置音量
    cmp     muted, TRUE
    je      mute
    INVOKE  waveOutSetVolume,
            hWaveOut,
            volume
    cmp     eax, MMSYSERR_NOERROR
    jne     closeEventHandle
    jmp     L0
mute:
    INVOKE  waveOutSetVolume,
            hWaveOut,
            0
    cmp     eax, MMSYSERR_NOERROR
    jne     closeEventHandle
    
L0:
    ; 计算缓存大小
    INVOKE  GetMinBufferSize, waveFormat
    mov     bufferSize, eax
    INVOKE  GetProcessHeap
    cmp     eax, NULL
    je      closeEventHandle
    mov     heapHandle, eax
    INVOKE  HeapAlloc, heapHandle, HEAP_ZERO_MEMORY, bufferSize
    cmp     eax, NULL
    je      closeEventHandle
    mov     buffer, eax

    ; 开始播放
    INVOKE  WaitForSingleObject,
            mutexPlaying,
            INFINITE
    mov     Playing, TRUE
    INVOKE  ReleaseSemaphore,
            mutexPlaying,
            1,
            NULL

    ; 正在播放
    INVOKE  WaitForSingleObject,
            mutexIsPlaying,
            INFINITE
    mov     isPlaying, TRUE
    INVOKE  ReleaseSemaphore,
            mutexIsPlaying,
            1,
            NULL
    
    INVOKE  WaitForSingleObject,
            mutexRead,
            INFINITE
    mov     haveRead, 0
    INVOKE  ReleaseSemaphore,
            mutexRead,
            1,
            NULL
    ; 循环开始
L1:
    mov     eax, bufferSize
    mov     realRead, eax
    ; 帧对齐
    mov     eax, haveRead
    mov     edx, 0
    div     bufferSize
    mul     bufferSize
    push    eax
    INVOKE  WaitForSingleObject,
            mutexRead,
            INFINITE
    pop     eax
    mov     haveRead, eax
    INVOKE  ReleaseSemaphore,
            mutexRead,
            1,
            NULL
    mov     over, FALSE
    ; 根据是否暂停填充不同数据
    cmp     isPlaying, TRUE
    jne     L4
    ; 不暂停
    mov     eax, realRead
    add     eax, haveRead
    ; 判断是否到缓冲区末尾
    cmp     eax, musicSize
    jb      L2
    ; 到了
    mov     eax, musicSize
    sub     eax, haveRead
    dec     eax
    mov     realRead, eax
L2: ; 没到
    mov     esi, musicBuffer
    add     esi, haveRead
    mov     edi, buffer
    mov     ecx, realRead
    cld
    rep     movsb
    ; 更新参数
    mov     eax, realRead
    push    eax
    INVOKE  WaitForSingleObject,
            mutexRead,
            INFINITE
    pop     eax
    add     haveRead, eax
    push    eax
    INVOKE  ReleaseSemaphore,
            mutexRead,
            1,
            NULL
    pop     eax
    ; 判断是否结束
    cmp     eax, bufferSize
    jae     L3
    mov     over, TRUE
L3:
    jmp     L5
L4:
    ; 若暂停
    mov     al, 0
    mov     edi, buffer
    mov     ecx, realRead
    cld
    rep     stosb
L5:
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
    jne     L6
    INVOKE  waveOutWrite,
            hWaveOut,
            esi,
            SIZEOF WAVEHDR
    cmp     eax, MMSYSERR_NOERROR
    jne     L6
    INVOKE  WaitForSingleObject,
            hEvent,
            INFINITE
    
    ; 更新参数
    mov     eax, haveRead
    inc     eax
    mov     edx, 0
    mul     totalTime
    div     musicSize
    mov     playedTime, eax
    cmp     Playing, FALSE
    je      L6
    cmp     over, TRUE
    je      L6
    jmp     L1
L6:
    ; 循环结束
    INVOKE  WaitForSingleObject,
            mutexIsPlaying,
            INFINITE
    mov     isPlaying, FALSE
    INVOKE  ReleaseSemaphore,
            mutexIsPlaying,
            1,
            NULL

    INVOKE  WaitForSingleObject,
            mutexPlaying,
            INFINITE
    mov     Playing, FALSE
    INVOKE  ReleaseSemaphore,
            mutexPlaying,
            1,
            NULL

    ; mov     playedTime, 0
    ; mov     totalTime, 0

    INVOKE  WaitForSingleObject,
            mutexRead,
            INFINITE
    mov     haveRead, 0
    INVOKE  ReleaseSemaphore,
            mutexRead,
            1,
            NULL

    mov     totalRead, 0
    INVOKE  HeapFree, heapHandle, 0, buffer
    INVOKE  Sleep, 500
    INVOKE  waveOutClose,
            hWaveOut
    cmp     musicType, WAV
    je      L7
    cmp     musicType, FLAC
    je      L7
    cmp     musicType, MP3
    je      L8
    jmp     L9
L7:
    INVOKE  HeapFree, heapHandle, 0, musicBuffer
    jmp     L9
L8:
    INVOKE  DeleteMp3Buffer, musicBuffer
L9:
    INVOKE  CloseHandle, hEvent
    INVOKE  CloseHandle, hFile
    INVOKE  DeleteFile, ADDR tempFilename

; 正确
right:
    INVOKE  ReleaseSemaphore, 
            canPlaying, 
            1, 
            NULL
    mov     eax, TRUE
    ret
; 错误
closeEventHandle:
    INVOKE  CloseHandle, hEvent
freeMemory:
    cmp     musicType, MP3
    je      freeMp3Memory
    INVOKE  GetProcessHeap
    INVOKE  HeapFree, eax, 0, musicBuffer
    jmp     closeFileHandle
freeMp3Memory:
    INVOKE  DeleteMp3Buffer, musicBuffer
closeFileHandle:
    INVOKE  CloseHandle, hFile
    INVOKE  DeleteFile, ADDR tempFilename
release:
    INVOKE  ReleaseSemaphore, 
            canPlaying, 
            1, 
            NULL
wrong:
    mov     eax, FALSE
    ret    
_PlayMusic ENDP

PlayMusic PROC USES esi,
            filename:   PTR BYTE    ; 文件名
    LOCAL   filenameLength: DWORD   ; 文件名长度
;   RETURN: BOOL
    ; 初始创建信号量
    cmp     mutexPlaying, 0
    jne     L1
    INVOKE  CreateSemaphore,
            NULL,
            1,
            1,
            ADDR s1Descript
    cmp     eax, 0
    je      wrong
    mov     mutexPlaying, eax
L1:
    cmp     mutexIsPlaying, 0
    jne     L2
    INVOKE  CreateSemaphore,
            NULL,
            1,
            1,
            ADDR s2Descript
    cmp     eax, 0
    je      wrong
    mov     mutexIsPlaying, eax
L2:
    cmp     canPlaying, 0
    jne     L3
    INVOKE  CreateSemaphore,
            NULL,
            1,
            1,
            ADDR s3Descript
    cmp     eax, 0
    je      wrong
    mov     canPlaying, eax
L3:
    cmp     mutexRead, 0
    jne     L4
    INVOKE  CreateSemaphore,
            NULL,
            1,
            1,
            ADDR s4Descript
    cmp     eax, 0
    je      wrong
    mov     mutexRead, eax
L4:
    INVOKE  StopMusic                       ; 终止先前的音乐播放
    mov     eax, filename
    mov     aMusicFile.filename, eax
    ; 判断文件格式
    INVOKE  lstrlen, filename
    cmp     eax, 5
    jb      wrong
    mov     filenameLength, eax
    mov     esi, filename
    add     esi, filenameLength
    sub     esi, 4
    INVOKE  lstrcmp, esi, ADDR wavExtension
    cmp     eax, 0
    je      isWav
    INVOKE  lstrcmp, esi, ADDR mp3Extension
    cmp     eax, 0
    je      isMp3
    cmp     filenameLength, 6
    jb      wrong
    dec     esi
    INVOKE  lstrcmp, esi, ADDR flacExtension
    cmp     eax, 0
    je      isFlac
    jmp     wrong
isWav:
    mov     aMusicFile.musicType, WAV
    jmp     after
isMp3:
    mov     aMusicFile.musicType, MP3
    jmp     after
isFlac:
    mov     aMusicFile.musicType, FLAC
after:
    INVOKE  CreateThread,
            NULL,
            0,
            _PlayMusic,                     ; 线程调用的函数名            
            NULL,
            0,
            NULL
    cmp     eax, NULL
    je      wrong
    mov     eax, TRUE
    ret
wrong:
    mov     eax, FALSE
    ret
PlayMusic ENDP

StopMusic PROC
;   RETURN: BOOL
    cmp     mutexPlaying, 0
    je      ignore
    INVOKE  WaitForSingleObject,
            mutexPlaying,
            INFINITE
    mov     Playing, FALSE
    INVOKE  ReleaseSemaphore,
            mutexPlaying,
            1,
            NULL
    cmp     canPlaying, 0
    je      ignore
    INVOKE  WaitForSingleObject,
            canPlaying,
            INFINITE
    INVOKE  ReleaseSemaphore,
            canPlaying,
            1,
            NULL
ignore:
    mov     eax, TRUE
    ret
StopMusic ENDP

PauseMusic PROC
;   RETURN: BOOL
    cmp     mutexIsPlaying, 0
    je      ignore
    INVOKE  WaitForSingleObject,
            mutexIsPlaying,
            INFINITE
    mov     isPlaying, FALSE
    INVOKE  ReleaseSemaphore,
            mutexIsPlaying,
            1,
            NULL
ignore:
    mov     eax, TRUE
    ret
wrong:
    mov     eax, FALSE
    ret
PauseMusic ENDP

ContinueMusic PROC
;   RETURN: BOOL
    cmp     mutexIsPlaying, 0
    je      ignore
    INVOKE  WaitForSingleObject,
            mutexIsPlaying,
            INFINITE
    mov     isPlaying, TRUE
    INVOKE  ReleaseSemaphore,
            mutexIsPlaying,
            1,
            NULL
ignore:
    mov     eax, TRUE
    ret
wrong:
    mov     eax, FALSE
    ret
ContinueMusic ENDP

SetVolume PROC,
    new_volume: DWORD                   ; 设置的音量大小
;   RETURN: BOOL
    cmp     Playing, TRUE
    jne     L1
    cmp     muted, TRUE
    je      L1
    INVOKE  waveOutSetVolume,
            hWaveOut,
            new_volume
    cmp     eax, MMSYSERR_NOERROR
    jne     wrong
L1:
    mov     eax, new_volume
    mov     volume, eax
    mov     eax, TRUE
    ret
wrong:
    mov     eax, FALSE
    ret     
SetVolume ENDP

IncreaseVolume PROC
;   RETURN: BOOL
    cmp     volume, 0F000F000h          ; 是否达到最大值
    je      wrong
    mov     eax, volume
    add     eax, 10001000h
    INVOKE  SetVolume, eax
    ret
wrong:
    mov     eax, FALSE
    ret
IncreaseVolume ENDP

DecreaseVolume PROC
;   RETURN: BOOL
    cmp     volume, 00000000h           ; 是否达到最小值
    je      wrong
    mov     eax, volume
    sub     eax, 10001000h
    INVOKE  SetVolume, eax
    ret
wrong:
    mov     eax, FALSE
    ret
DecreaseVolume ENDP

Mute PROC
;   RETURN: BOOL
    cmp     Playing, TRUE
    jne     L1
    INVOKE  waveOutSetVolume,
            hWaveOut,
            0
    cmp     eax, MMSYSERR_NOERROR
    jne     wrong
L1:
    mov     muted, TRUE
    mov     eax, TRUE
    ret
wrong:
    mov     eax, FALSE
    ret
Mute ENDP

unMute PROC
;   RETURN: BOOL
    cmp     Playing, TRUE
    jne     L1
    INVOKE  waveOutSetVolume,
            hWaveOut,
            volume
    cmp     eax, MMSYSERR_NOERROR
    jne     wrong
L1:
    mov     muted, FALSE
    mov     eax, TRUE
    ret
wrong:
    mov     eax, FALSE
    ret
unMute ENDP

SetMusicTime PROC,
    time: DWORD     ; 设置的进度条时间，单位秒（s）
;   RETURN: BOOL
    cmp     Playing, TRUE
    jne     wrong
    mov     eax, time
    add     eax, 5
    cmp     eax, totalTime
    ja      wrong
    mov     eax, time
    mul     totalRead
    div     totalTime
    push    eax
    cmp     mutexRead, 0
    je      wrong
    INVOKE  WaitForSingleObject,
            mutexRead,
            INFINITE
    pop     eax
    mov     haveRead, eax
    INVOKE  ReleaseSemaphore,
            mutexRead,
            1,
            NULL
    mov     eax, TRUE
    ret
wrong:
    mov     eax, FALSE
    ret
SetMusicTime ENDP

ForwardMusicTime PROC
    mov     eax, playedTime
    add     eax, 10
    INVOKE  SetMusicTime, eax
    ret
ForwardMusicTime ENDP

BackwardMusicTime PROC
    mov     eax, playedTime
    cmp     eax, 10
    jb      L1
    sub     eax, 10
    jmp     L2
L1:
    mov     eax, 0
L2:
    INVOKE  SetMusicTime, eax
    ret
BackwardMusicTime ENDP

GetPlaying PROC
    mov     eax, Playing
    ret
GetPlaying ENDP

GetIsPlaying PROC
    mov     eax, isPlaying
    ret
GetIsPlaying ENDP

GetVolume PROC
    mov     eax, volume
    ret
GetVolume ENDP

GetMuted PROC
    mov     eax, muted
    ret
GetMuted ENDP

GetTotalTime PROC
    mov     eax, totalTime
    ret
GetTotalTime ENDP

GetPlayedTime PROC
    mov     eax, playedTime
    ret
GetPlayedTime ENDP

END