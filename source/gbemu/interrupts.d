module gbemu.interrupts;

import std.datetime, std.experimental.logger;
import gbemu.emulator;

enum InterruptFlags {
	vblank = 1 << 0,
	lcdStat = 1 << 1,
	timer = 1 << 2,
	serial = 1 << 3,
	joypad = 1 << 4,
}

class Interrupts {

	Emulator emulator;

	auto cpu() { return emulator.cpu; }

	ubyte master;
	ubyte enable;
	ubyte flags;

	enum delayVblank = 16750418;
	enum delayYCoord = 16750418 / 160;

	StopWatch stopwatchVblank;
	StopWatch stopwatchYCoord;

	this(Emulator emulator) {
		this.emulator = emulator;

		stopwatchVblank.start();
		stopwatchYCoord.start();
	}

	void update() {
		if(stopwatchYCoord.peek.nsecs > delayYCoord) {
			stopwatchYCoord.reset();
			yCoord();
		}

		if(master == 0 || enable == 0)
			return;

		if(stopwatchVblank.peek.nsecs > delayVblank) {
			stopwatchVblank.reset();
			vblank();
		}
	}

	void vblank() {
		log("vblank");

		flags = InterruptFlags.vblank;
		master = 0;
		cpu.stackPush!ushort(cpu.registers.pc);
		cpu.registers.pc = 0x40;
	}

	void lcdStat() {
		flags = InterruptFlags.lcdStat;
		master = 0;
		cpu.stackPush!ushort(cpu.registers.pc);
		cpu.registers.pc = 0x50;
	}

	// TODO: Move this somewhere else
	void yCoord() {
		//log("yCoord: ", emulator.memory[0xFF44]);
		emulator.memory[0xFF44] = cast(ubyte)(emulator.memory[0xFF44] + 1);
		if(emulator.memory[0xFF44] >= 160)
			emulator.memory[0xFF44] = 0;
	}
}