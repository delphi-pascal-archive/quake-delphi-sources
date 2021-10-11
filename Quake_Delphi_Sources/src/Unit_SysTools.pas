// ------------------------------------------------------------------------------
//
// Copyright (C) 1996-1997 Id Software, Inc.
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//
// See the GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not,  write to the Free Software
// Foundation,  Inc., 59 Temple Place - Suite 330,  Boston,  MA  02111-1307, USA.
//
// ------------------------------------------------------------------------------
// Roman Vereshagin
// Valavanis Jim
//

unit Unit_SysTools;

interface

uses
  SysUtils,
  Math,
  WinSock;

type
  TVector2f        = array[0..1] of single;
  TVector3f        = array[0..2] of single;
  TVector3i        = array[0..2] of longint;
  TVector4f        = array[0..3] of single;
  PVector4f        = ^TVector4f;
  PVector3f        = ^TVector3f;

  Pvec_t = ^Single;

  mat3_t = array[0..2, 0..2] of single;
  Pmat3_t = ^mat3_t;

  vec5_t = array[0..4] of single;
  Pvec5_t = ^vec5_t;

const
  M_PI = 3.14159265358979323846; // matches value in gcc v2 math.h

type
  fixed4_t = integer;
  fixed8_t = integer;
  fixed16_t = integer;

var
  vec3_origin     : TVector3f = (0.0, 0.0, 0.0);
  min_vec3_origin : TVector3f = (-16.0, -16.0, -24.0);
  max_vec3_origin : TVector3f = (16.0, 16.0, 24.0);

const
  NULLFILE = -1;
  
const
  IDS_STRING1 = 1;
  IDD_DIALOG1 = 108;
  IDD_PROGRESS = 109;
  IDC_PROGRESS = 1000;

type
  qboolean  = LongBool;
  Pqboolean = ^qboolean;

  PByte = ^Byte;
  PInteger = ^integer;

  Pfloat = ^single;

  unsigned = longword;
  Punsigned = ^unsigned;

  unsigned_int = longword;
  Punsigned_int = ^unsigned_int;

  signed_char = shortint;
  unsigned_char = byte;

  short = smallint;
  Pshort = ^short;

  u_short = word;
  Pu_short = ^u_short;

  unsigned_short = word;
  Punsigned_short = ^unsigned_short;

  LONG = longint;
  PLONG = ^LONG;

  PByteArray = ^TByteArray;
  TByteArray = array[0..$FFFF] of byte;

  Punsigned_shortArray = ^Tunsigned_shortArray;
  Tunsigned_shortArray = array[0..$FFFF] of unsigned_short;

  PIntegerArray = ^TIntegerArray;
  TIntegerArray = array[0..$FFFF] of integer;

  PunsignedArray = ^TunsignedArray;
  TunsignedArray = array[0..$FFFF] of unsigned;

  PFloatArray = ^TFloatArray;
  TFloatArray = array[0..$FFFF] of single;

  PShortArray = ^TShortArray;
  TShortArray = array[0..$FFFF] of short;

  PCharArray = ^TCharArray;
  TCharArray = array[0..$FFFF] of char;

  PPChar = ^PChar;

procedure sprintf(s: PChar; const Fmt: PChar); overload;
procedure sprintf(s: PChar; const Fmt: PChar; const Args: array of const); overload;
procedure sprintf(s: string; const Fmt: PChar); overload;
procedure sprintf(s: string; const Fmt: PChar; const Args: array of const); overload;
procedure sprintf(s: PChar; const Fmt: string); overload;
procedure sprintf(s: PChar; const Fmt: string; const Args: array of const); overload;
procedure sprintf(s: string; const Fmt: string); overload;
procedure sprintf(s: string; const Fmt: string; const Args: array of const); overload;

procedure fprintf(var f: text; const Fmt: PChar); overload;
procedure fprintf(var f: file; const Fmt: PChar); overload;
procedure fprintf(f: integer; const Fmt: PChar); overload;
procedure fprintf(var f: text; const Fmt: PChar; const Args: array of const); overload;
procedure fprintf(var f: file; const Fmt: PChar; const Args: array of const); overload;
procedure fprintf(f: integer; const Fmt: PChar; const Args: array of const); overload;
procedure fprintf(var f: text; const Fmt: string); overload;
procedure fprintf(var f: file; const Fmt: string); overload;
procedure fprintf(f: integer; const Fmt: string); overload;
procedure fprintf(var f: text; const Fmt: string; const Args: array of const); overload;
procedure fprintf(var f: file; const Fmt: string; const Args: array of const); overload;
procedure fprintf(f: integer; const Fmt: string; const Args: array of const); overload;

function itoa(i: integer): string;
function atoi(const s: string): integer; overload;
function atoi(const s: PChar): integer; overload;
function atof(const s: string): single; overload;
function atof(const s: PChar): single; overload;

function memcpy(dst: pointer; const src: pointer; len: integer): pointer; overload;
function memmove(dst: pointer; const src: pointer; len: integer): pointer;
function memset(buf: pointer; c: integer; len: integer): pointer;
function malloc(size: integer): Pointer;
procedure free(var p: pointer);

function IntToStrZfill(const z: integer; const x: integer): string;

function boolval(const x: integer): boolean; overload;
function boolval(const c: char): boolean; overload;
function boolval(const p: pointer): boolean; overload;
function boolval(const f: single): boolean; overload;

function intval(const b: boolean): integer;

function floatval(const b: boolean): single;

function decide(const contition: boolean; const iftrue: integer; const iffalse: integer): integer; overload;
function decide(const contition: boolean; const iftrue: boolean; const iffalse: boolean): boolean; overload;
function decide(const contition: boolean; const iftrue: string; const iffalse: string): string; overload;
function decide(const contition: boolean; const iftrue: pointer; const iffalse: pointer): pointer; overload;
function decide(const contition: integer; const iftrue: integer; const iffalse: integer): integer; overload;
function decide(const contition: integer; const iftrue: boolean; const iffalse: boolean): boolean; overload;
function decide(const contition: integer; const iftrue: string; const iffalse: string): string; overload;
function decide(const contition: integer; const iftrue: pointer; const iffalse: pointer): pointer; overload;

function fread(buf: pointer; size: integer; count: integer; f: integer): integer; overload;
function fread(buf: pointer; size: integer; count: integer; var f: file): integer; overload;
function fwrite(buf: pointer; size: integer; count: integer; f: integer): integer; overload;
function fwrite(buf: pointer; size: integer; count: integer; var f: file): integer; overload;
procedure fclose(var f: integer); overload;
procedure fclose(var f: file); overload;
procedure fclose(var f: text); overload;

procedure fscanf(var f: text; buf: PChar); overload;
procedure fscanf(var f: text; var num: single); overload;
procedure fscanf(var f: text; var num: integer); overload;

function strstr(const _string: PChar; const strCharSet: PChar): PChar;
function strchr(const _string: PChar; const strChar: char): boolean;
function getc(f: integer; var c: char): char; overload;
function getc(var f: file; var c: char): char; overload;
function getc(var f: text; var c: char): char; overload;
procedure ZeroMemory(X: pointer; Count: Integer);
function rand: integer; // VJ mayby use VC rand anlogithm???
procedure incp(var p: pointer; const diff: integer);
function strncmp(s1, s2: PChar; count: Integer): Integer;
function strnicmp(s1, s2: PChar; count: Integer): Integer;
function strncpy(dest, source: PChar; count: Integer): PChar;
function FileIsOpened(f: integer): boolean; overload;
function FileIsOpened(var f: file): boolean; overload;
function FileIsOpened(var f: text): boolean; overload;
function boolval(var f: file): boolean; overload;
function isupper(ch: Char): boolean;
function islower(ch: Char): boolean;
function isalpha(ch: Char): boolean;
function isdigit(ch: Char): boolean;
function toupper(ch: Char): Char;
function tolower(ch: Char): Char;
function strcpy(Dest: PChar; const Source: PChar): PChar; assembler;
function strlen(const Str: PChar): integer; assembler;
function strcmp(const Str1, Str2: PChar): Integer; assembler;
function strend(const Str: PChar): PChar; assembler;
function strcat(Dest: PChar; const Source: PChar): PChar;
function int(const f: single): integer;
function uint(const f: single): unsigned_int;
function fatan(const f: single): single;
function ftan(const f: single): single;
function fasin(const f: single): single;
function fatan2(const y, x: single): Extended;
function fpow(const Base, Exponent: single): single;
function floor(x: single): integer;
function ceil(x: single): integer;
function read_string(var f: file): PChar; overload;
function read_string(f: integer): PChar; overload;
function read_int(var f: file): integer;
function read_float(var f: file): single; overload;
function read_float(f: integer): single; overload;
procedure unlink(name: PChar);
function fopen(name: PChar; mode: string): integer; overload;
function fopen(name: PChar; mode: string; var f: file): boolean; overload;
function fopen(name: PChar; mode: string; var t: text): boolean; overload;
function fseek(Handle, Offset, Origin: Integer): Integer;
function C_PChar(const p: pointer; offs: integer): PChar;
procedure FixFileName(name: PChar);

 function ReplaceStrAll(Const S, FromStr, ToStr: string): string;
 function recvfrom_a(s: TSocket; var Buf; len, flags: Integer; from: PSockAddr; fromlen: PInteger): Integer; stdcall;

implementation

function recvfrom_a; external 'wsock32.dll' name 'recvfrom';

procedure sprintf(s: PChar; const Fmt: PChar);
begin
  strcpy(s, Fmt);
//  sprintf(s, Fmt, []);
end;

procedure sprintf(s: PChar; const Fmt: PChar; const Args: array of const);
var
  i: Integer;
begin
  if high(Args) - low(Args) = -1 then
    sprintf(s, Fmt)
  else
    StrFmt(s, Fmt, Args);
  for i := 0 to Length(s) do
    if s[i] = ',' then
      s[i] := '.';
end;

procedure sprintf(s: string; const Fmt: PChar); overload;
begin
  sprintf(PChar(s), Fmt);
end;

procedure sprintf(s: string; const Fmt: PChar; const Args: array of const);
begin
  sprintf(PChar(s), Fmt, Args);
end;

procedure sprintf(s: PChar; const Fmt: string);
begin
  sprintf(s, PChar(Fmt));
end;

procedure sprintf(s: PChar; const Fmt: string; const Args: array of const); overload;
begin
  sprintf(s, PChar(Fmt), Args);
end;

procedure sprintf(s: string; const Fmt: string); overload;
begin
  sprintf(PChar(s), PChar(Fmt));
end;

procedure sprintf(s: string; const Fmt: string; const Args: array of const); overload;
begin
  sprintf(PChar(s), PChar(Fmt), Args);
end;

procedure fprintf(var f: text; const Fmt: PChar);
begin
  fprintf(f, Fmt, []);
end;

procedure fprintf(var f: file; const Fmt: PChar);
begin
  fprintf(f, Fmt, []);
end;

procedure fprintf(f: integer; const Fmt: PChar);
begin
  fprintf(f, Fmt, []);
end;

procedure fprintf(var f: text; const Fmt: PChar; const Args: array of const);
var
  s: string;
begin
  s := Format(Fmt, Args);
  write(f, s);
end;

procedure fprintf(var f: file; const Fmt: PChar; const Args: array of const); overload;
var
  s: string;
  i: integer;
begin
  s := Format(Fmt, Args);
  for i := 1 to Length(s) do
    BlockWrite(f, s[i], 1);
end;

procedure fprintf(f: integer; const Fmt: PChar; const Args: array of const);
var
  s: string;
  i: integer;
begin
  s := Format(Fmt, Args);
  for i := 1 to Length(s) do
    FileWrite(f, s[i], 1);
end;

procedure fprintf(var f: text; const Fmt: string);
begin
  fprintf(f, PChar(fmt));
end;

procedure fprintf(var f: file; const Fmt: string); overload;
begin
  fprintf(f, PChar(fmt));
end;

procedure fprintf(f: integer; const Fmt: string);
begin
  fprintf(f, PChar(fmt));
end;

procedure fprintf(var f: text; const Fmt: string; const Args: array of const); overload;
begin
  fprintf(f, PChar(fmt), Args);
end;

procedure fprintf(var f: file; const Fmt: string; const Args: array of const); overload;
begin
  fprintf(f, PChar(fmt), Args);
end;

procedure fprintf(f: integer; const Fmt: string; const Args: array of const); overload;
begin
  fprintf(f, PChar(fmt), Args);
end;

function itoa(i: integer): string;
begin
  result := IntToStr(i);
end;

function atoi(const s: string): integer;
begin
  result := StrToIntDef(s, 0);
end;

function atoi(const s: PChar): integer;
begin
  result := atoi(StrPas(s));
end;

function StrToFloatDef(const s: string; def: single): single;
var
  code: integer;
begin
  val(s, result, code);
  if code <> 0 then
    result := def;
end;

function atof2(const s: string): single;
var
  s2: string;
  i: Integer;
begin
  s2 := s;
  for i := 1 to length(s2) do
  begin
    if s2[i] in ['.', ','] then
      s2[i] := DecimalSeparator;
  end;
  result := StrToFloatDef(s2, 0.0);
end;

function atof(const s: string): single;
begin
  result := StrToFloatDef(s, 0.0);
end;

function atof(const s: PChar): single; overload;
begin
  result := atof(StrPas(s));
end;

function memcpy(dst: pointer; const src: pointer; len: integer): pointer;
begin
  move(src^, dst^, len);
  result := dst;
end;

function memmove(dst: pointer; const src: pointer; len: integer): pointer;
begin
  move(src^, dst^, len);
  result := dst;
end;

function memset(buf: pointer; c: integer; len: integer): pointer;
begin
  FillChar(buf^, len, c);
  Result := buf;
end;

function malloc(size: integer): Pointer;
begin
  GetMem(Result, size);
  ZeroMemory(Result, size);
end;

procedure free(var p: pointer);
begin
  ReAllocMem(p, 0);
end;

function IntToStrZfill(const z: integer; const x: integer): string;
var
  i: integer;
  len: integer;
begin
  result := IntToStr(x);
  len := Length(result);
  for i := len + 1 to z do
    result := '0' + result;
end;

function boolval(const x: integer): boolean;
begin
  result := x <> 0;
end;

function boolval(const c: char): boolean;
begin
  result := c <> #0;
end;

function boolval(const p: pointer): boolean;
begin
  result := p <> nil;
end;

function boolval(const f: single): boolean; overload;
begin
  result := f <> 0.0;
end;

function intval(const b: boolean): integer;
begin
  if b then
    result := 1
  else
    result := 0;
end;

function floatval(const b: boolean): single;
begin
  if b then
    result := 1.0
  else
    result := 0.0;
end;

function decide(const contition: boolean;
  const iftrue: integer; const iffalse: integer): integer;
begin
  if contition then
    result := iftrue
  else
    result := iffalse;
end;

function decide(const contition: boolean;
  const iftrue: boolean; const iffalse: boolean): boolean;
begin
  if contition then
    result := iftrue
  else
    result := iffalse;
end;

function decide(const contition: boolean;
  const iftrue: string; const iffalse: string): string;
begin
  if contition then
    result := iftrue
  else
    result := iffalse;
end;

function decide(const contition: boolean;
  const iftrue: pointer; const iffalse: pointer): pointer;
begin
  if contition then
    result := iftrue
  else
    result := iffalse;
end;

function decide(const contition: integer;
  const iftrue: integer; const iffalse: integer): integer;
begin
  if contition <> 0 then
    result := iftrue
  else
    result := iffalse;
end;

function decide(const contition: integer;
  const iftrue: boolean; const iffalse: boolean): boolean;
begin
  if contition <> 0 then
    result := iftrue
  else
    result := iffalse;
end;

function decide(const contition: integer;
  const iftrue: string; const iffalse: string): string;
begin
  if contition <> 0 then
    result := iftrue
  else
    result := iffalse;
end;

function decide(const contition: integer;
  const iftrue: pointer; const iffalse: pointer): pointer;
begin
  if contition <> 0 then
    result := iftrue
  else
    result := iffalse;
end;

function fread(buf: pointer; size: integer; count: integer; f: integer): integer;
begin
  result := FileRead(f, buf^, size * count);
  result := result div size;
end;

function fread(buf: pointer; size: integer; count: integer; var f: file): integer;
begin
  BlockRead(f, buf^, size * count, result);
  result := result div size;
end;

function fwrite(buf: pointer; size: integer; count: integer; f: integer): integer;
begin
  result := FileWrite(f, buf^, size * count);
  result := result div size;
end;

function fwrite(buf: pointer; size: integer; count: integer; var f: file): integer;
begin
  BlockWrite(f, buf^, size * count, result);
  result := result div size;
end;

procedure fclose(var f: integer);
begin
  if f <> NULLFILE then
  begin
    FileClose(f);
    f := NULLFILE;
  end;
end;

procedure fclose(var f: file);
begin
  close(f);
end;

procedure fclose(var f: text); overload;
begin
  close(f);
end;

procedure fscanf(var f: text; buf: PChar);
var
  s: string;
begin
  readln(f, s);
  strcpy(buf, PChar(s));
end;

procedure fscanf(var f: text; var num: single);
var
  s: string;
begin
  readln(f, s);
  num := atof(s);
end;

procedure fscanf(var f: text; var num: integer); overload;
var
  s: string;
begin
  readln(f, s);
  num := atoi(s);
end;

function strstr(const _string: PChar; const strCharSet: PChar): PChar;
var
  p: integer;
begin
  if strCharSet = nil then
  begin
    result := _string;
    exit;
  end;

  if strCharSet[0] = #0 then
  begin
    result := _string;
    exit;
  end;

  result := nil;
  p := Pos(StrPas(strCharSet), StrPas(_string));
  if p > 0 then
    result := @_string[p];
end;

function strchr(const _string: PChar; const strChar: char): boolean;
begin
  result := Pos(strChar, StrPas(_string)) > 0;
end;

function getc(f: integer; var c: char): char;
begin
  FileRead(f, c, SizeOf(c));
  result := c;
end;

function getc(var f: file; var c: char): char;
begin
  BlockRead(f, c, SizeOf(c));
  result := c;
end;

function getc(var f: text; var c: char): char;
begin
  read(f, c);
  result := c;
end;

procedure ZeroMemory(X: pointer; Count: Integer);
begin
  FillChar(X^, Count, Chr(0));
end;

const
  RAND_MAX = $7FFF;

var
  holdrand: integer = 0;

function rand: integer;
begin
  holdrand := holdrand * 214013 + 2531011;
  result := holdrand div $FFFF and RAND_MAX;
end;

procedure incp(var p: pointer; const diff: integer);
begin
  p := pointer(integer(p) + diff);
end;

function strncmp(s1, s2: PChar; count: Integer): Integer;
var
  z1, z2: string;
begin
  z1 := s1;
  z2 := s2;
  z1 := Copy(z1, 1, count);
  z2 := Copy(z2, 1, count);
  if z1 > z2 then
    result := -1
  else if z1 < z2 then
    result := 1
  else
    result := 0;
end;

function strnicmp(s1, s2: PChar; count: Integer): Integer;
var
  z1, z2: string;
begin
  z1 := s1;
  z2 := s2;
  z1 := UpperCase(Copy(z1, 1, count));
  z2 := UpperCase(Copy(z2, 1, count));
  if z1 > z2 then
    result := -1
  else if z1 < z2 then
    result := 1
  else
    result := 0;
end;

function strncpy(dest, source: PChar; count: Integer): PChar;
var
  len, i: Integer;
begin
  result := dest;
  len := strlen(source);
  if count <= len then
  begin
    move(source^, dest^, count);
  end
  else
  begin
    for i := 1 to len do
    begin
      dest^ := source^;
      inc(dest);
      inc(source);
      dec(count);
    end;
    for i := 1 to count do
    begin
      dest^ := #0;
      inc(dest);
    end;
  end;
end;

function FileIsOpened(f: integer): boolean; overload;
begin
  result := f >= 0;
end;

function FileIsOpened(var f: file): boolean;
begin
{$I-}
  FilePos(f);
{$I+}
  result := IOResult = 0;
end;

function FileIsOpened(var f: text): boolean; overload;
begin
{$I-}
  FilePos(f);
{$I+}
  result := IOResult = 0;
end;

function boolval(var f: file): boolean;
begin
{$I-}
  FilePos(f);
{$I+}
  result := IOResult = 0;
end;

function isupper(ch: Char): boolean;
begin
  result := (ch >= 'A') and (ch <= 'Z');
end;

function islower(ch: Char): boolean;
begin
  result := (ch >= 'a') and (ch <= 'z');
end;

function isalpha(ch: Char): boolean;
begin
  result := ((ch >= 'A') and (ch <= 'Z')) or
    ((ch >= 'a') and (ch <= 'z'));
end;

function isdigit(ch: Char): boolean;
begin
  result := ch in ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
end;

function toupper(ch: Char): Char;
asm
{ ->    AL      Character       }
{ <-    AL      Result          }

        CMP     AL,'a'
        JB      @@exit
        CMP     AL,'z'
        JA      @@exit
        SUB     AL,'a' - 'A'
@@exit:
end;

function tolower(ch: Char): Char;
asm
{ ->    AL      Character       }
{ <-    AL      Result          }

        CMP     AL,'A'
        JB      @@exit
        CMP     AL,'Z'
        JA      @@exit
        SUB     AL,'A' - 'a'
@@exit:
end;

function strcpy(Dest: PChar; const Source: PChar): PChar; assembler;
asm
        PUSH    EDI
        PUSH    ESI
        MOV     ESI,EAX
        MOV     EDI,EDX
        MOV     ECX,0FFFFFFFFH
        XOR     AL,AL
        REPNE   SCASB
        NOT     ECX
        MOV     EDI,ESI
        MOV     ESI,EDX
        MOV     EDX,ECX
        MOV     EAX,EDI
        SHR     ECX,2
        REP     MOVSD
        MOV     ECX,EDX
        AND     ECX,3
        REP     MOVSB
        POP     ESI
        POP     EDI
end;

function strlen(const Str: PChar): integer; assembler;
asm
        MOV     EDX,EDI
        MOV     EDI,EAX
        MOV     ECX,0FFFFFFFFH
        XOR     AL,AL
        REPNE   SCASB
        MOV     EAX,0FFFFFFFEH
        SUB     EAX,ECX
        MOV     EDI,EDX
end;

function strcmp(const Str1, Str2: PChar): Integer; assembler;
asm
        PUSH    EDI
        PUSH    ESI
        MOV     EDI,EDX
        MOV     ESI,EAX
        MOV     ECX,0FFFFFFFFH
        XOR     EAX,EAX
        REPNE   SCASB
        NOT     ECX
        MOV     EDI,EDX
        XOR     EDX,EDX
        REPE    CMPSB
        MOV     AL,[ESI-1]
        MOV     DL,[EDI-1]
        SUB     EAX,EDX
        POP     ESI
        POP     EDI
end;

function strend(const Str: PChar): PChar; assembler;
asm
        MOV     EDX,EDI
        MOV     EDI,EAX
        MOV     ECX,0FFFFFFFFH
        XOR     AL,AL
        REPNE   SCASB
        LEA     EAX,[EDI-1]
        MOV     EDI,EDX
end;

function strcat(Dest: PChar; const Source: PChar): PChar;
begin
  strcpy(strend(Dest), Source);
  Result := Dest;
end;

function int(const f: single): integer;
begin
  result := round(f);
end;

function uint(const f: single): unsigned_int;
begin
  result := trunc(f);
end;

function fatan(const f: single): single;
begin
  result := arctan(f); // VJ check and optimize this!
end;

function ftan(const f: single): single;
begin
  result := tan(f); // VJ check and optimize this!
end;

function fasin(const f: single): single;
begin
  result := arcsin(f); // VJ check and optimize this!
end;

function fatan2(const y, x: single): Extended; //ArcTan2
asm
              FLD  Y
              FLD  X
              FPATAN
              FWAIT
end;

function fpow(const Base, Exponent: single): single;
begin
  result := power(Base, Exponent); // VJ optimize this!
end;

function floor(x: single): integer;
begin
  Result := Integer(Trunc(X));
  if Frac(X) < 0 then
    Dec(Result);
end;

function ceil(x: single): integer;
begin
  Result := Integer(Trunc(X));
  if Frac(X) > 0 then
    Inc(Result);
end;

const
  WORDBUFSIZE = 1024;

var
  wordbuf: array[0..WORDBUFSIZE - 1] of char;

function read_string(var f: file): PChar;
const
  DELIMETERS: set of char = [#13, #10, ' '];
var
  i: integer;
  c: char;
begin
  c := #0;
  while (c in DELIMETERS) and not eof(f) do
  begin
    BlockRead(f, c, SizeOf(c));
  end;

  if eof(f) then
  begin
    result := nil;
    exit;
  end;

  i := 0;
  while (i < WORDBUFSIZE - 1) and not eof(f) do
  begin
    if not (c in DELIMETERS) then
    begin
      wordbuf[i] := c;
      BlockRead(f, c, SizeOf(c));
    end
    else
    begin
      wordbuf[i] := #0;
      break;
    end;
    inc(i);
  end;
  result := @wordbuf[0];
end;

function read_string(f: integer): PChar;
const
  DELIMETERS: set of char = [#13, #10, ' '];
var
  i: integer;
  c: char;
  numread: integer;
begin
  c := #0;
  numread := SizeOf(c);
  while (c in DELIMETERS) do
  begin
    numread := FileRead(f, c, SizeOf(c));
    if numread <> SizeOf(c) then
      break;
  end;

  if numread <> SizeOf(c) then
  begin
    result := nil;
    exit;
  end;

  i := 0;
  while (i < WORDBUFSIZE - 1) and (numread = SizeOf(c)) do
  begin
    if not (c in DELIMETERS) then
    begin
      wordbuf[i] := c;
      numread := FileRead(f, c, SizeOf(c));
    end
    else
    begin
      wordbuf[i] := #0;
      break;
    end;
    inc(i);
  end;
  result := @wordbuf[0];
end;

function read_int(var f: file): integer;
begin
  result := atoi(read_string(f));
end;

function read_float(var f: file): single;
begin
  result := atof(read_string(f));
end;

function read_float(f: integer): single;
begin
  result := atof(read_string(f));
end;

procedure unlink(name: PChar);
begin
  deletefile(name);
end;

procedure FixFileName(name: PChar);
var
  p: PChar;
begin
  p := name;
  while p^ <> #0 do
  begin
    if p^ = '/' then
      p^ := '\';
    inc(p);
  end;
end;

function fopen(name: PChar; mode: string): integer;
begin
  FixFileName(name);
  if (mode = 'r') or (mode = 'rb') then
    result := FileOpen(name, fmOpenRead or fmShareDenyNone)
  else if (mode = 'w') or (mode = 'wb') then
    result := FileCreate(name)
  else
    result := NULLFILE;
end;

function fopen(name: PChar; mode: string; var f: file): boolean;
begin
  FixFileName(name);
{$I-}
  assign(f, StrPas(name));
  if mode = 'rb' then
    reset(f, 1)
  else if mode = 'wb' then
    rewrite(f, 1)
  else
  begin
    result := false;
    exit;
  end;
{$I+}
  result := IOresult = 0;
end;

function fopen(name: PChar; mode: string; var t: text): boolean;
begin
  FixFileName(name);
{$I-}
  assign(t, StrPas(name));
  if mode = 'r' then
    reset(t)
  else if mode = 'w' then
    rewrite(t)
  else
  begin
    result := false;
    exit;
  end;
{$I+}
  result := IOresult = 0;
end;

function fseek(Handle, Offset, Origin: Integer): Integer;
begin
  result := FileSeek(Handle, Offset, Origin);
end;

function C_PChar(const p: pointer; offs: integer): PChar;
begin
  result := PChar(integer(p) + offs);
end;

 function  ReplaceStrAll(Const S, FromStr, ToStr: string): string;
 var
   I: integer;
 begin
   Result := s;
   while true do
   begin
           I := Pos(FromStr, Result);
           if I > 0 then
           begin
                Delete(Result, I, Length(FromStr));
                Insert(ToStr, Result, I);
           end else exit;
   end;
 end;

end.

