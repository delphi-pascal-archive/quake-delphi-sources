//
//
// Roman Vereshagin
// 
//

unit Textures;

interface

uses
  SysUtils, Windows, OpenGL12, Graphics, JPEG;

function LoadTexture(Filename: String; const Texture: TGLuint; var Width, Height : Integer): Boolean;

implementation

procedure CreateTexture(TextureID : Integer; Width, Height, Format : Word; pData : Pointer);
begin
  glBindTexture(GL_TEXTURE_2D, TextureID);
  glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);  {Texture blends with object background}
  gluBuild2DMipmaps(GL_TEXTURE_2D, 4, Width, Height, Format, GL_UNSIGNED_BYTE, pData);
end;

function LoadAnyTexture(const Filename: String; const Texture: TGLuint; var Width, Height : Integer): Boolean;
var
  Data : Array of LongWord;
  W : Integer;
  H : Integer;
  BMP : TBitmap;
  Pic : TPicture;
  C : LongWord;
  Line : ^LongWord;
begin
  result :=FALSE;
  if not FileExists(Filename) then exit;
  Pic:=TPicture.Create;
  Pic.LoadFromFile(Filename);

  BMP:=TBitmap.Create;
  BMP.pixelformat:=pf32bit;
  BMP.width:=Pic.width;
  BMP.height:=Pic.height;
  BMP.canvas.draw(0,0,Pic.Graphic);        // Copy the JPEG onto the Bitmap

  Width  := BMP.Width;
  Height := BMP.Height;
  SetLength(Data, Width*Height);

  For H:=0 to Height-1 do
  Begin
    Line :=BMP.scanline[H];   // flip JPEG  !! ??
    For W:=0 to Width-1 do
    Begin
      c:=Line^ and $FFFFFF; // Need to do a color swap
      Data[W+(H*Width)] :=(((c and $FF) shl 16)+(c shr 16)+(c and $FF00)) or $FF000000;  // 4 channel.
      inc(Line);
    End;
  End;

  BMP.free;
  Pic.free;

  CreateTexture(Texture, Width, Height, GL_RGBA, addr(Data[0]));
  result  := TRUE;
end;

function LoadTGATexture(Filename: String; const Texture: TGLuint; var Width, Height : Integer): Boolean;
var
  TGAHeader : packed record   // Header type for TGA images
    FileType     : Byte;
    ColorMapType : Byte;
    ImageType    : Byte;
    ColorMapSpec : Array[0..4] of Byte;
    OrigX  : Array [0..1] of Byte;
    OrigY  : Array [0..1] of Byte;
    Width  : Array [0..1] of Byte;
    Height : Array [0..1] of Byte;
    BPP    : Byte;
    ImageInfo : Byte;
  end;
  TGAFile   : File;
  bytesRead : Integer;
  image     : Pointer;    {or PRGBTRIPLE}
  ColorDepth    : Integer;
  ImageSize     : Integer;
  I : Integer;
  Front: ^Byte;
  Back: ^Byte;
  Temp: Byte;
begin
  Result := False;
  if not FileExists(Filename) then exit;

      AssignFile(TGAFile, Filename);
      Reset(TGAFile, 1);

      // Read in the bitmap file header
      BlockRead(TGAFile, TGAHeader, SizeOf(TGAHeader));

      // Only support uncompressed images
      if (TGAHeader.ImageType <> 2) then  { TGA_RGB }
      begin
        Result := False;
        CloseFile(tgaFile);
        MessageBox(0, PChar('Couldn''t load "'+ Filename +'". Compressed TGA files not supported.'), PChar('TGA File Error'), MB_OK);
        Exit;
      end;

      // Don't support colormapped files
      if TGAHeader.ColorMapType <> 0 then
      begin
        Result := False;
        CloseFile(TGAFile);
        MessageBox(0, PChar('Couldn''t load "'+ Filename +'". Colormapped TGA files not supported.'), PChar('TGA File Error'), MB_OK);
        Exit;
      end;

      // Get the width, height, and color depth
      Width  := TGAHeader.Width[0]  + TGAHeader.Width[1]  * 256;
      Height := TGAHeader.Height[0] + TGAHeader.Height[1] * 256;
      ColorDepth := TGAHeader.BPP;
      ImageSize  := Width*Height*(ColorDepth div 8);

      if ColorDepth <> 24 then
      begin
        Result := False;
        CloseFile(TGAFile);
        MessageBox(0, PChar('Couldn''t load "'+ Filename +'". Only 24 bit TGA files supported.'), PChar('TGA File Error'), MB_OK);
        Exit;
      end;

      GetMem(Image, ImageSize);

      // Read in the image
      BlockRead(TGAFile, image^, ImageSize, bytesRead);
      if bytesRead <> ImageSize then
      begin
        Result := False;
        CloseFile(TGAFile);
        MessageBox(0, PChar('Couldn''t read file "'+ Filename +'".'), PChar('TGA File Error'), MB_OK);
        Exit;
      end;

  // TGAs are stored BGR and not RGB, so swap the R and B bytes.
  for I :=0 to Width * Height - 1 do
  begin
    Front := Pointer(Integer(Image) + I*3);
    Back := Pointer(Integer(Image) + I*3 + 2);
    Temp := Front^;
    Front^ := Back^;
    Back^ := Temp;
  end;

  CreateTexture(Texture, Width, Height, GL_RGB, Image);
  Result :=TRUE;
  FreeMem(Image);
end;


{------------------------------------------------------------------}
{  Determines file type and sends to correct function              }
{------------------------------------------------------------------}
function LoadTexture(Filename: String; const Texture: TGLuint; var Width, Height : Integer): Boolean;
begin
  if copy(filename, length(filename)-3, 4) = '.tga' then Result := LoadTGATexture(Filename, Texture, Width, Height)
                                                    else Result := LoadAnyTexture(Filename, Texture, Width, Height);
end;


end.
