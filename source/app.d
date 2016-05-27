import std.stdio;
import gbemu.emulator;

void main()
{
	auto emulator = new Emulator();
	emulator.loadRom("roms/tetris.gb");
	emulator.start();
}
