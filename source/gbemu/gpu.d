module gbemu.gpu;

import gbemu.emulator;
import gbemu.memory;

class Gpu
{
	Emulator emulator;
	private Memory _memory;

	ubyte lcdcYCoord;

	this(Emulator emulator)
	{
		this.emulator = emulator;
		_memory = emulator.memory;

		lcdcYCoord = 0;
	}

	ubyte[8][8] getTilePatternPixels(ubyte tableId)(ubyte tileId) {
		static assert(tableId < 2, "Tile pattern table id must be 0 or 1.");
		
		assert(tileId < 256, "tileId must be less than 256.");
		
		ubyte[16] tileDataBytes;
		
		static if(tableId == 0)
			tileDataBytes = _memory[0x8000 + tileId * 16 .. 0x8000 + tileId * 16 + 16];
		else
			tileDataBytes = _memory[0x8800 + tileId * 16 .. 0x8800 + tileId * 16 + 16];
		
		ubyte[8][8] pixels;
		
		foreach(y; 0 .. 8) {
			ubyte lineDataUp = tileDataBytes[y * 2];
			ubyte lineDataDown = tileDataBytes[y * 2 + 1];
			
			pixels[0][y] = ((lineDataUp >> 7) & 0x1) + ((lineDataDown >> 7) & 0x1) * 2;
			pixels[1][y] = ((lineDataUp >> 6) & 0x1) + ((lineDataDown >> 6) & 0x1) * 2;
			pixels[2][y] = ((lineDataUp >> 5) & 0x1) + ((lineDataDown >> 5) & 0x1) * 2;
			pixels[3][y] = ((lineDataUp >> 4) & 0x1) + ((lineDataDown >> 4) & 0x1) * 2;
			pixels[4][y] = ((lineDataUp >> 3) & 0x1) + ((lineDataDown >> 3) & 0x1) * 2;
			pixels[5][y] = ((lineDataUp >> 2) & 0x1) + ((lineDataDown >> 2) & 0x1) * 2;
			pixels[6][y] = ((lineDataUp >> 1) & 0x1) + ((lineDataDown >> 1) & 0x1) * 2;
			pixels[7][y] = ((lineDataUp >> 0) & 0x1) + ((lineDataDown >> 0) & 0x1) * 2;
		}

		return pixels;
	}
	
	ubyte getTileMapByte(ubyte tileMapId)(ubyte x, ubyte y) {
		static assert(tileMapId < 2, "Map must be 0 or 1.");
		
		assert(x < 32, "X must be less than 20.");
		assert(y < 32, "Y must be less than 18.");
		
		static if(tileMapId == 0)
			return _memory[0x9800 + x + (y * 32)];
		else
			return _memory[0x9C00 + x + (y * 32)];
	}
	
	void update() {
		lcdcYCoord = (lcdcYCoord + 1) % 154;
	}
}