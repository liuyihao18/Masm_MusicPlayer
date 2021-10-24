;my_window.inc
;将时间转化为供人阅读的字符串

TimeToString PROTO, 
    time: DWORD, pstr: PTR BYTE

Str_concat  PROTO,
    target: PTR  BYTE,   source:  PTR BYTE