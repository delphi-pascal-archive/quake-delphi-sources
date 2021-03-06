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

{$Z4}

unit progs_h;

interface

uses
  Unit_SysTools,
  common,
  pr_comp, // defs shared with qcc
  progdefs, // generated by program cdefs
  quakedef;

type
  Peval_t = ^eval_t;
  eval_t = record
    case integer of
      0: (_string: string_t);
      1: (_float: single);
      2: (vector: array[0..2] of single);
      3: (func: func_t);
      4: (_int: integer);
      5: (edict: integer);
  end;

const
  MAX_ENT_LEAFS = 16;

type
  Pedict_t = ^edict_t;
  edict_t = record
    free: qboolean;
    area: link_t; // linked to a division node or leaf

    num_leafs: integer;
    leafnums: array[0..MAX_ENT_LEAFS - 1] of short;

    baseline: entity_state_t;

    freetime: single; // sv.time when the object was freed
    v: entvars_t; // C exported fields from progs
// other fields from progs come immediately after
  end;

function EDICT_FROM_AREA(l: Plink_t): Pedict_t;
function NEXT_EDICT(e: Pedict_t): Pedict_t;
function EDICT_TO_PROG(e: Pedict_t): integer;
function PROG_TO_EDICT(e: integer): Pedict_t;
function G_FLOAT(o: integer): Pfloat;
function G_STRING(o: integer): PChar;
function G_INT(o: integer): PInteger;
function G_EDICT(o: integer): Pedict_t;
function E_STRING(e: Pedict_t; o: integer): PChar;
function EDICT_NUM(n: integer): Pedict_t;
function NUM_FOR_EDICT(e: Pedict_t): integer;
function G_EDICTNUM(o: integer): integer;
function G_VECTOR(o: integer): PVector3f;

type
  builtin_t = procedure;
  Pbuiltin_t = ^builtin_t;

implementation

uses
  pr_edict,
  sv_main,
  sys_win;

function EDICT_FROM_AREA(l: Plink_t): Pedict_t; // VJ SOS
begin
  result := Pedict_t(integer(l) - integer(@Pedict_t(0).area));
end;

function NEXT_EDICT(e: Pedict_t): Pedict_t;
begin
  result := Pedict_t(integer(e) + pr_edict_size);
end;

function EDICT_TO_PROG(e: Pedict_t): integer;
begin
  result := integer(e) - integer(sv.edicts);
end;

function PROG_TO_EDICT(e: integer): Pedict_t;
begin
  result := Pedict_t(integer(sv.edicts) + e);
end;

//============================================================================

function G_FLOAT(o: integer): Pfloat;
begin
  result := @pr_globals[o];
end;

function G_STRING(o: integer): PChar;
begin
  result := @pr_strings[Pstring_t(@pr_globals[o])^];
end;

function G_INT(o: integer): PInteger;
begin
  result := PInteger(@pr_globals[o]);
end;

function G_EDICT(o: integer): Pedict_t;
begin
  result := Pedict_t(integer(sv.edicts) + PInteger(@pr_globals[o])^); // VJ CHECK!
end;

function E_STRING(e: Pedict_t; o: integer): PChar;
begin
  result := @pr_strings[PIntegerArray(@e.v)[o]]; // VJ SOS
end;
//#define  E_STRING(e,o) (pr_strings + *(string_t *)&((float*)&e->v)[o])

function EDICT_NUM(n: integer): Pedict_t;
begin
  if (n < 0) or (n >= sv.max_edicts) then
    Sys_Error('EDICT_NUM: bad number %d', [n]);
  result := Pedict_t(integer(sv.edicts) + n * pr_edict_size);
end;

function NUM_FOR_EDICT(e: Pedict_t): integer;
begin
  result := integer(e) - integer(sv.edicts);
  result := result div pr_edict_size;

  if (result < 0) or (result >= sv.num_edicts) then
    Sys_Error('NUM_FOR_EDICT: bad pointer');
end;


function G_EDICTNUM(o: integer): integer;
begin
  result := NUM_FOR_EDICT(G_EDICT(o))
end;

function G_VECTOR(o: integer): PVector3f;
begin
  result := PVector3f(@pr_globals[o]);
end;

end.
