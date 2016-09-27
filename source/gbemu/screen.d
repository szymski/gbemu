module gbemu.screen;

import derelict.opengl3.gl;
import gbemu.memory;

class Screen
{
	Memory memory;

	this(Memory memory) {
		this.memory = memory;
	}

	ubyte[8][8] getTilePatternPixels(ubyte tableId)(ubyte tileId) {
		static assert(tableId < 2, "Tile pattern table id must be 0 or 1.");

		assert(tileId < 256, "tileId must be less than 256.");

		ubyte[16] tileDataBytes;

		static if(tableId == 0)
			tileDataBytes = memory[0x8000 + tileId * 16 .. 0x8000 + tileId * 16 + 16];
		else
			tileDataBytes = memory[0x8800 + tileId * 16 .. 0x8800 + tileId * 16 + 16];

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
			return memory[0x9800 + x + (y * 32)];
		else
			return memory[0x9C00 + x + (y * 32)];
	}
}

struct Pixel {
	ubyte r, g, b;
}

class ScreenRenderer {
	const palette = [Pixel(255, 255, 255), Pixel(192, 192, 192), Pixel(96, 96, 96), Pixel(0, 0, 0)];

	Screen screen;
	Pixel[160][144] screenBytes;

	this(Screen screen) {
		this.screen = screen;

		// TODO: Debug, remove
		import std.file;
		auto rom = cast(ubyte[])read("rom.bin");
		screen.memory.vram = rom[0x8000 .. 0xA000];
	}

	void render() {
		renderToBytes();
		renderToScreen();
	}

	private void renderToBytes() {
		foreach(y; 0 .. 18)
		foreach(x; 0 .. 20) {
			ubyte tileId =  screen.getTileMapByte!0(cast(ubyte)x, cast(ubyte)y);
			ubyte[8][8] tilePixels = screen.getTilePatternPixels!0(tileId);
			foreach(pY; 0 .. 8)
			foreach(pX; 0 .. 8)
					screenBytes[y * 8 + pY][x * 8 + pX] = palette[tilePixels[pX][pY]];
		}
	}

	private void renderToScreen() {
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		glViewport(0, 0, 800, 600);
		glOrtho(0, 800, 0, 600, -1, 1);
		glMatrixMode(GL_MODELVIEW);
		
		glRasterPos3f(0, 600, 0);
		glPixelZoom(3f, -3f);
		glDrawPixels(160, 144, GL_RGB, GL_UNSIGNED_BYTE, screenBytes.ptr);
	}
}