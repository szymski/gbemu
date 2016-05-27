module gbemu.memory;

import std.conv;

class Memory
{
	ubyte[0x8000] cartridge; // 0x0000 - 0x7FFF
	ubyte[0x2000] vram; // 0x8000 - 0x9FFF
	ubyte[0x2000] extram; // 0xA000 - 0xBFFF
	ubyte[0x2000] wram; // 0xC000 - 0xDFFF
	ubyte[0x100] oam; // 0xFE00 - 0xFE9F
	ubyte[0x100] io; // 0xFF00 - 0xFF7F
	ubyte[0x80] hram; // 0xFF80 - 0xFFFE

	ubyte opIndex(ushort address) {
		return getReference(address);
	}

	void opIndexAssign(ubyte value, ushort address) {
		getReference(address) = value;
	}

	void opIndexAssign(ushort value, ushort address) {
		getReference(address) = value >> 8;
		getReference(cast(ushort)(address + 1)) = value & 0xFF;
	}

	ref ubyte getReference(ushort address) {
		if(address >= 0x0000 && address <= 0x7FFF)
			return cartridge[address];

		if(address >= 0x8000 && address <= 0x9FFF)
			return vram[address - 0x8000];

		if(address >= 0xA000 && address <= 0xBFFF)
			return extram[address - 0xA000];

		if(address >= 0xC000 && address <= 0xDFFF)
			return wram[address - 0xC000];

		if(address >= 0xFE00 && address <= 0xFE9F)
			return oam[address - 0xFE00];

		if(address >= 0xFF7F && address <= 0xFF00)
			return io[address - 0xFF7F];

		if(address >= 0xFF80 && address <= 0xFFFE)
			return io[address - 0xFF80];

		throw new Exception("Invalid memory reference " ~ address.to!string(16));
	}
}

unittest {
	import std.random;

	Memory memory;

	foreach(i; 0 .. 0xCFFF) {
		ubyte value = cast(ubyte)uniform(0, 255);
		memory[cast(ushort)i] = value;
		assert(memory[cast(ushort)i] == value);
	}
}