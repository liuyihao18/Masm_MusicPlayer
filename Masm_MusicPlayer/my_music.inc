; util.inc
INCLUDELIB  my_music.lib

; MPC解码函数
DecodeMp3ToBuffer PROTO,
    file:       HANDLE,             ; 文件句柄
    musicSize:  PTR DWORD           ; 缓冲大小
; 返回：PTR BYTE
;   - 若成功，结果为指向缓冲区的指针
;   - 若失败，结果为空指针

; MP3文件格式获取
GetMp3Format PROTO,
    filename:   PTR CHAR,           ; 文件名
    format:     PTR WAVEFORMATEX    ; 格式结构体指针
; 返回：BOOL
;   - 若成功，返回TRUE
;   - 若失败，返回FALSE
