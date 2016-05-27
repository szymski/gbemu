module gbemu.cpu;

import std.experimental.logger, std.format, std.stdio, std.conv : to;
import gbemu.emulator, gbemu.registers, gbemu.memory;

class Instruction {
	string disassembly;
	ubyte length;
	void delegate() execute;

	this(string disassembly, ubyte length, void delegate() execute) {
		this.disassembly = disassembly;
		this.length = length;
		this.execute = execute;
	}
}

class Cpu
{
	Emulator emulator;
	Memory memory;

	Registers registers;

	Instruction[256] instructions;

	this(Emulator emulator)
	{
		this.emulator = emulator;
		memory = emulator.memory;
		 
		reset();
		registerInstructions();
	}

	void reset() { 
		registers.pc = 0;
		registers.sp = 0;
	}

	void registerInstructions() {
		registerInstruction!(0x00, "NOP", 0)(&nop);
		registerInstruction!(0x01, "LD BC, 0x%X", 2)(&ld_reg_nn!"bc");
		registerInstruction!(0x02, "LD (BC), A", 0)(&ld_regptr_reg!("bc", "a"));
		registerInstruction!(0x03, "INC BC", 0)(&inc_reg!"bc");
		registerInstruction!(0x04, "INC B", 0)(&inc_reg!"b");
		registerInstruction!(0x05, "DEC B", 0)(&dec_reg!"b");
		registerInstruction!(0x06, "LD B, 0x%X", 1)(&ld_reg_n!"b");

		registerInstruction!(0x08, "LD (0x%X), SP", 2)(&ld_nnptr_reg!"sp");
		registerInstruction!(0x09, "ADD HL, BC", 0)(&add_reg_reg!("hl", "bc"));
		registerInstruction!(0x0A, "LD A, (BC)", 0)(&ld_reg_regptr!("a", "bc"));
		registerInstruction!(0x0B, "DEC BC", 0)(&dec_reg!"bc");
		registerInstruction!(0x0C, "INC C", 0)(&inc_reg!"c");
		registerInstruction!(0x0D, "DEC C", 0)(&dec_reg!"c");
		registerInstruction!(0x0E, "LD C, 0x%X", 1)(&ld_reg_n!"c");


		registerInstruction!(0xC3, "JP 0x%X", 2)(&jp_nn);
	}

	void registerInstruction(ubyte opcode, string disassembly, ubyte length, T...)(void delegate(T) execute) {
		static if(length == 1)
			static assert(is(typeof(execute) : void delegate(ubyte)), "Invalid delegate type. For operand size 1, it must be void delegate(ubyte).");
		static if(length == 2)
			static assert(is(typeof(execute) : void delegate(ushort)), "Invalid delegate type. For operand size 2, it must be void delegate(ushort).");

		instructions[opcode] = new Instruction(disassembly, length, cast(void delegate())execute);
	}

	/*
	 * Instruction handlers
	 */

	void nop() {
	}

	// LD reg, nn
	void ld_reg_nn(string register)(ushort value) {
		mixin(`registers.` ~ register ~ ` = value;`);
	}

	// LD reg, n
	void ld_reg_n(string register)(ubyte value) {
		mixin(`registers.` ~ register ~ ` = value;`);
	}

	// LD (reg), nn
	void ld_regptr_nn(string register)(ushort value) {
		// TODO:
		mixin(`memory[registers.` ~ register ~ `] = value;`);
	}

	// LD (reg), reg
	void ld_regptr_reg(string register1, string register2)(ushort value) {
		mixin(`memory[registers.` ~ register1 ~ `] = registers.` ~ register2 ~ `;`);
	}

	// LD reg, reg
	void ld_reg_reg(string register1, string register2)() {
		mixin(`registers.` ~ register1 ~ ` = registers.` ~ register2 ~ `;`);
	}

	// LD reg, (reg)
	void ld_reg_regptr(string register1, string register2)() {
		mixin(`registers.` ~ register1 ~ ` = memory[registers.` ~ register2 ~ `];`);
	}

	// LD (nn), reg
	void ld_nnptr_reg(string register)(ushort value) {
		mixin(`memory[value] = registers.` ~ register ~ `;`);
	}

	// INC reg
	void inc_reg(string register)() {
		// TODO: Flags
		mixin(`registers.` ~ register ~ `++;`);
	}

	// DEC reg
	void dec_reg(string register)() {
		// TODO: Flags
		mixin(`registers.` ~ register ~ `--;`);
	}

	// ADD reg, reg
	void add_reg_reg(string register1, string register2)() {
		// TODO: Flags
		mixin(`registers.` ~ register1 ~ ` += registers.` ~ register2 ~ `;`);
	}

	void jp_nn(ushort address) {
		registers.pc = address;
	}

	/*
	 * End Instruction handlers
	 */

	void doCycle() {
		auto opcode = memory[registers.pc];
		registers.pc++;

		log("Executing: 0x", opcode.to!string(16));

		if(auto instruction = instructions[opcode]) {
			logInstruction(instruction);
			executeInstruction(instruction);
		}
		else
			log("Unknown opcode: 0x", opcode.to!string(16));
	}

	void executeInstruction(Instruction instruction) {
		if(instruction.length == 0)
			instruction.execute();
		else if(instruction.length == 1) {
			auto value = readByte();
			(cast(void delegate(ubyte))(instruction.execute))(value);
		}
		else if(instruction.length == 2) {
			auto value = readShort();
			(cast(void delegate(ushort))(instruction.execute))(value);
		}
	}

	ubyte readByte() {
		ubyte value = memory[registers.pc];
		registers.pc++;
		return value;
	}

	ushort readShort() {
		ushort value = memory[cast(ushort)(registers.pc + 1)] << 8 | cast(ushort)memory[registers.pc];
		registers.pc += 2;
		return value;
	}

	ubyte readByteNoMove() {
		ubyte value = memory[registers.pc];
		return value;
	}
	
	ushort readShortNoMove() {
		ushort value = memory[cast(ushort)(registers.pc + 1)] << 8 | cast(ushort)memory[registers.pc];
		return value;
	}

	void logInstruction(Instruction instruction) {
		writef("0x%X: ", registers.pc);

		if(instruction.length == 0)
			writefln(format(instruction.disassembly));
		else if(instruction.length == 1)
			writefln(format(instruction.disassembly, readByteNoMove));
		else if(instruction.length == 2)
			writefln(format(instruction.disassembly, readShortNoMove));
	}
}

