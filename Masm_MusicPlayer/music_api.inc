; music_api.inc
INCLUDE     Winmm.inc
INCLUDELIB  Winmm.lib

; 音乐类型
WAV = 1
MP3 = 2

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
