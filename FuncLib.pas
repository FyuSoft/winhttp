unit FuncLib;

// {$DEFINE SMALL} //��С���
interface

uses
  Windows, Sysutils, Messages, ShellAPI{$IFNDEF SMALL}, ActiveX, ComObj{$ENDIF}
  {, shlobj};

type
  TStrArr = array of string;

procedure OutDebug(s: string);          // �������

function StrDec(const Str: string): string; // �ַ����ܺ���
function FloatToStr2(const f: Double; const n: Integer): string;

function GetFileVersion(FileName: string): Word;
function GetFileSize(const Path: string): Int64;
function GetSizeKMG(byteSize: Int64): string; // �Զ�����KB MB GB
function GetModulePath(hinst: Cardinal; DllName: PChar): PChar; // ���DLL����Ŀ¼
procedure MousePosClick(x, y: Integer); // �����ָ������

function RandStr(minLen, maxLen: WORD): AnsiString; // ����ַ�
function RandGBString(min, max: Integer): string; // ��GB2312�������ȡһ�����������Ŀɼ��ַ�
function GetSubStr(const _Str, _Start, _End: string): string;
function GetSubStrEx(const _Str, _Start, _End: string; var _LastStr: string
  { ���²��� }): string;
function SplitStrArr(const Separators, sContent: string; var StrArr: TStrArr):
  Integer;

function Chs2Cht(Str: string): string;  // CHS -> CHT
function Cht2Chs(Str: string): string;  // CHT -> CHS
function BIG5Encode(Str: AnsiString): AnsiString; // GBK -> BIG5
function BIG5Decode(Str: AnsiString): AnsiString; // BIG5 -> GBK

function SetPrivilege(const Privilege: PChar): Boolean;
// SeShutdownPrivilege �ػ�Ȩ��  SeDebugPrivilege ����Ȩ��

function RegDelValue(hKey: HKEY; Key, Vname: PChar): Boolean; // ɾ��ע���ֵ
function RegReadStr(hKey: HKEY; Key, Vname: PChar): string; // ��ע��� str
function RegReadInt(hKey: HKEY; Key, Vname: PChar): DWORD; // ��ע���Integer
function RegWriteStr(hKey: HKEY; Key, Vname, Value: PChar): Boolean; // дSTR
function RegWriteInt(hKey: HKEY; Key, Vname: PChar; Value: Integer): Boolean;

function CopyFileAndDir(const source, dest: string): Boolean; // �����ļ���Ŀ¼
function DelFileAndDir(const source: string): Boolean; // ɾ���ļ���Ŀ¼

function WaitForExec(const CommLine: AnsiString; Time, cmdShow: Cardinal):
  Cardinal;                             // �������̲��ȴ�����PID
function SelectDesktop(pName: PChar): Boolean; stdcall; // ѡ������
function InputDesktopSelected: Boolean; stdcall; // �Ƿ�Ϊ��ǰ����

function XmlEntitiesEnc(const s: string): string; // Xml�ַ�ʵ�����(< = &lt;)
function JavaScriptEscape(const s: string): string; // JAVASCRIPTת���ַ�
{$IFNDEF SMALL}
function RunJavaScript(const JsCode, JsVar: string): string;
// ���� JsCode ��Ҫִ�е� Js ����; ���� JsVar ��Ҫ���صı���
{$ENDIF}

function GetTickCountUSec(): DWORD;     // ΢���ʱ����1/1000 000��
function DiffTickCount(tOld, tNew: DWORD): DWORD; // ����ʱ���
function MSecondToTimeStr(ms: Cardinal): string;

function TrimMultiCRLF(const Text: string): string; // ɾ��StringList�п���
function StrIsIn(const Subs: array of string; Text: string): Boolean;
// �ж����ַ��Ƿ����ַ�����

implementation

procedure OutDebug(s: string);
begin
  OutputDebugString(PChar(s));
end;

function StrDec(const Str: string): string; // �ַ����ܺ���
const
  XorKey            : array[0..7] of Byte = ($B2, $09, $AA, $55, $93, $6D, $84,
    $47);
  // �ַ���������
var
  i, j              : Integer;
begin
  Result := '';
  j := 0;
  try
    for i := 1 to Length(Str) div 2 do
    begin
      Result := Result + Char(StrToInt('$' + Copy(Str, i * 2 - 1, 2)) xor
        XorKey[j]);
      j := (j + 1) mod 8;
    end;
  except
  end;
end;

function FloatToStr2(const f: Double; const n: Integer): string;
// <== 20100313 hou
var
  i, j, k           : Integer;
begin
  j := 1;
  for i := 1 to n do
    j := j * 10;

  k := Trunc(f);
  Result := IntToStr(k) + '.' + IntToStr(Trunc((f - k) * j));
end;

function GetFileVersion(FileName: string): Word;
type
  PVerInfo = ^TVS_FIXEDFILEINFO;

  TVS_FIXEDFILEINFO = record
    dwSignature: longint;
    dwStrucVersion: longint;
    dwFileVersionMS: longint;
    dwFileVersionLS: longint;
    dwFileFlagsMask: longint;
    dwFileFlags: longint;
    dwFileOS: longint;
    dwFileType: longint;
    dwFileSubtype: longint;
    dwFileDateMS: longint;
    dwFileDateLS: longint;
  end;
var
  ExeNames          : array[0..255] of char;
  VerInfo           : PVerInfo;
  Buf               : pointer;
  Sz                : word;
  L, Len            : Cardinal;
begin
  Result := 0;
  StrPCopy(ExeNames, FileName);
  Sz := GetFileVersionInfoSize(ExeNames, L);
  if Sz = 0 then
    Exit;

  try
    GetMem(Buf, Sz);
    try
      GetFileVersionInfo(ExeNames, 0, Sz, Buf);
      if VerQueryValue(Buf, '\', Pointer(VerInfo), Len) then
      begin
        { Result := IntToStr(HIWORD(VerInfo.dwFileVersionMS)) + '.' +
          IntToStr(LOWORD(VerInfo.dwFileVersionMS)) + '.' +
          IntToStr(HIWORD(VerInfo.dwFileVersionLS)) + '.' +
          IntToStr(LOWORD(VerInfo.dwFileVersionLS)); }
        Result := HIWORD(VerInfo.dwFileVersionMS);
      end;
    finally
      FreeMem(Buf);
    end;
  except
    Result := 0;
  end;
end;

function GetFileSize(const Path: string): Int64;
var
  hFindFile         : THandle;
  findData          : TWin32FindData;
begin
  hFindFile := FindFirstFile(PChar(Path), findData);
  if hFindFile <> INVALID_HANDLE_VALUE then
  begin
    Result := findData.nFileSizeHigh * $100000000 + findData.nFileSizeLow;
    Windows.FindClose(hFindFile);
  end
  else
    Result := 0;
end;

function GetSizeKMG(byteSize: Int64): string; // �Զ�����KB MB GB
begin
  if byteSize < 1024 then
    Result := IntToStr(byteSize) + ' B'
  else if byteSize < 1024 * 1024 then
    Result := FloatToStr2(byteSize / 1024, 2) + ' KB'
      // format2('%.2f KB', [byteSize / 1024])
  else if byteSize < 1024 * 1024 * 1024 then
    Result := FloatToStr2(byteSize / (1024 * 1024), 2) + ' MB'
      // format('%.2f MB', [byteSize / (1024 * 1024)])
  else
    Result := FloatToStr2(byteSize / (1024 * 1024 * 1024), 2) + ' GB';
  // format('%.2f GB', [byteSize / (1024 * 1024 * 1024)]);
end;

{ -------------------------------------------------------------------------------
  ������:    GetModulePath
  ����:      HouSoft
  ����:      2009.12.01
  ����:      ģ��ʵ��  ģ���� (ģ��ʵ��Ϊ0ʱģ��������Ч)
  ����ֵ:    PChar
  ------------------------------------------------------------------------------- }

function GetModulePath(hinst: Cardinal; DllName: PChar): PChar;
var
  i, n              : Integer;
  szFilePath        : array[0..MAX_PATH] of Char;
begin
  if hInst > 0 then
    GetModuleFileName(hInst, szFilePath, SizeOf(szFilePath))
  else
    GetModuleFileName(GetModuleHandle(DllName), szFilePath, SizeOf(szFilePath));
  n := 0;
  for i := Low(szFilePath) to High(szFilePath) do
    case szFilePath[I] of
      '\':
        n := i;
      #0:
        Break;
    end;
  szFilePath[n + 1] := #0;
  Result := szFilePath;                 // �˴���,����DLL�����в������
end;

procedure MousePosClick(x, y: Integer);
var
  lpPoint           : TPoint;
begin
  GetCursorPos(lpPoint);
  SetCursorPos(x, y);
  mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);
  mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);
  SetCursorPos(lpPoint.X, lpPoint.Y);
end;

function RandStr(minLen, maxLen: WORD): AnsiString; // 20100804 Fix
const
  USER_CHARS        : PAnsiChar = 'abcdefghijklmnopurstuvwxyz1234567890';
var
  i, r, rLen        : Integer;
  rChr              : AnsiChar;
begin
  rLen := minLen + GetTickCount mod (maxLen - minLen + 1); // �������
  SetLength(Result, rLen);
  for i := 1 to rLen do
  begin
    r := Random(GetTickCount);
    rChr := USER_CHARS[r mod Length(USER_CHARS)]; // ����ַ�

    if ((i = 1) or (i = rLen))
      and (rChr in ['0'..'9']) then     // ��ͷ��β��Ϊ����
      rChr := AnsiChar(Ord('a') + r mod 26);
    Result[i] := rChr;
  end;
end;

{ ��GB2312�������ȡһ�����������Ŀɼ��ַ� }
var
  g_GBIndex         : DWORD = 0;

function RandGBString(min, max: Integer): string;
const
  GB_H_L            = $B0;
  GB_H_H            = $F7;
  MAX_GB_H          = GB_H_H - GB_H_L + 1; // 48
  GB_L_L            = $A1;              // $A0 is null,�����λ
  GB_L_H            = $FE;
  MAX_GB_L          = GB_L_H - GB_L_L + 1; // 94
var
  i, n              : Integer;
  bHigh, bLow       : Byte;
  lpPtr             : PChar;
  gbIndex           : DWORD;

  llCount           : Int64;
begin
  Result := '';
  if max < 1 then
    max := 1;
  QueryPerformanceCounter(llCount);     // ��߾���
  n := llCount mod max + 1;
  if n < min then
    n := min;

  SetLength(Result, 2 * n);
  lpPtr := @Result[1];                  { ����UniqueString��� }
  for i := 0 to n - 1 do
  begin
    gbIndex := InterlockedIncrement(Integer(g_GBIndex)); // 20100907 Fix Thread
    { ���󷨣��������Ӱ�� }
    bLow := GB_L_L + gbIndex mod MAX_GB_L;
    bHigh := GB_H_L + gbIndex mod MAX_GB_H;
    { ������ }
    { bLow := GB_L_L + gbIndex mod MAX_GB_L;
      bHigh := GB_H_L + gbIndex div MAX_GB_L mod MAX_GB_H; }

    lpPtr[2 * i] := Char(bHigh);
    lpPtr[2 * i + 1] := Char(bLow);
    // PWord(@lpPtr[2 * i])^ := bLow shl 8 or bHigh; { Little-Endian X86 }
  end;
end;

function GetSubStr(const _Str, _Start, _End: string): string;
// 20100306
var
  Index             : Integer;
begin
  if _Start <> '' then
  begin
    Index := Pos(_Start, _Str);
    if Index = 0 then
    begin
      Result := '';
      Exit;
    end;
  end
  else
    Index := 1;

  Result := Copy(_Str, Index + Length(_Start), MaxInt);
  if _End = '' then
    Index := Length(Result) + 1
  else
    Index := Pos(_End, Result);

  Result := Copy(Result, 1, Index - 1);
end;

function GetSubStrEx(const _Str, _Start, _End: string; var _LastStr: string
  { ���²��� }): string;
// 20100306 Pos �� StrPos �� 1.5��
var
  Index             : Integer;
begin
  if _Start <> '' then
  begin
    Index := Pos(_Start, _Str);
    if Index = 0 then
    begin
      Result := '';
      _LastStr := _Str;
      Exit;
    end;
  end
  else
    Index := 1;

  _LastStr := Copy(_Str, Index + Length(_Start), MaxInt);
  if _End = '' then
    Index := Length(_Str) + 1
  else
    Index := Pos(_End, _LastStr);

  Result := Copy(_LastStr, 1, Index - 1);
  _LastStr := Copy(_LastStr, Index + Length(_End), MaxInt);
end;

function SplitStrArr(const Separators, sContent: string; var StrArr: TStrArr):
  Integer;
var
  sStr, sTmp        : string;
begin
  Result := 0;
  SetLength(StrArr, Result);
  sStr := sContent + Separators;
  repeat
    sTmp := GetSubStrEx(sStr, '', Separators, sStr);
    if sTmp <> '' then
    begin
      Inc(Result);
      SetLength(StrArr, Result);
      StrArr[High(StrArr)] := sTmp;
    end;
  until sTmp = '';
end;

function Chs2Cht(Str: string): string;
var
  len               : Integer;
begin
  len := Length(Str);
  SetLength(Result, len);
  LCMapString($804, LCMAP_TRADITIONAL_CHINESE,
    PChar(Str), -1, PChar(Result), len);
end;

function Cht2Chs(Str: string): string;
var
  len               : Integer;
begin
  len := Length(Str);
  SetLength(Result, len);
  LCMapString($804, LCMAP_SIMPLIFIED_CHINESE,
    PChar(Str), -1, PChar(Result), len);
end;

function BIG5Encode(Str: AnsiString): AnsiString;
var
  len               : Integer;
  lpUnicode         : PWideChar;
begin
  len := Length(Str);
  SetLength(Result, len);
  lpUnicode := AllocMem(len * 2);

  // GBK - > Unicode
  MultiByteToWideChar(936, 0, PAnsiChar(Str), -1, lpUnicode, len);
  // Unicode - > BIG5
  WideCharToMultiByte(950, 0, lpUnicode, -1, PAnsiChar(Result), len, nil, nil);

  FreeMemory(lpUnicode);
end;

function BIG5Decode(Str: AnsiString): AnsiString;
var
  len               : Integer;
  lpUnicode         : PWideChar;
begin
  len := Length(Str);
  SetLength(Result, len);
  lpUnicode := AllocMem(len * 2);

  // Big5 - > Unicode
  MultiByteToWideChar(950, 0, PAnsiChar(Str), -1, lpUnicode, len);
  // Unicode - > (GBK) GB CHT
  WideCharToMultiByte(936, 0, lpUnicode, -1, PAnsiChar(Result), len, nil, nil);

  FreeMemory(lpUnicode);
end;

function SetPrivilege(const Privilege: PChar): Boolean; // Ȩ��
var
  OldTokenPrivileges, TokenPrivileges: TTokenPrivileges;
  ReturnLength      : DWORD;
  hToken            : THandle;
  luid              : Int64;
begin
  OpenProcessToken(GetCurrentProcess, TOKEN_ADJUST_PRIVILEGES, hToken);
  LookupPrivilegeValue(nil, Privilege, luid);
  TokenPrivileges.Privileges[0].luid := luid;
  TokenPrivileges.PrivilegeCount := 1;
  TokenPrivileges.Privileges[0].Attributes := 0;
  AdjustTokenPrivileges(hToken, false, TokenPrivileges,
    SizeOf(TTokenPrivileges), OldTokenPrivileges, ReturnLength);
  OldTokenPrivileges.Privileges[0].luid := luid;
  OldTokenPrivileges.PrivilegeCount := 1;
  OldTokenPrivileges.Privileges[0].Attributes :=
    TokenPrivileges.Privileges[0].Attributes or SE_PRIVILEGE_ENABLED;
  Result := AdjustTokenPrivileges(hToken, false, OldTokenPrivileges,
    ReturnLength, PTokenPrivileges(nil)^, ReturnLength);
end;
{ ----------end------------- }

function RegDelValue(hKey: HKEY; Key, Vname: PChar): Boolean; // ɾ��ע���ֵ
var
  hk                : Windows.HKEY;
begin
  Result := false;
  if RegOpenKey(hKey, Key, hk) = ERROR_SUCCESS then
    if RegDeleteValue(hk, Vname) = ERROR_SUCCESS then
      Result := True;
  RegCloseKey(hk);
end;

function RegReadStr(hKey: HKEY; Key, Vname: PChar): string;
var
  hk                : Windows.HKEY;
  dwSize            : DWORD;
  szBuf             : array[0..MAX_PATH - 1] of Char;
begin
  Result := '';
  dwSize := SizeOf(szBuf);
  if RegOpenKey(hKey, Key, hk) = 0 then
    if RegQueryValueEx(hk, Vname, nil, nil, @szBuf, @dwSize) = 0 then
      Result := szBuf;
  RegCloseKey(hk);
end;

function RegReadInt(hKey: HKEY; Key, Vname: PChar): DWORD; // ��ע���Integer
var
  hk                : Windows.HKEY;
  dwSize            : DWORD;
begin
  Result := 0;
  dwSize := SizeOf(Result);
  if RegOpenKey(hKey, Key, hk) = 0 then
    RegQueryValueEx(hk, Vname, nil, nil, @Result, @dwSize);
  RegCloseKey(hk);
end;

function RegWriteStr(hKey: HKEY; Key, Vname, Value: PChar): Boolean; // дSTR
var
  hk                : Windows.HKEY;
  D                 : DWORD;
begin
  Result := false;
  D := REG_CREATED_NEW_KEY;
  if RegCreateKeyEx(hKey, Key, 0, nil, 0, KEY_ALL_ACCESS, nil, hk,
    @D) = 0 then
    if RegSetValueEx(hk, Vname, 0, REG_SZ, Value, Length(Value) * SizeOf(Char))
      = 0 then
      Result := True;
  RegCloseKey(hk);
end;

function RegWriteInt(hKey: HKEY; Key, Vname: PChar; Value: Integer): Boolean;
// дDWORD
var
  hk                : Windows.HKEY;
  D                 : DWORD;
begin
  Result := false;
  D := REG_CREATED_NEW_KEY;
  if RegCreateKeyEx(hKey, Key, 0, nil, 0, KEY_ALL_ACCESS, nil, hk,
    @D) = 0 then
    if RegSetValueEx(hk, Vname, 0, REG_DWORD, @Value, SizeOf(Value)) = 0 then
      Result := True;
  RegCloseKey(hk);
end;

function CopyFileAndDir(const source, dest: string): Boolean;
var
  fo                : TSHFILEOPSTRUCT;
begin
  FillChar(fo, SizeOf(fo), 0);
  with fo do
  begin
    Wnd := 0;
    wFunc := FO_Copy;
    pFrom := PChar(source);
    pTo := PChar(dest);
    fFlags := FOF_NOCONFIRMATION or FOF_NOERRORUI or FOF_SILENT;
  end;
  Result := (SHFileOperation(fo) = 0);
end;

function DelFileAndDir(const source: string): Boolean;
var
  fo                : TSHFILEOPSTRUCT;
begin
  FillChar(fo, SizeOf(fo), 0);
  with fo do
  begin
    Wnd := 0;
    wFunc := FO_DELETE;
    pFrom := PChar(source);
    pTo := nil;
    fFlags := FOF_NOCONFIRMATION + FOF_SILENT;
  end;
  Result := (SHFileOperation(fo) = 0);
end;

function WaitForExec(const CommLine: AnsiString; Time, cmdShow: Cardinal):
  Cardinal;                             // �������̲��ȴ�����PID
var
  si                : _STARTUPINFOA;
  pi                : PROCESS_INFORMATION;
begin
  ZeroMemory(@si, SizeOf(si));
  si.cb := SizeOf(si);
  si.dwFlags := STARTF_USESHOWWINDOW;
  si.wShowWindow := cmdShow;
  if CreateProcessA(nil, PAnsiChar(CommLine), nil, nil, false,
    CREATE_DEFAULT_ERROR_MODE, nil, nil, si, pi) then // CreateProcessW ��������
  begin
    WaitForSingleObject(pi.hProcess, Time);
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
  end;
  Result := pi.dwProcessID;
end;

{ �����л� }

function SelectHDESK(HNewDesk: HDESK): Boolean; stdcall;
var
  HOldDesk          : HDESK;
  dwDummy           : DWORD;
  sName             : array[0..MAX_PATH - 1] of Char;
begin
  Result := false;
  HOldDesk := GetThreadDesktop(GetCurrentThreadId);
  if (not GetUserObjectInformation(HNewDesk, UOI_NAME, @sName, SizeOf(sName),
    dwDummy)) then
  begin
    // OutputDebugString('GetUserObjectInformation Failed.');
    exit;
  end;
  if (not SetThreadDesktop(HNewDesk)) then
  begin
    // OutputDebugString('SetThreadDesktop Failed.');
    exit;
  end;
  if (not CloseDesktop(HOldDesk)) then
  begin
    // OutputDebugString('CloseDesktop Failed.');
    exit;
  end;
  Result := True;
end;

function SelectDesktop(pName: PChar): Boolean; stdcall;
var
  HDesktop          : HDESK;
begin
  Result := false;
  if Assigned(pName) then
    HDesktop := OpenDesktop(pName, 0, false,
      DESKTOP_CREATEMENU or DESKTOP_CREATEWINDOW or
      DESKTOP_ENUMERATE or DESKTOP_HOOKCONTROL or
      DESKTOP_WRITEOBJECTS or DESKTOP_READOBJECTS or
      DESKTOP_SWITCHDESKTOP or GENERIC_WRITE)
  else
    HDesktop := OpenInputDesktop(0, false,
      DESKTOP_CREATEMENU or DESKTOP_CREATEWINDOW or
      DESKTOP_ENUMERATE or DESKTOP_HOOKCONTROL or
      DESKTOP_WRITEOBJECTS or DESKTOP_READOBJECTS or
      DESKTOP_SWITCHDESKTOP or GENERIC_WRITE);
  if (HDesktop = 0) then
  begin
    // OutputDebugString(PChar('Get Desktop Failed: ' + IntToStr(GetLastError)));
    exit;
  end;
  Result := SelectHDESK(HDesktop);
end;

function InputDesktopSelected: Boolean; stdcall;
var
  HThdDesk          : HDESK;
  HInpDesk          : HDESK;
  // dwError: DWORD;
  dwDummy           : DWORD;
  sThdName          : array[0..MAX_PATH - 1] of Char;
  sInpName          : array[0..MAX_PATH - 1] of Char;
begin
  Result := false;
  HThdDesk := GetThreadDesktop(GetCurrentThreadId);
  HInpDesk := OpenInputDesktop(0, false,
    DESKTOP_CREATEMENU or DESKTOP_CREATEWINDOW or
    DESKTOP_ENUMERATE or DESKTOP_HOOKCONTROL or
    DESKTOP_WRITEOBJECTS or DESKTOP_READOBJECTS or
    DESKTOP_SWITCHDESKTOP);
  if (HInpDesk = 0) then
  begin
    // OutputDebugString('OpenInputDesktop Failed.');
    // dwError := GetLastError;
    // result := (dwError = 170);
    exit;
  end;
  if (not GetUserObjectInformation(HThdDesk, UOI_NAME, @sThdName,
    SizeOf(sThdName),
    dwDummy)) then
  begin
    // OutputDebugString('GetUserObjectInformation HThdDesk Failed.');
    CloseDesktop(HInpDesk);
    exit;
  end;
  if (not GetUserObjectInformation(HInpDesk, UOI_NAME, @sInpName,
    SizeOf(sInpName),
    dwDummy)) then
  begin
    // OutputDebugString('GetUserObjectInformation HInpDesk Failed.');
    CloseDesktop(HInpDesk);
    exit;
  end;
  CloseDesktop(HInpDesk);
  Result := (lstrcmp(sThdName, sInpName) = 0);
end;

{ procedure ScreenTextOut(Str: PChar);
  var
  dm: hDC;
  begin
  dm := GetWindowDC(0);
  SetTextColor(dm,$0000FF);
  // SetBkMode(dm, TRANSPARENT);
  TextOut(dm, GetSystemMetrics(SM_CXSCREEN) div 2, GetSystemMetrics(SM_CYSCREEN) div 2, Str, Length(Str));

  end; }

{
  �����������XML�ĵ���Ԥ����õ�ʵ�壺

  &lt;	<	С�ں�
  &gt;	>	���ں�
  &amp;	&	��
  &apos;	'	������
  &quot;	"	˫����

  ʵ������Է���"&"��ͷ���Է���";"��β��

  ע��: ֻ��"<" �ַ���"&"�ַ�����XML��˵���ϸ��ֹʹ�õġ�
  ʣ�µĶ��ǺϷ��ģ�Ϊ�˼��ٳ���ʹ��ʵ����һ����ϰ�ߡ�

}

function XmlEntitiesEnc(const s: string): string;
var
  i                 : Integer;
  sTmp              : string;
begin
  sTmp := '';
  if Length(s) > 0 then
    for i := 1 to Length(s) do
      case Ord(s[i]) of
        $003C:
          sTmp := sTmp + '&lt;';        // <
        $003E:
          sTmp := sTmp + '&gt;';        // >
        $0026:
          sTmp := sTmp + '&amp;';       // &
        $0027:
          sTmp := sTmp + '&apos;';      // '
        $0022:
          sTmp := sTmp + '&quot;';      // "
      else
        sTmp := sTmp + s[i];
      end;
  Result := sTmp;
end;

{
  ת������ �ַ�
  \b �˸�
  \f ��ֽ��ҳ
  \n ����
  \r �س�
  \t �������� (Ctrl-I)
  \' ������
  \" ˫����
  \\ ��б��
}

function JavaScriptEscape(const s: string): string;
var
  i                 : Integer;
  sTmp              : string;
begin
  sTmp := '';
  if Length(s) > 0 then
    for i := 1 to Length(s) do
      case Ord(s[i]) of
        $005C:
          sTmp := sTmp + '\\';
        $0022:
          sTmp := sTmp + '\"';
        $0027:
          sTmp := sTmp + '\''';
        $000D:
          sTmp := sTmp + '\r';
        $000C:
          sTmp := sTmp + '\f';
        $000A:
          sTmp := sTmp + '\n';
        $0009:
          sTmp := sTmp + '\t';
        $0008:
          sTmp := sTmp + '\b';
      else
        sTmp := sTmp + s[i];
      end;
  Result := sTmp;
end;

{$IFNDEF SMALL}
{ �˺�����Ҫ ComObj ��Ԫ��֧�� }
{ ���� JsCode ��Ҫִ�е� Js ����; ���� JsVar ��Ҫ���صı��� }
{ WinExec('regsvr32 Msscript.ocx', SW_SHOW); }

function RunJavaScript(const JsCode, JsVar: string): string;
var
  script            : OleVariant;
begin
  try
    CoInitialize(nil);
    script := CreateOleObject('ScriptControl');
    // CreateOleObject('ScriptControl');
    script.Language := 'JScript';
    script.ExecuteStatement(JsCode);
    Result := script.Eval(JsVar);
    CoUninitialize;
  except
    on E: Exception do
    begin
      OutDebug('RunJavaScript ' + E.Message);
      Result := '';
    end;
  end;
end;
{$ENDIF}

var
  Frequency         : Int64;

function GetTickCountUSec;              // �� GetTickCount���ȸ�25~30����
var
  lpPerformanceCount: Int64;
begin
  if Frequency = 0 then
  begin
    QueryPerformanceFrequency(Frequency);
    // WINDOWS API ���ؼ���Ƶ��(Intel86:1193180)(���ϵͳ�ĸ�����Ƶ�ʼ�������һ���ڵ��𶯴���)
    Frequency := Frequency div 1000000; // һ΢�����񶯴���
  end;
  QueryPerformanceCounter(lpPerformanceCount);
  Result := lpPerformanceCount div Frequency;
end;

function DiffTickCount;                 // ����ʱ���
begin
  if tNew >= tOld then
    Result := tNew - tOld
  else
    Result := DWORD($FFFFFFFF) - tOld + tNew;
end;

function MSecondToTimeStr;              // fix 20100719
const
  MSecsPerHour      = MSecsPerSec * SecsPerMin * MinsPerHour;
  MSecsPerMin       = MSecsPerSec * SecsPerMin;
var
  Day, Hour, Min, Sec: Word;
begin
  Day := ms div MSecsPerDay;
  ms := ms mod MSecsPerDay;

  Hour := ms div MSecsPerHour;
  ms := ms mod MSecsPerHour;

  Min := ms div MSecsPerMin;
  ms := ms mod MSecsPerMin;

  Sec := ms div MSecsPerSec;

  Result := '';
  if Day > 0 then
    Result := Result + IntToStr(Day) + '��';
  if Hour > 0 then
    Result := Result + IntToStr(Hour) + 'Сʱ';
  if Min > 0 then
    Result := Result + IntToStr(Min) + '��';
  if Sec > 0 then
    Result := Result + IntToStr(Sec) + '��';
end;

function TrimMultiCRLF(const Text: string): string;
begin
  if StrLComp(#13#10, PChar(Text), 2) = 0 then
    Result := Copy(Text, 3, MaxInt)
  else
    Result := Text;
  while Pos(#13#10#13#10, Result) > 0 do
    Result := StringReplace(Result, #13#10#13#10, #13#10, [rfReplaceAll]);
end;

function StrIsIn(const Subs: array of string; Text: string): Boolean;
var
  i                 : Integer;
begin
  Result := False;
  for i := Low(Subs) to High(Subs) do
  begin
    if Subs[i] = '' then
      Continue;

    if Pos(Subs[i], Text) > 0 then
    begin
      Result := True;
      Break;
    end;
  end;
end;

end.

