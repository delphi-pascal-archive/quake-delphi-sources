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

unit chase;

interface

uses
  cvar;

procedure Chase_Init;

procedure Chase_Reset;
procedure Chase_Update;

var
  chase_back: cvar_t = (name: 'chase_back'; text: '100');
  chase_up: cvar_t = (name: 'chase_up'; text: '16');
  chase_right: cvar_t = (name: 'chase_right'; text: '0');
  chase_active: cvar_t = (name: 'chase_active'; text: '0');

implementation

uses
  Unit_SysTools,
  mathlib,
  world,
  cl_main_h,
  gl_rmain,
  quakedef;

var
  chase_dest: TVector3f;


procedure Chase_Init;
begin
  ConsoleVars.RegisterVariable(@chase_back);
  ConsoleVars.RegisterVariable(@chase_up);
  ConsoleVars.RegisterVariable(@chase_right);
  ConsoleVars.RegisterVariable(@chase_active);
end;

procedure Chase_Reset;
begin
  { for respawning and teleporting start position 12 units behind head }
end;

procedure TraceLine(start: PVector3f; _end: PVector3f; impact: PVector3f);
var
  trace: trace_t;
begin
  ZeroMemory(@trace, SizeOf(trace));
  SV_RecursiveHullCheck(@cl.worldmodel.hulls, 0, 0, 1, start, _end, @trace);

  VectorCopy(@trace.endpos, impact);
end;

procedure Chase_Update;
var
  i: integer;
  dist: single;
  _forward, up, right: TVector3f;
  dest, stop: TVector3f;
begin
  AngleVectors(@cl.viewangles, @_forward, @right, @up);

  for i := 0 to 2 do
    chase_dest[i] := r_refdef.vieworg[i] -
      _forward[i] * chase_back.value -
      right[i] * chase_right.value;

  chase_dest[2] := r_refdef.vieworg[2] + chase_up.value;

  VectorMA(@r_refdef.vieworg, 4096, @_forward, @dest);
  TraceLine(@r_refdef.vieworg, @dest, @stop);

  VectorSubtract(@stop, @r_refdef.vieworg, @stop);
  dist := VectorDotProduct(@stop, @_forward);
  if dist < 1 then
    dist := 1;
  r_refdef.viewangles[PITCH] := -fatan(stop[2] / dist) / M_PI * 180;

  VectorCopy(@chase_dest, @r_refdef.vieworg);
end;


end.

