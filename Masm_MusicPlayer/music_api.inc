; music_api.inc

; 音乐类型
WAV = 1
MP3 = 2
FLAC = 3

; 播放音乐函数
PlayMusic PROTO,
    filename: PTR CHAR  ; 指向文件名的指针
; 返回：BOOL
;   - 若成功，则为TRUE
;   - 若失败，则为FALSE

; 停止播放函数
StopMusic PROTO
; 返回：BOOL
;   - 若成功，则为TRUE
;   - 若失败，则为FALSE

; 暂停播放函数
PauseMusic PROTO
; 返回：BOOL
;   - 若成功，则为TRUE
;   - 若失败，则为FALSE

; 继续播放函数
ContinueMusic PROTO
; 返回：BOOL
;   - 若成功，则为TRUE
;   - 若失败，则为FALSE

; 设置音量函数
SetVolume PROTO,
    new_volume: DWORD       ; 设置的音量大小
; 返回：BOOL
;   - 若成功，则为TRUE
;   - 若失败，则为FALSE

; 增加音量函数
IncreaseVolume PROTO
; 返回：BOOL
;   - 若成功，则为TRUE
;   - 若失败，则为FALSE

; 减少音量函数
DecreaseVolume PROTO
; 返回：BOOL
;   - 若成功，则为TRUE
;   - 若失败，则为FALSE

; 静音函数
Mute PROTO
; 返回：BOOL
;   - 若成功，则为TRUE
;   - 若失败，则为FALSE

; 取消静音函数
unMute PROTO
; 返回：BOOL
;   - 若成功，则为TRUE
;   - 若失败，则为FALSE

; 设置时间函数
SetMusicTime PROTO,
    time: DWORD         ; 设置的进度条时间，单位秒（s）
; 返回：BOOL
;   - 若成功，则为TRUE
;   - 若失败，则为FALSE

; 快进10s函数
ForwardMusicTime PROTO
; 返回：BOOL
;   - 若成功，则为TRUE
;   - 若失败，则为FALSE

; 退后10s函数
BackwardMusicTime PROTO
; 返回：BOOL
;   - 若成功，则为TRUE
;   - 若失败，则为FALSE

; 获得播放状态
GetPlaying PROTO
; 返回：BOOL
;   - 若为TRUE，表示播放进程正在执行
;   - 若为FALSE，表示播放进程已经停止

; 获得播放状态
GetIsPlaying PROTO
; 返回：BOOL
;   - 若为TRUE，表示正在播放
;   - 若为FALSE，表示暂停播放

; 获得音量
GetVolume PROTO
; 返回：DWORD
;   - 音量大小0~F，可以通过&80000000获取
;   - 高四位为右声道，低四位为左声道

; 获得静音状态
GetMuted PROTO
; 返回：BOOL
;   - 若为TRUE，表示静音
;   - 若为FALSE，表示没有静音

; 获得播放总时长
GetTotalTime PROTO
; 返回：DWORD
;   - 时间单位为秒(s)

; 获得已经播放的时长
GetPlayedTime PROTO
; 返回：DWORD
;   - 时间单位为秒(s)
