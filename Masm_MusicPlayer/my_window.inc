;my_window.inc
;将时间转化为供人阅读的字符串

TimeToString PROTO, 
    time: DWORD, pstr: PTR BYTE

Str_concat  PROTO,
    target: PTR  BYTE,   source:  PTR BYTE

GetStockObject PROTO, 
    i: DWORD

CreateCompatibleBitmap PROTO,
    hdc: DWORD, x: DWORD, y: DWORD

CreateCompatibleDC PROTO,
    hdc: DWORD

SelectObject PROTO,
    hdc: DWORD, h: DWORD

BitBlt PROTO,
    hdc: DWORD, x: DWORD, y: DWORD, cxx: DWORD, cy: DWORD, 
    hdcSrc: DWORD, xl: DWORD, yl: DWORD, rop: DWORD