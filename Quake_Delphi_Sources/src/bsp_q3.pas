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
unit bsp_q3;

interface

uses
  Windows,
  OpenGL12,
  Unit_SysTools,
  unit_Textures;

const
  FACE_POLYGON = 1;
  MAX_TEXTURES = 1000;

type
  TBSPHeader = record
    strID: array[0..3] of Char; // This should always be 'IBSP'
    Version: Integer; // This should be 0x2e for Quake 3 files
  end;
  PBSPHeader = ^TBSPHeader;

  TBSPLump = record
    Offset: Integer; // The offset into the file for the start of this lump
    Length: Integer; // The length in bytes for this lump
  end;
  PBSPLump = ^TBSPLump;

  TBSPVertex = record
    Position: TVector3f; // (x, y, z) position.
    TextureCoord: TVector2f; // (u, v) texture coordinate
    LightmapCoord: TVector2f; // (u, v) lightmap coordinate
    Normal: TVector3f; // (x, y, z) normal vector
    Color: array[0..3] of Byte // RGBA color for the vertex
  end;

  TBSPFace = record
    textureID: Integer; // The index into the texture array
    effect: Integer; // The index for the effects (or -1 = n/a)
    FaceType: Integer; // 1=polygon, 2=patch, 3=mesh, 4=billboard
    startVertIndex: Integer; // The starting index into this face's first vertex
    numOfVerts: Integer; // The number of vertices for this face
    meshVertIndex: Integer; // The index into the first meshvertex
    numMeshVerts: Integer; // The number of mesh vertices
    lightmapID: Integer; // The texture index for the lightmap
    lMapCorner: array[0..1] of Integer; // The face's lightmap corner in the image
    lMapSize: array[0..1] of Integer; // The size of the lightmap section
    lMapPos: TVector3f; // The 3D origin of lightmap.
    lMapVecs: array[0..1] of TVector3f; // The 3D space for s and t unit vectors.
    vNormal: TVector3f; // The face normal.
    Size: array[0..1] of Integer; // The bezier patch dimensions.
  end;

  TBSPTexture = record
    TextureName: array[0..63] of Char; // The name of the texture w/o the extension
    flags: Integer; // The surface flags (unknown)
    contents: Integer; // The content flags (unknown)
  end;

  TBSPLightmap = record
    imageBits: array[0..127, 0..127, 0..2] of Byte; // The RGB data in a 128x128 image
  end;

  TBSPLights = record
    Position: TVector3i;
    Color: record r, g, b: TGLFloat; end;
  end;

  TBSPBrush = record
    brushside: Integer;
    numOfBrushsides: Integer;
    Texture: integer; // Texture index
  end;
  TBSPBrushSide = record
    plane: Integer; // Plane Index
    texture: integer; // Texture Index
  end;
  tBSPPlane = record
    vNormal: TVector3f; // Plane normal.
    d: TGLFloat; // The plane distance from origin
  end;

  tBSPLeaf = record
    cluster: Integer; // The visibility cluster
    area: Integer; // The area portal
    min: tVector3i; // The bounding box min position
    max: tVector3i; // The bounding box max position
    leafface: Integer; // The first index into the face array
    numOfLeafFaces: Integer; // The number of faces for this leaf
    leafBrush: Integer; // The first index for into the brushes
    numOfLeafBrushes: Integer; // The number of brushes for this leaf
  end;

  tBSPNode = record
    plane: Integer; // The index into the planes array
    front: Integer; // The child index for the front node
    back: Integer; // The child index for the back node
    min: tVector3i; // The bounding box min position.
    max: tVector3i; // The bounding box max position.
  end;

  tBSPVisData = record
    numOfClusters: Integer; // The number of clusters
    bytesPerCluster: Integer; // The amount of bytes (8 bits) in the cluster's bitset
    pBitsets: array of byte; // The array of bytes that holds the cluster bitsets
  end;
  TQuake3BSP = object
    numOfVerts: Integer; // The number of verts in the model
    numOfFaces: Integer; // The number of faces in the model
    numOfBrushes: Integer; // The number of brushes in the model
    numOfBrushSides: Integer; // The number of brushsides in the model
    numOfLeafBrushes: Integer; // The number of leaf brushes
    numOfMeshVerts: integer; // The number of mesh verts

    numOfTextures: Integer; // The number of texture maps
    numOfLightmaps: Integer; // The number of light maps
    numOfModels: Integer; // The number of Models
    SizeOfEntities: Integer; // The length of the entity string
    numOfLights: Integer; // The number of Lights

    m_numOfNodes: Integer;
    m_numOfLeafs: Integer;
    m_numOfLeafFaces: Integer;
    m_numOfPlanes: Integer;
    Lights: array of TBSPLights; //?

    Vertices: array of TBSPVertex; // The object's vertices
    Faces: array of TBSPFace; // The faces information of the object
    LightMaps: array of TBSPLightmap;
    MeshVertices: array of TBSPVertex;

    Brushes: array of TBSPBrush;
    BrushSides: array of TBSPBrushSide;
    Leafbrushes: array of Integer;

      // The texture and lightmap array for the level
    BSPTextures: array of TBSPTexture;

    m_pLeafs: array of tBSPLeaf;
    m_pNodes: array of tBSPNode;
    m_pPlanes: array of tBSPPlane;
    m_pLeafFaces: array of integer;
    m_clusters: tBSPVisData;

    FacesDrawn: array of Boolean;
    ModelsDrawn: array of Boolean;
      // TEMP
    Textures: array of Integer;
    LTextures: array of Integer;
    fbuffer: array of byte;
    buffer: Pointer;
    bufferIndex: Integer;

    procedure RenderFace(faceIndex: Integer);

    procedure LumpLoadTextures(const lump: TBSPLump);
    procedure LumpVertices(const lump: TBSPLump);
    procedure LumpFaces(const lump: TBSPLump);
    procedure LumpBrushes(const lump: TBSPLump);

    function LoadBSP(const FileName: string): Boolean; overload;
    procedure LoadBSP(const Data: Pointer); overload;
    procedure RenderLevel;
    procedure GetBuffer(var Buf; Size: Integer);
  end;

  // This is our lumps enumeration
const
  kEntities = 0; // Stores player/object positions, etc...
  kTextures = 1; // Stores texture information
  kPlanes = 2; // Stores the splitting planes
  kNodes = 3; // Stores the BSP nodes
  kLeafs = 4; // Stores the leafs of the nodes
  kLeafFaces = 5; // Stores the leaf's indices into the faces
  kLeafBrushes = 6; // Stores the leaf's indices into the brushes
  kModels = 7; // Stores the info of world models
  kBrushes = 8; // Stores the brushes info (for collision)
  kBrushSides = 9; // Stores the brush surfaces info
  kVertices = 10; // Stores the level vertices
  kMeshVerts = 11; // Stores the model vertices offsets
  kShaders = 12; // Stores the shader files (blending, anims..)
  kFaces = 13; // Stores the faces for the level
  kLightmaps = 14; // Stores the lightmaps for the level
  kLightVolumes = 15; // Stores extra world lighting information
  kVisData = 16; // Stores PVS and cluster info (visibility)
  kMaxLumps = 17; // A constant to store the number of lumps

implementation

{ TQuake3BSP }

{-----------------------------------------------------------}
{---  This loads in all of the .bsp data for the level   ---}
{-----------------------------------------------------------}

function TQuake3BSP.LoadBSP(const FileName: string): Boolean;
var FileIn: file;
begin
  result := FALSE;

  // Check if the .bsp file can be opened
  AssignFile(FileIn, filename);
{$I-}
  Reset(FileIn, 1);
{$I+}
  if IOResult <> 0 then
  begin
    MessageBox(0, 'Could not find the BSP file!', 'Error', MB_OK);
    exit;
  end;

  SetLength(fbuffer, FileSize(FileIn));

  BlockRead(FileIn, fbuffer[0], FileSize(FileIn));
  CloseFile(FileIn);

  LoadBSP(@fbuffer[0]);

  result := TRUE;
end;

{-----------------------------------------------------------}
{--- Renders a face, determined by the passed in index   ---}
{-----------------------------------------------------------}

procedure TQuake3BSP.GetBuffer(var Buf; Size: Integer);
var
  p: Pointer;
begin
  p := Pointer(Integer(buffer) + bufferIndex);
  move(p^, Buf, Size);
  bufferIndex := bufferIndex + Size;
end;

procedure TQuake3BSP.LoadBSP(const Data: Pointer);
var
  Header: TBSPHeader;
  Lumps: array of TBSPLump;
begin
  buffer := Data;
  bufferIndex := 0;

  SetLength(Lumps, kMaxLumps);

  // Read in the header and lump data
  GetBuffer(Header, SizeOf(TBSPHeader));
  GetBuffer(Lumps[0], kMaxLumps * sizeof(TBSPLump));

  // Allocate memory to read in the texture information.

  LumpVertices(lumps[kVertices]);
  LumpFaces(lumps[kFaces]);
  LumpLoadTextures(lumps[kTextures]);
  LumpBrushes(lumps[kBrushes]);
end;

procedure TQuake3BSP.LumpBrushes(const lump: TBSPLump);
begin
  bufferIndex := lump.offset;

  numOfBrushes := round(lump.length / sizeof(TBSPBrush));
  SetLength(Brushes, numOfBrushes);

  GetBuffer(Brushes[0], numOfBrushes * sizeof(TBSPBrush));
end;

procedure TQuake3BSP.LumpFaces(const lump: TBSPLump);
begin
  bufferIndex := lump.offset;
  // Allocate the face memory
  numOfFaces := Round(lump.length / sizeof(TBSPFace));
  SetLength(Faces, numOfFaces);

  GetBuffer(Faces[0], numOfFaces * sizeOf(TBSPFace));
end;

procedure TQuake3BSP.LumpLoadTextures(const lump: TBSPLump);
var
  i: Integer;
begin
  bufferIndex := lump.offset;
  numOfTextures := Round(lump.length / sizeof(TBSPTexture));
  SetLength(BSPTextures, numOfTextures);
  SetLength(Textures, numOfTextures);

  GetBuffer(BSPTextures[0], numOfTextures * sizeOf(TBSPTexture));

  // Go through all of the textures
  for I := 0 to numOfTextures - 1 do
  begin
    // for some reason known only to ID they dont store file extentions
    Textures[i] := GL_LoadTexture(BSPTextures[i].TextureName, 128, 128, nil, true, false);
  end;
end;

procedure TQuake3BSP.LumpVertices(const lump: TBSPLump);
var
  i: Integer;
begin
  bufferIndex := lump.offset;

  // Allocate the vertex memory
  numOfVerts := Round(lump.length / sizeof(TBSPVertex));
  SetLength(Vertices, numOfVerts);

  // Go through all of the vertices that need to be read and swap axises
  for I := 0 to numOfVerts - 1 do
  begin
    // Read in the current vertex
    GetBuffer(Vertices[i], sizeOf(TBSPVertex));

    // Swap the y and z values, and negate the new z so Y is up.
//    Temp := Vertices[i].Position[1];
//    Vertices[i].Position[1] := Vertices[i].Position[2];
//    Vertices[i].Position[2] := -temp;

    // Negate the V texture coordinate because it is upside down otherwise...
//    Vertices[i].TextureCoord[1] := -Vertices[i].TextureCoord[1];
  end;
end;

procedure TQuake3BSP.RenderFace(faceIndex: Integer);
var Face: TBSPFace;
begin
  // Here we grab the face from the index passed in
  Face := Faces[faceIndex];

  glEnable(GL_TEXTURE_2D); // Turn on texture mapping and bind the face's texture map
  glBindTexture(GL_TEXTURE_2D, textures[Face.textureID]);

  // Draw the face in a triangle face, starting from the starting index
  // to the starting index + the number of vertices.  This is a vertex array function.
  glDrawArrays(GL_TRIANGLE_FAN, Face.startVertIndex, Face.numOfVerts);
end;

{---------------------------------------------------------------------}
{--- Goes through all faces and draws them if type is FACE_POLYGON ---}
{---------------------------------------------------------------------}

procedure TQuake3BSP.RenderLevel;
var i: Integer;
begin
  // Give OpenGL our vertices to use for vertex arrays
  glVertexPointer(3, GL_FLOAT, sizeof(TBSPVertex), @Vertices[0].Position);

  // Since we are using vertex arrays, we need to tell OpenGL which texture
  // coordinates to use for each texture pass.  We switch our current texture
  // to the first one, then set our texture coordinates.
  glTexCoordPointer(2, GL_FLOAT, sizeof(TBSPVertex), @Vertices[0].TextureCoord);

  // Set our vertex array client states for vertices and texture coordinates
  glEnableClientState(GL_VERTEX_ARRAY);
  glEnableClientState(GL_TEXTURE_COORD_ARRAY);

  // Get the number of faces in our level and go through all the faces
  i := numOfFaces;
  while i > 0 do
  begin
    Dec(I);

    // Before drawing this face, make sure it's a normal polygon
    if Faces[i].Facetype = FACE_POLYGON then
      RenderFace(i);
  end;
end;

end.

