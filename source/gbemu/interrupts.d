module gbemu.interrupts;

import std.datetime, std.experimental.logger;
import gbemu.emulator;

class Interrupts {

	Emulator emulator;

	auto cpu() { return emulator.cpu; }

	ubyte master;
	ubyte enable;
	ubyte flags;

	enum delayVblank = 16750418;

	StopWatch stopwatchVblank;

	this(Emulator emulator) {
		this.emulator = emulator;

		stopwatchVblank.start();
	}

	void update() {
		if(master == 0 || enable == 0 || flags == 0)
			return;

		if(stopwatchVblank.peek.nsecs > delayVblank) {
			stopwatchVblank.reset();
			vblank();
		}
	}

	void vblank() {
		log("vblank");

		master = 0;
		cpu.stackPush!ushort(cpu.registers.pc);
		cpu.registers.pc = 0x40;
	}

	void lcdStat() {
		master = 0;
		cpu.stackPush!ushort(cpu.registers.pc);
		cpu.registers.pc = 0x50;
	}
}