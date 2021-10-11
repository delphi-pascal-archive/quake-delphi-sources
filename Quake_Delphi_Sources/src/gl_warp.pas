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

unit gl_warp;

// gl_warp.c -- sky and water polygons

interface

uses
  Unit_SysTools,
  gl_planes;

var
  skytexturenum: integer;
  solidskytexture: integer;
  alphaskytexture: integer;
  speedscale: single; // for top sky and bottom sky

procedure R_InitSky(mt: Ptexture_t);
procedure GL_SubdivideSurface(fa: Pmsurface_t);
procedure EmitWaterPolys(fa: Pmsurface_t);
procedure EmitSkyPolys(fa: Pmsurface_t);
procedure EmitBothSkyLayers(fa: Pmsurface_t);
procedure R_DrawSkyChain(s: Pmsurface_t);

implementation

uses
  mathlib,
  sys_win,
  gl_model,
  bspfile,
  OpenGL12,
  zone,
  host_h,
  gl_rmain_h,
  gl_rsurf,
  unit_Textures,
  gl_vidnt;

var
  warpface: Pmsurface_t;

//extern cvar_t gl_subdivide_size;

procedure BoundPoly(numverts: integer; verts: PFloatArray; mins: PVector3f; maxs: PVector3f);
var
  i, j: integer;
  v: Pfloat;
begin
  mins[0] := 9999;
  mins[1] := 9999;
  mins[2] := 9999;
  maxs[0] := -9999;
  maxs[1] := -9999;
  maxs[2] := -9999;

  v := @verts[0];
  for i := 0 to numverts - 1 do
    for j := 0 to 2 do // VJ mayby crack loop -> a bit faster ?
    begin
      if v^ < mins[j] then mins[j] := v^;
      if v^ > maxs[j] then maxs[j] := v^;
      inc(v);
    end;
end;

procedure SubdividePolygon(numverts: integer; verts: PFloatArray);
var
  i, j, k: integer;
  mins, maxs: TVector3f;
  m: single;
  v: Pfloat;
  front, back: array[0..63] of TVector3f;
  f, b: integer;
  dist: array[0..63] of single;
  frac: single;
  poly: Pglpoly_t;
  s, t: single;
  tmp: single;
begin
  if numverts > 60 then
    Sys_Error('numverts = %d', [numverts]);

  BoundPoly(numverts, verts, @mins, @maxs);

  for i := 0 to 2 do
  begin
    m := (mins[i] + maxs[i]) * 0.5;
    m := gl_subdivide_size.value * floor(m / gl_subdivide_size.value + 0.5);
    if maxs[i] - m < 8 then
      continue;
    if m - mins[i] < 8 then
      continue;

    // cut it
    v := @verts[i];
    for j := 0 to numverts - 1 do
    begin
      dist[j] := v^ - m;
      inc(v, 3);
    end;

    // wrap cases
    dist[numverts] := dist[0];
    dec(v, i);
    VectorCopy(PVector3f(verts), PVector3f(v));

    f := 0;
    b := 0;
    v := @verts[0];
    for j := 0 to numverts - 1 do
    begin
      if dist[j] >= 0 then
      begin
        VectorCopy(PVector3f(v), @front[f]);
        inc(f);
      end;
      if dist[j] <= 0 then
      begin
        VectorCopy(PVector3f(v), @back[b]);
        inc(b);
      end;
      if (dist[j] = 0) or (dist[j + 1] = 0) then
      else if (dist[j] > 0) <> (dist[j + 1] > 0) then
      begin
        // clip point
        frac := dist[j] / (dist[j] - dist[j + 1]);
        for k := 0 to 2 do
        begin
          tmp := PVector3f(v)[k] + frac * (PVector3f(v)[3 + k] - PVector3f(v)[k]);
          front[f][k] := tmp;
          back[b][k] := tmp;
        end;
        inc(f);
        inc(b);
      end;
      inc(v, 3);
    end;

    SubdividePolygon(f, @front[0]);
    SubdividePolygon(b, @back[0]);
    exit;
  end;

  poly := Hunk_Alloc(SizeOf(glpoly_t) + (numverts - 4) * VERTEXSIZE * SizeOf(single));
  poly.next := warpface.polys;
  warpface.polys := poly;
  poly.numverts := numverts;
  for i := 0 to numverts - 1 do
  begin
    VectorCopy(@verts[0], @poly.verts[i]);
    s := VectorDotProduct(@verts[0], @warpface.texinfo.vecs[0]);
    t := VectorDotProduct(@verts[0], @warpface.texinfo.vecs[1]);
    poly.verts[i][3] := s;
    poly.verts[i][4] := t;
    verts := @verts[3];
  end;
end;

(*
================
GL_SubdivideSurface

Breaks a polygon up along axial 64 unit
boundaries so that turbulent and sky warps
can be done reasonably.
================
*)

procedure GL_SubdivideSurface(fa: Pmsurface_t);
var
  verts: array[0..63] of TVector3f;
  numverts: integer;
  i: integer;
  lindex: integer;
  vec: PVector3f;
begin
  warpface := fa;

  //
  // convert edges back to a normal polygon
  //
  numverts := 0;
  for i := 0 to fa.numedges - 1 do
  begin
    lindex := loadmodel.surfedges[fa.firstedge + i];

    if lindex > 0 then vec := @loadmodel.vertexes[loadmodel.edges[lindex].v[0]].position
    else vec := @loadmodel.vertexes[loadmodel.edges[-lindex].v[1]].position;
    VectorCopy(vec, @verts[numverts]);
    inc(numverts);
  end;

  SubdividePolygon(numverts, @verts[0]);
end;

//=========================================================



// speed up sin calculations - Ed
const
  turbsin: array[0..255] of single = (
{$INCLUDE gl_warp_sin.inc}
    );

const
  TURBSCALE = (256.0 / (2 * M_PI));

(*
=============
EmitWaterPolys

Does a water warp on the pre-fragmented glpoly_t chain
=============
*)

procedure EmitWaterPolys(fa: Pmsurface_t);
var
  p: Pglpoly_t;
  v: PFloatArray;
  i: integer;
  s, t, os, ot: single;
begin
  p := fa.polys;
  while p <> nil do
  begin
    glBegin(GL_POLYGON);
    v := @p.verts[0];
    for i := 0 to p.numverts - 1 do
    begin
      os := v[3];
      ot := v[4];

      s := os + turbsin[int((ot * 0.125 + realtime) * TURBSCALE) and 255];
      s := s * (1.0 / 64);

      t := ot + turbsin[int((os * 0.125 + realtime) * TURBSCALE) and 255];
      t := t * (1.0 / 64);

      glTexCoord2f(s, t);
      glVertex3fv(@v[0]);
      v := @v[VERTEXSIZE]; // VJ check this
    end;
    glEnd;
    p := p.next;
  end;
end;




(*
=============
EmitSkyPolys
=============
*)

procedure EmitSkyPolys(fa: Pmsurface_t);
var
  p: Pglpoly_t;
  v: PVector3f;
  i: integer;
  s, t: single;
  dir: TVector3f;
  length: single;
begin
  p := fa.polys;
  while p <> nil do
  begin
    glBegin(GL_POLYGON);
    v := @p.verts[0];
    for i := 0 to p.numverts - 1 do
    begin
      VectorSubtract(v, @r_origin, @dir);
      dir[2] := dir[2] * 3; // flatten the sphere

      length := dir[0] * dir[0] + dir[1] * dir[1] + dir[2] * dir[2];
      length := sqrt(length);
      length := 6 * 63 / length;

      dir[0] := dir[0] * length;
      dir[1] := dir[1] * length;

      s := (speedscale + dir[0]) * (1.0 / 128);
      t := (speedscale + dir[1]) * (1.0 / 128);

      glTexCoord2f(s, t);
      glVertex3fv(@v[0]);

      v := @PFloatArray(v)[VERTEXSIZE]; // VJ check this. mayby inc(v, VERTEXSIZE) ??
    end;
    glEnd;
    p := p.next;
  end;
end;

(*
===============
EmitBothSkyLayers

Does a sky warp on the pre-fragmented glpoly_t chain
This will be called for brushmodels, the world
will have them chained together.
===============
*)

procedure EmitBothSkyLayers(fa: Pmsurface_t);
begin
  GL_DisableMultitexture;

  GL_Bind(solidskytexture);
  speedscale := realtime * 8;
  speedscale := speedscale - int(speedscale) and (not 127); // VJ check this

  EmitSkyPolys(fa);

  glEnable(GL_BLEND);
  GL_Bind(alphaskytexture);
  speedscale := realtime * 16;
  speedscale := speedscale - int(speedscale) and (not 127); // VJ check this

  EmitSkyPolys(fa);

  glDisable(GL_BLEND);
end;

//(*
//#ifndef QUAKE2
(*
=================
R_DrawSkyChain
=================
*)

procedure R_DrawSkyChain(s: Pmsurface_t);
var
  fa: Pmsurface_t;
begin
  GL_DisableMultitexture;

  // used when gl_texsort is on
  GL_Bind(solidskytexture);
  speedscale := realtime * 8;
  speedscale := speedscale - (int(speedscale) and (not 127));

  fa := s;
  while fa <> nil do
  begin
    EmitSkyPolys(fa);
    fa := fa.texturechain;
  end;

  glEnable(GL_BLEND);
  GL_Bind(alphaskytexture);
  speedscale := realtime * 16;
  speedscale := speedscale - (int(speedscale) and (not 127));

  fa := s;
  while fa <> nil do
  begin
    EmitSkyPolys(fa);
    fa := fa.texturechain;
  end;

  glDisable(GL_BLEND);
end;

//#endif
//*)

(*
=================================================================

  Quake 2 environment sky

=================================================================
*)

(*
#ifdef QUAKE2


#define  SKY_TEX    2000

/*
=================================================================

  PCX Loading

=================================================================
*/

typedef struct
{
    char  manufacturer;
    char  version;
    char  encoding;
    char  bits_per_pixel;
    unsigned short  xmin,ymin,xmax,ymax;
    unsigned short  hres,vres;
    unsigned char  palette[48];
    char  reserved;
    char  color_planes;
    unsigned short  bytes_per_line;
    unsigned short  palette_type;
    char  filler[58];
    unsigned   data;      // unbounded
} pcx_t;

byte  *pcx_rgb;

/*
============
LoadPCX
============
*/
void LoadPCX (FILE *f)
{
  pcx_t  *pcx, pcxbuf;
  byte  palette[768];
  byte  *pix;
  int    x, y;
  int    dataByte, runLength;
  int    count;

//
// parse the PCX file
//
  fread (&pcxbuf, 1, sizeof(pcxbuf), f);

  pcx = &pcxbuf;

  if (pcx->manufacturer != 0x0a
    || pcx->version != 5
    || pcx->encoding != 1
    || pcx->bits_per_pixel != 8
    || pcx->xmax >= 320
    || pcx->ymax >= 256)
  {
    Con_Printf ("Bad pcx file\n");
    return;
  }

  // seek to palette
  fseek (f, -768, SEEK_END);
  fread (palette, 1, 768, f);

  fseek (f, sizeof(pcxbuf) - 4, SEEK_SET);

  count = (pcx->xmax+1) * (pcx->ymax+1);
  pcx_rgb = malloc( count * 4);

  for (y=0 ; y<=pcx->ymax ; y++)
  {
    pix = pcx_rgb + 4*y*(pcx->xmax+1);
    for (x=0 ; x<=pcx->ymax ; )
    {
      dataByte = fgetc(f);

      if((dataByte & 0xC0) == 0xC0)
      {
        runLength = dataByte & 0x3F;
        dataByte = fgetc(f);
      }
      else
        runLength = 1;

      while(runLength-- > 0)
      {
        pix[0] = palette[dataByte*3];
        pix[1] = palette[dataByte*3+1];
        pix[2] = palette[dataByte*3+2];
        pix[3] = 255;
        pix += 4;
        x++;
      }
    }
  }
}

/*
=========================================================

TARGA LOADING

=========================================================
*/

typedef struct _TargaHeader {
  unsigned char   id_length, colormap_type, image_type;
  unsigned short  colormap_index, colormap_length;
  unsigned char  colormap_size;
  unsigned short  x_origin, y_origin, width, height;
  unsigned char  pixel_size, attributes;
} TargaHeader;


TargaHeader    targa_header;
byte      *targa_rgba;

int fgetLittleShort (FILE *f)
{
  byte  b1, b2;

  b1 = fgetc(f);
  b2 = fgetc(f);

  return (short)(b1 + b2*256);
}

int fgetLittleLong (FILE *f)
{
  byte  b1, b2, b3, b4;

  b1 = fgetc(f);
  b2 = fgetc(f);
  b3 = fgetc(f);
  b4 = fgetc(f);

  return b1 + (b2<<8) + (b3<<16) + (b4<<24);
}


/*
=============
LoadTGA
=============
*/
void LoadTGA (FILE *fin)
{
  int        columns, rows, numPixels;
  byte      *pixbuf;
  int        row, column;

  targa_header.id_length = fgetc(fin);
  targa_header.colormap_type = fgetc(fin);
  targa_header.image_type = fgetc(fin);

  targa_header.colormap_index = fgetLittleShort(fin);
  targa_header.colormap_length = fgetLittleShort(fin);
  targa_header.colormap_size = fgetc(fin);
  targa_header.x_origin = fgetLittleShort(fin);
  targa_header.y_origin = fgetLittleShort(fin);
  targa_header.width = fgetLittleShort(fin);
  targa_header.height = fgetLittleShort(fin);
  targa_header.pixel_size = fgetc(fin);
  targa_header.attributes = fgetc(fin);

  if (targa_header.image_type!=2
    && targa_header.image_type!=10)
    Sys_Error ("LoadTGA: Only type 2 and 10 targa RGB images supported\n");

  if (targa_header.colormap_type !=0
    || (targa_header.pixel_size!=32 && targa_header.pixel_size!=24))
    Sys_Error ("Texture_LoadTGA: Only 32 or 24 bit images supported (no colormaps)\n");

  columns = targa_header.width;
  rows = targa_header.height;
  numPixels = columns * rows;

  targa_rgba = malloc (numPixels*4);

  if (targa_header.id_length != 0)
    fseek(fin, targa_header.id_length, SEEK_CUR);  // skip TARGA image comment

  if (targa_header.image_type==2) {  // Uncompressed, RGB images
    for(row=rows-1; row>=0; row--) {
      pixbuf = targa_rgba + row*columns*4;
      for(column=0; column<columns; column++) {
        unsigned char red,green,blue,alphabyte;
        switch (targa_header.pixel_size) {
          case 24:

              blue = getc(fin);
              green = getc(fin);
              red = getc(fin);
              *pixbuf++ = red;
              *pixbuf++ = green;
              *pixbuf++ = blue;
              *pixbuf++ = 255;
              break;
          case 32:
              blue = getc(fin);
              green = getc(fin);
              red = getc(fin);
              alphabyte = getc(fin);
              *pixbuf++ = red;
              *pixbuf++ = green;
              *pixbuf++ = blue;
              *pixbuf++ = alphabyte;
              break;
        }
      }
    }
  }
  else if (targa_header.image_type==10) {   // Runlength encoded RGB images
    unsigned char red,green,blue,alphabyte,packetHeader,packetSize,j;
    for(row=rows-1; row>=0; row--) {
      pixbuf = targa_rgba + row*columns*4;
      for(column=0; column<columns; ) {
        packetHeader=getc(fin);
        packetSize = 1 + (packetHeader & 0x7f);
        if (packetHeader & 0x80) {        // run-length packet
          switch (targa_header.pixel_size) {
            case 24:
                blue = getc(fin);
                green = getc(fin);
                red = getc(fin);
                alphabyte = 255;
                break;
            case 32:
                blue = getc(fin);
                green = getc(fin);
                red = getc(fin);
                alphabyte = getc(fin);
                break;
          }

          for(j=0;j<packetSize;j++) {
            *pixbuf++=red;
            *pixbuf++=green;
            *pixbuf++=blue;
            *pixbuf++=alphabyte;
            column++;
            if (column==columns) { // run spans across rows
              column=0;
              if (row>0)
                row--;
              else
                goto breakOut;
              pixbuf = targa_rgba + row*columns*4;
            }
          }
        }
        else {                            // non run-length packet
          for(j=0;j<packetSize;j++) {
            switch (targa_header.pixel_size) {
              case 24:
                  blue = getc(fin);
                  green = getc(fin);
                  red = getc(fin);
                  *pixbuf++ = red;
                  *pixbuf++ = green;
                  *pixbuf++ = blue;
                  *pixbuf++ = 255;
                  break;
              case 32:
                  blue = getc(fin);
                  green = getc(fin);
                  red = getc(fin);
                  alphabyte = getc(fin);
                  *pixbuf++ = red;
                  *pixbuf++ = green;
                  *pixbuf++ = blue;
                  *pixbuf++ = alphabyte;
                  break;
            }
            column++;
            if (column==columns) { // pixel packet run spans across rows
              column=0;
              if (row>0)
                row--;
              else
                goto breakOut;
              pixbuf = targa_rgba + row*columns*4;
            }
          }
        }
      }
      breakOut:;
    }
  }

  fclose(fin);
}

/*
==================
R_LoadSkys
==================
*/
char  *suf[6] = {"rt", "bk", "lf", "ft", "up", "dn"};
void R_LoadSkys (void)
{
  int    i;
  FILE  *f;
  char  name[64];

  for (i=0 ; i<6 ; i++)
  {
    GL_Bind (SKY_TEX + i);
    sprintf (name, "gfx/env/bkgtst%s.tga", suf[i]);
    COM_FOpenFile (name, &f);
    if (!f)
    {
      Con_Printf ("Couldn't load %s\n", name);
      continue;
    }
    LoadTGA (f);
//    LoadPCX (f);

    glTexImage2D (GL_TEXTURE_2D, 0, gl_solid_format, 256, 256, 0, GL_RGBA, GL_UNSIGNED_BYTE, targa_rgba);
//    glTexImage2D (GL_TEXTURE_2D, 0, gl_solid_format, 256, 256, 0, GL_RGBA, GL_UNSIGNED_BYTE, pcx_rgb);

    free (targa_rgba);
//    free (pcx_rgb);

    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  }
}


vec3_t  skyclip[6] = {
  {1,1,0},
  {1,-1,0},
  {0,-1,1},
  {0,1,1},
  {1,0,1},
  {-1,0,1}
};
int  c_sky;

// 1 = s, 2 = t, 3 = 2048
int  st_to_vec[6][3] =
{
  {3,-1,2},
  {-3,1,2},

  {1,3,2},
  {-1,-3,2},

  {-2,-1,3},    // 0 degrees yaw, look straight up
  {2,-1,-3}    // look straight down

//  {-1,2,3},
//  {1,2,-3}
};

// s = [0]/[2], t = [1]/[2]
int  vec_to_st[6][3] =
{
  {-2,3,1},
  {2,3,-1},

  {1,3,2},
  {-1,3,-2},

  {-2,-1,3},
  {-2,1,-3}

//  {-1,2,3},
//  {1,2,-3}
};

float  skymins[2][6], skymaxs[2][6];

void DrawSkyPolygon (int nump, vec3_t vecs)
{
  int    i,j;
  vec3_t  v, av;
  float  s, t, dv;
  int    axis;
  float  *vp;

  c_sky++;
#if 0
glBegin (GL_POLYGON);
for (i=0 ; i<nump ; i++, vecs+=3)
{
  VectorAdd(vecs, r_origin, v);
  glVertex3fv (v);
}
glEnd();
return;
#endif
  // decide which face it maps to
  VectorCopy (vec3_origin, v);
  for (i=0, vp=vecs ; i<nump ; i++, vp+=3)
  {
    VectorAdd (vp, v, v);
  }
  av[0] = fabs(v[0]);
  av[1] = fabs(v[1]);
  av[2] = fabs(v[2]);
  if (av[0] > av[1] && av[0] > av[2])
  {
    if (v[0] < 0)
      axis = 1;
    else
      axis = 0;
  }
  else if (av[1] > av[2] && av[1] > av[0])
  {
    if (v[1] < 0)
      axis = 3;
    else
      axis = 2;
  }
  else
  {
    if (v[2] < 0)
      axis = 5;
    else
      axis = 4;
  }

  // project new texture coords
  for (i=0 ; i<nump ; i++, vecs+=3)
  {
    j = vec_to_st[axis][2];
    if (j > 0)
      dv = vecs[j - 1];
    else
      dv = -vecs[-j - 1];

    j = vec_to_st[axis][0];
    if (j < 0)
      s = -vecs[-j -1] / dv;
    else
      s = vecs[j-1] / dv;
    j = vec_to_st[axis][1];
    if (j < 0)
      t = -vecs[-j -1] / dv;
    else
      t = vecs[j-1] / dv;

    if (s < skymins[0][axis])
      skymins[0][axis] = s;
    if (t < skymins[1][axis])
      skymins[1][axis] = t;
    if (s > skymaxs[0][axis])
      skymaxs[0][axis] = s;
    if (t > skymaxs[1][axis])
      skymaxs[1][axis] = t;
  }
}

#define  MAX_CLIP_VERTS  64
void ClipSkyPolygon (int nump, vec3_t vecs, int stage)
{
  float  *norm;
  float  *v;
  qboolean  front, back;
  float  d, e;
  float  dists[MAX_CLIP_VERTS];
  int    sides[MAX_CLIP_VERTS];
  vec3_t  newv[2][MAX_CLIP_VERTS];
  int    newc[2];
  int    i, j;

  if (nump > MAX_CLIP_VERTS-2)
    Sys_Error ("ClipSkyPolygon: MAX_CLIP_VERTS");
  if (stage == 6)
  {  // fully clipped, so draw it
    DrawSkyPolygon (nump, vecs);
    return;
  }

  front = back = false;
  norm = skyclip[stage];
  for (i=0, v = vecs ; i<nump ; i++, v+=3)
  {
    d = DotProduct (v, norm);
    if (d > ON_EPSILON)
    {
      front = true;
      sides[i] = SIDE_FRONT;
    }
    else if (d < ON_EPSILON)
    {
      back = true;
      sides[i] = SIDE_BACK;
    }
    else
      sides[i] = SIDE_ON;
    dists[i] = d;
  }

  if (!front || !back)
  {  // not clipped
    ClipSkyPolygon (nump, vecs, stage+1);
    return;
  }

  // clip it
  sides[i] = sides[0];
  dists[i] = dists[0];
  VectorCopy (vecs, (vecs+(i*3)) );
  newc[0] = newc[1] = 0;

  for (i=0, v = vecs ; i<nump ; i++, v+=3)
  {
    switch (sides[i])
    {
    case SIDE_FRONT:
      VectorCopy (v, newv[0][newc[0]]);
      newc[0]++;
      break;
    case SIDE_BACK:
      VectorCopy (v, newv[1][newc[1]]);
      newc[1]++;
      break;
    case SIDE_ON:
      VectorCopy (v, newv[0][newc[0]]);
      newc[0]++;
      VectorCopy (v, newv[1][newc[1]]);
      newc[1]++;
      break;
    }

    if (sides[i] == SIDE_ON || sides[i+1] == SIDE_ON || sides[i+1] == sides[i])
      continue;

    d = dists[i] / (dists[i] - dists[i+1]);
    for (j=0 ; j<3 ; j++)
    {
      e = v[j] + d*(v[j+3] - v[j]);
      newv[0][newc[0]][j] = e;
      newv[1][newc[1]][j] = e;
    }
    newc[0]++;
    newc[1]++;
  }

  // continue
  ClipSkyPolygon (newc[0], newv[0][0], stage+1);
  ClipSkyPolygon (newc[1], newv[1][0], stage+1);
}

/*
=================
R_DrawSkyChain
=================
*/
void R_DrawSkyChain (msurface_t *s)
{
  msurface_t  *fa;

  int    i;
  vec3_t  verts[MAX_CLIP_VERTS];
  glpoly_t  *p;

  c_sky = 0;
  GL_Bind(solidskytexture);

  // calculate vertex values for sky box

  for (fa=s ; fa ; fa=fa->texturechain)
  {
    for (p=fa->polys ; p ; p=p->next)
    {
      for (i=0 ; i<p->numverts ; i++)
      {
        VectorSubtract (p->verts[i], r_origin, verts[i]);
      }
      ClipSkyPolygon (p->numverts, verts[0], 0);
    }
  }
}


/*
==============
R_ClearSkyBox
==============
*/
void R_ClearSkyBox (void)
{
  int    i;

  for (i=0 ; i<6 ; i++)
  {
    skymins[0][i] = skymins[1][i] = 9999;
    skymaxs[0][i] = skymaxs[1][i] = -9999;
  }
}


void MakeSkyVec (float s, float t, int axis)
{
  vec3_t    v, b;
  int      j, k;

  b[0] = s*2048;
  b[1] = t*2048;
  b[2] = 2048;

  for (j=0 ; j<3 ; j++)
  {
    k = st_to_vec[axis][j];
    if (k < 0)
      v[j] = -b[-k - 1];
    else
      v[j] = b[k - 1];
    v[j] += r_origin[j];
  }

  // avoid bilerp seam
  s = (s+1)*0.5;
  t = (t+1)*0.5;

  if (s < 1.0/512)
    s = 1.0/512;
  else if (s > 511.0/512)
    s = 511.0/512;
  if (t < 1.0/512)
    t = 1.0/512;
  else if (t > 511.0/512)
    t = 511.0/512;

  t = 1.0 - t;
  glTexCoord2f (s, t);
  glVertex3fv (v);
}

/*
==============
R_DrawSkyBox
==============
*/
int  skytexorder[6] = {0,2,1,3,4,5};
void R_DrawSkyBox (void)
{
  int    i, j, k;
  vec3_t  v;
  float  s, t;

#if 0
glEnable (GL_BLEND);
glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
glColor4f (1,1,1,0.5);
glDisable (GL_DEPTH_TEST);
#endif
  for (i=0 ; i<6 ; i++)
  {
    if (skymins[0][i] >= skymaxs[0][i]
    || skymins[1][i] >= skymaxs[1][i])
      continue;

    GL_Bind (SKY_TEX+skytexorder[i]);
#if 0
skymins[0][i] = -1;
skymins[1][i] = -1;
skymaxs[0][i] = 1;
skymaxs[1][i] = 1;
#endif
    glBegin (GL_QUADS);
    MakeSkyVec (skymins[0][i], skymins[1][i], i);
    MakeSkyVec (skymins[0][i], skymaxs[1][i], i);
    MakeSkyVec (skymaxs[0][i], skymaxs[1][i], i);
    MakeSkyVec (skymaxs[0][i], skymins[1][i], i);
    glEnd ();
  }
#if 0
glDisable (GL_BLEND);
glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
glColor4f (1,1,1,0.5);
glEnable (GL_DEPTH_TEST);
#endif
}


#endif
*)

//===============================================================

(*
=============
R_InitSky

A sky texture is 256*128, with the right side being a masked overlay
==============
*)

procedure R_InitSky(mt: Ptexture_t);
var
  i, j, p: integer;
  src: PByteArray;
  trans: array[0..128 * 128 - 1] of unsigned;
  transpix: unsigned;
  r, g, b: integer;
  rgba: PUnsigned;
//  extern  int      skytexturenum;
begin
  src := @(PByteArray(mt)[mt.offsets[0]]);

  // make an average value for the back to avoid
  // a fringe on the top level

  r := 0;
  g := 0;
  b := 0;
  for i := 0 to 127 do
    for j := 0 to 127 do
    begin
      p := src[i * 256 + j + 128];
      rgba := @d_8to24table[p];
      trans[(i * 128) + j] := rgba^;
      r := r + PByteArray(rgba)[0];
      g := g + PByteArray(rgba)[1];
      b := b + PByteArray(rgba)[2];
    end;

  PByteArray(@transpix)[0] := r div (128 * 128);
  PByteArray(@transpix)[1] := g div (128 * 128);
  PByteArray(@transpix)[2] := b div (128 * 128);
  PByteArray(@transpix)[3] := 0;


  if not boolval(solidskytexture) then
  begin
    solidskytexture := texture_extension_number;
    inc(texture_extension_number);
  end;
  GL_Bind(solidskytexture);
  glTexImage2D(GL_TEXTURE_2D, 0, gl_solid_format, 128, 128, 0, GL_RGBA, GL_UNSIGNED_BYTE, @trans);
  glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);


  for i := 0 to 127 do
    for j := 0 to 127 do
    begin
      p := src[i * 256 + j];
      if p = 0 then
        trans[(i * 128) + j] := transpix
      else
        trans[(i * 128) + j] := d_8to24table[p];
    end;

  if not boolval(alphaskytexture) then
  begin
    alphaskytexture := texture_extension_number;
    inc(texture_extension_number);
  end;
  GL_Bind(alphaskytexture);
  glTexImage2D(GL_TEXTURE_2D, 0, gl_alpha_format, 128, 128, 0, GL_RGBA, GL_UNSIGNED_BYTE, @trans);
  glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
end;


end.

