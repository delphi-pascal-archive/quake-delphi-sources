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

unit MapFileFormats;

interface

uses
  zone,
  sys_win,
  common,
  bsp_q3,
  bspfile,
  bsp30,
  gl_planes,
  gl_model_h;

procedure Mod_LoadBrushModel(mdl: PBSPModelFile; buffer: pointer);
procedure svLoadMap_QuakeIII(mdl: PBSPModelFile; buffer: pointer);

implementation

procedure svLoadMap_QuakeIII(mdl: PBSPModelFile; buffer: pointer);
var
  q3: TQuake3BSP;
  i: Integer;
begin
  q3.LoadBSP(buffer);

//  Mod_LoadVertexes(@header.lumps[LUMP_VERTEXES]);
  loadmodel._type := mod_brush;

  loadmodel.numvertexes := q3.numOfVerts;
  loadmodel.vertexes := Hunk_AllocName(loadmodel.numvertexes * SizeOf(mvertex_t), loadname);
  for i := 0 to q3.numOfVerts - 1 do
    loadmodel.vertexes[i].position := q3.Vertices[i].Position;

//  Mod_LoadFaces(@header.lumps[LUMP_FACES]);
  loadmodel.numsurfaces := q3.numOfFaces;
  loadmodel.surfaces := Hunk_AllocName(loadmodel.numframes * SizeOf(msurface_t), loadname);
  for i := 0 to q3.numOfFaces - 1 do
  begin
     //
    loadmodel.surfaces[i].lightmaptexturenum := q3.Faces[i].lightmapID;
  end;

//  Mod_LoadEdges(@header.lumps[LUMP_EDGES]);
  loadmodel.numedges := 0;

//  Mod_LoadSurfedges(@header.lumps[LUMP_SURFEDGES]);
  loadmodel.numsurfedges := 0;

//  Mod_LoadTextures(@header.lumps[LUMP_TEXTURES]);
  loadmodel.numtextures := 0;

//  Mod_LoadLighting(@header.lumps[LUMP_LIGHTING]);
  loadmodel.lightdata := nil;

//  Mod_LoadPlanes(@header.lumps[LUMP_PLANES]);
//  Mod_LoadTexinfo(@header.lumps[LUMP_TEXINFO]);

//  Mod_LoadMarksurfaces(@header.lumps[LUMP_MARKSURFACES]);
//  Mod_LoadVisibility(@header.lumps[LUMP_VISIBILITY]);
//  Mod_LoadLeafs(@header.lumps[LUMP_LEAFS]);
//  Mod_LoadNodes(@header.lumps[LUMP_NODES]);
//  Mod_LoadClipnodes(@header.lumps[LUMP_CLIPNODES]);
//  Mod_LoadEntities(@header.lumps[LUMP_ENTITIES]);
//  Mod_LoadSubmodels(@header.lumps[LUMP_MODELS]);

end;

procedure Mod_LoadBrushModel(mdl: PBSPModelFile; buffer: pointer);
type
  Tids = array[0..4] of char;
  Pids = ^Tids;
var
  i: integer;
  header: PBSPHeader;
  ids: Pids;
begin
  loadmodel._type := mod_brush;

  header := PBSPHeader(buffer);

  i := LittleLong(header.version);
  case i of
    BSPVERSION_QuakeI: MOD_BSPFile.LoadMap_QuakeI(mdl, buffer);
    BSPVERSION_HalfLife: MOD_BSPFile.LoadMap_HalfLife(mdl, buffer);
  else
    ids := Pids(buffer);
    if ids^ = 'IBSP.' then
    begin
      svLoadMap_QuakeIII(mdl, buffer);
      exit;
    end;
//    if ids^ = 'VBSP!' then // HalfLife2

    Sys_Error('Mod_LoadBrushModel: %s has wrong version number (%d should be %d)', [mdl.name, i, BSPVERSION_QuakeI]);
  end;
end;

end.

