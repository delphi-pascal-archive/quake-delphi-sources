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

{$Z4}

unit menu;

//
// the net drivers should just set the apropriate bits in m_activenet,
// instead of having the menu code look through their internal tables
//

interface

uses
  Unit_SysTools,
  wad;

const
  MNET_IPX = 1;
  MNET_TCP = 2;

type
  TMainMenu = class
  private
    procedure ConfigureNetSubsystem;

    procedure SerialConfig_Key(key: integer);
    procedure ModemConfig_Key(key: integer);
    procedure LanConfig_Key(key: integer);
    procedure GameOptions_Key(key: integer);
    procedure Search_Key(key: integer);
    procedure ServerList_Key(k: integer);

    procedure Quit_Key(key: integer);
    procedure Help_Key(key: integer);
    procedure Video_Key(key: integer);
    procedure Keys_Key(k: integer);
    procedure Options_Key(k: integer);
    procedure Net_Key(k: integer);
    procedure Setup_Key(k: integer);
    procedure MultiPlayer_Key(key: integer);
    procedure Save_Key(k: integer);
    procedure Load_Key(k: integer);
    procedure SinglePlayer_Key(key: integer);
    procedure Main_Key(key: integer);

    procedure ServerList_Draw;
    procedure Search_Draw;
    procedure GameOptions_Draw;
    procedure LanConfig_Draw;
    procedure ModemConfig_Draw;
    procedure SerialConfig_Draw;
    procedure Quit_Draw;
    procedure Help_Draw;
    procedure Video_Draw;
    procedure Keys_Draw;
    procedure Options_Draw;
    procedure Net_Draw;
    procedure Setup_Draw;
    procedure MultiPlayer_Draw;
    procedure Save_Draw;
    procedure Load_Draw;
    procedure SinglePlayer_Draw;
    procedure Main_Draw;
  public
    procedure Init;
    procedure Keydown(key: integer);
    procedure Draw;
    procedure DrawPic(x, y: integer; pic: Pqpic_t);

    procedure Print(cx, cy: integer; str: PChar);
    procedure PrintWhite(cx, cy: integer; str: PChar);
  end;

var
  MainMenu: TMainMenu;

procedure M_ToggleMenu_f;
procedure M_Menu_Quit_f;
procedure M_Menu_Main_f;
procedure M_Menu_Options_f;

type
  state_t = (
    m_none,
    m_main,
    m_singleplayer,
    m_load,
    m_save,
    m_multiplayer,
    m_setup,
    m_net,
    m_options,
    m_video,
    m_keys,
    m_help,
    m_quit,
    m_serialconfig,
    m_modemconfig,
    m_lanconfig,
    m_gameoptions,
    m_search,
    m_slist
    );

var
  m_state: state_t;
  m_return_state: state_t;
  m_return_onerror: qboolean;
  m_return_reason: array[0..31] of char;

var
  vid_menudrawfn: procedure;
  vid_menukeyfn: procedure(i: integer);

implementation

uses
  quakedef,
  net_main,
  gl_draw,
  gl_vidnt,
  render_h,
  keys,
  keys_h,
  console,
  cl_main,
  cl_main_h,
  host_h,
  common,
  client,
  snd_dma,
  sv_main,
  gl_screen,
  cmd,
  cvar,
  view,
  snd_dma_h,
  cl_input,
  host_cmd,
  net;

const
  MAIN_ITEMS = 5;
  SINGLEPLAYER_ITEMS = 3;
  MAX_SAVEGAMES = 12;
  NUM_SETUP_CMDS = 5;
  MULTIPLAYER_ITEMS = 3;
  OPTIONS_ITEMS = 14;
  SLIDER_RANGE = 10;
  NUMCOMMANDS = 18;
  NUM_HELP_PAGES = 6;
  NUM_GAMEOPTIONS = 9;
  NUM_LANCONFIG_CMDS = 3;

const
  lanConfig_cursor_table: array[0..NUM_LANCONFIG_CMDS - 1] of integer = (72, 92, 124);
  net_helpMessage: array[0..15] of PChar =
  (
//   .........1.........2....
    '',
    ' Two computers connected',
    '   through two modems.',
    '',

    '',
    ' Two computers connected',
    ' by a null-modem cable.',
    '',

    ' Novell network LANs',
    ' or Windows 95 DOS-box.',
    '',
    '(LAN=Local Area Network)',

    ' Commonly used to play',
    ' over the Internet, but',
    ' also used on a Local',
    ' Area Network.'
    );

  bindnames: array[0..NUMCOMMANDS - 1, 0..1] of PChar = (
    ('+attack', 'attack'),
    ('impulse 10', 'change weapon'),
    ('+jump', 'jump / swim up'),
    ('+forward', 'walk forward'),
    ('+back', 'backpedal'),
    ('+left', 'turn left'),
    ('+right', 'turn right'),
    ('+speed', 'run'),
    ('+moveleft', 'step left'),
    ('+moveright', 'step right'),
    ('+strafe', 'sidestep'),
    ('+lookup', 'look up'),
    ('+lookdown', 'look down'),
    ('centerview', 'center view'),
    ('+mlook', 'mouse look'),
    ('+klook', 'keyboard look'),
    ('+moveup', 'swim up'),
    ('+movedown', 'swim down')
    );

var
  searchComplete: qboolean = false;
  searchCompleteTime: double;

var
  m_filenames: array[0..MAX_SAVEGAMES - 1] of array[0..SAVEGAME_COMMENT_LENGTH] of char;
  loadable: array[0..MAX_SAVEGAMES - 1] of qboolean;
  m_main_cursor: integer;
  m_singleplayer_cursor: integer;
  load_cursor: integer; // 0 < load_cursor < MAX_SAVEGAMES
  options_cursor: integer;
  keys_cursor: integer;
  gameoptions_cursor: integer;
  lanConfig_cursor: integer = -1;

  bind_grab: qboolean;

  identityTable: array[0..255] of byte;
  translationTable: array[0..255] of byte;

  m_entersound: qboolean = false;
  m_recursiveDraw: qboolean;
  m_multiplayer_cursor: integer;
  m_net_cursor: integer;
  m_save_demonum: integer;

  setup_cursor: integer = 4;
  setup_cursor_table: array[0..4] of integer = (40, 56, 80, 104, 140);

  setup_hostname: array[0..15] of char;
  setup_myname: array[0..15] of char;
  setup_oldtop: integer;
  setup_oldbottom: integer;
  setup_top: integer;
  setup_bottom: integer;

  m_net_items: integer;
  slist_cursor: integer;
  slist_sorted: qboolean;
  lanConfig_port: integer;
  lanConfig_portname: array[0..5] of char;
  lanConfig_joinname: array[0..21] of char;
  help_page: integer;
  msgNumber: integer;
  m_quit_prevstate: state_t;
  wasInMenus: qboolean;
  startepisode: integer;
  startlevel: integer;
  maxplayers: integer;
  m_serverInfoMessage: qboolean = false;
  m_serverInfoMessageTime: double;

type
  level_t = record
    name: PChar;
    description: PChar;
  end;

const
  levels: array[0..37] of level_t = (

    (name: 'start'; description: 'Entrance'), // 0

    (name: 'e1m1'; description: 'Slipgate Complex'), // 1
    (name: 'e1m2'; description: 'Castle of the Damned'),
    (name: 'e1m3'; description: 'The Necropolis'),
    (name: 'e1m4'; description: 'The Grisly Grotto'),
    (name: 'e1m5'; description: 'Gloom Keep'),
    (name: 'e1m6'; description: 'The Door To Chthon'),
    (name: 'e1m7'; description: 'The House of Chthon'),
    (name: 'e1m8'; description: 'Ziggurat Vertigo'),

    (name: 'e2m1'; description: 'The Installation'), // 9
    (name: 'e2m2'; description: 'Ogre Citadel'),
    (name: 'e2m3'; description: 'Crypt of Decay'),
    (name: 'e2m4'; description: 'The Ebon Fortress'),
    (name: 'e2m5'; description: 'The Wizard''s Manse'),
    (name: 'e2m6'; description: 'The Dismal Oubliette'),
    (name: 'e2m7'; description: 'Underearth'),

    (name: 'e3m1'; description: 'Termination Central'), // 16
    (name: 'e3m2'; description: 'The Vaults of Zin'),
    (name: 'e3m3'; description: 'The Tomb of Terror'),
    (name: 'e3m4'; description: 'Satan''s Dark Delight'),
    (name: 'e3m5'; description: 'Wind Tunnels'),
    (name: 'e3m6'; description: 'Chambers of Torment'),
    (name: 'e3m7'; description: 'The Haunted Halls'),

    (name: 'e4m1'; description: 'The Sewage System'), // 23
    (name: 'e4m2'; description: 'The Tower of Despair'),
    (name: 'e4m3'; description: 'The Elder God Shrine'),
    (name: 'e4m4'; description: 'The Palace of Hate'),
    (name: 'e4m5'; description: 'Hell''s Atrium'),
    (name: 'e4m6'; description: 'The Pain Maze'),
    (name: 'e4m7'; description: 'Azure Agony'),
    (name: 'e4m8'; description: 'The Nameless City'),

    (name: 'end'; description: 'Shub-Niggurath''s Pit'), // 31

    (name: 'dm1'; description: 'Place of Two Deaths'), // 32
    (name: 'dm2'; description: 'Claustrophobopolis'),
    (name: 'dm3'; description: 'The Abandoned Base'),
    (name: 'dm4'; description: 'The Bad Place'),
    (name: 'dm5'; description: 'The Cistern'),
    (name: 'dm6'; description: 'The Dark Zone')
    );

//MED 01/06/97 added hipnotic levels
  hipnoticlevels: array[0..17] of level_t = (

    (name: 'start'; description: 'Command HQ'), // 0

    (name: 'hip1m1'; description: 'The Pumping Station'), // 1
    (name: 'hip1m2'; description: 'Storage Facility'),
    (name: 'hip1m3'; description: 'The Lost Mine'),
    (name: 'hip1m4'; description: 'Research Facility'),
    (name: 'hip1m5'; description: 'Military Complex'),

    (name: 'hip2m1'; description: 'Ancient Realms'), // 6
    (name: 'hip2m2'; description: 'The Black Cathedral'),
    (name: 'hip2m3'; description: 'The Catacombs'),
    (name: 'hip2m4'; description: 'The Crypt'),
    (name: 'hip2m5'; description: 'Mortum''s Keep'),
    (name: 'hip2m6'; description: 'The Gremlin''s Domain'),

    (name: 'hip3m1'; description: 'Tur Torment'), // 12
    (name: 'hip3m2'; description: 'Pandemonium'),
    (name: 'hip3m3'; description: 'Limbo'),
    (name: 'hip3m4'; description: 'The Gauntlet'),

    (name: 'hipend'; description: 'Armagon''s Lair'), // 16

    (name: 'hipdm1'; description: 'The Edge of Oblivion') // 17
    );

//PGM 01/07/97 added rogue levels
//PGM 03/02/97 added dmatch level
  roguelevels: array[0..16] of level_t = (

    (name: 'start'; description: 'Split Decision'),
    (name: 'r1m1'; description: 'Deviant''s Domain'),
    (name: 'r1m2'; description: 'Dread Portal'),
    (name: 'r1m3'; description: 'Judgement Call'),
    (name: 'r1m4'; description: 'Cave of Death'),
    (name: 'r1m5'; description: 'Towers of Wrath'),
    (name: 'r1m6'; description: 'Temple of Pain'),
    (name: 'r1m7'; description: 'Tomb of the Overlord'),
    (name: 'r2m1'; description: 'Tempus Fugit'),
    (name: 'r2m2'; description: 'Elemental Fury I'),
    (name: 'r2m3'; description: 'Elemental Fury II'),
    (name: 'r2m4'; description: 'Curse of Osiris'),
    (name: 'r2m5'; description: 'Wizard''s Keep'),
    (name: 'r2m6'; description: 'Blood Sacrifice'),
    (name: 'r2m7'; description: 'Last Bastion'),
    (name: 'r2m8'; description: 'Source of Evil'),
    (name: 'ctf1'; description: 'Division of Change')
    );

type
  episode_t = record
    description: PChar;
    firstLevel: integer;
    levels: integer;
  end;

const
  episodes: array[0..6] of episode_t = (
    (description: 'Welcome to Quake'; firstLevel: 0; levels: 1),
    (description: 'Doomed Dimension'; firstLevel: 1; levels: 8),
    (description: 'Realm of Black Magic'; firstLevel: 9; levels: 7),
    (description: 'Netherworld'; firstLevel: 16; levels: 7),
    (description: 'The Elder World'; firstLevel: 23; levels: 8),
    (description: 'Final Level'; firstLevel: 31; levels: 1),
    (description: 'Deathmatch Arena'; firstLevel: 32; levels: 6)
    );

const
//MED 01/06/97  added hipnotic episodes
  hipnoticepisodes: array[0..5] of episode_t = (
    (description: 'Scourge of Armagon'; firstLevel: 0; levels: 1),
    (description: 'Fortress of the Dead'; firstLevel: 1; levels: 5),
    (description: 'Dominion of Darkness'; firstLevel: 6; levels: 6),
    (description: 'The Rift'; firstLevel: 12; levels: 4),
    (description: 'Final Level'; firstLevel: 16; levels: 1),
    (description: 'Deathmatch Arena'; firstLevel: 17; levels: 1)
    );

const
//PGM 01/07/97 added rogue episodes
//PGM 03/02/97 added dmatch episode
  rogueepisodes: array[0..3] of episode_t = (
    (description: 'Introduction'; firstLevel: 0; levels: 1),
    (description: 'Hell''s Fortress'; firstLevel: 1; levels: 7),
    (description: 'Corridors of Time'; firstLevel: 8; levels: 8),
    (description: 'Deathmatch Arena'; firstLevel: 16; levels: 1)
    );

const
  gameoptions_cursor_table: array[0..NUM_GAMEOPTIONS - 1] of integer =
  (40, 56, 64, 72, 80, 88, 96, 112, 120);

function StartingGame: boolean;
begin
  result := m_multiplayer_cursor = 1
end;

function JoiningGame: boolean;
begin
  result := m_multiplayer_cursor = 0;
end;

function SerialConfig: boolean;
begin
  result := m_net_cursor = 0;
end;

function DirectConfig: boolean;
begin
  result := m_net_cursor = 1;
end;

function IPXConfig: boolean;
begin
  result := m_net_cursor = 2;
end;

function TCPIPConfig: boolean;
begin
  result := m_net_cursor = 3
end;

procedure M_DrawCharacter(cx: integer; line: integer; num: integer);
begin
  Draw_Character(cx + ((vid.width - 320) div 2), line, num);
end;

procedure M_DrawTransPic(x, y: integer; pic: Pqpic_t);
begin
  Draw_TransPic(x + ((vid.width - 320) div 2), y, pic);
end;

procedure M_BuildTranslationTable(top, bottom: integer);
var
  j: integer;
  dest, source: PByteArray;
begin
  for j := 0 to 255 do
    identityTable[j] := j;
  dest := @translationTable;
  source := @identityTable;
  memcpy(dest, source, 256);

  if top < 128 then // the artists made some backwards ranges.  sigh.
    memcpy(@dest[TOP_RANGE], @source[top], 16)
  else
    for j := 0 to 15 do
      dest[TOP_RANGE + j] := source[top + 15 - j];

  if bottom < 128 then
    memcpy(@dest[BOTTOM_RANGE], @source[bottom], 16)
  else
    for j := 0 to 15 do
      dest[BOTTOM_RANGE + j] := source[bottom + 15 - j];
end;

procedure M_DrawTransPicTranslate(x, y: integer; pic: Pqpic_t);
begin
  Draw_TransPicTranslate(x + ((vid.width - 320) div 2), y, pic, @translationTable);
end;

procedure M_DrawTextBox(x, y: integer; width: integer; lines: integer);
var
  p: Pqpic_t;
  cx, cy: integer;
  n: integer;
begin
  // draw left side
  cx := x;
  cy := y;
  p := Draw_CachePic('gfx/box_tl.lmp');
  M_DrawTransPic(cx, cy, p);
  p := Draw_CachePic('gfx/box_ml.lmp');
  for n := 0 to lines - 1 do
  begin
    inc(cy, 8);
    M_DrawTransPic(cx, cy, p);
  end;
  p := Draw_CachePic('gfx/box_bl.lmp');
  M_DrawTransPic(cx, cy + 8, p);

  // draw middle
  inc(cx, 8);
  while width > 0 do
  begin
    cy := y;
    p := Draw_CachePic('gfx/box_tm.lmp');
    M_DrawTransPic(cx, cy, p);
    p := Draw_CachePic('gfx/box_mm.lmp');
    for n := 0 to lines - 1 do
    begin
      inc(cy, 8);
      if n = 1 then
        p := Draw_CachePic('gfx/box_mm2.lmp');
      M_DrawTransPic(cx, cy, p);
    end;
    p := Draw_CachePic('gfx/box_bm.lmp');
    M_DrawTransPic(cx, cy + 8, p);
    dec(width, 2);
    inc(cx, 16);
  end;

  // draw right side
  cy := y;
  p := Draw_CachePic('gfx/box_tr.lmp');
  M_DrawTransPic(cx, cy, p);
  p := Draw_CachePic('gfx/box_mr.lmp');
  for n := 0 to lines - 1 do
  begin
    inc(cy, 8);
    M_DrawTransPic(cx, cy, p);
  end;
  p := Draw_CachePic('gfx/box_br.lmp');
  M_DrawTransPic(cx, cy + 8, p);
end;

procedure M_ToggleMenu_f;
begin
  m_entersound := true;

  if key_dest = key_menu then
  begin
    if m_state <> m_main then
    begin
      M_Menu_Main_f;
      exit;
    end;
    key_dest := key_game;
    m_state := m_none;
    exit;
  end;
  if key_dest = key_console then
    Con_ToggleConsole_f
  else
    M_Menu_Main_f
end;

procedure M_Menu_Main_f;
begin
  if key_dest <> key_menu then
  begin
    m_save_demonum := cls.demonum;
    cls.demonum := -1;
  end;
  key_dest := key_menu;
  m_state := m_main;
  m_entersound := true;
end;

procedure M_Menu_SinglePlayer_f;
begin
  key_dest := key_menu;
  m_state := m_singleplayer;
  m_entersound := true;
end;

procedure M_ScanSaves;
var
  i, j: integer;
  name: array[0..MAX_OSPATH - 1] of char;
  f: text;
  version: integer;
begin
  for i := 0 to MAX_SAVEGAMES - 1 do
  begin
    strcpy(m_filenames[i], '--- UNUSED SLOT ---');
    loadable[i] := false;
    sprintf(name, '%s/s%d.sav', [com_gamedir, i]);
    if fopen(name, 'r', f) then
    begin
      fscanf(f, version);
      fscanf(f, name);
      strncpy(m_filenames[i], name, SizeOf(m_filenames[i]) - 1);

    // change _ back to space
      for j := 0 to SAVEGAME_COMMENT_LENGTH - 1 do
        if m_filenames[i][j] = '_' then
          m_filenames[i][j] := ' ';
      loadable[i] := true;
      fclose(f);
    end;
  end;
end;

procedure M_Menu_Load_f;
begin
  m_entersound := true;
  m_state := m_load;
  key_dest := key_menu;
  M_ScanSaves;
end;

procedure M_Menu_Save_f;
begin
  if not sv.active then
    exit;
  if cl.intermission <> 0 then
    exit;
  if svs.maxclients <> 1 then
    exit;
  m_entersound := true;
  m_state := m_save;
  key_dest := key_menu;
  M_ScanSaves;
end;

procedure M_LoadSave_Draw(pic: PChar);
var
  i: integer;
  p: Pqpic_t;
begin
  p := Draw_CachePic(pic);
  MainMenu.DrawPic((320 - p.width) div 2, 4, p);

  for i := 0 to MAX_SAVEGAMES - 1 do
    MainMenu.Print(16, 32 + 8 * i, m_filenames[i]);

// line cursor
  M_DrawCharacter(8, 32 + load_cursor * 8, 12 + (int(realtime * 4) and 1));
end;

procedure M_Menu_MultiPlayer_f;
begin
  key_dest := key_menu;
  m_state := m_multiplayer;
  m_entersound := true;
end;

procedure M_Menu_Setup_f;
begin
  key_dest := key_menu;
  m_state := m_setup;
  m_entersound := true;
  Q_strcpy(setup_myname, cl_name.text);
  Q_strcpy(setup_hostname, hostname.text);
  setup_oldtop := int(cl_color.value) div 16;
  setup_top := setup_oldtop;
  setup_oldbottom := int(cl_color.value) and 15;
  setup_bottom := setup_oldbottom;
end;

procedure M_Menu_Net_f;
begin
  key_dest := key_menu;
  m_state := m_net;
  m_entersound := true;
  m_net_items := 4;

  if m_net_cursor >= m_net_items then
    m_net_cursor := 0;
  dec(m_net_cursor);
  MainMenu.Net_Key(K_DOWNARROW);
end;

procedure M_Menu_Options_f;
begin
  key_dest := key_menu;
  m_state := m_options;
  m_entersound := true;

//#ifdef _WIN32
  if (options_cursor = 13) and (modestate <> MS_WINDOWED) then
    options_cursor := 0;
//#endif
end;

procedure M_AdjustSliders(dir: integer);
begin
  S_LocalSound('misc/menu3.wav');

  case options_cursor of
    3: // screen size
      begin
        scr_viewsize.value := scr_viewsize.value + dir * 10;
        if scr_viewsize.value < 30 then
          scr_viewsize.value := 30;
        if scr_viewsize.value > 120 then
          scr_viewsize.value := 120;
        ConsoleVars.SetValue('viewsize', scr_viewsize.value);
      end;
    4: // gamma
      begin
        v_gamma.value := v_gamma.value - dir * 0.05;
        if v_gamma.value < 0.5 then
          v_gamma.value := 0.5;
        if v_gamma.value > 1 then
          v_gamma.value := 1;
        ConsoleVars.SetValue('gamma', v_gamma.value);
      end;
    5: // mouse speed
      begin
        sensitivity.value := sensitivity.value + dir * 0.5;
        if sensitivity.value < 1 then
          sensitivity.value := 1;
        if sensitivity.value > 11 then
          sensitivity.value := 11;
        ConsoleVars.SetValue('sensitivity', sensitivity.value);
      end;
    6: // music volume
      begin
//#ifdef _WIN32
        bgmvolume.value := bgmvolume.value + dir * 1.0;
(*
#else
    bgmvolume.value += dir * 0.1;
#endif
*)
        if bgmvolume.value < 0 then
          bgmvolume.value := 0;
        if bgmvolume.value > 1 then
          bgmvolume.value := 1;
        ConsoleVars.SetValue('bgmvolume', bgmvolume.value);
      end;
    7: // sfx volume
      begin
        volume.value := volume.value + dir * 0.1;
        if volume.value < 0 then
          volume.value := 0;
        if volume.value > 1 then
          volume.value := 1;
        ConsoleVars.SetValue('volume', volume.value);
      end;

    8: // allways run
      begin
        if cl_forwardspeed.value > 200 then
        begin
          ConsoleVars.SetValue('cl_forwardspeed', 200);
          ConsoleVars.SetValue('cl_backspeed', 200);
        end
        else
        begin
          ConsoleVars.SetValue('cl_forwardspeed', 400);
          ConsoleVars.SetValue('cl_backspeed', 400);
        end;
      end;

    9: // invert mouse
      begin
        ConsoleVars.SetValue('m_pitch', -m_pitch.value);
      end;

    10: // lookspring
      begin
        ConsoleVars.SetValue('lookspring', not boolval(lookspring.value));
      end;

    11: // lookstrafe
      begin
        ConsoleVars.SetValue('lookstrafe', not boolval(lookstrafe.value));
      end;

//#ifdef _WIN32
    13: // _windowed_mouse
      begin
        ConsoleVars.SetValue('_windowed_mouse', not boolval(_windowed_mouse.value));
      end;
//#endif
  end;
end;

procedure M_DrawSlider(x, y: integer; range: single);
var
  i: integer;
begin
  if range < 0 then
    range := 0;
  if range > 1 then
    range := 1;
  M_DrawCharacter(x - 8, y, 128);
  i := 0;
  while i < SLIDER_RANGE do
  begin
    M_DrawCharacter(x + i * 8, y, 129);
    inc(i);
  end;
  M_DrawCharacter(x + i * 8, y, 130);
  M_DrawCharacter(x + int((SLIDER_RANGE - 1) * 8 * range), y, 131);
end;

procedure M_DrawCheckbox(x, y: integer; _on: boolean); overload;
begin
  if _on then MainMenu.Print(x, y, 'on')
  else MainMenu.Print(x, y, 'off');
end;

procedure M_DrawCheckbox(x, y: integer; _on: single); overload;
begin
  M_DrawCheckbox(x, y, boolval(_on));
end;

procedure M_Menu_Keys_f;
begin
  key_dest := key_menu;
  m_state := m_keys;
  m_entersound := true;
end;

procedure M_FindKeysForCommand(command: PChar; twokeys: PIntegerArray);
var
  count: integer;
  j: integer;
  l: integer;
  b: PChar;
begin
  twokeys[0] := -1;
  twokeys[1] := -1;
  l := strlen(command);
  count := 0;

  for j := 0 to 255 do
  begin
    b := keybindings[j];
    if b = nil then
      continue;
    if strncmp(b, command, l) = 0 then
    begin
      twokeys[count] := j;
      inc(count);
      if count = 2 then
        break;
    end;
  end;
end;

procedure M_UnbindCommand(command: PChar);
var
  j: integer;
  l: integer;
  b: PChar;
begin
  l := strlen(command);

  for j := 0 to 255 do
  begin
    b := keybindings[j];
    if b = nil then
      continue;
    if not boolval(strncmp(b, command, l)) then
      Key_SetBinding(j, '');
  end;
end;

procedure M_Menu_Video_f;
begin
  key_dest := key_menu;
  m_state := m_video;
  m_entersound := true;
end;

procedure M_Menu_Help_f;
begin
  key_dest := key_menu;
  m_state := m_help;
  m_entersound := true;
  help_page := 0;
end;

procedure M_Menu_Quit_f;
begin
  if m_state = m_quit then
    exit;
  wasInMenus := key_dest = key_menu;
  key_dest := key_menu;
  m_quit_prevstate := m_state;
  m_state := m_quit;
  m_entersound := true;
  msgNumber := rand and 7;
end;

procedure M_Menu_SerialConfig_f;
begin
end;

procedure M_Menu_LanConfig_f;
begin
  key_dest := key_menu;
  m_state := m_lanconfig;
  m_entersound := true;
  if lanConfig_cursor = -1 then
  begin
    if JoiningGame and TCPIPConfig then
      lanConfig_cursor := 2
    else
      lanConfig_cursor := 1;
  end;
  if StartingGame and (lanConfig_cursor = 2) then
    lanConfig_cursor := 1;
  lanConfig_port := DEFAULTnet_hostport;
  sprintf(lanConfig_portname, '%u', [lanConfig_port]);

  m_return_onerror := false;
  m_return_reason[0] := #0;
end;

procedure M_Menu_GameOptions_f;
begin
  key_dest := key_menu;
  m_state := m_gameoptions;
  m_entersound := true;
  if maxplayers = 0 then
    maxplayers := svs.maxclients;
  if maxplayers < 2 then
    maxplayers := svs.maxclientslimit;
end;

procedure M_NetStart_Change(dir: integer);
var
  count: integer;
begin
  case gameoptions_cursor of
    1:
      begin
        inc(maxplayers, dir);
        if maxplayers > svs.maxclientslimit then
        begin
          maxplayers := svs.maxclientslimit;
          m_serverInfoMessage := true;
          m_serverInfoMessageTime := realtime;
        end;
        if maxplayers < 2 then
          maxplayers := 2;
      end;

    2:
      begin
        ConsoleVars.SetValue('coop', Decide(boolval(coop.value), 0, 1));
      end;

    3:
      begin
        if rogue then
          count := 6
        else
          count := 2;

        ConsoleVars.SetValue('teamplay', teamplay.value + dir);
        if teamplay.value > count then ConsoleVars.SetValue('teamplay', 0)
        else if teamplay.value < 0 then ConsoleVars.SetValue('teamplay', count);
      end;

    4:
      begin
        ConsoleVars.SetValue('skill', skill.value + dir);
        if skill.value > 3 then ConsoleVars.SetValue('skill', 0);
        if skill.value < 0 then ConsoleVars.SetValue('skill', 3);
      end;

    5:
      begin
        ConsoleVars.SetValue('fraglimit', fraglimit.value + dir * 10);
        if fraglimit.value > 100 then ConsoleVars.SetValue('fraglimit', 0);
        if fraglimit.value < 0 then ConsoleVars.SetValue('fraglimit', 100);
      end;

    6:
      begin
        ConsoleVars.SetValue('timelimit', timelimit.value + dir * 5);
        if timelimit.value > 60 then ConsoleVars.SetValue('timelimit', 0);
        if timelimit.value < 0 then ConsoleVars.SetValue('timelimit', 60);
      end;

    7:
      begin
        inc(startepisode, dir);
      //MED 01/06/97 added hipnotic count
        if hipnotic then
          count := 6
      //PGM 01/07/97 added rogue count
      //PGM 03/02/97 added 1 for dmatch episode
        else if rogue then
          count := 4
        else if registered.value <> 0 then
          count := 7
        else
          count := 2;

        if startepisode < 0 then
          startepisode := count - 1;

        if startepisode >= count then
          startepisode := 0;

        startlevel := 0;
      end;

    8:
      begin
        inc(startlevel, dir);
        //MED 01/06/97 added hipnotic episodes
        if hipnotic then
          count := hipnoticepisodes[startepisode].levels
      //PGM 01/06/97 added hipnotic episodes
        else if rogue then
          count := rogueepisodes[startepisode].levels
        else
          count := episodes[startepisode].levels;

        if startlevel < 0 then
          startlevel := count - 1;

        if startlevel >= count then
          startlevel := 0;
      end;
  end;
end;

procedure M_Menu_Search_f;
begin
  key_dest := key_menu;
  m_state := m_search;
  m_entersound := false;
  slistSilent := true;
  slistLocal := false;
  searchComplete := false;
  NET_Slist_f;
end;

procedure M_Menu_ServerList_f;
begin
  key_dest := key_menu;
  m_state := m_slist;
  m_entersound := true;
  slist_cursor := 0;
  m_return_onerror := false;
  m_return_reason[0] := #0;
  slist_sorted := false;
end;

{ TMainMenu }

procedure TMainMenu.ConfigureNetSubsystem;
begin
  Cbuf_AddText('stopdemo'#10);
  if IPXConfig or TCPIPConfig then
    net_hostport := lanConfig_port;
end;

procedure TMainMenu.Draw;
begin
  if (m_state = m_none) or (key_dest <> key_menu) then
    exit;

  if not m_recursiveDraw then
  begin
    scr_copyeverything := true;

    if boolval(scr_con_current) then
    begin
      Draw_ConsoleBackground(vid.height);
      VID_UnlockBuffer;
      S_ExtraUpdate;
      VID_LockBuffer;
    end
    else
      Draw_FadeScreen;

    scr_fullupdate := 0;
  end
  else
    m_recursiveDraw := false;

  case m_state of
    m_none: ;
    m_main: Main_Draw;
    m_singleplayer: SinglePlayer_Draw;
    m_load: Load_Draw;
    m_save: Save_Draw;
    m_multiplayer: MultiPlayer_Draw;
    m_setup: Setup_Draw;
    m_net: Net_Draw;
    m_options: Options_Draw;
    m_keys: Keys_Draw;
    m_video: Video_Draw;
    m_help: Help_Draw;
    m_quit: Quit_Draw;
    m_serialconfig: SerialConfig_Draw;
    m_modemconfig: ModemConfig_Draw;
    m_lanconfig: LanConfig_Draw;
    m_gameoptions: GameOptions_Draw;
    m_search: Search_Draw;
    m_slist: ServerList_Draw;
  end;

  if m_entersound then
  begin
    S_LocalSound('misc/menu2.wav');
    m_entersound := false;
  end;

  VID_UnlockBuffer;
  S_ExtraUpdate;
  VID_LockBuffer;
end;

procedure TMainMenu.DrawPic(x, y: integer; pic: Pqpic_t);
begin
  Draw_Pic(x + ((vid.width - 320) div 2), y, pic);
end;

procedure TMainMenu.GameOptions_Draw;
var
  p: Pqpic_t;
  x: integer;
  msg: PChar;
begin
  M_DrawTransPic(16, 4, Draw_CachePic('gfx/qplaque.lmp'));
  p := Draw_CachePic('gfx/p_multi.lmp');
  MainMenu.DrawPic((320 - p.width) div 2, 4, p);

  M_DrawTextBox(152, 32, 10, 1);
  MainMenu.Print(160, 40, 'begin game');

  MainMenu.Print(0, 56, '      Max players');
  MainMenu.Print(160, 56, va('%d', [maxplayers]));

  MainMenu.Print(0, 64, '        Game Type');
  if boolval(coop.value) then MainMenu.Print(160, 64, 'Cooperative')
  else MainMenu.Print(160, 64, 'Deathmatch');

  MainMenu.Print(0, 72, '        Teamplay');
  if rogue then
  begin

    case int(teamplay.value) of
      1: msg := 'No Friendly Fire';
      2: msg := 'Friendly Fire';
      3: msg := 'Tag';
      4: msg := 'Capture the Flag';
      5: msg := 'One Flag CTF';
      6: msg := 'Three Team CTF';
    else
      msg := 'Off';
    end;
    MainMenu.Print(160, 72, msg);

  end
  else
  begin

    case int(teamplay.value) of
      1: msg := 'No Friendly Fire';
      2: msg := 'Friendly Fire';
    else
      msg := 'Off';
    end;
    MainMenu.Print(160, 72, msg);

  end;

  MainMenu.Print(0, 80, '            Skill');
  if skill.value = 0 then MainMenu.Print(160, 80, 'Easy difficulty')
  else if skill.value = 1 then MainMenu.Print(160, 80, 'Normal difficulty')
  else if skill.value = 2 then MainMenu.Print(160, 80, 'Hard difficulty')
  else MainMenu.Print(160, 80, 'Nightmare difficulty');

  MainMenu.Print(0, 88, '       Frag Limit');
  if fraglimit.value = 0 then MainMenu.Print(160, 88, 'none')
  else MainMenu.Print(160, 88, va('%d frags', [int(fraglimit.value)]));

  MainMenu.Print(0, 96, '       Time Limit');
  if timelimit.value = 0 then MainMenu.Print(160, 96, 'none')
  else MainMenu.Print(160, 96, va('%d minutes', [int(timelimit.value)]));
  MainMenu.Print(0, 112, '         Episode');
   //MED 01/06/97 added hipnotic episodes
  if hipnotic then MainMenu.Print(160, 112, hipnoticepisodes[startepisode].description)
   //PGM 01/07/97 added rogue episodes
  else if rogue then MainMenu.Print(160, 112, rogueepisodes[startepisode].description)
  else MainMenu.Print(160, 112, episodes[startepisode].description);

  MainMenu.Print(0, 120, '           Level');
   //MED 01/06/97 added hipnotic episodes
  if hipnotic then
  begin
    MainMenu.Print(160, 120, hipnoticlevels[hipnoticepisodes[startepisode].firstLevel + startlevel].description);
    MainMenu.Print(160, 128, hipnoticlevels[hipnoticepisodes[startepisode].firstLevel + startlevel].name);
  end
   //PGM 01/07/97 added rogue episodes
  else if rogue then
  begin
    MainMenu.Print(160, 120, roguelevels[rogueepisodes[startepisode].firstLevel + startlevel].description);
    MainMenu.Print(160, 128, roguelevels[rogueepisodes[startepisode].firstLevel + startlevel].name);
  end
  else
  begin
    MainMenu.Print(160, 120, levels[episodes[startepisode].firstLevel + startlevel].description);
    MainMenu.Print(160, 128, levels[episodes[startepisode].firstLevel + startlevel].name);
  end;

// line cursor
  M_DrawCharacter(144, gameoptions_cursor_table[gameoptions_cursor], 12 + (int(realtime * 4) and 1));

  if m_serverInfoMessage then
  begin
    if realtime - m_serverInfoMessageTime < 5.0 then
    begin
      x := (320 - 26 * 8) div 2;
      M_DrawTextBox(x, 138, 24, 4);
      inc(x, 8);
      MainMenu.Print(x, 146, '  More than 4 players   ');
      MainMenu.Print(x, 154, ' requires using command ');
      MainMenu.Print(x, 162, 'line parameters; please ');
      MainMenu.Print(x, 170, '   see techinfo.txt.    ');
    end
    else
    begin
      m_serverInfoMessage := false;
    end
  end;
end;

procedure TMainMenu.GameOptions_Key(key: integer);
begin
  case key of
    K_ESCAPE:
      begin
        M_Menu_Net_f;
      end;

    K_UPARROW:
      begin
        S_LocalSound('misc/menu1.wav');
        dec(gameoptions_cursor);
        if gameoptions_cursor < 0 then
          gameoptions_cursor := NUM_GAMEOPTIONS - 1;
      end;

    K_DOWNARROW:
      begin
        S_LocalSound('misc/menu1.wav');
        inc(gameoptions_cursor);
        if gameoptions_cursor >= NUM_GAMEOPTIONS then
          gameoptions_cursor := 0;
      end;

    K_LEFTARROW:
      begin
        if gameoptions_cursor <> 0 then
        begin
          S_LocalSound('misc/menu3.wav');
          M_NetStart_Change(-1);
        end;
      end;

    K_RIGHTARROW:
      begin
        if gameoptions_cursor <> 0 then
        begin
          S_LocalSound('misc/menu3.wav');
          M_NetStart_Change(1);
        end;
      end;

    K_ENTER:
      begin
        S_LocalSound('misc/menu2.wav');
        if gameoptions_cursor = 0 then
        begin
          if sv.active then
            Cbuf_AddText('disconnect'#10);
          Cbuf_AddText('listen 0'#10); // so host_netport will be re-examined
          Cbuf_AddText(va('maxplayers %u'#10, [maxplayers]));
          SCR_BeginLoadingPlaque;

          if hipnotic then
            Cbuf_AddText(va('map %s'#10, [hipnoticlevels[hipnoticepisodes[startepisode].firstLevel + startlevel].name]))
          else if rogue then
            Cbuf_AddText(va('map %s'#10, [roguelevels[rogueepisodes[startepisode].firstLevel + startlevel].name]))
          else
            Cbuf_AddText(va('map %s'#10, [levels[episodes[startepisode].firstLevel + startlevel].name]));
        end
        else
          M_NetStart_Change(1);
      end;
  end;
end;

procedure TMainMenu.Help_Draw;
begin
  MainMenu.DrawPic(0, 0, Draw_CachePic(va('gfx/help%d.lmp', [help_page])));
end;

procedure TMainMenu.Help_Key(key: integer);
begin
  case key of
    K_ESCAPE:
      begin
        M_Menu_Main_f;
      end;

    K_UPARROW,
      K_RIGHTARROW:
      begin
        m_entersound := true;
        inc(help_page);
        if help_page >= NUM_HELP_PAGES then
          help_page := 0;
      end;

    K_DOWNARROW,
      K_LEFTARROW:
      begin
        m_entersound := true;
        dec(help_page);
        if help_page < 0 then
          help_page := NUM_HELP_PAGES - 1;
      end;
  end;
end;

procedure TMainMenu.Init;
begin
  Cmd_AddCommand('togglemenu', M_ToggleMenu_f);

  Cmd_AddCommand('menu_main', M_Menu_Main_f);
  Cmd_AddCommand('menu_singleplayer', M_Menu_SinglePlayer_f);
  Cmd_AddCommand('menu_load', M_Menu_Load_f);
  Cmd_AddCommand('menu_save', M_Menu_Save_f);
  Cmd_AddCommand('menu_multiplayer', M_Menu_MultiPlayer_f);
  Cmd_AddCommand('menu_setup', M_Menu_Setup_f);
  Cmd_AddCommand('menu_options', M_Menu_Options_f);
  Cmd_AddCommand('menu_keys', M_Menu_Keys_f);
  Cmd_AddCommand('menu_video', M_Menu_Video_f);
  Cmd_AddCommand('help', M_Menu_Help_f);
  Cmd_AddCommand('menu_quit', M_Menu_Quit_f);
end;

procedure TMainMenu.Keydown(key: integer);
begin
  case m_state of
    m_none: ;
    m_main: Main_Key(key);
    m_singleplayer: SinglePlayer_Key(key);
    m_load: Load_Key(key);
    m_save: Save_Key(key);
    m_multiplayer: MultiPlayer_Key(key);
    m_setup: Setup_Key(key);
    m_net: Net_Key(key);
    m_options: Options_Key(key);
    m_keys: Keys_Key(key);
    m_video: Video_Key(key);
    m_help: Help_Key(key);
    m_quit: Quit_Key(key);
    m_serialconfig: SerialConfig_Key(key);
    m_modemconfig: ModemConfig_Key(key);
    m_lanconfig: LanConfig_Key(key);
    m_gameoptions: GameOptions_Key(key);
    m_search: Search_Key(key);
    m_slist: ServerList_Key(key);
  end;
end;

procedure TMainMenu.Keys_Draw;
var
  i: integer;
  keys: array[0..1] of integer;
  name: PChar;
  x, y: integer;
  p: Pqpic_t;
begin
  p := Draw_CachePic('gfx/ttl_cstm.lmp');
  MainMenu.DrawPic((320 - p.width) div 2, 4, p);

  if bind_grab then MainMenu.Print(12, 32, 'Press a key or button for this action')
  else MainMenu.Print(18, 32, 'Enter to change, backspace to clear');

// search for known bindings
  for i := 0 to NUMCOMMANDS - 1 do
  begin
    y := 48 + 8 * i;

    MainMenu.Print(16, y, bindnames[i][1]);

    M_FindKeysForCommand(bindnames[i][0], @keys);

    if keys[0] = -1 then
    begin
      MainMenu.Print(140, y, '???');
    end
    else
    begin
      name := Key_KeynumToString(keys[0]);
      MainMenu.Print(140, y, name);
      x := strlen(name) * 8;
      if keys[1] <> -1 then
      begin
        MainMenu.Print(140 + x + 8, y, 'or');
        MainMenu.Print(140 + x + 32, y, Key_KeynumToString(keys[1]));
      end;
    end;
  end;

  if bind_grab then
    M_DrawCharacter(130, 48 + keys_cursor * 8, Ord('='))
  else
    M_DrawCharacter(130, 48 + keys_cursor * 8, 12 + (int(realtime * 4) and 1));
end;

procedure TMainMenu.Keys_Key(k: integer);
var
  cmd: array[0..79] of char;
  keys: array[0..1] of integer;
begin
  if bind_grab then
  begin // defining a key
    S_LocalSound('misc/menu1.wav');
    if k = K_ESCAPE then
      bind_grab := false
    else if k <> Ord('`') then
    begin
      sprintf(cmd, 'bind "%s" "%s'#10, [Key_KeynumToString(k), bindnames[keys_cursor][0]]);
      Cbuf_InsertText(cmd);
    end;

    bind_grab := false;
    exit;
  end;

  case k of
    K_ESCAPE:
      begin
        M_Menu_Options_f;
      end;

    K_LEFTARROW,
      K_UPARROW:
      begin
        S_LocalSound('misc/menu1.wav');
        dec(keys_cursor);
        if keys_cursor < 0 then
          keys_cursor := NUMCOMMANDS - 1;
      end;

    K_DOWNARROW,
      K_RIGHTARROW:
      begin
        S_LocalSound('misc/menu1.wav');
        inc(keys_cursor);
        if keys_cursor >= NUMCOMMANDS then
          keys_cursor := 0;
      end;

    K_ENTER: // go into bind mode
      begin
        M_FindKeysForCommand(bindnames[keys_cursor][0], @keys);
        S_LocalSound('misc/menu2.wav');
        if keys[1] <> -1 then
          M_UnbindCommand(bindnames[keys_cursor][0]);
        bind_grab := true;
      end;

    K_BACKSPACE, // delete bindings
      K_DEL: // delete bindings
      begin
        S_LocalSound('misc/menu2.wav');
        M_UnbindCommand(bindnames[keys_cursor][0]);
      end;
  end;
end;

procedure TMainMenu.LanConfig_Draw;
var
  p: Pqpic_t;
  basex: integer;
  startJoin: PChar;
  protocol: PChar;
begin
  M_DrawTransPic(16, 4, Draw_CachePic('gfx/qplaque.lmp'));
  p := Draw_CachePic('gfx/p_multi.lmp');
  basex := (320 - p.width) div 2;
  MainMenu.DrawPic(basex, 4, p);

  if StartingGame then startJoin := 'New Game'
  else startJoin := 'Join Game';
  if IPXConfig then protocol := 'IPX'
  else protocol := 'TCP/IP';

  MainMenu.Print(basex, 32, va('%s - %s', [startJoin, protocol]));
  inc(basex, 8);

  MainMenu.Print(basex, 52, 'Address:');
  if IPXConfig then MainMenu.Print(basex + 9 * 8, 52, my_ipx_address)
  else MainMenu.Print(basex + 9 * 8, 52, my_tcpip_address);

  MainMenu.Print(basex, lanConfig_cursor_table[0], 'Port');
  M_DrawTextBox(basex + 8 * 8, lanConfig_cursor_table[0] - 8, 6, 1);
  MainMenu.Print(basex + 9 * 8, lanConfig_cursor_table[0], lanConfig_portname);

  if JoiningGame then
  begin
    MainMenu.Print(basex, lanConfig_cursor_table[1], 'Search for local games...');
    MainMenu.Print(basex, 108, 'Join game at:');
    M_DrawTextBox(basex + 8, lanConfig_cursor_table[2] - 8, 22, 1);
    MainMenu.Print(basex + 16, lanConfig_cursor_table[2], lanConfig_joinname);
  end
  else
  begin
    M_DrawTextBox(basex, lanConfig_cursor_table[1] - 8, 2, 1);
    MainMenu.Print(basex + 8, lanConfig_cursor_table[1], 'OK');
  end;

  M_DrawCharacter(basex - 8, lanConfig_cursor_table[lanConfig_cursor], 12 + (int(realtime * 4) and 1));

  if lanConfig_cursor = 0 then
    M_DrawCharacter(basex + 9 * 8 + 8 * strlen(lanConfig_portname), lanConfig_cursor_table[0], 10 + (int(realtime * 4) and 1));

  if lanConfig_cursor = 2 then
    M_DrawCharacter(basex + 16 + 8 * strlen(lanConfig_joinname), lanConfig_cursor_table[2], 10 + (int(realtime * 4) and 1));

  if m_return_reason[0] <> #0 then
    MainMenu.PrintWhite(basex, 148, m_return_reason);
end;

procedure TMainMenu.LanConfig_Key(key: integer);
label
  break1;
var
  l: integer;
begin
  case key of
    K_ESCAPE:
      begin
        M_Menu_Net_f;
      end;

    K_UPARROW:
      begin
        S_LocalSound('misc/menu1.wav');
        dec(lanConfig_cursor);
        if lanConfig_cursor < 0 then
          lanConfig_cursor := NUM_LANCONFIG_CMDS - 1;
      end;

    K_DOWNARROW:
      begin
        S_LocalSound('misc/menu1.wav');
        inc(lanConfig_cursor);
        if lanConfig_cursor >= NUM_LANCONFIG_CMDS then
          lanConfig_cursor := 0;
      end;

    K_ENTER:
      begin
        if lanConfig_cursor > 0 then
        begin
          m_entersound := true;

          ConfigureNetSubsystem;

          if lanConfig_cursor = 1 then
          begin
            if StartingGame then
            begin
              M_Menu_GameOptions_f;
              goto break1;
            end;
            M_Menu_Search_f;
            goto break1;
          end;

          if lanConfig_cursor = 2 then
          begin
            m_return_state := m_state;
            m_return_onerror := true;
            key_dest := key_game;
            m_state := m_none;
            Cbuf_AddText(va('connect "%s"'#10, [lanConfig_joinname]));
          end;
        end;
      end;
    K_BACKSPACE:
      begin
        if lanConfig_cursor = 0 then
        begin
          l := strlen(lanConfig_portname);
          if l > 0 then
            lanConfig_portname[l - 1] := #0;
        end;

        if lanConfig_cursor = 2 then
        begin
          l := strlen(lanConfig_joinname);
          if l > 0 then
            lanConfig_joinname[l - 1] := #0;
        end;
      end;

  else
    begin
      if (key < 32) or (key > 127) then
        goto break1;

      if lanConfig_cursor = 2 then
      begin
        l := strlen(lanConfig_joinname);
        if l < 21 then
        begin
          lanConfig_joinname[l + 1] := #0;
          lanConfig_joinname[l] := Chr(key);
        end;
      end;

      if (key < Ord('0')) or (key > Ord('9')) then
        goto break1;

      if lanConfig_cursor = 0 then
      begin
        l := strlen(lanConfig_portname);
        if l < 5 then
        begin
          lanConfig_portname[l + 1] := #0;
          lanConfig_portname[l] := Chr(key);
        end;
      end;

    end;
  end;

  break1:

  if StartingGame and (lanConfig_cursor = 2) then
  begin
    if key = K_UPARROW then // VJ check this!
      lanConfig_cursor := 1
    else
      lanConfig_cursor := 0;
  end;

  l := Q_atoi(lanConfig_portname);
  if l <= 65535 then
    lanConfig_port := l;
  sprintf(lanConfig_portname, '%u', [lanConfig_port]);
end;

procedure TMainMenu.Load_Draw;
begin
  M_LoadSave_Draw('gfx/p_load.lmp');
end;

procedure TMainMenu.Load_Key(k: integer);
begin
  case k of
    K_ESCAPE:
      begin
        M_Menu_SinglePlayer_f;
      end;

    K_ENTER:
      begin
        S_LocalSound('misc/menu2.wav');
        if not loadable[load_cursor] then
          exit;
        m_state := m_none;
        key_dest := key_game;

  // Host_Loadgame_f can't bring up the loading plaque because too much
  // stack space has been used, so do it now
        SCR_BeginLoadingPlaque;

  // issue the load command
        Cbuf_AddText(va('load s%d'#10, [load_cursor]));
      end;

    K_UPARROW,
      K_LEFTARROW:
      begin
        S_LocalSound('misc/menu1.wav');
        dec(load_cursor);
        if load_cursor < 0 then
          load_cursor := MAX_SAVEGAMES - 1;
      end;

    K_DOWNARROW,
      K_RIGHTARROW:
      begin
        S_LocalSound('misc/menu1.wav');
        inc(load_cursor);
        if load_cursor >= MAX_SAVEGAMES then
          load_cursor := 0;
      end;
  end;
end;

procedure TMainMenu.Main_Draw;
var
  f: integer;
  p: Pqpic_t;
begin
  M_DrawTransPic(16, 4, Draw_CachePic('gfx/qplaque.lmp'));
  p := Draw_CachePic('gfx/ttl_main.lmp');
  MainMenu.DrawPic((320 - p.width) div 2, 4, p);
  M_DrawTransPic(72, 32, Draw_CachePic('gfx/mainmenu.lmp'));

  f := int(host_time * 10) mod 6;

  M_DrawTransPic(54, 32 + m_main_cursor * 20, Draw_CachePic(va('gfx/menudot%d.lmp', [f + 1])));
end;

procedure TMainMenu.Main_Key(key: integer);
begin
  case key of
    K_ESCAPE:
      begin
        key_dest := key_game;
        m_state := m_none;
        cls.demonum := m_save_demonum;
        if (cls.demonum <> -1) and (not cls.demoplayback) and (cls.state <> ca_connected) then
          ClientMain.NextDemo;
      end;

    K_DOWNARROW:
      begin
        S_LocalSound('misc/menu1.wav');
        inc(m_main_cursor); // VJ check this (++)
        if m_main_cursor >= MAIN_ITEMS then
          m_main_cursor := 0;
      end;

    K_UPARROW:
      begin
        S_LocalSound('misc/menu1.wav');
        dec(m_main_cursor); // VJ check (--)
        if m_main_cursor < 0 then
          m_main_cursor := MAIN_ITEMS - 1;
      end;

    K_ENTER:
      begin
        m_entersound := true;

        case m_main_cursor of
          0: M_Menu_SinglePlayer_f;
          1: M_Menu_MultiPlayer_f;
          2: M_Menu_Options_f;
          3: M_Menu_Help_f;
          4: M_Menu_Quit_f;
        end;

      end;
  end;
end;

procedure TMainMenu.ModemConfig_Draw;
begin
  MainMenu.Print(320 - 10, 32, 'unavailable...');
end;

procedure TMainMenu.ModemConfig_Key(key: integer);
begin

end;

procedure TMainMenu.MultiPlayer_Draw;
var
  f: integer;
  p: Pqpic_t;
begin
  M_DrawTransPic(16, 4, Draw_CachePic('gfx/qplaque.lmp'));
  p := Draw_CachePic('gfx/p_multi.lmp');
  MainMenu.DrawPic((320 - p.width) div 2, 4, p);
  M_DrawTransPic(72, 32, Draw_CachePic('gfx/mp_menu.lmp'));

  f := int(host_time * 10) mod 6;

  M_DrawTransPic(54, 32 + m_multiplayer_cursor * 20, Draw_CachePic(va('gfx/menudot%d.lmp', [f + 1])));

  if serialAvailable or ipxAvailable or tcpipAvailable then
    exit;
  MainMenu.PrintWhite((320 div 2) - ((27 * 8) div 2), 148, 'No Communications Available');
end;

procedure TMainMenu.MultiPlayer_Key(key: integer);
begin
  case key of
    K_ESCAPE:
      begin
        M_Menu_Main_f;
      end;

    K_DOWNARROW:
      begin
        S_LocalSound('misc/menu1.wav');
        inc(m_multiplayer_cursor); // VJ check!
        if m_multiplayer_cursor >= MULTIPLAYER_ITEMS then
          m_multiplayer_cursor := 0;
      end;

    K_UPARROW:
      begin
        S_LocalSound('misc/menu1.wav');
        dec(m_multiplayer_cursor); // VJ check!
        if m_multiplayer_cursor < 0 then
          m_multiplayer_cursor := MULTIPLAYER_ITEMS - 1;
      end;

    K_ENTER:
      begin
        m_entersound := true;
        case m_multiplayer_cursor of
          0: // VJ mayby 0, 1: // same code for 0 and 1
            begin
              if serialAvailable or ipxAvailable or tcpipAvailable then
                M_Menu_Net_f;
            end;

          1:
            begin
              if serialAvailable or ipxAvailable or tcpipAvailable then
                M_Menu_Net_f;
            end;

          2:
            begin
              M_Menu_Setup_f;
            end;
        end;
      end;
  end;
end;

procedure TMainMenu.Net_Draw;
var
  f: integer;
  p: Pqpic_t;
  i: integer;
begin
  M_DrawTransPic(16, 4, Draw_CachePic('gfx/qplaque.lmp'));
  p := Draw_CachePic('gfx/p_multi.lmp');
  MainMenu.DrawPic((320 - p.width) div 2, 4, p);

  f := 32;

  if serialAvailable then
  begin
    p := Draw_CachePic('gfx/netmen1.lmp');
  end
  else
  begin
//#ifdef _WIN32
    p := nil;
//#else
//    p = Draw_CachePic ("gfx/dim_modm.lmp");
//#endif
  end;

  if p <> nil then
    M_DrawTransPic(72, f, p);

  inc(f, 19);

  if serialAvailable then
  begin
    p := Draw_CachePic('gfx/netmen2.lmp');
  end
  else
  begin
//#ifdef _WIN32
    p := nil;
//#else
//    p = Draw_CachePic ("gfx/dim_drct.lmp");
//#endif
  end;

  if p <> nil then
    M_DrawTransPic(72, f, p);

  inc(f, 19);
  if ipxAvailable then
    p := Draw_CachePic('gfx/netmen3.lmp')
  else
    p := Draw_CachePic('gfx/dim_ipx.lmp');
  M_DrawTransPic(72, f, p);

  inc(f, 19);
  if tcpipAvailable then
    p := Draw_CachePic('gfx/netmen4.lmp')
  else
    p := Draw_CachePic('gfx/dim_tcp.lmp');
  M_DrawTransPic(72, f, p);

  if m_net_items = 5 then // JDC, could just be removed
  begin
    inc(f, 19);
    p := Draw_CachePic('gfx/netmen5.lmp');
    M_DrawTransPic(72, f, p);
  end;

  f := (320 - 26 * 8) div 2;
  M_DrawTextBox(f, 134, 24, 4);
  inc(f, 8);

  for i := 0 to 3 do
    MainMenu.Print(f, 142 + i * 8, net_helpMessage[m_net_cursor * 4 + i]);

{  M_Print(f, 142, PChar(net_helpMessage[m_net_cursor * 4 + 0])); // VJ may a loop
  M_Print(f, 150, PChar(net_helpMessage[m_net_cursor * 4 + 1]));
  M_Print(f, 158, PChar(net_helpMessage[m_net_cursor * 4 + 2]));
  M_Print(f, 166, PChar(net_helpMessage[m_net_cursor * 4 + 3]));}

  f := int(host_time * 10) mod 6;
  M_DrawTransPic(54, 32 + m_net_cursor * 20, Draw_CachePic(va('gfx/menudot%d.lmp', [f + 1])));
end;

procedure TMainMenu.Net_Key(k: integer);
label
  again;
begin
  again:
  case k of
    K_ESCAPE:
      begin
        M_Menu_MultiPlayer_f;
      end;

    K_DOWNARROW:
      begin
        S_LocalSound('misc/menu1.wav');
        inc(m_net_cursor); // VJ check ++
        if m_net_cursor >= m_net_items then m_net_cursor := 0;
      end;

    K_UPARROW:
      begin
        S_LocalSound('misc/menu1.wav');
        dec(m_net_cursor); // VJ check
        if m_net_cursor < 0 then m_net_cursor := m_net_items - 1;
      end;

    K_ENTER:
      begin
        m_entersound := true;

        case m_net_cursor of
          0: M_Menu_SerialConfig_f;
          1: M_Menu_SerialConfig_f;
          2: M_Menu_LanConfig_f;
          3: M_Menu_LanConfig_f;
        end;

      end;
  end;

  if (m_net_cursor = 0) and not serialAvailable then goto again;
  if (m_net_cursor = 1) and not serialAvailable then goto again;
  if (m_net_cursor = 2) and not ipxAvailable then goto again;
  if (m_net_cursor = 3) and not tcpipAvailable then goto again;
end;

procedure TMainMenu.Options_Draw;
var
  r: single;
  p: Pqpic_t;
begin
  M_DrawTransPic(16, 4, Draw_CachePic('gfx/qplaque.lmp'));
  p := Draw_CachePic('gfx/p_option.lmp');
  MainMenu.DrawPic((320 - p.width) div 2, 4, p);

  MainMenu.Print(16, 32, '    Customize controls');
  MainMenu.Print(16, 40, '         Go to console');
  MainMenu.Print(16, 48, '     Reset to defaults');

  MainMenu.Print(16, 56, '           Screen size');
  r := (scr_viewsize.value - 30) / (120 - 30);
  M_DrawSlider(220, 56, r);

  MainMenu.Print(16, 64, '            Brightness');
  r := (1.0 - v_gamma.value) / 0.5;
  M_DrawSlider(220, 64, r);

  MainMenu.Print(16, 72, '           Mouse Speed');
  r := (sensitivity.value - 1) / 10;
  M_DrawSlider(220, 72, r);

  MainMenu.Print(16, 80, '       CD Music Volume');
  r := bgmvolume.value;
  M_DrawSlider(220, 80, r);

  MainMenu.Print(16, 88, '          Sound Volume');
  r := volume.value;
  M_DrawSlider(220, 88, r);

  MainMenu.Print(16, 96, '            Always Run');
  M_DrawCheckbox(220, 96, cl_forwardspeed.value > 200);

  MainMenu.Print(16, 104, '          Invert Mouse');
  M_DrawCheckbox(220, 104, m_pitch.value < 0);

  MainMenu.Print(16, 112, '            Lookspring');
  M_DrawCheckbox(220, 112, lookspring.value);

  MainMenu.Print(16, 120, '            Lookstrafe');
  M_DrawCheckbox(220, 120, lookstrafe.value);

  if Assigned(vid_menudrawfn) then
    MainMenu.Print(16, 128, '         Video Options');

//#ifdef _WIN32
  if modestate = MS_WINDOWED then
  begin
    MainMenu.Print(16, 136, '             Use Mouse');
    M_DrawCheckbox(220, 136, _windowed_mouse.value);
  end;
//#endif

// cursor
  M_DrawCharacter(200, 32 + options_cursor * 8, 12 + (int(realtime * 4) and 1));
end;

procedure TMainMenu.Options_Key(k: integer);
begin
  case k of
    K_ESCAPE:
      begin
        M_Menu_Main_f;
      end;

    K_ENTER:
      begin
        m_entersound := true;
        case options_cursor of
          0:
            begin
              M_Menu_Keys_f;
            end;

          1:
            begin
              m_state := m_none;
              Con_ToggleConsole_f;
            end;
          2:
            begin
              Cbuf_AddText('exec default.cfg'#10);
            end;
          12:
            begin
              M_Menu_Video_f;
            end;
        else
          M_AdjustSliders(1);
        end;
        exit;
      end;

    K_UPARROW:
      begin
        S_LocalSound('misc/menu1.wav');
        dec(options_cursor);
        if options_cursor < 0 then
          options_cursor := OPTIONS_ITEMS - 1;
      end;

    K_DOWNARROW:
      begin
        S_LocalSound('misc/menu1.wav');
        inc(options_cursor);
        if options_cursor >= OPTIONS_ITEMS then
          options_cursor := 0;
      end;

    K_LEFTARROW:
      begin
        M_AdjustSliders(-1);
      end;

    K_RIGHTARROW:
      begin
        M_AdjustSliders(1);
      end;

  end;

  if (options_cursor = 12) and not Assigned(vid_menudrawfn) then
  begin
    if k = K_UPARROW then
      options_cursor := 11
    else
      options_cursor := 0;
  end;

//#ifdef _WIN32
  if (options_cursor = 13) and (modestate <> MS_WINDOWED) then
  begin
    if k = K_UPARROW then
      options_cursor := 12
    else
      options_cursor := 0;
  end;
//#endif
end;

procedure TMainMenu.Print(cx, cy: integer; str: PChar);
begin
  while str^ <> #0 do
  begin
    M_DrawCharacter(cx, cy, Ord(str^) + 128);
    inc(str);
    inc(cx, 8);
  end;
end;

procedure TMainMenu.PrintWhite(cx, cy: integer; str: PChar);
begin
  while str^ <> #0 do
  begin
    M_DrawCharacter(cx, cy, Ord(str^));
    inc(str);
    inc(cx, 8);
  end;
end;

procedure TMainMenu.Quit_Draw;
begin
  if wasInMenus then
  begin
    m_state := m_quit_prevstate;
    m_recursiveDraw := true;
    MainMenu.Draw;
    m_state := m_quit;
  end;

//#ifdef _WIN32
  M_DrawTextBox(0, 0, 38, 23);
  MainMenu.PrintWhite(16, 12, '  Quake version 1.09 by id Software'#10#10);
  MainMenu.PrintWhite(16, 28, 'Programming        Art '#10);
  MainMenu.Print(16, 36, ' John Carmack       Adrian Carmack'#10);
  MainMenu.Print(16, 44, ' Michael Abrash     Kevin Cloud'#10);
  MainMenu.Print(16, 52, ' John Cash          Paul Steed'#10);
  MainMenu.Print(16, 60, ' Dave ''Zoid'' Kirsch'#10);
  MainMenu.PrintWhite(16, 68, 'Design             Biz'#10);
  MainMenu.Print(16, 76, ' John Romero        Jay Wilbur'#10);
  MainMenu.Print(16, 84, ' Sandy Petersen     Mike Wilson'#10);
  MainMenu.Print(16, 92, ' American McGee     Donna Jackson'#10);
  MainMenu.Print(16, 100, ' Tim Willits        Todd Hollenshead'#10);
  MainMenu.PrintWhite(16, 108, 'Support            Projects'#10);
  MainMenu.Print(16, 116, ' Barrett Alexander  Shawn Green'#10);
  MainMenu.PrintWhite(16, 124, 'Sound Effects'#10);
  MainMenu.Print(16, 132, ' Trent Reznor and Nine Inch Nails'#10#10);
  MainMenu.PrintWhite(16, 140, 'Quake is a trademark of Id Software,'#10);
  MainMenu.PrintWhite(16, 148, 'inc.,(c)1996 Id Software, inc. All'#10);
  MainMenu.PrintWhite(16, 156, 'rights reserved. NIN logo is a'#10);
  MainMenu.PrintWhite(16, 164, 'registered trademark licensed to'#10);
  MainMenu.PrintWhite(16, 172, 'Nothing Interactive, Inc. All rights'#10);
  MainMenu.PrintWhite(16, 180, 'reserved. Press y to exit'#10);
(*
#else
  M_DrawTextBox (56, 76, 24, 4);
  M_Print (64, 84,  quitMessage[msgNumber*4+0]);
  M_Print (64, 92,  quitMessage[msgNumber*4+1]);
  M_Print (64, 100, quitMessage[msgNumber*4+2]);
  M_Print (64, 108, quitMessage[msgNumber*4+3]);
#endif
*)
end;

procedure TMainMenu.Quit_Key(key: integer);
begin
  case key of
    K_ESCAPE,
      Ord('n'),
      Ord('N'):
      begin
        if wasInMenus then
        begin
          m_state := m_quit_prevstate;
          m_entersound := true;
        end
        else
        begin
          key_dest := key_game;
          m_state := m_none;
        end;
      end;

    Ord('Y'),
      Ord('y'):
      begin
        key_dest := key_console;
        Host_Quit_f;
      end;
  end;
end;

procedure TMainMenu.Save_Draw;
begin
  M_LoadSave_Draw('gfx/p_save.lmp');
end;

procedure TMainMenu.Save_Key(k: integer);
begin
  case k of
    K_ESCAPE:
      begin
        M_Menu_SinglePlayer_f;
      end;

    K_ENTER:
      begin
        m_state := m_none;
        key_dest := key_game;
        Cbuf_AddText(va('save s%d'#10, [load_cursor]));
      end;

    K_UPARROW,
      K_LEFTARROW:
      begin
        S_LocalSound('misc/menu1.wav');
        dec(load_cursor);
        if load_cursor < 0 then
          load_cursor := MAX_SAVEGAMES - 1;
      end;

    K_DOWNARROW,
      K_RIGHTARROW:
      begin
        S_LocalSound('misc/menu1.wav');
        inc(load_cursor);
        if load_cursor >= MAX_SAVEGAMES then
          load_cursor := 0;
      end;
  end;
end;

procedure TMainMenu.Search_Draw;
var
  p: Pqpic_t;
  x: integer;
begin
  p := Draw_CachePic('gfx/p_multi.lmp');
  MainMenu.DrawPic((320 - p.width) div 2, 4, p);
  x := (320 div 2) - ((12 * 8) div 2) + 4;
  M_DrawTextBox(x - 8, 32, 12, 1);
  MainMenu.Print(x, 40, 'Searching...');

  if slistInProgress then
  begin
    NET_Poll;
    exit;
  end;

  if not searchComplete then
  begin
    searchComplete := true;
    searchCompleteTime := realtime;
  end;

  if boolval(hostCacheCount) then
  begin
    M_Menu_ServerList_f;
    exit;
  end;

  MainMenu.PrintWhite((320 div 2) - ((22 * 8) div 2), 64, 'No Quake servers found');
  if (realtime - searchCompleteTime) < 3.0 then
    exit;

  M_Menu_LanConfig_f;
end;

procedure TMainMenu.Search_Key(key: integer);
begin

end;

procedure TMainMenu.SerialConfig_Draw;
begin
  MainMenu.Print(320 - 10, 32, 'unavailable...');
end;

procedure TMainMenu.SerialConfig_Key(key: integer);
begin

end;

procedure TMainMenu.ServerList_Draw;
var
  n: integer;
  str: array[0..63] of char;
  p: Pqpic_t;
  i, j: integer;
  temp: hostcache_t;
begin
  if not slist_sorted then
  begin
    if hostCacheCount > 1 then
    begin
      for i := 0 to hostCacheCount - 1 do
        for j := i + 1 to hostCacheCount - 1 do
          if strcmp(hostcache[j].name, hostcache[i].name) < 0 then
          begin
            Q_memcpy(@temp, @hostcache[j], SizeOf(hostcache_t));
            Q_memcpy(@hostcache[j], @hostcache[i], SizeOf(hostcache_t));
            Q_memcpy(@hostcache[i], @temp, SizeOf(hostcache_t));
          end;
    end;
    slist_sorted := true;
  end;

  p := Draw_CachePic('gfx/p_multi.lmp');
  MainMenu.DrawPic((320 - p.width) div 2, 4, p);
  for n := 0 to hostCacheCount - 1 do
  begin
    if boolval(hostcache[n].maxusers) then
      sprintf(str, '%-15.15s %-15.15s %2u/%2u'#10, [hostcache[n].name, hostcache[n].map, hostcache[n].users, hostcache[n].maxusers])
    else
      sprintf(str, '%-15.15s %-15.15s'#10, [hostcache[n].name, hostcache[n].map]);
    MainMenu.Print(16, 32 + 8 * n, str);
  end;
  M_DrawCharacter(0, 32 + slist_cursor * 8, 12 + (int(realtime * 4) and 1));

  if m_return_reason[0] <> #0 then
    MainMenu.PrintWhite(16, 148, m_return_reason);
end;

procedure TMainMenu.ServerList_Key(k: integer);
begin
  case k of
    K_ESCAPE:
      begin
        M_Menu_LanConfig_f;
      end;

    K_SPACE:
      begin
        M_Menu_Search_f;
      end;

    K_UPARROW,
      K_LEFTARROW:
      begin
        S_LocalSound('misc/menu1.wav');
        dec(slist_cursor);
        if slist_cursor < 0 then
          slist_cursor := hostCacheCount - 1;
      end;

    K_DOWNARROW,
      K_RIGHTARROW:
      begin
        S_LocalSound('misc/menu1.wav');
        inc(slist_cursor);
        if slist_cursor >= hostCacheCount then
          slist_cursor := 0;
      end;

    K_ENTER:
      begin
        S_LocalSound('misc/menu2.wav');
        m_return_state := m_state;
        m_return_onerror := true;
        slist_sorted := false;
        key_dest := key_game;
        m_state := m_none;
        Cbuf_AddText(va('connect "%s"'#10, [hostcache[slist_cursor].cname]));
      end;
  end;
end;

procedure TMainMenu.Setup_Draw;
var
  p: Pqpic_t;
begin
  M_DrawTransPic(16, 4, Draw_CachePic('gfx/qplaque.lmp'));
  p := Draw_CachePic('gfx/p_multi.lmp');
  MainMenu.DrawPic((320 - p.width) div 2, 4, p);

  MainMenu.Print(64, 40, 'Hostname');
  M_DrawTextBox(160, 32, 16, 1);
  MainMenu.Print(168, 40, setup_hostname);

  MainMenu.Print(64, 56, 'Your name');
  M_DrawTextBox(160, 48, 16, 1);
  MainMenu.Print(168, 56, setup_myname);

  MainMenu.Print(64, 80, 'Shirt color');
  MainMenu.Print(64, 104, 'Pants color');

  M_DrawTextBox(64, 140 - 8, 14, 1);
  MainMenu.Print(72, 140, 'Accept Changes');

  p := Draw_CachePic('gfx/bigbox.lmp');
  M_DrawTransPic(160, 64, p);
  p := Draw_CachePic('gfx/menuplyr.lmp');
  M_BuildTranslationTable(setup_top * 16, setup_bottom * 16);
  M_DrawTransPicTranslate(172, 72, p);

  M_DrawCharacter(56, setup_cursor_table[setup_cursor], 12 + (int(realtime * 4) and 1));

  if setup_cursor = 0 then
    M_DrawCharacter(168 + 8 * strlen(setup_hostname), setup_cursor_table[setup_cursor], 10 + (int(realtime * 4) and 1));

  if setup_cursor = 1 then
    M_DrawCharacter(168 + 8 * strlen(setup_myname), setup_cursor_table[setup_cursor], 10 + (int(realtime * 4) and 1));
end;

procedure TMainMenu.Setup_Key(k: integer);
var
  l: integer;

  procedure forward1;
  begin
    S_LocalSound('misc/menu3.wav');
    if setup_cursor = 2 then
      inc(setup_top);
    if setup_cursor = 3 then
      inc(setup_bottom);
  end;

begin
  case k of
    K_ESCAPE:
      begin
        M_Menu_MultiPlayer_f;
      end;

    K_UPARROW:
      begin
        S_LocalSound('misc/menu1.wav');
        dec(setup_cursor);
        if setup_cursor < 0 then
          setup_cursor := NUM_SETUP_CMDS - 1;
      end;

    K_DOWNARROW:
      begin
        S_LocalSound('misc/menu1.wav');
        inc(setup_cursor);
        if setup_cursor >= NUM_SETUP_CMDS then
          setup_cursor := 0;
      end;

    K_LEFTARROW:
      begin
        if setup_cursor < 2 then
          exit;
        S_LocalSound('misc/menu3.wav');
        if setup_cursor = 2 then
          dec(setup_top);
        if setup_cursor = 3 then
          dec(setup_bottom);
      end;

    K_RIGHTARROW:
      begin
        if setup_cursor < 2 then
          exit;
        forward1;
      end;

    K_ENTER:
      begin
        if setup_cursor in [0, 1] then
          exit;

        if setup_cursor in [2, 3] then
          forward1
        else
        begin
          // setup_cursor == 4 (OK)
          if Q_strcmp(cl_name.text, setup_myname) <> 0 then Cbuf_AddText(va('name "%s"'#10, [setup_myname]));
          if Q_strcmp(hostname.text, setup_hostname) <> 0 then ConsoleVars.SetValue('hostname', setup_hostname);
          if (setup_top <> setup_oldtop) or (setup_bottom <> setup_oldbottom) then
            Cbuf_AddText(va('color %d %d'#10, [setup_top, setup_bottom]));
          m_entersound := true;
          M_Menu_MultiPlayer_f;
        end;
      end;

    K_BACKSPACE:
      begin
        if setup_cursor = 0 then
        begin
          l := strlen(setup_hostname);
          if l > 0 then
            setup_hostname[l - 1] := #0;
        end;
        if setup_cursor = 1 then
        begin
          l := strlen(setup_myname);
          if l > 0 then
            setup_myname[l - 1] := #0;
        end;
      end;

  else
    begin
      if (k >= 32) or (k <= 127) then
      begin
        if setup_cursor = 0 then
        begin
          l := strlen(setup_hostname);
          if l < 15 then
          begin
            setup_hostname[l + 1] := #0;
            setup_hostname[l] := Chr(k);
          end;
        end;
        if setup_cursor = 1 then
        begin
          l := strlen(setup_myname);
          if l < 15 then
          begin
            setup_myname[l + 1] := #0;
            setup_myname[l] := Chr(k);
          end;
        end;
      end;
    end;

  end;

  if setup_top > 13 then setup_top := 0;
  if setup_top < 0 then setup_top := 13;
  if setup_bottom > 13 then setup_bottom := 0;
  if setup_bottom < 0 then setup_bottom := 13;
end;

procedure TMainMenu.SinglePlayer_Draw;
var
  f: integer;
  p: Pqpic_t;
begin
  M_DrawTransPic(16, 4, Draw_CachePic('gfx/qplaque.lmp'));
  p := Draw_CachePic('gfx/ttl_sgl.lmp');
  MainMenu.DrawPic((320 - p.width) div 2, 4, p);
  M_DrawTransPic(72, 32, Draw_CachePic('gfx/sp_menu.lmp'));

  f := int(host_time * 10) mod 6;

  M_DrawTransPic(54, 32 + m_singleplayer_cursor * 20, Draw_CachePic(va('gfx/menudot%d.lmp', [f + 1])));
end;

procedure TMainMenu.SinglePlayer_Key(key: integer);
begin
  case key of
    K_ESCAPE:
      begin
        M_Menu_Main_f;
      end;

    K_DOWNARROW:
      begin
        S_LocalSound('misc/menu1.wav');
        inc(m_singleplayer_cursor); // VJ check --
        if m_singleplayer_cursor >= SINGLEPLAYER_ITEMS then
          m_singleplayer_cursor := 0;
      end;

    K_UPARROW:
      begin
        S_LocalSound('misc/menu1.wav');
        dec(m_singleplayer_cursor); // VJ check --
        if m_singleplayer_cursor < 0 then
          m_singleplayer_cursor := SINGLEPLAYER_ITEMS - 1;
      end;

    K_ENTER:
      begin
        m_entersound := true;

        case m_singleplayer_cursor of
          0: begin
              if sv.active then
                if not SCR_ModalMessage('Are you sure you want to'#10'start a new game?'#10) then exit;
              key_dest := key_game;
              if sv.active then Cbuf_AddText('disconnect'#10);
              Cbuf_AddText('maxplayers 1'#10);
              Cbuf_AddText('map start'#10);
            end;
          1: M_Menu_Load_f;
          2: M_Menu_Save_f;
        end;
      end;
  end;
end;

procedure TMainMenu.Video_Draw;
begin
  if Assigned(vid_menudrawfn) then
    vid_menudrawfn;
end;

procedure TMainMenu.Video_Key(key: integer);
begin
  if Assigned(vid_menukeyfn) then
    vid_menukeyfn(key);
end;

initialization
  MainMenu := TMainMenu.Create;
finalization
  MainMenu.Free;
end.

