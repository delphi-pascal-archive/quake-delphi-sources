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

unit cvar;

// cvar.c -- dynamic variable tracking

interface

uses
  Unit_SysTools;

type
  Pcvar_t = ^cvar_t;
  cvar_t = record
    name: PChar;
    text: PChar;
    archive: qboolean; // set to true to cause it to be saved to vars.rc
    server: qboolean; // notifies players when changed
    value: single;
    next: Pcvar_t;
  end;

type
  TConsoleVars = class
    cvar_vars: Pcvar_t;
    constructor Create;
    destructor Destroy; override;

    function FindVar(var_name: PChar): Pcvar_t;
    function VariableValue(var_name: PChar): single;
    function VariableString(var_name: PChar): PChar;
    function CompleteVariable(partial: PChar): PChar;
    procedure SetValue(const var_name: PChar; const value: PChar); overload;
    procedure SetValue(const var_name: PChar; const value: single); overload;
    procedure SetValue(const var_name: PChar; const value: qboolean); overload;
    procedure SetValue(const var_name: string; const value: single); overload;
    procedure SetValue(const var_name: string; const value: qboolean); overload;
    procedure RegisterVariable(variable: Pcvar_t);
    function Command: qboolean;
    procedure WriteVariables(var f: text);
  end;

var
  ConsoleVars: TConsoleVars;

implementation

uses
  common,
  console,
  zone,
  sv_main,
  host,
  cmd;

{ TConsoleVars }

function TConsoleVars.Command: qboolean;
var
  v: Pcvar_t;
begin
// check variables
  v := FindVar(Cmd_Argv_f(0));
  if v = nil then
  begin
    result := false;
    exit;
  end;

// perform a variable print or set
  if Cmd_Argc_f = 1 then
  begin
    Con_Printf('"%s" is "%s"'#10, [v.name, v.text]);
    result := true;
    exit;
  end;

  SetValue(v.name, Cmd_Argv_f(1));
  result := true;
end;

function TConsoleVars.CompleteVariable(partial: PChar): PChar;
var
  Item: Pcvar_t;
  len: integer;
begin
  len := Q_strlen(partial);

  if len = 0 then
  begin
    result := nil;
    exit;
  end;

// check functions
  Item := cvar_vars;
  while Item <> nil do
  begin
    if Q_strncmp(partial, Item.name, len) = 0 then
    begin
      result := Item.name;
      exit;
    end;
    Item := Item.next;
  end;

  result := nil;
end;

constructor TConsoleVars.Create;
begin
  inherited;

end;

destructor TConsoleVars.Destroy;
begin

  inherited;
end;

function TConsoleVars.FindVar(var_name: PChar): Pcvar_t;
var
  Item: Pcvar_t;
begin
  Item := cvar_vars;
  while Item <> nil do
  begin
    if Q_strcmp(var_name, Item.name) = 0 then
    begin
      result := Item;
      exit;
    end;
    Item := Item.next;
  end;

  result := nil;
end;

procedure TConsoleVars.RegisterVariable(variable: Pcvar_t);
var
  oldstr: PChar;
begin
// first check to see if it has allready been defined
  if FindVar(variable.name) <> nil then
  begin
    Con_Printf('Can''t register variable %s, allready defined'#10, [variable.name]);
    exit;
  end;

// check for overlap with a command
  if Cmd_Exists(variable.name) then
  begin
    Con_Printf('Cvar_RegisterVariable: %s is a command'#10, [variable.name]);
    exit;
  end;

// copy the value off, because future sets will Z_Free it
  oldstr := variable.text;
  variable.text := Z_Malloc(Q_strlen(variable.text) + 1);
  Q_strcpy(variable.text, oldstr);
  variable.value := Q_atof(variable.text);

// link the variable in
  variable.next := cvar_vars;
  cvar_vars := variable;
end;

procedure TConsoleVars.SetValue(const var_name: PChar; const value: qboolean);
var
  f: single;
begin
  if value then f := 1.0
  else f := 0.0;
  SetValue(var_name, f);
end;

procedure TConsoleVars.SetValue(const var_name: PChar; const value: single);
var
  val: array[0..31] of char;
begin
  sprintf(val, '%f', [value]);
  SetValue(var_name, val);
end;

procedure TConsoleVars.SetValue(const var_name: PChar; const value: PChar);
var
  Item: Pcvar_t;
  changed: qboolean;
begin
  Item := FindVar(var_name);
  if Item = nil then
  begin // there is an error in C code if this happens
    Con_Printf('Cvar_Set: variable %s not found'#10, [var_name]);
    exit;
  end;

  changed := Q_strcmp(Item.text, value) = 0;

  Z_Free(Item.text); // free the old value string

  Item.text := Z_Malloc(Q_strlen(value) + 1);
  Q_strcpy(Item.text, value);
  Item.value := Q_atof(Item.text);
  if Item.server and changed then
  begin
    if sv.active then
      SV_BroadcastPrintf('"%s" changed to "%s"'#10, [Item.name, Item.text]);
  end;
end;

procedure TConsoleVars.SetValue(const var_name: string; const value: qboolean);
begin
  SetValue(PChar(var_name), value);
end;

procedure TConsoleVars.SetValue(const var_name: string; const value: single);
begin
  SetValue(PChar(var_name), value);
end;

function TConsoleVars.VariableString(var_name: PChar): PChar;
var
  Item: Pcvar_t;
begin
  Item := FindVar(var_name);
  if Item = nil then result := ''
  else result := Item.text;
end;

function TConsoleVars.VariableValue(var_name: PChar): single;
var
  Item: Pcvar_t;
begin
  Item := FindVar(var_name);
  if Item = nil then result := 0
  else result := Q_atof(Item.text);
end;

procedure TConsoleVars.WriteVariables(var f: text);
var
  Item: Pcvar_t;
begin
  Item := cvar_vars;
  while Item <> nil do
  begin
    if Item.archive then
      fprintf(f, '%s "%s"'#10, [Item.name, Item.text]);
    Item := Item.next;
  end;
end;

initialization
  ConsoleVars := TConsoleVars.Create;
finalization
  ConsoleVars.Free;
end.

