module gbemu.screen;

import derelict.opengl3.gl;
import gbemu.gpu;

struct Pixel {
	ubyte r, g, b;
}

class ScreenRenderer {
	const palette = [Pixel(255, 255, 255), Pixel(192, 192, 192), Pixel(96, 96, 96), Pixel(0, 0, 0)];

	Gpu gpu;
	Pixel[160][144] screenBytes;
	Pixel[32 * 8][32 * 8] tileBytes;

	this(Gpu gpu) {
		this.gpu = gpu;

		// TODO: Debug, remove
		import std.file;
		//auto rom = cast(ubyte[])read("rom.bin");
		//screen.memory.vram = rom[0x8000 .. 0xA000];
	}

	void render() {
		renderToBytes();
		renderToScreen();
	}

	private void renderToBytes() {
		foreach(y; 0 .. 18)
		foreach(x; 0 .. 20) {
			ubyte tileId =  gpu.getTileMapByte!0(cast(ubyte)x, cast(ubyte)y);
			ubyte[8][8] tilePixels = gpu.getTilePatternPixels!0(tileId);
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
		glLoadIdentity();
		
		glRasterPos3f(0, 600, 0);
		glPixelZoom(1f, -1f);
		glDrawPixels(160, 144, GL_RGB, GL_UNSIGNED_BYTE, screenBytes.ptr);

		// Tiles
		glRasterPos3f(300, 600, 0);

		foreach(i; 0 .. 256) {
			ubyte[8][8] tilePixels = gpu.getTilePatternPixels!0(cast(ubyte)i);
			foreach(pY; 0 .. 8)
				foreach(pX; 0 .. 8)
					tileBytes[(i / 32) * 8 + pY][(i % 32) * 8 + pX] = palette[tilePixels[pX][pY]];
		}

		glDrawPixels(32 * 8, 32 * 8, GL_RGB, GL_UNSIGNED_BYTE, tileBytes.ptr);
	}
}