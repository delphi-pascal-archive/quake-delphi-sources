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
unit bspfile;

interface

uses
  SysUtils,
  OpenGL12,
  gl_rsurf,
  gl_model,
  gl_model_h,
  gl_planes,
  gl_warp,
  gl_vidnt,
  gl_rmain_h,
  gl_mesh,
  bsp30,
  unit_Textures,
  Unit_SysTools,
  modelgen,
  spritegn,
  cvar,
  zone,
  sys_win,
  mathlib,
  common,
  glquake_h,
  quakedef,
  console
  ;
(*

type
 TBspEntryTypes_1 =
   (eEntities
   ,ePlanes
   ,eMipTex
   ,eVertices
   ,eVisiList
   ,eNodes
   ,eTexInfo
   ,eSurfaces
   ,eLightmaps
   ,eBoundNodes
   ,eLeaves
   ,eListSurf
   ,eEdges
   ,eListEdges
   ,eHulls);

 TBspEntryTypes_2 =
   (lump_entities
   ,lump_planes
   ,lump_vertexes
   ,lump_visibility
   ,lump_nodes
   ,lump_texinfo
   ,lump_faces
   ,lump_lighting
   ,lump_leafs
   ,lump_leaffaces
   ,lump_leafbrushes
   ,lump_edges
   ,lump_surfedges
   ,lump_models
   ,lump_brushes
   ,lump_brushsides
   ,lump_pop
   ,lump_areas
   ,lump_areaportals);

  TBspEntryTypes_3 =
   (eBsp3_entities
   ,eBsp3_texinfo
   ,eBsp3_planes
   ,eBsp3_nodes
   ,eBsp3_leafs
   ,eBsp3_leaffaces
   ,eBsp3_leafbrushes
   ,eBsp3_models
   ,eBsp3_brushes
   ,eBsp3_brushsides
   ,eBsp3_vertexes
   ,eBsp3_meshvertexes
   ,eBsp3_effects
   ,eBsp3_faces
   ,eBsp3_lighting
   ,eBsp3_lightvol
   ,eBsp3_visibility);

 const
  NoBsp1 = TBspEntryTypes_1(-1);
  NoBsp2 = TBspEntryTypes_2(-1);
  NoBsp3 = TBspEntryTypes_3(-1);
*)

var
  loadmodel: PBSPModelFile;
  loadname: array[0..31] of char; // for hunk tags
  mod_novis: array[0..MAX_MAP_LEAFS div 8 - 1] of byte;

const
  MAX_MOD_KNOWN = 512;

var
  mod_known: array[0..MAX_MOD_KNOWN - 1] of TBSPModelFile;
  mod_numknown: integer;

type
  TBSPFile = class
  private
    mod_base: PByteArray;
    procedure Funny_Lump_Size;

    procedure LoadTexinfo(l: PBSPLump);
    procedure LoadEdges(l: PBSPLump);
    procedure LoadSubmodels(l: PBSPLump);
    procedure LoadVertexes(l: PBSPLump);
    procedure LoadSurfedges(l: PBSPLump);
    procedure LoadPlanes(l: PBSPLump);
    procedure LoadLighting(l: PBSPLump);
    procedure LoadTextures(l: PBSPLump);
    procedure LoadTexturesHL(l: PBSPLump);
    procedure LoadFaces(l: PBSPLump);
    procedure LoadMarksurfaces(l: PBSPLump);
    procedure LoadVisibility(l: PBSPLump);
    procedure LoadEntities(l: PBSPLump);
    procedure LoadLeafs(l: PBSPLump);
    procedure LoadClipnodes(l: PBSPLump);
    procedure LoadNodes(l: PBSPLump);
    procedure MakeHull0;
  public
    procedure LoadMap_QuakeI(mdl: PBSPModelFile; buffer: pointer);
    procedure LoadMap_HalfLife(mdl: PBSPModelFile; buffer: pointer);
  end;

var
  MOD_BSPFile: TBSPFile;

implementation

{ TBSPFile }

procedure TBSPFile.Funny_Lump_Size;
begin
  Sys_Error('MOD_LoadBmodel: funny lump size in %s', [loadmodel.name]);
end;

procedure TBSPFile.LoadClipnodes(l: PBSPLump);
var
  _in, _out: PBSPClipNode;
  i, count: integer;
  hull: Phull_t;
begin
  _in := PBSPClipNode(@mod_base[l.Offset]);
  if l.Length mod SizeOf(TBSPClipNode) <> 0 then
    Funny_Lump_Size;
  count := l.Length div SizeOf(TBSPClipNode);
  _out := Hunk_AllocName(count * SizeOf(TBSPClipNode), loadname);

  loadmodel.clipnodes := _out;
  loadmodel.numclipnodes := count;

  hull := @loadmodel.hulls[1]; // VJ mayby hulls[1] & hulls[2] in one function?
  hull.clipnodes := _out;
  hull.firstclipnode := 0;
  hull.lastclipnode := count - 1;
  hull.planes := @loadmodel.planes[0];
  hull.clip_mins[0] := -16;
  hull.clip_mins[1] := -16;
  hull.clip_mins[2] := -24;
  hull.clip_maxs[0] := 16;
  hull.clip_maxs[1] := 16;
  hull.clip_maxs[2] := 32;

  hull := @loadmodel.hulls[2];
  hull.clipnodes := _out;
  hull.firstclipnode := 0;
  hull.lastclipnode := count - 1;
  hull.planes := @loadmodel.planes[0];
  hull.clip_mins[0] := -32;
  hull.clip_mins[1] := -32;
  hull.clip_mins[2] := -24;
  hull.clip_maxs[0] := 32;
  hull.clip_maxs[1] := 32;
  hull.clip_maxs[2] := 64;

  for i := 0 to count - 1 do
  begin
    _out.PlaneIndex := LittleLong(_in.PlaneIndex);
    _out.children[0] := LittleShort(_in.children[0]);
    _out.children[1] := LittleShort(_in.children[1]);
    inc(_in);
    inc(_out);
  end;
end;

procedure TBSPFile.LoadEdges(l: PBSPLump);
var
  _in: PBSPEdge;
  _out: Pmedge_t;
  i, count: integer;
begin
  _in := PBSPEdge(@mod_base[l.Offset]);
  if l.Length mod SizeOf(TBSPEdge) <> 0 then
    Funny_Lump_Size;
  count := l.Length div SizeOf(TBSPEdge);
  _out := Hunk_AllocName((count + 1) * SizeOf(medge_t), loadname);

  loadmodel.edges := Pmedge_tArray(_out);
  loadmodel.numedges := count;

  for i := 0 to count - 1 do
  begin
    _out.v[0] := unsigned_short(LittleShort(_in.v[0]));
    _out.v[1] := unsigned_short(LittleShort(_in.v[1]));
    inc(_in);
    inc(_out);
  end;
end;

procedure TBSPFile.LoadEntities(l: PBSPLump);
begin
  if l.Length = 0 then
  begin
    loadmodel.entities := nil;
    exit;
  end;
  loadmodel.entities := Hunk_AllocName(l.Length, loadname);
  memcpy(loadmodel.entities, @mod_base[l.Offset], l.Length);
end;

procedure TBSPFile.LoadFaces(l: PBSPLump);
label
  continue1;
var
  _in: PBSPFace;
  _out: Pmsurface_t;
  i, count, surfnum: integer;
  planenum, side: integer;
begin
  _in := PBSPFace(@mod_base[l.Offset]);
  if l.Length mod SizeOf(TBSPFace) <> 0 then
    Funny_Lump_Size;
  count := l.Length div SizeOf(TBSPFace);
  _out := Hunk_AllocName(count * SizeOf(msurface_t), loadname);

  loadmodel.surfaces := Pmsurface_tArray(_out);
  loadmodel.numsurfaces := count;

  for surfnum := 0 to count - 1 do
  begin
    _out.firstedge := LittleLong(_in.firstedge);
    _out.numedges := LittleShort(_in.numedges);
    _out.flags := 0;

    planenum := LittleShort(_in.PlaneIndex);
    side := LittleShort(_in.side);
    if side <> 0 then
      _out.flags := _out.flags or SURF_PLANEBACK;

    _out.plane := @loadmodel.planes[planenum];

    _out.texinfo := @loadmodel.texinfo[LittleShort(_in.texinfo)]; // VJ should check this

    CalcSurfaceExtents(_out);

  // lighting info

    for i := 0 to MAXLIGHTMAPS - 1 do
      _out.styles[i] := _in.styles[i];
    i := LittleLong(_in.light_offset);
    if i = -1 then
      _out.samples := nil
    else
      _out.samples := @loadmodel.lightdata[i]; // VJ should check this

  // set the drawing flags flag

    if Q_strncmp(_out.texinfo.texture.name, 'sky', 3) = 0 then // sky
    begin
      _out.flags := _out.flags or (SURF_DRAWSKY or SURF_DRAWTILED);
(*
#ifndef QUAKE2
      GL_SubdivideSurface (out);  // cut up polygon for warps
#endif
*)
      goto continue1;
    end;

    if Q_strncmp(_out.texinfo.texture.name, '*', 1) = 0 then // turbulent
    begin
      _out.flags := _out.flags or (SURF_DRAWTURB or SURF_DRAWTILED);
      for i := 0 to 1 do
      begin
        _out.extents[i] := 16384;
        _out.texturemins[i] := -8192;
      end;
      GL_SubdivideSurface(_out); // cut up polygon for warps
      goto continue1;
    end;
    continue1:
    inc(_in);
    inc(_out);
  end;
end;

procedure TBSPFile.LoadLeafs(l: PBSPLump);
var
  _in: PBSPLeaf;
  _out: Pmleaf_t;
  i, j, count, p: integer;
begin
  _in := PBSPLeaf(@mod_base[l.Offset]);
  if l.Length mod SizeOf(TBSPLeaf) <> 0 then
    Funny_Lump_Size;
  count := l.Length div SizeOf(TBSPLeaf);
  _out := Hunk_AllocName(count * SizeOf(mleaf_t), loadname);

  loadmodel.leafs := Pmleaf_tArray(_out);
  loadmodel.numleafs := count;

  for i := 0 to count - 1 do
  begin
    for j := 0 to 2 do
    begin
      _out.minmaxs[j] := LittleShort(_in.mins[j]);
      _out.minmaxs[3 + j] := LittleShort(_in.maxs[j]);
    end;

    p := LittleLong(_in.contents);
    _out.contents := p;

    _out.firstmarksurface := @loadmodel.marksurfaces[LittleShort(_in.firstmarksurface)]; // VJ SOS SOS SOS

    _out.nummarksurfaces := LittleShort(_in.nummarksurfaces);

    p := LittleLong(_in.visofs);
    if p = -1 then
      _out.compressed_vis := nil
    else
      _out.compressed_vis := @loadmodel.visdata[p]; // VJ Should check this
    _out.efrags := nil;

    for j := 0 to 3 do
      _out.ambient_sound_level[j] := _in.ambient_level[j];

    // gl underwater warp
    if _out.contents <> CONTENTS_EMPTY then
    begin
      for j := 0 to _out.nummarksurfaces - 1 do
        _out.firstmarksurface[j].flags := _out.firstmarksurface[j].flags or SURF_UNDERWATER;
    end;
    inc(_in);
    inc(_out);
  end;
end;

procedure TBSPFile.LoadLighting(l: PBSPLump);
begin
  if l.Length = 0 then
  begin
    loadmodel.lightdata := nil;
    exit;
  end;

  loadmodel.lightdata := Hunk_AllocName(l.Length, loadname);
  memcpy(loadmodel.lightdata, @mod_base[l.Offset], l.Length);
end;

procedure TBSPFile.LoadMap_HalfLife(mdl: PBSPModelFile; buffer: pointer);
var
  i, j: integer;
  header: PBSPHeader;
  bm: PBSPModel;
  name: array[0..9] of char;
begin
  gl_lightmap_format := GL_RGB;
  loadmodel._type := mod_brush;

  header := PBSPHeader(buffer);
  //
  // check ID :)

// swap all the lumps
  mod_base := PByteArray(header);

  for i := 0 to SizeOf(TBSPHeader) div 4 - 1 do
    PIntegerArray(header)[i] := LittleLong(PIntegerArray(header)[i]);

// load into heap

  LoadVertexes(@header.lumps[LUMP_VERTEXES]);
  LoadEdges(@header.lumps[LUMP_EDGES]);
  LoadSurfedges(@header.lumps[LUMP_SURFEDGES]);
  LoadTexturesHL(@header.lumps[LUMP_TEXTURES]);
  LoadLighting(@header.lumps[LUMP_LIGHTING]);
  LoadPlanes(@header.lumps[LUMP_PLANES]);
  LoadTexinfo(@header.lumps[LUMP_TEXINFO]);
  LoadFaces(@header.lumps[LUMP_FACES]);
  LoadMarksurfaces(@header.lumps[LUMP_MARKSURFACES]);
  LoadVisibility(@header.lumps[LUMP_VISIBILITY]);
  LoadLeafs(@header.lumps[LUMP_LEAFS]);
  LoadNodes(@header.lumps[LUMP_NODES]);
  LoadClipnodes(@header.lumps[LUMP_CLIPNODES]);
  LoadEntities(@header.lumps[LUMP_ENTITIES]);
  LoadSubmodels(@header.lumps[LUMP_MODELS]);

  MakeHull0;

  mdl.numframes := 2; // regular and alternate animation

//
// set up the submodels (FIXME: this is confusing)
//
  for i := 0 to mdl.numsubmodels - 1 do
  begin
    bm := @mdl.submodels[i];

    mdl.hulls[0].firstclipnode := bm.headnode[0];
    for j := 1 to MAX_MAP_HULLS - 1 do
    begin
      mdl.hulls[j].firstclipnode := bm.headnode[j];
      mdl.hulls[j].lastclipnode := mdl.numclipnodes - 1;
    end;

    mdl.firstmodelsurface := bm.firstface;
    mdl.nummodelsurfaces := bm.numfaces;

    VectorCopy(@bm.maxs, @mdl.maxs);
    VectorCopy(@bm.mins, @mdl.mins);

    mdl.radius := RadiusFromBounds(@mdl.mins, @mdl.maxs);

    mdl.numleafs := bm.visleafs;

    if i < mdl.numsubmodels - 1 then
    begin // duplicate the basic information
      sprintf(name, '*' + IntToStr(i + 1));
      loadmodel := Mod_FindName(name);
      loadmodel^ := mdl^;
      strcpy(loadmodel.name, name);
      mdl := loadmodel;
    end;
  end;
end;

procedure TBSPFile.LoadMap_QuakeI(mdl: PBSPModelFile; buffer: pointer);
var
  i, j: integer;
  header: PBSPHeader;
  bm: PBSPModel;
  name: array[0..9] of char;
begin
  gl_lightmap_format := GL_LUMINANCE;
  loadmodel._type := mod_brush;

  header := PBSPHeader(buffer);
  //
  // check ID :)

// swap all the lumps
  mod_base := PByteArray(header);

  for i := 0 to SizeOf(TBSPHeader) div 4 - 1 do
    PIntegerArray(header)[i] := LittleLong(PIntegerArray(header)[i]);

// load into heap

  LoadVertexes(@header.lumps[LUMP_VERTEXES]);
  LoadEdges(@header.lumps[LUMP_EDGES]);
  LoadSurfedges(@header.lumps[LUMP_SURFEDGES]);
  LoadTextures(@header.lumps[LUMP_TEXTURES]);
  LoadLighting(@header.lumps[LUMP_LIGHTING]);
  LoadPlanes(@header.lumps[LUMP_PLANES]);
  LoadTexinfo(@header.lumps[LUMP_TEXINFO]);
  LoadFaces(@header.lumps[LUMP_FACES]);
  LoadMarksurfaces(@header.lumps[LUMP_MARKSURFACES]);
  LoadVisibility(@header.lumps[LUMP_VISIBILITY]);
  LoadLeafs(@header.lumps[LUMP_LEAFS]);
  LoadNodes(@header.lumps[LUMP_NODES]);
  LoadClipnodes(@header.lumps[LUMP_CLIPNODES]);
  LoadEntities(@header.lumps[LUMP_ENTITIES]);
  LoadSubmodels(@header.lumps[LUMP_MODELS]);

  MakeHull0;

  mdl.numframes := 2; // regular and alternate animation

//
// set up the submodels (FIXME: this is confusing)
//
  for i := 0 to mdl.numsubmodels - 1 do
  begin
    bm := @mdl.submodels[i];

    mdl.hulls[0].firstclipnode := bm.headnode[0];
    for j := 1 to MAX_MAP_HULLS - 1 do
    begin
      mdl.hulls[j].firstclipnode := bm.headnode[j];
      mdl.hulls[j].lastclipnode := mdl.numclipnodes - 1;
    end;

    mdl.firstmodelsurface := bm.firstface;
    mdl.nummodelsurfaces := bm.numfaces;

    VectorCopy(@bm.maxs, @mdl.maxs);
    VectorCopy(@bm.mins, @mdl.mins);

    mdl.radius := RadiusFromBounds(@mdl.mins, @mdl.maxs);

    mdl.numleafs := bm.visleafs;

    if i < mdl.numsubmodels - 1 then
    begin // duplicate the basic information
      sprintf(name, '*%d', [i + 1]);
      loadmodel := Mod_FindName(name);
      loadmodel^ := mdl^;
      strcpy(loadmodel.name, name);
      mdl := loadmodel;
    end;
  end;
end;

procedure TBSPFile.LoadMarksurfaces(l: PBSPLump);
var
  i, j, count: integer;
  _in: PShortArray;
  _out: Pmsurface_tPArray;
begin
  _in := PShortArray(@mod_base[l.Offset]);
  if l.Length mod SizeOf(short) <> 0 then
    Funny_Lump_Size;
  count := l.Length div SizeOf(short);
  _out := Hunk_AllocName(count * SizeOf(Pmsurface_t), loadname);

  loadmodel.marksurfaces := _out;
  loadmodel.nummarksurfaces := count;

  for i := 0 to count - 1 do
  begin
    j := LittleShort(_in[i]);
    if j >= loadmodel.numsurfaces then
      Sys_Error('Mod_ParseMarksurfaces: bad surface number');
    _out[i] := @loadmodel.surfaces[j];
  end;
end;

procedure TBSPFile.LoadNodes(l: PBSPLump);
var
  i, j, count, p: integer;
  _in: PBSPNode;
  _out: Pmnode_t;
begin
  _in := PBSPNode(@mod_base[l.Offset]);
  if l.Length mod SizeOf(TBSPNode) <> 0 then
    Funny_Lump_Size;
  count := l.Length div SizeOf(TBSPNode);
  _out := Hunk_AllocName(count * SizeOf(mnode_t), loadname);

  loadmodel.nodes := _out;
  loadmodel.numnodes := count;

  for i := 0 to count - 1 do
  begin
    for j := 0 to 2 do
    begin
      _out.minmaxs[j] := LittleShort(_in.mins[j]);
      _out.minmaxs[3 + j] := LittleShort(_in.maxs[j]);
    end;

    p := LittleLong(_in.PlaneIndex);
    _out.plane := @loadmodel.planes[p];

    _out.firstsurface := LittleShort(_in.firstface);
    _out.numsurfaces := LittleShort(_in.numfaces);

    for j := 0 to 1 do
    begin
      p := LittleShort(_in.children[j]);
      if p >= 0 then
      begin
        _out.children[j] := loadmodel.nodes; //[p] // VJ check this
        inc(_out.children[j], p);
      end
      else
        _out.children[j] := Pmnode_t(@loadmodel.leafs[-1 - p]); // VJ check this
    end;
    inc(_in);
    inc(_out);
  end;

  Mod_SetParent(loadmodel.nodes, nil); // sets nodes and leafs
end;

procedure TBSPFile.LoadPlanes(l: PBSPLump);
var
  i, j: integer;
  _out: Pmplane_t;
  _in: PBSPPlane;
  count: integer;
  bits: integer;
begin
  _in := PBSPPlane(@mod_base[l.Offset]);
  if l.Length mod SizeOf(TBSPPlane) <> 0 then
    Funny_Lump_Size;
  count := l.Length div SizeOf(TBSPPlane);
  _out := Hunk_AllocName(count * 2 * SizeOf(mplane_t), loadname);

  loadmodel.planes := Pmplane_tArray(_out);
  loadmodel.numplanes := count;

  for i := 0 to count - 1 do
  begin
    bits := 0;
    for j := 0 to 2 do
    begin
      _out.normal[j] := LittleFloat(_in.normal[j]);
      if _out.normal[j] < 0 then
        bits := bits or (1 shl j);
    end;

    _out.dist := LittleFloat(_in.dist);
    _out.PlaneType := LittleLong(_in.PlaneType);
    _out.signbits := bits;
    inc(_in);
    inc(_out);
  end;
end;

procedure TBSPFile.LoadSubmodels(l: PBSPLump);
var
  _in: PBSPModel;
  _out: PBSPModel;
  i, j, count: integer;
begin
  _in := PBSPModel(@mod_base[l.Offset]);
  if l.Length mod SizeOf(TBSPModel) <> 0 then
    Funny_Lump_Size;
  count := l.Length div SizeOf(TBSPModel);
  _out := Hunk_AllocName(count * SizeOf(TBSPModel), loadname);

  loadmodel.submodels := PBSPModelArray(_out);
  loadmodel.numsubmodels := count;

  for i := 0 to count - 1 do
  begin
    for j := 0 to 2 do
    begin // spread the mins / maxs by a pixel
      _out.mins[j] := LittleFloat(_in.mins[j]) - 1;
      _out.maxs[j] := LittleFloat(_in.maxs[j]) + 1;
      _out.origin[j] := LittleFloat(_in.origin[j]);
    end;
    for j := 0 to MAX_MAP_HULLS - 1 do
      _out.headnode[j] := LittleLong(_in.headnode[j]);
    _out.visleafs := LittleLong(_in.visleafs);
    _out.firstface := LittleLong(_in.firstface);
    _out.numfaces := LittleLong(_in.numfaces);
    inc(_in);
    inc(_out);
  end;
end;

procedure TBSPFile.LoadSurfedges(l: PBSPLump);
var
  i, count: integer;
  _in, _out: PIntegerArray;
begin
  _in := PIntegerArray(@mod_base[l.Offset]);
  if l.Length mod SizeOf(integer) <> 0 then
    Funny_Lump_Size;
  count := l.Length div SizeOf(integer);
  _out := Hunk_AllocName(count * SizeOf(integer), loadname);

  loadmodel.surfedges := _out;
  loadmodel.numsurfedges := count;

  for i := 0 to count - 1 do
    _out[i] := LittleLong(_in[i]);
end;

procedure TBSPFile.LoadTexinfo(l: PBSPLump);
var
  _in: Ptexinfo_t;
  _out: Pmtexinfo_t;
  i, j, count: integer;
  miptex: integer;
  len1, len2: single;
begin
  _in := Ptexinfo_t(@mod_base[l.Offset]);
  if l.Length mod SizeOf(texinfo_t) <> 0 then
    Funny_Lump_Size;
  count := l.Length div SizeOf(texinfo_t);
  _out := Hunk_AllocName(count * SizeOf(mtexinfo_t), loadname);

  loadmodel.texinfo := Pmtexinfo_tArray(_out);
  loadmodel.numtexinfo := count;

  for i := 0 to count - 1 do
  begin
    for j := 0 to 7 do
      _out.vecs[0][j] := LittleFloat(_in.vecs[0][j]);
    len1 := VectorLength(@_out.vecs[0]); // VJ was Length()
    len2 := VectorLength(@_out.vecs[1]);
    len1 := (len1 + len2) / 2;
    if len1 < 0.32 then
      _out.mipadjust := 4
    else if len1 < 0.49 then
      _out.mipadjust := 3
    else if len1 < 0.99 then
      _out.mipadjust := 2
    else
      _out.mipadjust := 1;
(*
#if 0
    if (len1 + len2 < 0.001)
      out->mipadjust = 1;    // don't crash
    else
      out->mipadjust = 1 / floor( (len1+len2)/2 + 0.1 );
#endif
*)
    miptex := LittleLong(_in.miptex);
    _out.flags := LittleLong(_in.flags);

    if loadmodel.textures = nil then
    begin
      _out.texture := r_notexture_mip; // checkerboard texture
      _out.flags := 0;
    end
    else
    begin
      if miptex >= loadmodel.numtextures then
        Sys_Error('miptex >= loadmodel.numtextures');
      _out.texture := loadmodel.textures[miptex];
      if _out.texture = nil then
      begin
        _out.texture := r_notexture_mip; // texture not found
        _out.flags := 0;
      end;
    end;
    inc(_in);
    inc(_out);
  end;
end;

procedure TBSPFile.LoadTextures(l: PBSPLump);
const
  ANIM_CYCLE = 2;
var
  i, j, pixels, altmax: integer;
  num, max: char;
  mt: Pmiptex_t;
  tx, tx2: Ptexture_t;
  anims: array[0..9] of Ptexture_t;
  altanims: array[0..9] of Ptexture_t;
  m: Pdmiptexlump_t;
begin
  if l.Length = 0 then
  begin
    loadmodel.textures := nil;
    exit;
  end;
  m := Pdmiptexlump_t(@mod_base[l.Offset]);

  m.nummiptex := LittleLong(m.nummiptex);

  loadmodel.numtextures := m.nummiptex;
  loadmodel.textures := Hunk_AllocName(m.nummiptex * SizeOf(texture_t), loadname);
  for i := 0 to m.nummiptex - 1 do
  begin
    m.dataofs[i] := LittleLong(m.dataofs[i]);
    if m.dataofs[i] = -1 then
      continue;
    mt := Pmiptex_t(integer(m) + m.dataofs[i]);
    mt.width := LittleLong(mt.width);
    mt.height := LittleLong(mt.height);
    for j := 0 to MIPLEVELS - 1 do
      mt.offsets[j] := LittleLong(mt.offsets[j]);

    if (mt.width and 15 <> 0) or (mt.height and 15 <> 0) then
      Sys_Error('Texture %s is not 16 aligned', [mt.name]);
    pixels := mt.width * mt.height div 64 * 85; // VJ should check operation priorities
    tx := Hunk_AllocName(SizeOf(texture_t) + pixels, loadname);
    loadmodel.textures[i] := tx;

    memcpy(@tx.name, @mt.name, SizeOf(tx.name));
    tx.width := mt.width;
    tx.height := mt.height;
    for j := 0 to MIPLEVELS - 1 do
      tx.offsets[j] := mt.offsets[j] + SizeOf(texture_t) - SizeOf(miptex_t);
    // the pixels immediately follow the structures
    memcpy(pointer(integer(tx) + SizeOf(texture_t)), pointer(integer(mt) + SizeOf(miptex_t)), pixels);

    if Q_strncmp(mt.name, 'sky', 3) = 0 then
      R_InitSky(tx)
    else
    begin
      texture_mode := GL_LINEAR_MIPMAP_NEAREST; //_LINEAR;

      textures_path := loadname;
      tx.gl_texturenum := GL_LoadTexture(mt.name, tx.width, tx.height, pointer(integer(tx) + SizeOf(texture_t)), true, false);
      textures_path := '';

      texture_mode := GL_LINEAR;
    end;
  end;

//
// sequence the animations
//
  for i := 0 to m.nummiptex - 1 do
  begin
    tx := loadmodel.textures[i];
    if (tx = nil) or (tx.name[0] <> '+') then
      continue;
    if tx.anim_next <> nil then
      continue; // allready sequenced

  // find the number of frames in the animation
    ZeroMemory(@anims, SizeOf(anims));
    ZeroMemory(@altanims, SizeOf(altanims));

    max := tx.name[1];
    altmax := 0;
    if (max >= 'a') and (max <= 'z') then
      max := Chr(Ord(max) - (Ord('a') - Ord('A')));
    if (max >= '0') and (max <= '9') then
    begin
      max := Chr(Ord(max) - Ord('0'));
      altmax := 0;
      anims[Ord(max)] := tx;
      inc(max);
    end
    else if (max >= 'A') and (max <= 'J') then
    begin
      altmax := Ord(max) - Ord('A');
      max := #0;
      altanims[altmax] := tx;
      inc(altmax);
    end
    else
      Sys_Error('Bad animating texture %s', [tx.name]);

    for j := i + 1 to m.nummiptex - 1 do
    begin
      tx2 := loadmodel.textures[j];
      if (tx2 = nil) or (tx2.name[0] <> '+') then
        continue;
      if strcmp(PChar(@tx2.name[2]), PChar(@(tx.name[2]))) <> 0 then // VJ check!
        continue;

      num := tx2.name[1];
      if (num >= 'a') and (num <= 'z') then
        num := Chr(Ord(num) - (Ord('a') - Ord('A')));
      if (num >= '0') and (num <= '9') then
      begin
        num := Chr(Ord(num) - Ord('0'));
        anims[Ord(num)] := tx2;
        if Ord(num) + 1 > Ord(max) then
          max := Chr(Ord(num) + 1);
      end
      else if (num >= 'A') and (num <= 'J') then
      begin
        num := Chr(Ord(num) - Ord('A'));
        altanims[Ord(num)] := tx2;
        if Ord(num) + 1 > altmax then
          altmax := Ord(num) + 1;
      end
      else
        Sys_Error('Bad animating texture %s', [tx.name]);
    end;

  // link them all together
    for j := 0 to Ord(max) - 1 do
    begin
      tx2 := anims[j];
      if tx2 = nil then
        Sys_Error('Missing frame %d of %s', [j, tx.name]);
      tx2.anim_total := Ord(max) * ANIM_CYCLE;
      tx2.anim_min := j * ANIM_CYCLE;
      tx2.anim_max := (j + 1) * ANIM_CYCLE;
      tx2.anim_next := anims[(j + 1) mod Ord(max)];
      if altmax <> 0 then
        tx2.alternate_anims := altanims[0];
    end;
    for j := 0 to altmax - 1 do
    begin
      tx2 := altanims[j];
      if tx2 = nil then
        Sys_Error('Missing frame %d of %s', [j, tx.name]);
      tx2.anim_total := altmax * ANIM_CYCLE;
      tx2.anim_min := j * ANIM_CYCLE;
      tx2.anim_max := (j + 1) * ANIM_CYCLE;
      tx2.anim_next := altanims[(j + 1) mod altmax];
      if max <> #0 then
        tx2.alternate_anims := anims[0];
    end;
  end;
end;

procedure TBSPFile.LoadTexturesHL(l: PBSPLump);
const
  ANIM_CYCLE = 2;
var
  i, j, pixels, altmax: integer;
  num, max: char;
  mt: Pmiptex_t;
  tx, tx2: Ptexture_t;
  anims: array[0..9] of Ptexture_t;
  altanims: array[0..9] of Ptexture_t;
  m: Pdmiptexlump_t;
begin
  if l.Length = 0 then
  begin
    loadmodel.textures := nil;
    exit;
  end;
  m := Pdmiptexlump_t(@mod_base[l.Offset]);

  m.nummiptex := LittleLong(m.nummiptex);

  loadmodel.numtextures := m.nummiptex;
  loadmodel.textures := Hunk_AllocName(m.nummiptex * SizeOf(texture_t), loadname);
  for i := 0 to m.nummiptex - 1 do
  begin
    m.dataofs[i] := LittleLong(m.dataofs[i]);
    if m.dataofs[i] = -1 then
      continue;
    mt := Pmiptex_t(integer(m) + m.dataofs[i]);
    mt.width := LittleLong(mt.width);
    mt.height := LittleLong(mt.height);

    for j := 0 to MIPLEVELS - 1 do
      mt.offsets[j] := LittleLong(mt.offsets[j]);

    if (mt.width and 15 <> 0) or (mt.height and 15 <> 0) then
      Sys_Error('Texture %s is not 16 aligned', [mt.name]);

    pixels := mt.width * mt.height div 64 * 85; // VJ should check operation priorities

    tx := Hunk_AllocName(SizeOf(texture_t) + pixels, loadname);
    loadmodel.textures[i] := tx;

    memcpy(@tx.name, @mt.name, SizeOf(tx.name));
    tx.width := mt.width;
    tx.height := mt.height;
    for j := 0 to MIPLEVELS - 1 do
      tx.offsets[j] := mt.offsets[j] + SizeOf(texture_t) - SizeOf(miptex_t);

    if (mt.offsets[0] = 0)
      and (mt.offsets[1] = 0)
      and (mt.offsets[2] = 0)
      and (mt.offsets[3] = 0) then
      if true then
      begin
        if Q_strncmp(mt.name, 'sky', 3) = 0 then
//             R_InitSky(tx)
        else
        begin
          texture_mode := {GL_LINEAR_MIPMAP_NEAREST} GL_LINEAR; //_LINEAR;

          textures_path := 'cs'; //+loadname;
          tx.gl_texturenum := GL_LoadTexture24(mt.name, tx.width, tx.height, nil, true, false, nil);
          textures_path := '';

          texture_mode := GL_LINEAR;
        end;
      end
      else
      begin
{}
        memcpy(pointer(integer(tx) + SizeOf(texture_t)), pointer(integer(mt) + SizeOf(miptex_t)), pixels);

        if Q_strncmp(mt.name, 'sky', 3) = 0 then
//             R_InitSky(tx)
        else
        begin
          texture_mode := GL_LINEAR {GL_LINEAR_MIPMAP_NEAREST}; //_LINEAR;

          textures_path := loadname;
          tx.gl_texturenum := GL_LoadTexture24(mt.name, tx.width, tx.height,
          pointer(integer(tx) + SizeOf(texture_t)), true, false,
          pointer(integer(mt) + SizeOf(miptex_t) + pixels + 2));
          textures_path := '';

          texture_mode := GL_LINEAR;
        end;
      end;
  end;
//
// sequence the animations
//
  for i := 0 to m.nummiptex - 1 do
  begin
    tx := loadmodel.textures[i];
    if (tx = nil) or (tx.name[0] <> '+') then
      continue;
    if tx.anim_next <> nil then
      continue; // allready sequenced

  // find the number of frames in the animation
    ZeroMemory(@anims, SizeOf(anims));
    ZeroMemory(@altanims, SizeOf(altanims));

    max := tx.name[1];
    altmax := 0;
    if (max >= 'a') and (max <= 'z') then
      max := Chr(Ord(max) - (Ord('a') - Ord('A')));
    if (max >= '0') and (max <= '9') then
    begin
      max := Chr(Ord(max) - Ord('0'));
      altmax := 0;
      anims[Ord(max)] := tx;
      inc(max);
    end
    else if (max >= 'A') and (max <= 'J') then
    begin
      altmax := Ord(max) - Ord('A');
      max := #0;
      altanims[altmax] := tx;
      inc(altmax);
    end
    else
      Sys_Error('Bad animating texture %s', [tx.name]);

    for j := i + 1 to m.nummiptex - 1 do
    begin
      tx2 := loadmodel.textures[j];
      if (tx2 = nil) or (tx2.name[0] <> '+') then
        continue;
      if strcmp(PChar(@tx2.name[2]), PChar(@(tx.name[2]))) <> 0 then // VJ check!
        continue;

      num := tx2.name[1];
      if (num >= 'a') and (num <= 'z') then
        num := Chr(Ord(num) - (Ord('a') - Ord('A')));
      if (num >= '0') and (num <= '9') then
      begin
        num := Chr(Ord(num) - Ord('0'));
        anims[Ord(num)] := tx2;
        if Ord(num) + 1 > Ord(max) then
          max := Chr(Ord(num) + 1);
      end
      else if (num >= 'A') and (num <= 'J') then
      begin
        num := Chr(Ord(num) - Ord('A'));
        altanims[Ord(num)] := tx2;
        if Ord(num) + 1 > altmax then
          altmax := Ord(num) + 1;
      end
      else
        Sys_Error('Bad animating texture %s', [tx.name]);
    end;

  // link them all together
    for j := 0 to Ord(max) - 1 do
    begin
      tx2 := anims[j];
      if tx2 = nil then
        Sys_Error('Missing frame %d of %s', [j, tx.name]);
      tx2.anim_total := Ord(max) * ANIM_CYCLE;
      tx2.anim_min := j * ANIM_CYCLE;
      tx2.anim_max := (j + 1) * ANIM_CYCLE;
      tx2.anim_next := anims[(j + 1) mod Ord(max)];
      if altmax <> 0 then
        tx2.alternate_anims := altanims[0];
    end;
    for j := 0 to altmax - 1 do
    begin
      tx2 := altanims[j];
      if tx2 = nil then
        Sys_Error('Missing frame %d of %s', [j, tx.name]);
      tx2.anim_total := altmax * ANIM_CYCLE;
      tx2.anim_min := j * ANIM_CYCLE;
      tx2.anim_max := (j + 1) * ANIM_CYCLE;
      tx2.anim_next := altanims[(j + 1) mod altmax];
      if max <> #0 then
        tx2.alternate_anims := anims[0];
    end;
  end;
end;

procedure TBSPFile.LoadVertexes(l: PBSPLump);
var
  _in: PBSPVertex;
  _out: Pmvertex_t;
  i, count: integer;
begin
  _in := PBSPVertex(@mod_base[l.Offset]);
  if l.Length mod SizeOf(TBSPVertex) <> 0 then
    Funny_Lump_Size;
  count := l.Length div SizeOf(TBSPVertex);
  _out := Hunk_AllocName(count * SizeOf(mvertex_t), loadname);

  loadmodel.vertexes := Pmvertex_tArray(_out);
  loadmodel.numvertexes := count;

  for i := 0 to count - 1 do
  begin
    _out.position := _in.Position;
    inc(_in); inc(_out);
  end;
end;

procedure TBSPFile.LoadVisibility(l: PBSPLump);
begin
  if l.Length = 0 then
  begin
    loadmodel.visdata := nil;
    exit;
  end;

  loadmodel.visdata := Hunk_AllocName(l.Length, loadname);
  memcpy(loadmodel.visdata, @mod_base[l.Offset], l.Length);
end;

procedure TBSPFile.MakeHull0;
var
  _in, child: Pmnode_t;
  _out: PBSPClipNode;
  i, j, count: integer;
  hull: Phull_t;
begin
  hull := @loadmodel.hulls[0];

  _in := loadmodel.nodes;
  count := loadmodel.numnodes;
  _out := Hunk_AllocName(count * SizeOf(TBSPClipNode), loadname);

  hull.clipnodes := _out;
  hull.firstclipnode := 0;
  hull.lastclipnode := count - 1;
  hull.planes := @loadmodel.planes[0];

  for i := 0 to count - 1 do
  begin
    _out.PlaneIndex := (integer(_in.plane) - integer(loadmodel.planes)) div SizeOf(mplane_t {mnode_t}); // TODO VJ -> should check this
    for j := 0 to 1 do
    begin
      child := _in.children[j];
      if child.contents < 0 then
        _out.children[j] := child.contents
      else
        _out.children[j] := (integer(child) - integer(loadmodel.nodes)) div SizeOf(mnode_t); // VJ CHECK CHECK CHECK!@!!!!!!
    end;
    inc(_in);
    inc(_out);
  end;
end;

initialization
  MOD_BSPFile := TBSPFile.Create;
finalization
  MOD_BSPFile.Free;
end.

