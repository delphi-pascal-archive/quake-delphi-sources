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

unit cl_tent;

interface

uses
  sound,
  gl_model_h,
  client;

type
  TClientEntity = class
  private
    num_temp_entities: integer;
    cl_temp_entities: array[0..MAX_TEMP_ENTITIES - 1] of entity_t;
    cl_beams: array[0..MAX_BEAMS - 1] of beam_t;

    cl_sfx_wizhit: Psfx_t;
    cl_sfx_knighthit: Psfx_t;
    cl_sfx_tink1: Psfx_t;
    cl_sfx_ric1: Psfx_t;
    cl_sfx_ric2: Psfx_t;
    cl_sfx_ric3: Psfx_t;
    cl_sfx_r_exp3: Psfx_t;
                      (*
                       #ifdef QUAKE2
                      sfx_t      *cl_sfx_imp;
                      sfx_t      *cl_sfx_rail;
                       #endif
                       *)
  public
    constructor Create;

    procedure Clear;

    procedure Init;
    procedure ParseBeam(m: PBSPModelFile);
    procedure Parse;
    function NewTempEntity: Pentity_t;
    procedure Update;
  end;
var
  ClientEntity: TClientEntity;

implementation

uses
  Unit_SysTools,
  snd_dma,
  mathlib,
  common,
  cl_main_h,
  console,
  protocol,
  r_part,
  cl_main,
  gl_model,
  sys_win,
  gl_vidnt;

{ TClientEntity }

procedure TClientEntity.Clear;
begin
  ZeroMemory(@cl_temp_entities, SizeOf(cl_temp_entities));
  ZeroMemory(@cl_beams, SizeOf(cl_beams));
end;

constructor TClientEntity.Create;
begin
  inherited;

end;

procedure TClientEntity.Init;
begin
  cl_sfx_wizhit := S_PrecacheSound('wizard/hit.wav');
  cl_sfx_knighthit := S_PrecacheSound('hknight/hit.wav');
  cl_sfx_tink1 := S_PrecacheSound('weapons/tink1.wav');
  cl_sfx_ric1 := S_PrecacheSound('weapons/ric1.wav');
  cl_sfx_ric2 := S_PrecacheSound('weapons/ric2.wav');
  cl_sfx_ric3 := S_PrecacheSound('weapons/ric3.wav');
  cl_sfx_r_exp3 := S_PrecacheSound('weapons/r_exp3.wav');
(*
#ifdef QUAKE2
  cl_sfx_imp = S_PrecacheSound ("shambler/sattck1.wav");
  cl_sfx_rail = S_PrecacheSound ("weapons/lstart.wav");
#endif
*)
end;

function TClientEntity.NewTempEntity: Pentity_t;
var
  ent: Pentity_t;
begin
  if cl_numvisedicts = MAX_VISEDICTS then
  begin
    result := nil;
    exit;
  end;

  if num_temp_entities = MAX_TEMP_ENTITIES then
  begin
    result := nil;
    exit;
  end;

  ent := @cl_temp_entities[num_temp_entities];
  memset(ent, 0, SizeOf(entity_t));
  inc(num_temp_entities);
  cl_visedicts[cl_numvisedicts] := ent;
  inc(cl_numvisedicts);

  ent.colormap := vid.colormap;
  result := ent;
end;

procedure TClientEntity.Parse;
var
  _type: integer;
  pos: TVector3f;
(*
#ifdef QUAKE2
  vec3_t  endpos;
#endif
*)
  dl: Pdlight_t;
  rnd: integer;
  colorStart, colorLength: integer;
begin
  _type := MSG_ReadByte;
  case _type of
    TE_WIZSPIKE: // spike hitting wall
      begin
        pos[0] := MSG_ReadCoord;
        pos[1] := MSG_ReadCoord;
        pos[2] := MSG_ReadCoord;
        R_RunParticleEffect(@pos, @vec3_origin, 20, 30);
        S_StartSound(-1, 0, cl_sfx_wizhit, @pos, 1, 1);
      end;

    TE_KNIGHTSPIKE: // spike hitting wall
      begin
        pos[0] := MSG_ReadCoord();
        pos[1] := MSG_ReadCoord();
        pos[2] := MSG_ReadCoord();
        R_RunParticleEffect(@pos, @vec3_origin, 226, 20);
        S_StartSound(-1, 0, cl_sfx_knighthit, @pos, 1, 1);
      end;

    TE_SPIKE: // spike hitting wall
      begin
        pos[0] := MSG_ReadCoord;
        pos[1] := MSG_ReadCoord;
        pos[2] := MSG_ReadCoord;
(*
#ifdef GLTEST // VJ
    Test_Spawn (pos);
#else
*)
        R_RunParticleEffect(@pos, @vec3_origin, 0, 10);
//#endif
        if (rand mod 5) <> 0 then
          S_StartSound(-1, 0, cl_sfx_tink1, @pos, 1, 1)
        else
        begin
          rnd := rand and 3;
          if rnd = 1 then
            S_StartSound(-1, 0, cl_sfx_ric1, @pos, 1, 1)
          else if rnd = 2 then
            S_StartSound(-1, 0, cl_sfx_ric2, @pos, 1, 1)
          else
            S_StartSound(-1, 0, cl_sfx_ric3, @pos, 1, 1);
        end;
      end;

    TE_SUPERSPIKE: // super spike hitting wall
      begin
        pos[0] := MSG_ReadCoord;
        pos[1] := MSG_ReadCoord;
        pos[2] := MSG_ReadCoord;
        R_RunParticleEffect(@pos, @vec3_origin, 0, 20);

        if (rand mod 5) <> 0 then
          S_StartSound(-1, 0, cl_sfx_tink1, @pos, 1, 1)
        else
        begin
          rnd := rand mod 3;
          if rnd = 1 then
            S_StartSound(-1, 0, cl_sfx_ric1, @pos, 1, 1)
          else if rnd = 2 then
            S_StartSound(-1, 0, cl_sfx_ric2, @pos, 1, 1)
          else
            S_StartSound(-1, 0, cl_sfx_ric3, @pos, 1, 1);
        end;
      end;

    TE_GUNSHOT: // bullet hitting wall
      begin
        pos[0] := MSG_ReadCoord;
        pos[1] := MSG_ReadCoord;
        pos[2] := MSG_ReadCoord;
        R_RunParticleEffect(@pos, @vec3_origin, 0, 20);
      end;

    TE_EXPLOSION: // rocket explosion
      begin
        pos[0] := MSG_ReadCoord;
        pos[1] := MSG_ReadCoord;
        pos[2] := MSG_ReadCoord;
        R_ParticleExplosion(@pos);
        dl := ClientMain.AllocDlight(0);
        VectorCopy(@pos, @dl.origin);
        dl.radius := 350;
        dl.die := cl.time + 0.5;
        dl.decay := 300;
        S_StartSound(-1, 0, cl_sfx_r_exp3, @pos, 1, 1);
      end;

    TE_TAREXPLOSION: // tarbaby explosion
      begin
        pos[0] := MSG_ReadCoord;
        pos[1] := MSG_ReadCoord;
        pos[2] := MSG_ReadCoord;
        R_BlobExplosion(@pos);

        S_StartSound(-1, 0, cl_sfx_r_exp3, @pos, 1, 1);
      end;

    TE_LIGHTNING1: // lightning bolts
      ParseBeam(Mod_ForName('progs/bolt.mdl', true));

    TE_LIGHTNING2: // lightning bolts
      ParseBeam(Mod_ForName('progs/bolt2.mdl', true));

    TE_LIGHTNING3: // lightning bolts
      ParseBeam(Mod_ForName('progs/bolt3.mdl', true));

// PGM 01/21/97
    TE_BEAM: // grappling hook beam
      ParseBeam(Mod_ForName('progs/beam.mdl', true));
// PGM 01/21/97

    TE_LAVASPLASH:
      begin
        pos[0] := MSG_ReadCoord;
        pos[1] := MSG_ReadCoord;
        pos[2] := MSG_ReadCoord;
        R_LavaSplash(@pos);
      end;

    TE_TELEPORT:
      begin
        pos[0] := MSG_ReadCoord;
        pos[1] := MSG_ReadCoord;
        pos[2] := MSG_ReadCoord;
        R_TeleportSplash(@pos);
      end;

    TE_EXPLOSION2: // color mapped explosion
      begin
        pos[0] := MSG_ReadCoord;
        pos[1] := MSG_ReadCoord;
        pos[2] := MSG_ReadCoord;
        colorStart := MSG_ReadByte;
        colorLength := MSG_ReadByte;
        R_ParticleExplosion2(@pos, colorStart, colorLength);
        dl := ClientMain.AllocDlight(0);
        VectorCopy(@pos, @dl.origin);
        dl.radius := 350;
        dl.die := cl.time + 0.5;
        dl.decay := 300;
        S_StartSound(-1, 0, cl_sfx_r_exp3, @pos, 1, 1);
      end;

(*
#ifdef QUAKE2
  case TE_IMPLOSION:
    pos[0] = MSG_ReadCoord ();
    pos[1] = MSG_ReadCoord ();
    pos[2] = MSG_ReadCoord ();
    S_StartSound (-1, 0, cl_sfx_imp, pos, 1, 1);
    break;

  case TE_RAILTRAIL:
    pos[0] = MSG_ReadCoord ();
    pos[1] = MSG_ReadCoord ();
    pos[2] = MSG_ReadCoord ();
    endpos[0] = MSG_ReadCoord ();
    endpos[1] = MSG_ReadCoord ();
    endpos[2] = MSG_ReadCoord ();
    S_StartSound (-1, 0, cl_sfx_rail, pos, 1, 1);
    S_StartSound (-1, 1, cl_sfx_r_exp3, endpos, 1, 1);
    R_RocketTrail (pos, endpos, 0+128);
    R_ParticleExplosion (endpos);
    dl = CL_AllocDlight (-1);
    VectorCopy (endpos, dl->origin);
    dl->radius = 350;
    dl->die = cl.time + 0.5;
    dl->decay = 300;
    break;
#endif
*)
  else
    Sys_Error('CL_ParseTEnt: bad type');
  end;
end;

procedure TClientEntity.ParseBeam(m: PBSPModelFile);
var
  ent: integer;
  start, _end: TVector3f;
  b: Pbeam_t;
  i: integer;
begin
  ent := MSG_ReadShort;

  start[0] := MSG_ReadCoord;
  start[1] := MSG_ReadCoord;
  start[2] := MSG_ReadCoord;

  _end[0] := MSG_ReadCoord;
  _end[1] := MSG_ReadCoord;
  _end[2] := MSG_ReadCoord;

// override any beam with the same entity
  b := @cl_beams[0];
  for i := 0 to MAX_BEAMS - 1 do
  begin
    if b.entity = ent then
    begin
      b.entity := ent;
      b.model := m;
      b.endtime := cl.time + 0.2;
      VectorCopy(@start, @b.start);
      VectorCopy(@_end, @b._end);
      exit;
    end;
    inc(b);
  end;

// find a free beam
  b := @cl_beams[0];
  for i := 0 to MAX_BEAMS - 1 do
  begin
    if (b.model = nil) or (b.endtime < cl.time) then
    begin
      b.entity := ent;
      b.model := m;
      b.endtime := cl.time + 0.2;
      VectorCopy(@start, @b.start);
      VectorCopy(@_end, @b._end);
      exit;
    end;
    inc(b);
  end;
  Con_Printf('beam list overflow!'#10);
end;

procedure TClientEntity.Update;
var
  i: integer;
  b: Pbeam_t;
  dist, org: TVector3f;
  d: single;
  ent: Pentity_t;
  _yaw, _pitch: single;
  _forward: single;
begin
  num_temp_entities := 0;

// update lightning
  b := @cl_beams[0];
  i := 0;
  while i < MAX_BEAMS - 1 do
  begin
    if (b.model = nil) or (b.endtime < cl.time) then
    begin
      inc(b);
      inc(i);
      continue;
    end;

  // if coming from the player, update the start position
    if b.entity = cl.viewentity then
      VectorCopy(@cl_entities[cl.viewentity].origin, @b.start);

  // calculate pitch and yaw
    VectorSubtract(@b._end, @b.start, @dist);

    if (dist[1] = 0) and (dist[0] = 0) then
    begin
      _yaw := 0;
      if dist[2] > 0 then
        _pitch := 90
      else
        _pitch := 270
    end
    else
    begin
      _yaw := int(fatan2(dist[1], dist[0]) * 180 / M_PI);
      if _yaw < 0 then
        _yaw := _yaw + 360;

      _forward := sqrt(dist[0] * dist[0] + dist[1] * dist[1]);
      _pitch := int(fatan2(dist[2], _forward) * 180 / M_PI);
      if _pitch < 0 then
        _pitch := _pitch + 360;
    end;

  // add new entities for the lightning
    VectorCopy(@b.start, @org);
    d := VectorNormalize(@dist);
    while d > 0 do
    begin
      ent := NewTempEntity;
      if ent = nil then
        exit;
      VectorCopy(@org, @ent.origin);
      ent.model := b.model;
      ent.angles[0] := _pitch;
      ent.angles[1] := _yaw;
      ent.angles[2] := rand mod 360;

      i := 0;
      while i < 3 do
      begin
        org[i] := org[i] + dist[i] * 30;
        inc(i);
      end;
      d := d - 30;
    end;
    inc(b);
    inc(i);
  end;
end;

initialization
  ClientEntity := TClientEntity.Create;
finalization
  ClientEntity.Free;
end.

