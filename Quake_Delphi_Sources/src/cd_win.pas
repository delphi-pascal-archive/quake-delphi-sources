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
// 
//

unit cd_win;

interface

uses
  Unit_SysTools,
  Windows;

type
  TCDAudio = class
  private
    initialized: boolean;
    enabled: boolean;

    cdvolume: single;
    remap: array[0..99] of byte;
    maxTrack: byte;
    cdValid: boolean;
    playTrack: byte;
    playing: boolean;
    wasPlaying: boolean;
    playLooping: boolean;

    wDeviceID: longword;
    procedure IntFunctions;
    function MessageHandler(_hWnd: HWND; uMsg: longword; _wParam: WPARAM; _lParam: LPARAM): LongInt;
  public
    constructor Create;
    destructor Destroy; override;

    function Init: Integer;
    procedure Shutdown;
    procedure Play(track: byte; looping: boolean);
    procedure Stop;
    procedure Pause;
    procedure Resume;
    procedure Update;
    procedure Eject;
    procedure CloseDoor;
    function GetAudioDiskInfo: integer;
  end;

var
  CDAudio: TCDAudio = nil;

function CDAudio_MessageHandler(_hWnd: HWND; uMsg: longword; _wParam: WPARAM; _lParam: LPARAM): LongInt;

implementation

uses
  common,
  mmsystem,
  console,
  gl_vidnt,
  cmd,
  snd_dma_h,
  cvar,
  cl_main_h,
  client;

procedure CD_IntFunctions;
begin
  CDAudio.IntFunctions;
end;

function CDAudio_MessageHandler(_hWnd: HWND; uMsg: longword; _wParam: WPARAM; _lParam: LPARAM): LongInt;
begin
  Result := CDAudio.MessageHandler(_hWnd, uMsg, _wParam, _lParam);
end;

{ TCDAudio }

constructor TCDAudio.Create;
begin
  inherited;
  cdValid := False;
  initialized := False;
  enabled := False;
  playing := False;
  wasPlaying := False;
  playLooping := False;
end;

destructor TCDAudio.Destroy;
begin

  inherited;
end;

procedure TCDAudio.CloseDoor;
var
  dwReturn: DWORD;
begin
  dwReturn := mciSendCommand(wDeviceID, MCI_SET, MCI_SET_DOOR_CLOSED, DWORD(0));
  if dwReturn <> 0 then
    Con_DPrintf('MCI_SET_DOOR_CLOSED failed (%d)'#10, [dwReturn]);
end;

procedure TCDAudio.Eject;
var
  dwReturn: DWORD;
begin
  dwReturn := mciSendCommand(wDeviceID, MCI_SET, MCI_SET_DOOR_OPEN, DWORD(0));
  if dwReturn <> 0 then
    Con_DPrintf('MCI_SET_DOOR_OPEN failed (%d)'#10, [dwReturn]);
end;

function TCDAudio.Init: Integer;
var
  dwReturn: DWORD;
  mciOpenParms: MCI_OPEN_PARMS;
  mciSetParms: MCI_SET_PARMS;
  n: integer;
begin
  if cls.state = ca_dedicated then
  begin
    result := -1;
    exit;
  end;

  if COM_CheckParm('-nocdaudio') <> 0 then
  begin
    result := -1;
    exit;
  end;

  mciOpenParms.lpstrDeviceType := 'cdaudio';
  dwReturn := mciSendCommand(0, MCI_OPEN, MCI_OPEN_TYPE or MCI_OPEN_SHAREABLE, DWORD(@mciOpenParms));
  if dwReturn <> 0 then
  begin
    Con_Printf('CDAudio_Init: MCI_OPEN failed (%d)'#10, [dwReturn]);
    result := -1;
    exit;
  end;

  wDeviceID := mciOpenParms.wDeviceID;

  // Set the time format to track/minute/second/frame (TMSF).
  mciSetParms.dwTimeFormat := MCI_FORMAT_TMSF;
  dwReturn := mciSendCommand(wDeviceID, MCI_SET, MCI_SET_TIME_FORMAT, DWORD(@mciSetParms));
  if dwReturn <> 0 then
  begin
    Con_Printf('MCI_SET_TIME_FORMAT failed (%d)'#10, [dwReturn]);
    mciSendCommand(wDeviceID, MCI_CLOSE, 0, DWORD(0));
    result := -1;
    exit;
  end;

  for n := 0 to 99 do
    remap[n] := n;
  initialized := true;
  enabled := true;

  if GetAudioDiskInfo <> 0 then
  begin
    Con_Printf('CDAudio_Init: No CD in player.'#10);
    cdValid := false;
  end;

  Cmd_AddCommand('cd', CD_IntFunctions);

  Con_Printf('CD Audio Initialized'#10);

  result := 0;
end;

procedure TCDAudio.Pause;
var
  dwReturn: DWORD;
  mciGenericParms: MCI_GENERIC_PARMS;
begin
  if not enabled then
    exit;

  if not playing then
    exit;

  mciGenericParms.dwCallback := DWORD(mainwindow);
  dwReturn := mciSendCommand(wDeviceID, MCI_PAUSE, 0, DWORD(@mciGenericParms));
  if dwReturn <> 0 then
    Con_DPrintf('MCI_PAUSE failed (%d)'#10, [dwReturn]);

  wasPlaying := playing;
  playing := false;
end;

procedure TCDAudio.Play(track: byte; looping: boolean);
var
  dwReturn: DWORD;
  mciPlayParms: MCI_PLAY_PARMS;
  mciStatusParms: MCI_STATUS_PARMS;
begin
  if not enabled then
    exit;

  if not cdValid then
  begin
    GetAudioDiskInfo;
    if not cdValid then
      exit;
  end;

  track := remap[track];

  if (track < 1) or (track > maxTrack) then
  begin
    Con_DPrintf('CDAudio: Bad track number %d.'#10, [track]);
    exit;
  end;

  // don't try to play a non-audio track
  mciStatusParms.dwItem := MCI_CDA_STATUS_TYPE_TRACK;
  mciStatusParms.dwTrack := track;
  dwReturn := mciSendCommand(wDeviceID, MCI_STATUS, MCI_STATUS_ITEM or MCI_TRACK or MCI_WAIT, DWORD(@mciStatusParms));
  if dwReturn <> 0 then
  begin
    Con_DPrintf('MCI_STATUS failed (%d)'#10, [dwReturn]);
    exit;
  end;
  if (mciStatusParms.dwReturn <> MCI_CDA_TRACK_AUDIO) then
  begin
    Con_Printf('CDAudio: track %d is not audio'#10, [track]);
    exit;
  end;

  // get the length of the track to be played
  mciStatusParms.dwItem := MCI_STATUS_LENGTH;
  mciStatusParms.dwTrack := track;
  dwReturn := mciSendCommand(wDeviceID, MCI_STATUS, MCI_STATUS_ITEM or MCI_TRACK or MCI_WAIT, DWORD(@mciStatusParms));
  if dwReturn <> 0 then
  begin
    Con_DPrintf('MCI_STATUS failed (%d)'#10, [dwReturn]);
    exit;
  end;

  if playing then
  begin
    if playTrack = track then
      exit;
    Stop;
  end;

  mciPlayParms.dwFrom := MCI_MAKE_TMSF(track, 0, 0, 0);
  mciPlayParms.dwTo := (mciStatusParms.dwReturn shl 8) or track;
  mciPlayParms.dwCallback := DWORD(mainwindow);
  dwReturn := mciSendCommand(wDeviceID, MCI_PLAY, MCI_NOTIFY or MCI_FROM or MCI_TO, DWORD(@mciPlayParms));
  if dwReturn <> 0 then
  begin
    Con_DPrintf('CDAudio: MCI_PLAY failed (%d)'#10, [dwReturn]);
    exit;
  end;

  playLooping := looping;
  playTrack := track;
  playing := true;

  if cdvolume = 0.0 then Pause;
end;

procedure TCDAudio.Resume;
var
  dwReturn: DWORD;
  mciPlayParms: MCI_PLAY_PARMS;
begin
  if not enabled then
    exit;

  if not cdValid then
    exit;

  if not wasPlaying then
    exit;

  mciPlayParms.dwFrom := MCI_MAKE_TMSF(playTrack, 0, 0, 0);
  mciPlayParms.dwTo := MCI_MAKE_TMSF(playTrack + 1, 0, 0, 0);
  mciPlayParms.dwCallback := DWORD(mainwindow);
  dwReturn := mciSendCommand(wDeviceID, MCI_PLAY, MCI_TO or MCI_NOTIFY, DWORD(@mciPlayParms));
  if dwReturn <> 0 then
  begin
    Con_DPrintf('CDAudio: MCI_PLAY failed (%d)'#10, [dwReturn]);
    exit;
  end;
  playing := true;
end;

procedure TCDAudio.Shutdown;
begin
  if not initialized then
    exit;

  Stop;
  if mciSendCommand(wDeviceID, MCI_CLOSE, MCI_WAIT, DWORD(0)) <> 0 then
    Con_DPrintf('CDAudio_Shutdown: MCI_CLOSE failed'#10);
end;

procedure TCDAudio.Stop;
var
  dwReturn: DWORD;
begin
  if not enabled then exit;
  if not playing then exit;

  dwReturn := mciSendCommand(wDeviceID, MCI_STOP, 0, DWORD(0));
  if dwReturn <> 0 then
    Con_DPrintf('MCI_STOP failed (%d)'#10, [dwReturn]);

  wasPlaying := false;
  playing := false;
end;

procedure TCDAudio.Update;
begin
  if not enabled then
    exit;

  if bgmvolume.value <> cdvolume then
  begin
    if cdvolume <> 0 then
    begin
      ConsoleVars.SetValue('bgmvolume', 0.0);
      cdvolume := bgmvolume.value;
      Pause;
    end
    else
    begin
      ConsoleVars.SetValue('bgmvolume', 1.0);
      cdvolume := bgmvolume.value;
      Resume;
    end;
  end;
end;

function TCDAudio.GetAudioDiskInfo: integer;
var
  dwReturn: DWORD;
  mciStatusParms: MCI_STATUS_PARMS;
begin
  cdValid := false;

  mciStatusParms.dwItem := MCI_STATUS_READY;
  dwReturn := mciSendCommand(wDeviceID, MCI_STATUS, MCI_STATUS_ITEM or MCI_WAIT, DWORD(@mciStatusParms));
  if dwReturn <> 0 then
  begin
    Con_DPrintf('CDAudio: drive ready test - get status failed'#10);
    result := -1;
    exit;
  end;

  if mciStatusParms.dwReturn = 0 then
  begin
    Con_DPrintf('CDAudio: drive not ready'#10);
    result := -1;
    exit;
  end;

  mciStatusParms.dwItem := MCI_STATUS_NUMBER_OF_TRACKS;
  dwReturn := mciSendCommand(wDeviceID, MCI_STATUS, MCI_STATUS_ITEM or MCI_WAIT, DWORD(@mciStatusParms));
  if dwReturn <> 0 then
  begin
    Con_DPrintf('CDAudio: get tracks - status failed'#10);
    result := -1;
    exit;
  end;

  if mciStatusParms.dwReturn < 1 then
  begin
    Con_DPrintf('CDAudio: no music tracks'#10);
    result := -1;
    exit;
  end;

  cdValid := true;
  maxTrack := mciStatusParms.dwReturn;

  result := 0;
end;

procedure TCDAudio.IntFunctions;
var
  command: PChar;
  ret: integer;
  n: integer;
begin
  if Cmd_Argc_f < 2 then
    exit;

  command := Cmd_Argv_f(1);

  if Q_strcasecmp(command, 'on') = 0 then
  begin
    enabled := true;
    exit;
  end;

  if Q_strcasecmp(command, 'off') = 0 then
  begin
    Stop;
    enabled := false;
    exit;
  end;

  if Q_strcasecmp(command, 'reset') = 0 then
  begin
    enabled := true;
    Stop;
    for n := 0 to 99 do
      remap[n] := n;
    CDAudio.GetAudioDiskInfo;
    exit;
  end;

  if Q_strcasecmp(command, 'remap') = 0 then
  begin
    ret := Cmd_Argc_f - 2;
    if ret <= 0 then
    begin
      for n := 1 to 99 do
        if remap[n] <> n then
          Con_Printf('  %d -> %d'#10, [n, remap[n]]);
      exit;
    end;
    for n := 1 to ret do
      remap[n] := Q_atoi(Cmd_Argv_f(n + 1));
    exit;
  end;

  if Q_strcasecmp(command, 'close') = 0 then
  begin
    CloseDoor;
    exit;
  end;

  if not cdValid then
  begin
    GetAudioDiskInfo;
    if not cdValid then
    begin
      Con_Printf('No CD in player.'#10);
      exit;
    end;
  end;

  if Q_strcasecmp(command, 'play') = 0 then
  begin
    Play(byte(Q_atoi(Cmd_Argv_f(2))), false);
    exit;
  end;

  if Q_strcasecmp(command, 'loop') = 0 then
  begin
    Play(byte(Q_atoi(Cmd_Argv_f(2))), true);
    exit;
  end;

  if Q_strcasecmp(command, 'stop') = 0 then
  begin
    Stop;
    exit;
  end;

  if Q_strcasecmp(command, 'pause') = 0 then
  begin
    Pause;
    exit;
  end;

  if Q_strcasecmp(command, 'resume') = 0 then
  begin
    Resume;
    exit;
  end;

  if Q_strcasecmp(command, 'eject') = 0 then
  begin
    Stop;
    Eject;
    cdValid := false;
    exit;
  end;

  if Q_strcasecmp(command, 'info') = 0 then
  begin
    Con_Printf('%d tracks'#10, [maxTrack]);
    if playing then Con_Printf('Currently %s track %d'#10, [decide(playLooping, 'looping', 'playing'), playTrack])
    else if wasPlaying then
      Con_Printf('Paused %s track %d'#10, [decide(playLooping, 'looping', 'playing'), playTrack]);
    Con_Printf('Volume is %f'#10, [cdvolume]);
    exit;
  end;
end;

function TCDAudio.MessageHandler(_hWnd: HWND; uMsg: longword;
  _wParam: WPARAM; _lParam: LPARAM): LongInt;
begin
  if Cardinal(_lParam) <> wDeviceID then
  begin
    result := 1;
    exit;
  end;

  case _wParam of
    MCI_NOTIFY_SUCCESSFUL:
      begin
        if playing then
        begin
          playing := false;
          if playLooping then
            CDAudio.Play(playTrack, true);
        end;
      end;

    MCI_NOTIFY_ABORTED,
      MCI_NOTIFY_SUPERSEDED:
      begin
      end;

    MCI_NOTIFY_FAILURE:
      begin
        Con_DPrintf('MCI_NOTIFY_FAILURE'#10);
        CDAudio.Stop;
        cdValid := false;
      end;
  else
    begin
      Con_DPrintf('Unexpected MM_MCINOTIFY type (%d)'#10, [_wParam]);
      result := 1;
      exit;
    end;
  end;

  result := 0;
end;

initialization
  CDAudio := TCDAudio.Create;
finalization
  CDAudio.Free;
end.

