local load = ...
-- The Gen 2 sprite-animation runtime (pokegold engine/sprite_anims/core.asm)
-- plus the slice of its data tables the Gold/Silver intro movie uses.
--
-- The cart draws every moving thing in the intro as OBJs driven by this one
-- system, and the movie's character comes from it: Lapras's bob, Pikachu's
-- charge, the fireball spiralling outward.  So this is a transcription rather
-- than an approximation -- ten struct slots, a frameset that steps OAM sets on
-- a per-frame duration, and one `AnimSeq_*` function per object that moves the
-- struct around between frames.
--
--   * data/sprite_anims/objects.asm  -> OBJECTS   (frameset + sequence)
--   * data/sprite_anims/framesets.asm-> FRAMESETS (oamframe lists)
--   * data/sprite_anims/oam.asm      -> OAMSETS   (vtile offset + dbsprites)
--   * engine/sprite_anims/functions.asm -> SEQUENCES
--
-- Coordinates are hardware OAM coordinates: a struct's x/y are the byte the
-- `depixel` macro built, and a drawn object sits at (x - 8, y - 16) on screen.
-- Everything is 8-bit and wraps, which several of the sequences rely on --
-- Lapras walks its x down past 0 to $d0 to decide it has left the screen.
--
-- The intro never populates wSpriteAnimDict with a live entry (IntroScene1/6/10
-- write SPRITE_ANIM_DICT_* -> $00), so GetSpriteAnimVTile always resolves to a
-- base vtile of 0 and the struct's TILE_ID is dropped here.

local bit = require("bit")

local SpriteAnims = {}

local NUM_STRUCTS = 10 -- NUM_SPRITE_ANIM_STRUCTS
-- wShadowOAM is 40 objects; UpdateAnimFrame returns carry once it is full and
-- DoNextFrameForAllSprites stops walking the structs.
local OAM_LIMIT = 40

local OAM_PRIO, OAM_YFLIP, OAM_XFLIP = 0x80, 0x40, 0x20
local OAM_FLAG_MASK = 0xe0 -- OAM_PRIO | OAM_YFLIP | OAM_XFLIP

--------------------------------------------------------------------------
-- Sine
--------------------------------------------------------------------------

-- engine/math/sine.asm `sine_table 32`: sin(x * pi/32) in Q8.8, so entry 16
-- is exactly $100.  calc_sine_wave masks the angle to six bits and mirrors the
-- upper half, giving a full period over 64 steps.
local SINE = {}
for index = 0, 31 do
  SINE[index] = math.floor(math.sin(index * math.pi / 32) * 256 + 0.5)
end
SpriteAnims.SINE = SINE

-- a = d * sin(a * pi/32), returned as the byte the ASM leaves in a (so a
-- negative result comes back in two's complement, ready to be added to a
-- coordinate).
function SpriteAnims.sine(angle, amplitude)
  angle = angle % 64
  local negative = angle >= 32
  if negative then angle = angle - 32 end
  -- The multiply accumulates into hl and only the high byte survives.
  local product = (amplitude % 256) * SINE[angle] % 0x10000
  local result = math.floor(product / 256)
  if negative then result = -result end
  return result % 256
end

-- Sprites_Cosine: cos(x) = sin(x + pi/2), i.e. eight table steps on.
function SpriteAnims.cosine(angle, amplitude)
  return SpriteAnims.sine(angle + 0x10, amplitude)
end

--------------------------------------------------------------------------
-- data/sprite_anims/oam.asm
--------------------------------------------------------------------------

-- `dbsprite x tile, y tile, x pixel, y pixel, vtile offset, attributes`
-- emits the y byte first, and both tile counts are taken mod $100 so a
-- negative column becomes $f8.
local function s(xTile, yTile, xPixel, yPixel, tile, attr)
  return {
    y = (yTile * 8 + yPixel) % 256,
    x = (xTile * 8 + xPixel) % 256,
    tile = tile,
    attr = attr,
  }
end

local OAMDATA = {
  OAMData_1x1_Palette0 = {
    s( -1,  -1, 4, 4, 0x00, 0x00),
  },
  OAMData_GSIntroShellder = {
    s( -1,  -1, 0, 0, 0x00, 0x00),
    s(  0,  -1, 0, 0, 0x01, 0x00),
    s( -1,   0, 0, 0, 0x10, 0x00),
    s(  0,   0, 0, 0, 0x11, 0x00),
  },
  OAMData_GSIntroMagikarp = {
    s( -2,  -1, 4, 0, 0x00, 0x01),
    s( -1,  -1, 4, 0, 0x01, 0x01),
    s(  0,  -1, 4, 0, 0x02, 0x01),
    s( -2,   0, 4, 0, 0x10, 0x01),
    s( -1,   0, 4, 0, 0x11, 0x01),
    s(  0,   0, 4, 0, 0x12, 0x01),
  },
  OAMData_GSIntroLapras1 = {
    s( -3,  -3, 0, 0, 0x00, 0x00),
    s( -2,  -3, 0, 0, 0x01, 0x00),
    s( -1,  -3, 0, 0, 0x02, 0x00),
    s( -3,  -2, 0, 0, 0x10, 0x00),
    s( -2,  -2, 0, 0, 0x11, 0x00),
    s( -1,  -2, 0, 0, 0x12, 0x00),
    s( -3,  -1, 0, 0, 0x20, 0x00),
    s( -2,  -1, 0, 0, 0x21, 0x00),
    s( -1,  -1, 0, 0, 0x22, 0x00),
    s(  0,  -1, 0, 0, 0x23, 0x00),
    s( -3,   0, 0, 0, 0x30, 0x80),
    s( -2,   0, 0, 0, 0x31, 0x80),
    s( -1,   0, 0, 0, 0x32, 0x80),
    s(  0,   0, 0, 0, 0x33, 0x80),
    s(  1,   0, 0, 0, 0x34, 0x80),
    s( -3,   1, 0, 0, 0x40, 0x80),
    s( -2,   1, 0, 0, 0x41, 0x80),
    s( -1,   1, 0, 0, 0x42, 0x80),
    s(  0,   1, 0, 0, 0x43, 0x80),
    s(  1,   1, 0, 0, 0x44, 0x80),
    s(  2,   1, 0, 0, 0x45, 0x80),
    s( -3,   2, 0, 0, 0x50, 0x80),
    s( -2,   2, 0, 0, 0x51, 0x80),
    s( -1,   2, 0, 0, 0x52, 0x80),
    s(  0,   2, 0, 0, 0x53, 0x80),
    s(  1,   2, 0, 0, 0x54, 0x80),
    s(  2,   2, 0, 0, 0x55, 0x80),
  },
  OAMData_GSIntroLapras2 = {
    s( -3,  -3, 0, 0, 0x0d, 0x00),
    s( -2,  -3, 0, 0, 0x0e, 0x00),
    s( -1,  -3, 0, 0, 0x0f, 0x00),
    s( -3,  -2, 0, 0, 0x1d, 0x00),
    s( -2,  -2, 0, 0, 0x1e, 0x00),
    s( -1,  -2, 0, 0, 0x1f, 0x00),
    s( -3,  -1, 0, 0, 0x20, 0x00),
    s( -2,  -1, 0, 0, 0x21, 0x00),
    s( -1,  -1, 0, 0, 0x22, 0x00),
    s(  0,  -1, 0, 0, 0x23, 0x00),
    s( -3,   0, 0, 0, 0x30, 0x80),
    s( -2,   0, 0, 0, 0x31, 0x80),
    s( -1,   0, 0, 0, 0x32, 0x80),
    s(  0,   0, 0, 0, 0x33, 0x80),
    s(  1,   0, 0, 0, 0x34, 0x80),
    s( -3,   1, 0, 0, 0x40, 0x80),
    s( -2,   1, 0, 0, 0x41, 0x80),
    s( -1,   1, 0, 0, 0x42, 0x80),
    s(  0,   1, 0, 0, 0x43, 0x80),
    s(  1,   1, 0, 0, 0x44, 0x80),
    s(  2,   1, 0, 0, 0x45, 0x80),
    s( -3,   2, 0, 0, 0x50, 0x80),
    s( -2,   2, 0, 0, 0x51, 0x80),
    s( -1,   2, 0, 0, 0x52, 0x80),
    s(  0,   2, 0, 0, 0x53, 0x80),
    s(  1,   2, 0, 0, 0x54, 0x80),
    s(  2,   2, 0, 0, 0x55, 0x80),
  },
  OAMData_GSIntroLapras3 = {
    s( -3,  -3, 0, 0, 0x00, 0x00),
    s( -2,  -3, 0, 0, 0x01, 0x00),
    s( -1,  -3, 0, 0, 0x02, 0x00),
    s(  0,  -3, 0, 0, 0x03, 0x00),
    s( -3,  -2, 0, 0, 0x10, 0x00),
    s( -2,  -2, 0, 0, 0x11, 0x00),
    s( -1,  -2, 0, 0, 0x12, 0x00),
    s(  0,  -2, 0, 0, 0x13, 0x00),
    s( -3,  -1, 0, 0, 0x20, 0x00),
    s( -2,  -1, 0, 0, 0x21, 0x00),
    s( -1,  -1, 0, 0, 0x22, 0x00),
    s(  0,  -1, 0, 0, 0x23, 0x00),
    s(  1,  -1, 0, 0, 0x24, 0x00),
    s( -3,   0, 0, 0, 0x30, 0x80),
    s( -2,   0, 0, 0, 0x31, 0x80),
    s( -1,   0, 0, 0, 0x32, 0x80),
    s(  0,   0, 0, 0, 0x33, 0x80),
    s(  1,   0, 0, 0, 0x34, 0x80),
    s( -3,   1, 0, 0, 0x40, 0x80),
    s( -2,   1, 0, 0, 0x41, 0x80),
    s( -1,   1, 0, 0, 0x42, 0x80),
    s(  0,   1, 0, 0, 0x43, 0x80),
    s(  1,   1, 0, 0, 0x44, 0x80),
    s(  2,   1, 0, 0, 0x45, 0x80),
    s( -2,   2, 0, 0, 0x51, 0x80),
    s( -1,   2, 0, 0, 0x52, 0x80),
    s(  0,   2, 0, 0, 0x53, 0x80),
    s(  1,   2, 0, 0, 0x54, 0x80),
    s(  2,   2, 0, 0, 0x55, 0x80),
  },
  OAMData_GSIntroNote = {
    s( -1,  -1, 4, 0, 0x00, 0x00),
    s( -1,   0, 4, 0, 0x10, 0x00),
  },
  OAMData_GSIntroJigglypuffPikachu = {
    s( -2,  -2, 0, 0, 0x00, 0x00),
    s( -1,  -2, 0, 0, 0x01, 0x00),
    s(  0,  -2, 0, 0, 0x02, 0x00),
    s(  1,  -2, 0, 0, 0x03, 0x00),
    s( -2,  -1, 0, 0, 0x10, 0x00),
    s( -1,  -1, 0, 0, 0x11, 0x00),
    s(  0,  -1, 0, 0, 0x12, 0x00),
    s(  1,  -1, 0, 0, 0x13, 0x00),
    s( -2,   0, 0, 0, 0x20, 0x00),
    s( -1,   0, 0, 0, 0x21, 0x00),
    s(  0,   0, 0, 0, 0x22, 0x00),
    s(  1,   0, 0, 0, 0x23, 0x00),
    s( -2,   1, 0, 0, 0x30, 0x00),
    s( -1,   1, 0, 0, 0x31, 0x00),
    s(  0,   1, 0, 0, 0x32, 0x00),
    s(  1,   1, 0, 0, 0x33, 0x00),
  },
  OAMData_GSIntroPikachuTail = {
    s(  3,  -2, 0, 0, 0x00, 0x00),
    s(  4,  -2, 0, 0, 0x01, 0x00),
    s(  2,  -1, 0, 0, 0x02, 0x00),
    s(  3,  -1, 0, 0, 0x03, 0x00),
    s(  2,   0, 0, 0, 0x04, 0x00),
  },
  OAMData_GSIntroSmallFireball = {
    s( -1,  -1, 0, 0, 0x00, 0x00),
    s(  0,  -1, 0, 0, 0x00, 0x20),
    s( -1,   0, 0, 0, 0x00, 0x40),
    s(  0,   0, 0, 0, 0x00, 0x60),
  },
  OAMData_TradePoofBubble = {
    s( -2,  -2, 0, 0, 0x00, 0x00),
    s( -1,  -2, 0, 0, 0x01, 0x00),
    s( -2,  -1, 0, 0, 0x02, 0x00),
    s( -1,  -1, 0, 0, 0x03, 0x00),
    s(  0,  -2, 0, 0, 0x01, 0x20),
    s(  1,  -2, 0, 0, 0x00, 0x20),
    s(  0,  -1, 0, 0, 0x03, 0x20),
    s(  1,  -1, 0, 0, 0x02, 0x20),
    s( -2,   0, 0, 0, 0x02, 0x40),
    s( -1,   0, 0, 0, 0x03, 0x40),
    s( -2,   1, 0, 0, 0x00, 0x40),
    s( -1,   1, 0, 0, 0x01, 0x40),
    s(  0,   0, 0, 0, 0x03, 0x60),
    s(  1,   0, 0, 0, 0x02, 0x60),
    s(  0,   1, 0, 0, 0x01, 0x60),
    s(  1,   1, 0, 0, 0x00, 0x60),
  },
  OAMData_GSIntroBigFireball = {
    s( -3,  -3, 0, 0, 0x00, 0x00),
    s( -2,  -3, 0, 0, 0x01, 0x00),
    s( -1,  -3, 0, 0, 0x02, 0x00),
    s( -3,  -2, 0, 0, 0x03, 0x00),
    s( -2,  -2, 0, 0, 0x04, 0x00),
    s( -1,  -2, 0, 0, 0x05, 0x00),
    s( -3,  -1, 0, 0, 0x06, 0x00),
    s( -2,  -1, 0, 0, 0x05, 0x00),
    s( -1,  -1, 0, 0, 0x05, 0x00),
    s(  0,  -3, 0, 0, 0x02, 0x20),
    s(  1,  -3, 0, 0, 0x01, 0x20),
    s(  2,  -3, 0, 0, 0x00, 0x20),
    s(  0,  -2, 0, 0, 0x05, 0x20),
    s(  1,  -2, 0, 0, 0x04, 0x20),
    s(  2,  -2, 0, 0, 0x03, 0x20),
    s(  0,  -1, 0, 0, 0x05, 0x20),
    s(  1,  -1, 0, 0, 0x05, 0x20),
    s(  2,  -1, 0, 0, 0x06, 0x20),
    s( -3,   0, 0, 0, 0x06, 0x40),
    s( -2,   0, 0, 0, 0x05, 0x40),
    s( -1,   0, 0, 0, 0x05, 0x40),
    s( -3,   1, 0, 0, 0x03, 0x40),
    s( -2,   1, 0, 0, 0x04, 0x40),
    s( -1,   1, 0, 0, 0x05, 0x40),
    s( -3,   2, 0, 0, 0x00, 0x40),
    s( -2,   2, 0, 0, 0x01, 0x40),
    s( -1,   2, 0, 0, 0x02, 0x40),
    s(  0,   0, 0, 0, 0x05, 0x60),
    s(  1,   0, 0, 0, 0x05, 0x60),
    s(  2,   0, 0, 0, 0x06, 0x60),
    s(  0,   1, 0, 0, 0x05, 0x60),
    s(  1,   1, 0, 0, 0x04, 0x60),
    s(  2,   1, 0, 0, 0x03, 0x60),
    s(  0,   2, 0, 0, 0x02, 0x60),
    s(  1,   2, 0, 0, 0x01, 0x60),
    s(  2,   2, 0, 0, 0x00, 0x60),
  },
  OAMData_GSIntroStarter = {
    s( -3,  -3, 4, 4, 0x00, 0x00),
    s( -3,  -2, 4, 4, 0x01, 0x00),
    s( -3,  -1, 4, 4, 0x02, 0x00),
    s( -3,   0, 4, 4, 0x03, 0x00),
    s( -3,   1, 4, 4, 0x04, 0x00),
    s( -2,  -3, 4, 4, 0x05, 0x00),
    s( -2,  -2, 4, 4, 0x06, 0x00),
    s( -2,  -1, 4, 4, 0x07, 0x00),
    s( -2,   0, 4, 4, 0x08, 0x00),
    s( -2,   1, 4, 4, 0x09, 0x00),
    s( -1,  -3, 4, 4, 0x0a, 0x00),
    s( -1,  -2, 4, 4, 0x0b, 0x00),
    s( -1,  -1, 4, 4, 0x0c, 0x00),
    s( -1,   0, 4, 4, 0x0d, 0x00),
    s( -1,   1, 4, 4, 0x0e, 0x00),
    s(  0,  -3, 4, 4, 0x0f, 0x00),
    s(  0,  -2, 4, 4, 0x10, 0x00),
    s(  0,  -1, 4, 4, 0x11, 0x00),
    s(  0,   0, 4, 4, 0x12, 0x00),
    s(  0,   1, 4, 4, 0x13, 0x00),
    s(  1,  -3, 4, 4, 0x14, 0x00),
    s(  1,  -2, 4, 4, 0x15, 0x00),
    s(  1,  -1, 4, 4, 0x16, 0x00),
    s(  1,   0, 4, 4, 0x17, 0x00),
    s(  1,   1, 4, 4, 0x18, 0x00),
  },
  -- The GameFreak splash (engine/movie/splash.asm).  The logo is a 3x5 block
  -- of tiles laid row-major and it is the only OAM set in this file that asks
  -- for OBJ palette 1 (`1 | OAM_PAL1`) -- which is the whole point, because
  -- GameFreakPresents_UpdateLogoPal rotates OBP1 out from under it while
  -- the star and sparkles stay on palette 0.
  OAMData_GSGameFreakLogo = {
    s( -2,  -3, 4, 4, 0x00, 0x11),
    s( -1,  -3, 4, 4, 0x01, 0x11),
    s(  0,  -3, 4, 4, 0x02, 0x11),
    s( -2,  -2, 4, 4, 0x03, 0x11),
    s( -1,  -2, 4, 4, 0x04, 0x11),
    s(  0,  -2, 4, 4, 0x05, 0x11),
    s( -2,  -1, 4, 4, 0x06, 0x11),
    s( -1,  -1, 4, 4, 0x07, 0x11),
    s(  0,  -1, 4, 4, 0x08, 0x11),
    s( -2,   0, 4, 4, 0x09, 0x11),
    s( -1,   0, 4, 4, 0x0a, 0x11),
    s(  0,   0, 4, 4, 0x0b, 0x11),
    s( -2,   1, 4, 4, 0x0c, 0x11),
    s( -1,   1, 4, 4, 0x0d, 0x11),
    s(  0,   1, 4, 4, 0x0e, 0x11),
  },
  -- Two tiles mirrored into a 16x16 star: only the left half is in the ROM.
  OAMData_GSGameFreakLogoStar = {
    s( -1,  -1, 0, 0, 0x00, 0x00),
    s(  0,  -1, 0, 0, 0x00, OAM_XFLIP),
    s( -1,   0, 0, 0, 0x01, 0x00),
    s(  0,   0, 0, 0, 0x01, OAM_XFLIP),
  },
}

-- SpriteAnimOAMData rows: `spriteanimoam <vtile offset>, <data>`.  Only the
-- GS intro's entries are here; the vtile offsets are what put Pikachu at $40
-- and his tail at $80 inside one 16-tile-wide OBJ sheet.
local OAMSETS = {
  GS_INTRO_BUBBLE_1 = { 0x4c, OAMDATA.OAMData_1x1_Palette0 },
  GS_INTRO_BUBBLE_2 = { 0x5c, OAMDATA.OAMData_1x1_Palette0 },
  GS_INTRO_SHELLDER_1 = { 0x6c, OAMDATA.OAMData_GSIntroShellder },
  GS_INTRO_SHELLDER_2 = { 0x6e, OAMDATA.OAMData_GSIntroShellder },
  GS_INTRO_MAGIKARP_1 = { 0x2d, OAMDATA.OAMData_GSIntroMagikarp },
  GS_INTRO_MAGIKARP_2 = { 0x4d, OAMDATA.OAMData_GSIntroMagikarp },
  GS_INTRO_LAPRAS_1 = { 0x00, OAMDATA.OAMData_GSIntroLapras1 },
  GS_INTRO_LAPRAS_2 = { 0x00, OAMDATA.OAMData_GSIntroLapras2 },
  GS_INTRO_LAPRAS_3 = { 0x06, OAMDATA.OAMData_GSIntroLapras3 },
  GS_INTRO_NOTE = { 0x0c, OAMDATA.OAMData_GSIntroNote },
  GS_INTRO_INVISIBLE_NOTE = { 0x0d, OAMDATA.OAMData_1x1_Palette0 },
  GS_INTRO_JIGGLYPUFF_1 = { 0x00, OAMDATA.OAMData_GSIntroJigglypuffPikachu },
  GS_INTRO_JIGGLYPUFF_2 = { 0x04, OAMDATA.OAMData_GSIntroJigglypuffPikachu },
  GS_INTRO_JIGGLYPUFF_3 = { 0x08, OAMDATA.OAMData_GSIntroJigglypuffPikachu },
  GS_INTRO_PIKACHU_1 = { 0x40, OAMDATA.OAMData_GSIntroJigglypuffPikachu },
  GS_INTRO_PIKACHU_2 = { 0x44, OAMDATA.OAMData_GSIntroJigglypuffPikachu },
  GS_INTRO_PIKACHU_3 = { 0x48, OAMDATA.OAMData_GSIntroJigglypuffPikachu },
  GS_INTRO_PIKACHU_4 = { 0x4c, OAMDATA.OAMData_GSIntroJigglypuffPikachu },
  GS_INTRO_PIKACHU_TAIL_1 = { 0x80, OAMDATA.OAMData_GSIntroPikachuTail },
  GS_INTRO_PIKACHU_TAIL_2 = { 0x85, OAMDATA.OAMData_GSIntroPikachuTail },
  GS_INTRO_PIKACHU_TAIL_3 = { 0x8a, OAMDATA.OAMData_GSIntroPikachuTail },
  GS_INTRO_SMALL_FIREBALL = { 0x00, OAMDATA.OAMData_GSIntroSmallFireball },
  GS_INTRO_MED_FIREBALL = { 0x01, OAMDATA.OAMData_TradePoofBubble },
  GS_INTRO_BIG_FIREBALL = { 0x09, OAMDATA.OAMData_GSIntroBigFireball },
  GS_INTRO_CHIKORITA = { 0x10, OAMDATA.OAMData_GSIntroStarter },
  GS_INTRO_CYNDAQUIL = { 0x29, OAMDATA.OAMData_GSIntroStarter },
  GS_INTRO_TOTODILE = { 0x42, OAMDATA.OAMData_GSIntroStarter },
  -- Splash offsets are relative to the dict base the splash sets ($8d, see
  -- System.vtileBase), so the logo lands on $8d, the star on $9c and the
  -- three sparkle frames on $9e-$a0.
  GS_GAMEFREAK_LOGO = { 0x00, OAMDATA.OAMData_GSGameFreakLogo },
  GS_GAMEFREAK_LOGO_STAR = { 0x0f, OAMDATA.OAMData_GSGameFreakLogoStar },
  GS_GAMEFREAK_LOGO_SPARKLE_1 = { 0x11, OAMDATA.OAMData_1x1_Palette0 },
  GS_GAMEFREAK_LOGO_SPARKLE_2 = { 0x12, OAMDATA.OAMData_1x1_Palette0 },
  GS_GAMEFREAK_LOGO_SPARKLE_3 = { 0x13, OAMDATA.OAMData_1x1_Palette0 },
}

--------------------------------------------------------------------------
-- data/sprite_anims/framesets.asm
--------------------------------------------------------------------------

-- `oamframe <oam set>, <duration>[, <flip>]`.  The flip argument lands in the
-- duration byte two bits up and GetSpriteAnimFrame shifts it back down into
-- wCurSpriteOAMFlags, so it is stored here as the OAM flag it becomes.
local function f(oamset, duration, flags)
  return { oamset = oamset, duration = duration, flags = flags or 0 }
end

-- "restart" is `oamrestart`, "end" is `oamend` (hold the last frame forever).
-- `oamdelete` is not a terminator: GetSpriteAnimFrame hands it back like an
-- OAM set and UpdateAnimFrame deinitializes the struct, so it is a frame.
local DELETE = f("delete", 0)

local FRAMESETS = {
  GSIntroBubble = {
    f("GS_INTRO_BUBBLE_1", 8), f("GS_INTRO_BUBBLE_2", 8), "restart",
  },
  GSIntroShellder = {
    f("GS_INTRO_SHELLDER_1", 8), f("GS_INTRO_SHELLDER_2", 8), "restart",
  },
  GSIntroMagikarp = {
    f("GS_INTRO_MAGIKARP_1", 1, OAM_XFLIP),
    f("GS_INTRO_MAGIKARP_2", 1, OAM_XFLIP),
    "restart",
  },
  GSIntroLapras = {
    f("GS_INTRO_LAPRAS_1", 7), f("GS_INTRO_LAPRAS_2", 7),
    f("GS_INTRO_LAPRAS_3", 7), f("GS_INTRO_LAPRAS_1", 7),
    "restart",
  },
  GSIntroNote = { f("GS_INTRO_NOTE", 8), "end" },
  GSIntroInvisibleNote = { f("GS_INTRO_INVISIBLE_NOTE", 8), "end" },
  GSIntroJigglypuff = {
    f("GS_INTRO_JIGGLYPUFF_1", 25, OAM_XFLIP),
    f("GS_INTRO_JIGGLYPUFF_3", 9),
    f("GS_INTRO_JIGGLYPUFF_1", 25),
    f("GS_INTRO_JIGGLYPUFF_3", 9),
    "restart",
  },
  GSIntroJigglypuff2 = { f("GS_INTRO_JIGGLYPUFF_2", 32), "end" },
  GSIntroPikachu = {
    f("GS_INTRO_PIKACHU_1", 4), f("GS_INTRO_PIKACHU_2", 5),
    f("GS_INTRO_PIKACHU_4", 4), "restart",
  },
  GSIntroPikachu2 = { f("GS_INTRO_PIKACHU_2", 8), "end" },
  GSIntroPikachu3 = { f("GS_INTRO_PIKACHU_3", 32), "end" },
  GSIntroPikachuTail = {
    f("GS_INTRO_PIKACHU_TAIL_1", 3), f("GS_INTRO_PIKACHU_TAIL_2", 3),
    f("GS_INTRO_PIKACHU_TAIL_3", 3), f("GS_INTRO_PIKACHU_TAIL_2", 3),
    "restart",
  },
  GSIntroPikachuTail2 = { f("GS_INTRO_PIKACHU_TAIL_1", 31), "end" },
  GSIntroFireball = {
    f("GS_INTRO_SMALL_FIREBALL", 1), f("GS_INTRO_MED_FIREBALL", 1),
    f("GS_INTRO_BIG_FIREBALL", 1), DELETE,
  },
  GSIntroChikorita = { f("GS_INTRO_CHIKORITA", 24), DELETE },
  GSIntroCyndaquil = { f("GS_INTRO_CYNDAQUIL", 24, OAM_XFLIP), DELETE },
  GSIntroTotodile = { f("GS_INTRO_TOTODILE", 24), DELETE },
  -- The logo holds one frame forever; the star flips vertically every three
  -- frames, which is what makes it twinkle as it spirals.
  GameFreakLogo = { f("GS_GAMEFREAK_LOGO", 8), "end" },
  GSGameFreakLogoStar = {
    f("GS_GAMEFREAK_LOGO_STAR", 3),
    f("GS_GAMEFREAK_LOGO_STAR", 3, OAM_YFLIP),
    "restart",
  },
  GSGameFreakLogoSparkle = {
    f("GS_GAMEFREAK_LOGO_SPARKLE_1", 2), f("GS_GAMEFREAK_LOGO_SPARKLE_2", 2),
    f("GS_GAMEFREAK_LOGO_SPARKLE_3", 2), f("GS_GAMEFREAK_LOGO_SPARKLE_2", 2),
    "restart",
  },
}

--------------------------------------------------------------------------
-- data/sprite_anims/objects.asm
--------------------------------------------------------------------------

local OBJECTS = {
  GS_INTRO_BUBBLE = { "GSIntroBubble", "GSIntroBubble" },
  GS_INTRO_SHELLDER = { "GSIntroShellder", "GSIntroShellder" },
  GS_INTRO_MAGIKARP = { "GSIntroMagikarp", "GSIntroMagikarp" },
  GS_INTRO_LAPRAS = { "GSIntroLapras", "GSIntroLapras" },
  GS_INTRO_NOTE = { "GSIntroNote", "GSIntroNote" },
  GS_INTRO_INVISIBLE_NOTE = { "GSIntroInvisibleNote", "GSIntroNote" },
  GS_INTRO_JIGGLYPUFF = { "GSIntroJigglypuff", "GSIntroJigglypuff" },
  GS_INTRO_PIKACHU = { "GSIntroPikachu", "GSIntroPikachu" },
  GS_INTRO_PIKACHU_TAIL = { "GSIntroPikachuTail", "GSIntroPikachuTail" },
  GS_INTRO_FIREBALL = { "GSIntroFireball", "GSIntroFireball" },
  GS_INTRO_CHIKORITA = { "GSIntroChikorita", "GSIntroChikoritaTotodile" },
  GS_INTRO_CYNDAQUIL = { "GSIntroCyndaquil", "GSIntroCyndaquil" },
  GS_INTRO_TOTODILE = { "GSIntroTotodile", "GSIntroChikoritaTotodile" },
  GAMEFREAK_LOGO = { "GameFreakLogo", "GameFreakLogo" },
  GS_GAMEFREAK_LOGO_STAR = { "GSGameFreakLogoStar", "GSGameFreakLogoStar" },
  GS_GAMEFREAK_LOGO_SPARKLE =
    { "GSGameFreakLogoSparkle", "GSGameFreakLogoSparkle" },
}

--------------------------------------------------------------------------
-- engine/sprite_anims/core.asm
--------------------------------------------------------------------------

local System = {}
System.__index = System

local function newStruct()
  return {
    index = 0, framesetId = nil, seqId = nil,
    x = 0, y = 0, xOffset = 0, yOffset = 0,
    duration = 0, durationOffset = 0, frame = -1,
    jt = 0, var1 = 0, var2 = 0, var3 = 0, var4 = 0,
    oamFlags = 0,
  }
end

-- `flag` is wIntroSpriteStateFlag, which the movie and three of the sequences
-- hand back and forth (Lapras sets it when it leaves; Jigglypuff waits on it).
function SpriteAnims.new()
  local self = setmetatable({
    structs = {},
    animCount = 0,
    globalX = 0, -- wGlobalAnimXOffset
    globalY = 0, -- wGlobalAnimYOffset
    flag = 0,
    -- GetSpriteAnimVTile's answer for whatever wSpriteAnimDict holds.  The
    -- intro leaves the dict empty and so resolves to 0; the GameFreak splash
    -- writes SPRITE_ANIM_DICT_GS_SPLASH -> $8d and every OAM set's offset is
    -- relative to that.
    vtileBase = 0,
    oam = {},
  }, System)
  for slot = 1, NUM_STRUCTS do self.structs[slot] = newStruct() end
  return self
end

-- ClearSpriteAnims zeroes the whole block, counter included.
function System:clear()
  for slot = 1, NUM_STRUCTS do self.structs[slot] = newStruct() end
  self.animCount = 0
  self.oam = {}
end

-- _InitSpriteAnimStruct: first free slot wins, nil if all ten are busy.
function System:init(objectId, x, y)
  local object = OBJECTS[objectId]
  if not object then error("unknown sprite anim object: " .. tostring(objectId)) end
  for slot = 1, NUM_STRUCTS do
    local st = self.structs[slot]
    if st.index == 0 then
      -- wSpriteAnimCount increments and skips 0, so the index doubles as the
      -- per-object variation several sequences read out of field 0.
      self.animCount = (self.animCount + 1) % 256
      if self.animCount == 0 then self.animCount = 1 end
      st.index = self.animCount
      st.framesetId = object[1]
      st.seqId = object[2]
      st.x, st.y = x % 256, y % 256
      st.xOffset, st.yOffset = 0, 0
      st.duration, st.durationOffset = 0, 0
      st.frame = -1
      st.jt, st.var1, st.var2, st.var3, st.var4 = 0, 0, 0, 0, 0
      st.oamFlags = 0
      return st
    end
  end
  return nil
end

local function deinit(st)
  st.index = 0
end

-- _ReinitSpriteAnimFrame: swap framesets and restart the frame walk.
local function reinit(st, framesetId)
  st.framesetId = framesetId
  st.duration = 0
  st.frame = -1
end

-- GetSpriteAnimFrame.  Returns the OAM set name for this frame; "wait" and
-- "delete" come back as themselves because UpdateAnimFrame, not this, is what
-- acts on them.
local function getFrame(st)
  local frames = FRAMESETS[st.framesetId]
  for _ = 1, 64 do
    if st.duration ~= 0 then
      st.duration = st.duration - 1
      local entry = frames[st.frame + 1]
      st.oamFlags = entry.flags
      return entry.oamset
    end
    st.frame = st.frame + 1
    local entry = frames[st.frame + 1]
    if entry == "restart" then
      st.duration = 0
      st.frame = -1
    elseif entry == "end" then
      -- Step back two so the next pass lands on the frame before this one.
      st.duration = 0
      st.frame = st.frame - 2
    else
      st.duration = (entry.duration + st.durationOffset) % 256
      st.oamFlags = entry.flags
      return entry.oamset
    end
  end
  error("sprite anim frameset never yields a frame: " .. tostring(st.framesetId))
end

-- AddOrSubtractY / AddOrSubtractX: a flipped object mirrors around its own
-- 8-pixel cell, which is `-8 - offset`.
local function mirror(value, flip)
  if not flip then return value end
  return (-(value + 8)) % 256
end

-- GetSpriteOAMAttr: the frame's flip flags toggle the entry's, everything
-- else (palette, bank) passes through.
local function attrOf(attr, flags)
  local toggled = bit.band(bit.bxor(attr, flags), OAM_FLAG_MASK)
  return bit.band(attr, 0xff - OAM_FLAG_MASK) + toggled
end

-- UpdateAnimFrame.  Returns true once wShadowOAM is full, which is the carry
-- that stops DoNextFrameForAllSprites.
function System:updateAnimFrame(st)
  -- InitSpriteAnimBuffer
  st.oamFlags = 0
  local oamset = getFrame(st)
  if oamset == "wait" then return false end
  if oamset == "delete" then
    deinit(st)
    return false
  end
  local set = OAMSETS[oamset]
  if not set then error("unknown OAM set: " .. tostring(oamset)) end
  local vtile = set[1] % 256
  local yFlip = bit.band(st.oamFlags, OAM_YFLIP) ~= 0
  local xFlip = bit.band(st.oamFlags, OAM_XFLIP) ~= 0
  for _, entry in ipairs(set[2]) do
    if #self.oam >= OAM_LIMIT then return true end
    self.oam[#self.oam + 1] = {
      y = (st.y + st.yOffset + self.globalY + mirror(entry.y, yFlip)) % 256,
      x = (st.x + st.xOffset + self.globalX + mirror(entry.x, xFlip)) % 256,
      tile = (self.vtileBase + vtile + entry.tile) % 256,
      attr = attrOf(entry.attr, st.oamFlags),
    }
  end
  return false
end

--------------------------------------------------------------------------
-- engine/sprite_anims/functions.asm
--------------------------------------------------------------------------

local SEQUENCES = {}

SEQUENCES.GSIntroBubble = function(_, st)
  local age = st.var2
  st.var2 = (st.var2 + 1) % 256
  if age >= 0x40 then
    deinit(st)
    return
  end
  st.yOffset = (st.yOffset - 1) % 256
  st.var1 = (st.var1 + 2) % 256
  st.xOffset = SpriteAnims.sine(st.var1, 8)
end

-- A Shellder is deleted once the rising camera has carried it past the bottom
-- of the screen; wGlobalAnimYOffset is the climb, and it is only read here.
SEQUENCES.GSIntroShellder = function(sys, st)
  if (sys.globalY + st.y) % 256 >= 0xb0 then deinit(st) end
end

SEQUENCES.GSIntroMagikarp = function(_, st)
  if st.jt == 0 then
    st.jt = st.jt + 1
    -- swap of a 0-3 value: the struct index spreads the school's phases out.
    st.var1 = st.index % 4 * 16
  end
  -- lb de, 2, 1 on a CGB; the SGB branch doubles both.
  local dx, dphase = 2, 1
  if st.xOffset >= 0xf0 then
    deinit(st)
    return
  end
  st.xOffset = (st.xOffset + dx) % 256
  st.var1 = (st.var1 + dphase) % 256
  st.yOffset = SpriteAnims.sine(st.var1, 8)
end

-- Lapras bobs on every frame and only moves on the odd ones; .update_y_offset
-- returns zero on the even ones, which is what `ret z` skips on.
local function laprasBob(st)
  local phase = st.var1
  st.var1 = (st.var1 + 1) % 256
  st.yOffset = SpriteAnims.sine(phase, 4)
  return st.var1 % 2 == 0
end

SEQUENCES.GSIntroLapras = function(sys, st)
  if st.jt == 0 then
    if laprasBob(st) then return end
    if st.x < 0x58 then
      st.jt = st.jt + 1
      st.var2 = 0xb0
      return
    end
    st.x = (st.x - 1) % 256
  elseif st.jt == 1 then
    laprasBob(st)
    if st.var2 == 0 then
      st.jt = st.jt + 1
      return
    end
    st.var2 = st.var2 - 1
  else
    if laprasBob(st) then return end
    if st.x == 0xd0 then
      deinit(st)
      sys.flag = 1
      return
    end
    st.x = (st.x - 1) % 256
  end
end

SEQUENCES.GSIntroNote = function(_, st)
  if st.jt == 0 then
    st.jt = st.jt + 1
    -- (index & 1) swapped then doubled: alternate notes start half a period on.
    st.var1 = st.index % 2 * 0x20
  end
  if st.xOffset >= 0x80 then
    deinit(st)
    return
  end
  st.xOffset = (st.xOffset + 1) % 256
  st.var1 = (st.var1 + 2) % 256
  local wobble = SpriteAnims.sine(st.var1, 4)
  st.yOffset = wobble
  -- The `and $2` tests the sine result, not var1 -- the hl it reloads first is
  -- thrown away -- so the note drifts up on two frames out of every four.
  if wobble % 4 >= 2 then st.y = (st.y - 1) % 256 end
end

SEQUENCES.GSIntroJigglypuff = function(sys, st)
  if st.jt == 0 then
    if sys.flag == 0 then return end
    st.jt = st.jt + 1
    reinit(st, "GSIntroJigglypuff2")
  end
  if st.x == 0xd0 then
    deinit(st)
    return
  end
  st.x = (st.x - 2) % 256
end

SEQUENCES.GSIntroPikachu = function(sys, st)
  if st.jt == 0 then
    if st.x == 0x80 then
      st.jt = st.jt + 1
      st.var2 = 0x30
      reinit(st, "GSIntroPikachu2")
      return
    end
    st.x = (st.x - 1) % 256
  elseif st.jt == 1 then
    if st.var2 == 0 then
      st.jt = st.jt + 1
      reinit(st, "GSIntroPikachu3")
      return
    end
    st.var2 = st.var2 - 1
  elseif st.jt == 2 then
    st.var1 = (st.var1 + 4) % 256
    st.yOffset = SpriteAnims.sine(st.var1, 4)
    if st.x == 0x50 then
      sys.flag = 1
      st.jt = st.jt + 1
      return
    end
    st.x = (st.x - 4) % 256
  else
    if st.x == 0xd0 then
      deinit(st)
      return
    end
    st.x = (st.x - 2) % 256
  end
end

SEQUENCES.GSIntroPikachuTail = function(sys, st)
  if st.jt == 0 then
    if st.x == 0x80 then
      st.jt = st.jt + 1
      st.var2 = 0x30
      reinit(st, "GSIntroPikachuTail2")
      return
    end
    st.x = (st.x - 1) % 256
  elseif st.jt == 1 then
    if st.var2 == 0 then
      st.jt = st.jt + 1
      return
    end
    local before = st.var2
    st.var2 = st.var2 - 1
    -- Two thirds of the way through the wind-up the tail starts swishing again.
    if before == 0x20 then reinit(st, "GSIntroPikachuTail") end
  else
    st.var1 = (st.var1 + 4) % 256
    st.yOffset = SpriteAnims.sine(st.var1, 4)
    if st.x == 0xd0 then
      deinit(st)
      return
    end
    st.x = (st.x - 2) % 256
    -- Before Pikachu himself has left, the tail runs at double speed to catch
    -- up with the body it belongs to.
    if sys.flag ~= 0 then return end
    st.x = (st.x - 2) % 256
  end
end

SEQUENCES.GSIntroFireball = function(_, st)
  if st.jt == 0 then
    st.jt = st.jt + 1
    -- Two slices of the struct index become the launch angle, so consecutive
    -- fireballs leave the mouth in different directions.
    st.var1 = (st.index % 4 * 16 + bit.band(st.index, 4) * 2) % 256
    return
  end
  st.x = (st.x - 4) % 256
  local amplitude = st.var2
  st.var2 = (st.var2 + 8) % 256
  st.yOffset = SpriteAnims.sine(st.var1, amplitude)
  st.xOffset = SpriteAnims.cosine(st.var1, amplitude)
end

-- The starters flash in from off-screen along a quarter arc: var1/var2 are two
-- angles a sixth of a period apart, and the amplitude is a flat $90 pixels.
local function starterFlash(st, xPhase)
  if st.jt == 0 then
    st.jt = st.jt + 1
    st.var1 = 0x30
    st.var2 = xPhase
    return
  end
  if st.var1 >= 0x3c then return end
  -- `inc [hl]` twice leaves a holding the value from before, so both offsets
  -- lag their counter by one step.
  local yPhase = st.var1
  st.var1 = (st.var1 + 2) % 256
  st.yOffset = SpriteAnims.sine(yPhase, 0x90)
  local xAngle = st.var2
  st.var2 = (st.var2 + 2) % 256
  st.xOffset = SpriteAnims.cosine(xAngle, 0x90)
end

SEQUENCES.GSIntroChikoritaTotodile = function(_, st) starterFlash(st, 0x30) end
SEQUENCES.GSIntroCyndaquil = function(_, st) starterFlash(st, 0x10) end

-- AnimSeq_GameFreakLogo does nothing but call GameFreakPresents_UpdateLogoPal,
-- which is a palette clock rather than a struct move; the splash screen owns
-- that clock, so the struct itself just sits where it was placed.
SEQUENCES.GameFreakLogo = function() end

-- The star spirals inward: VAR1 is the radius, dropping 2 a frame from $80 to
-- 0 over 64 frames, and every time it crosses a multiple of $20 the per-frame
-- angle step (VAR2, counting DOWN from 0 through $ff, $fe...) gets one bigger,
-- so it whips round faster the tighter it gets.  The sine reads the radius
-- from BEFORE the decrement -- `ld d, a` happens first.
--
-- Its death is the scene's cue: .delete writes wIntroSceneFrameCounter, which
-- is what GameFreakPresents_PlaceLogo is waiting on, and `flag` carries that
-- here the same way it carries wIntroSpriteStateFlag for the movie.
SEQUENCES.GSGameFreakLogoStar = function(sys, st)
  local radius = st.var1
  if radius == 0 then
    sys.flag = 1
    deinit(st)
    return
  end
  st.var1 = (st.var1 - 2) % 256
  if radius % 0x20 == 0 then st.var2 = (st.var2 - 1) % 256 end
  local angle = st.jt
  st.yOffset = SpriteAnims.sine(angle, radius)
  st.xOffset = SpriteAnims.cosine(angle, radius)
  st.jt = (st.jt + st.var2) % 256
end

-- A sparkle flies out along the angle its spawn picked.  Two 16-bit values
-- share the four VAR slots: VAR1/VAR2 is a speed that bleeds off by $10 a
-- frame, VAR3/VAR4 the distance it has accumulated -- and VAR4, the HIGH byte
-- of that distance, is read back as the sine amplitude, which is what turns a
-- 16-bit accumulator into a smooth 8-bit radius.  The angle flips half a turn
-- every frame (`xor $20`), so one struct reads as a pair of opposed sparkles.
SEQUENCES.GSGameFreakLogoSparkle = function(_, st)
  local speed = st.var1 + st.var2 * 256
  if speed == 0 then
    deinit(st)
    return
  end
  local amplitude, angle = st.var4, st.jt
  st.yOffset = SpriteAnims.sine(angle, amplitude)
  st.xOffset = SpriteAnims.cosine(angle, amplitude)
  local travelled = (st.var3 + st.var4 * 256 + speed) % 0x10000
  st.var3, st.var4 = travelled % 256, math.floor(travelled / 256)
  speed = (speed - 0x10) % 0x10000
  st.var1, st.var2 = speed % 256, math.floor(speed / 256)
  st.jt = bit.bxor(st.jt, 0x20)
end

-- PlaySpriteAnimations / DoNextFrameForAllSprites: run every live struct's
-- sequence, then let it write its OAM entries.  A struct that deinitializes
-- itself still draws this frame -- the ASM calls UpdateAnimFrame either way.
function System:playFrame()
  self.oam = {}
  for slot = 1, NUM_STRUCTS do
    local st = self.structs[slot]
    if st.index ~= 0 then
      local sequence = SEQUENCES[st.seqId]
      if not sequence then
        error("unknown sprite anim sequence: " .. tostring(st.seqId))
      end
      sequence(self, st)
      if self:updateAnimFrame(st) then break end
    end
  end
  return self.oam
end

function System:activeCount()
  local count = 0
  for slot = 1, NUM_STRUCTS do
    if self.structs[slot].index ~= 0 then count = count + 1 end
  end
  return count
end

SpriteAnims.OAMSETS = OAMSETS
SpriteAnims.FRAMESETS = FRAMESETS
SpriteAnims.OBJECTS = OBJECTS
SpriteAnims.SEQUENCES = SEQUENCES
SpriteAnims.NUM_STRUCTS = NUM_STRUCTS
SpriteAnims.OAM_LIMIT = OAM_LIMIT
SpriteAnims.OAM_PRIO = OAM_PRIO
SpriteAnims.OAM_YFLIP = OAM_YFLIP
SpriteAnims.OAM_XFLIP = OAM_XFLIP

return SpriteAnims
