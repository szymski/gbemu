import std.stdio;
import gbemu.emulator;
import std.file : read;

void main()
{
	auto emulator = new Emulator();
	emulator.loadRom((cast(ubyte[])read("roms/tetris.gb"))[0 .. 32 * 1024]);
	emulator.start();
}
