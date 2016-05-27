﻿module gbemu.cpu;

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
		registerInstruction!(0x07, "RLCA", 0)(&rlca);
		registerInstruction!(0x08, "LD (0x%X), SP", 2)(&ld_nnptr_reg!"sp");
		registerInstruction!(0x09, "ADD HL, BC", 0)(&add_reg_reg!("hl", "bc"));
		registerInstruction!(0x0A, "LD A, (BC)", 0)(&ld_reg_regptr!("a", "bc"));
		registerInstruction!(0x0B, "DEC BC", 0)(&dec_reg!"bc");
		registerInstruction!(0x0C, "INC C", 0)(&inc_reg!"c");
		registerInstruction!(0x0D, "DEC C", 0)(&dec_reg!"c");
		registerInstruction!(0x0E, "LD C, 0x%X", 1)(&ld_reg_n!"c");
		registerInstruction!(0x0F, "RRCA", 0)(&rrca);
		registerInstruction!(0x10, "STOP", 1)(&stop);
		registerInstruction!(0x11, "LD DE, 0x%X", 2)(&ld_reg_nn!"de");
		registerInstruction!(0x12, "LD (DE), A", 0)(&ld_regptr_reg!("de", "a"));
		registerInstruction!(0x13, "INC DE", 0)(&inc_reg!"de");
		registerInstruction!(0x14, "INC D", 0)(&inc_reg!"d");
		registerInstruction!(0x15, "DEC D", 0)(&dec_reg!"d");
		registerInstruction!(0x16, "LD D, 0x%X", 1)(&ld_reg_n!"d");
		registerInstruction!(0x17, "RLA", 0)(&rla);
		registerInstruction!(0x18, "JR 0x%X", 1)(&jr_n);
		registerInstruction!(0x19, "ADD HL, DE", 0)(&add_reg_reg!("hl", "de"));
		registerInstruction!(0x1A, "LD A, (DE)", 0)(&ld_reg_regptr!("a", "de"));
		registerInstruction!(0x1B, "DEC DE", 0)(&dec_reg!"de");
		registerInstruction!(0x1C, "INC E", 0)(&inc_reg!"e");
		registerInstruction!(0x1D, "DEC E", 0)(&dec_reg!"e");
		registerInstruction!(0x1E, "LD E, 0x%X", 1)(&ld_reg_n!"e");
		registerInstruction!(0x1F, "RRA", 0)(&rra);
		registerInstruction!(0x20, "JR NZ, 0x%X", 1)(&jr_nz_n);
		registerInstruction!(0x21, "LD HL, 0x%X", 2)(&ld_reg_nn!"hl");
		registerInstruction!(0x22, "LDI (HL), A", 0)(&ldi_regptr_reg!("hl", "a"));
		registerInstruction!(0x23, "INC HL", 0)(&inc_reg!"hl");
		registerInstruction!(0x24, "INC H", 0)(&inc_reg!"h");
		registerInstruction!(0x25, "DEC H", 0)(&dec_reg!"h");
		registerInstruction!(0x26, "LD H, 0x%X", 1)(&ld_reg_n!"h");
		registerInstruction!(0x27, "DAA", 0)(&daa);
		registerInstruction!(0x28, "JR Z, 0x%X", 1)(&jr_z_n);
		registerInstruction!(0x29, "ADD HL, HL", 0)(&add_reg_reg!("hl", "hl"));
		registerInstruction!(0x2A, "LDI A, (HL)", 0)(&ldi_reg_regptr!("a", "hl"));
		registerInstruction!(0x2B, "DEC HL", 0)(&dec_reg!"hl");
		registerInstruction!(0x2C, "INC L", 0)(&inc_reg!"l");
		registerInstruction!(0x2D, "DEC L", 0)(&dec_reg!"l");
		registerInstruction!(0x2E, "LD L, 0x%X", 1)(&ld_reg_n!"l");
		registerInstruction!(0x2F, "CPL", 0)(&cpl);
		registerInstruction!(0x30, "JR NC, 0x%X", 1)(&jr_nc_n);
		registerInstruction!(0x31, "LD SP, 0x%X", 2)(&ld_reg_nn!"sp");
		registerInstruction!(0x32, "LDD (HL), A", 0)(&ldd_regptr_reg!("hl", "a"));
		registerInstruction!(0x33, "INC SP", 0)(&inc_reg!"sp");
		registerInstruction!(0x34, "INC (HL)", 0)(&inc_regptr!"hl");
		registerInstruction!(0x35, "DEC (HL)", 0)(&dec_regptr!"hl");
		registerInstruction!(0x36, "LD (HL), 0x%X", 1)(&ld_regptr_n!"hl");
		registerInstruction!(0x37, "SCF", 0)(&scf);
		registerInstruction!(0x38, "JR C, 0x%X", 1)(&jr_c_n);
		registerInstruction!(0x39, "ADD HL, SP", 0)(&add_reg_reg!("hl", "sp"));
		registerInstruction!(0x3A, "LDD A, (HL)", 0)(&ldd_reg_regptr!("a", "hl"));
		registerInstruction!(0x3B, "DEC SP", 0)(&dec_reg!"sp");
		registerInstruction!(0x3C, "INC A", 0)(&inc_reg!"a");
		registerInstruction!(0x3D, "DEC A", 0)(&dec_reg!"a");
		registerInstruction!(0x3E, "LD A, 0x%X", 1)(&ld_reg_n!"a");
		registerInstruction!(0x3F, "CCF", 0)(&ccf);

		registerInstruction!(0x40, "LD B, B", 0)(&nop);
		registerInstruction!(0x41, "LD B, C", 0)(&ld_reg_reg!("b", "c"));
		registerInstruction!(0x42, "LD B, D", 0)(&ld_reg_reg!("b", "d"));
		registerInstruction!(0x43, "LD B, E", 0)(&ld_reg_reg!("b", "e"));
		registerInstruction!(0x44, "LD B, H", 0)(&ld_reg_reg!("b", "h"));
		registerInstruction!(0x45, "LD B, L", 0)(&ld_reg_reg!("b", "l"));
		registerInstruction!(0x46, "LD B, (HL)", 0)(&ld_reg_regptr!("b", "hl"));
		registerInstruction!(0x47, "LD B, A", 0)(&ld_reg_reg!("b", "a"));

		registerInstruction!(0x48, "LD C, B", 0)(&ld_reg_reg!("c", "b"));
		registerInstruction!(0x49, "LD C, C", 0)(&nop);
		registerInstruction!(0x4A, "LD C, D", 0)(&ld_reg_reg!("c", "d"));
		registerInstruction!(0x4B, "LD C, E", 0)(&ld_reg_reg!("c", "e"));
		registerInstruction!(0x4C, "LD C, H", 0)(&ld_reg_reg!("c", "h"));
		registerInstruction!(0x4D, "LD C, L", 0)(&ld_reg_reg!("c", "l"));
		registerInstruction!(0x4E, "LD C, (HL)", 0)(&ld_reg_regptr!("c", "hl"));
		registerInstruction!(0x4F, "LD C, A", 0)(&ld_reg_reg!("c", "a"));

		registerInstruction!(0x50, "LD D, B", 0)(&ld_reg_reg!("d", "b"));
		registerInstruction!(0x51, "LD D, C", 0)(&ld_reg_reg!("d", "c"));
		registerInstruction!(0x52, "LD D, D", 0)(&nop);
		registerInstruction!(0x53, "LD D, E", 0)(&ld_reg_reg!("d", "e"));
		registerInstruction!(0x54, "LD D, H", 0)(&ld_reg_reg!("d", "h"));
		registerInstruction!(0x55, "LD D, L", 0)(&ld_reg_reg!("d", "l"));
		registerInstruction!(0x56, "LD D, (HL)", 0)(&ld_reg_regptr!("d", "hl"));
		registerInstruction!(0x57, "LD D, A", 0)(&ld_reg_reg!("d", "a"));

		registerInstruction!(0x58, "LD E, B", 0)(&ld_reg_reg!("e", "b"));
		registerInstruction!(0x59, "LD E, C", 0)(&ld_reg_reg!("e", "c"));
		registerInstruction!(0x5A, "LD E, D", 0)(&ld_reg_reg!("e", "d"));
		registerInstruction!(0x5B, "LD E, E", 0)(&nop);
		registerInstruction!(0x5C, "LD E, H", 0)(&ld_reg_reg!("e", "h"));
		registerInstruction!(0x5D, "LD E, L", 0)(&ld_reg_reg!("e", "l"));
		registerInstruction!(0x5E, "LD E, (HL)", 0)(&ld_reg_regptr!("e", "hl"));
		registerInstruction!(0x5F, "LD E, A", 0)(&ld_reg_reg!("e", "a"));

		registerInstruction!(0x60, "LD H, B", 0)(&ld_reg_reg!("h", "b"));
		registerInstruction!(0x61, "LD H, C", 0)(&ld_reg_reg!("h", "c"));
		registerInstruction!(0x62, "LD H, D", 0)(&ld_reg_reg!("h", "d"));
		registerInstruction!(0x63, "LD H, E", 0)(&ld_reg_reg!("h", "e"));
		registerInstruction!(0x64, "LD H, H", 0)(&nop);
		registerInstruction!(0x65, "LD H, L", 0)(&ld_reg_reg!("h", "l"));
		registerInstruction!(0x66, "LD H, (HL)", 0)(&ld_reg_regptr!("h", "hl"));
		registerInstruction!(0x67, "LD H, A", 0)(&ld_reg_reg!("h", "a"));

		registerInstruction!(0x68, "LD L, B", 0)(&ld_reg_reg!("l", "b"));
		registerInstruction!(0x69, "LD L, C", 0)(&ld_reg_reg!("l", "c"));
		registerInstruction!(0x6A, "LD L, D", 0)(&ld_reg_reg!("l", "d"));
		registerInstruction!(0x6B, "LD L, E", 0)(&ld_reg_reg!("l", "e"));
		registerInstruction!(0x6C, "LD L, H", 0)(&ld_reg_reg!("l", "h"));
		registerInstruction!(0x6D, "LD L, L", 0)(&nop);
		registerInstruction!(0x6E, "LD L, (HL)", 0)(&ld_reg_regptr!("l", "hl"));
		registerInstruction!(0x6F, "LD L, A", 0)(&ld_reg_reg!("l", "a"));

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

	// LD (reg), n
	void ld_regptr_n(string register)(ubyte value) {
		// TODO:
		mixin(`memory[registers.` ~ register ~ `] = value;`);
	}

	// LD (reg), reg
	void ld_regptr_reg(string register1, string register2)(ushort value) {
		mixin(`memory[registers.` ~ register1 ~ `] = registers.` ~ register2 ~ `;`);
	}

	// LDI (reg), reg
	void ldi_regptr_reg(string register1, string register2)(ushort value) {
		mixin(`memory[registers.` ~ register1 ~ `++] = registers.` ~ register2 ~ `;`);
	}

	// LDD (reg), reg
	void ldd_regptr_reg(string register1, string register2)(ushort value) {
		mixin(`memory[registers.` ~ register1 ~ `--] = registers.` ~ register2 ~ `;`);
	}

	// LD reg, reg
	void ld_reg_reg(string register1, string register2)() {
		mixin(`registers.` ~ register1 ~ ` = registers.` ~ register2 ~ `;`);
	}

	// LD reg, (reg)
	void ld_reg_regptr(string register1, string register2)() {
		mixin(`registers.` ~ register1 ~ ` = memory[registers.` ~ register2 ~ `];`);
	}

	// LDI reg, (reg)
	void ldi_reg_regptr(string register1, string register2)() {
		mixin(`registers.` ~ register1 ~ ` = memory[registers.` ~ register2 ~ `++];`);
	}

	// LDD reg, (reg)
	void ldd_reg_regptr(string register1, string register2)() {
		mixin(`registers.` ~ register1 ~ ` = memory[registers.` ~ register2 ~ `--];`);
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

	// INC regptr
	void inc_regptr(string register)() {
		// TODO: Flags
		mixin(`memory[registers.` ~ register ~ `] = cast(ubyte)(memory[registers.` ~ register ~ `] + 1);`);
	}

	// DEC regptr
	void dec_regptr(string register)() {
		// TODO: Flags
		mixin(`memory[registers.` ~ register ~ `] = cast(ubyte)(memory[registers.` ~ register ~ `] - 1);`);
	}

	// RLCA
	void rlca() {
		registers.f = (registers.a & 0x80) >> 3;
		registers.a = cast(ubyte)((registers.a << 1) | (registers.a >> 7));
	}

	// RRCA
	void rrca() {
		registers.f = (registers.a & 0x1) << 4;
		registers.a = cast(ubyte)((registers.a >> 1) | (registers.a << 7));
	}

	// STOP
	void stop(ubyte value) {
		// TODO
	}

	// RLA
	void rla() {
		// TODO
	}

	// JR n
	void jr_n(ubyte value) {
		registers.pc += cast(byte)value;
	}

	// RRA
	void rra() {
		// TODO
	}

	// JR NZ, n
	void jr_nz_n(ubyte value) {
		if(!registers.flagZero) {
			registers.pc += cast(byte)value;
		}
	}

	// JR Z, n
	void jr_z_n(ubyte value) {
		if(registers.flagZero) {
			registers.pc += cast(byte)value;
		}
	}

	// JR NC, n
	void jr_nc_n(ubyte value) {
		if(!registers.flagCarry) {
			registers.pc += cast(byte)value;
		}
	}

	// JR C, n
	void jr_c_n(ubyte value) {
		if(registers.flagCarry) {
			registers.pc += cast(byte)value;
		}
	}

	// JP nn
	void jp_nn(ushort address) {
		registers.pc = address;
	}

	// DAA
	void daa() {
		if(registers.flagNegative) {
			if(registers.flagHalfCarry)
				registers.a = (registers.a - 0x06) & 0xFF;
			if(registers.flagCarry)
				registers.a -= 0x60;
		}
		else {
			if(registers.flagHalfCarry || (registers.a & 0x0F) > 9)
				registers.a += 0x06;
			if(registers.flagCarry || registers.a > 0x9F)
				registers.a += 0x60;
		}

		registers.flagHalfCarry = false;
		registers.flagZero = registers.a == 0;

		if(registers.a >= 0x100)
			registers.flagCarry = true;
	}

	// CPL
	void cpl() {
		registers.a = ~registers.a;
		registers.flagHalfCarry = true;
		registers.flagNegative = true;
	}

	// SCF
	void scf() {
		registers.flagCarry = true;
		registers.flagNegative = false;
		registers.flagHalfCarry = false;
	}

	// CCF
	void ccf() {
		registers.flagCarry = !registers.flagCarry;
		registers.flagHalfCarry = !registers.flagHalfCarry;
		registers.flagNegative = false;
	}

	/*
	 * End Instruction handlers
	 */

	void doCycle() {
		auto opcode = memory[registers.pc];
		registers.pc++;

		//log("Executing: 0x", opcode.to!string(16));

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

