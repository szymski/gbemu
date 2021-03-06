﻿module gbemu.cpu;

import std.experimental.logger, std.format, std.stdio, std.conv : to;
import gbemu.emulator, gbemu.registers, gbemu.memory, gbemu.interrupts;

enum fixedCycleCount = 200;
bool logging = true;

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
	Interrupts interrupts;
	 
	Registers registers;

	Instruction[256] instructions;
	Instruction[256] extendedInstructions;

	bool stopped;

	this(Emulator emulator)
	{
		this.emulator = emulator;
		memory = emulator.memory;
		interrupts = emulator.interrupts; 

		reset();
		registerInstructions();
		registerExtendedInstructions();
	}

	void reset() { 
		stopped = false;

		registers.af = 0x01;
		registers.f = 0xB0;
		registers.bc = 0x0013;
		registers.de = 0x00D8;
		registers.hl = 0x014D;
		registers.pc = 0x100;
		registers.sp = 0xFFFE;

		interrupts.master = 1;
		interrupts.enable = 0;
		interrupts.flags = 0;

		memory[0xFF05] = 0x00;
		memory[0xFF06] = 0x00;
		memory[0xFF07] = 0x00;
		memory[0xFF10] = 0x80;
		memory[0xFF11] = 0xBF;
		memory[0xFF12] = 0xF3;
		memory[0xFF14] = 0xBF;
		memory[0xFF16] = 0x3F;
		memory[0xFF17] = 0x00;
		memory[0xFF19] = 0xBF;
		memory[0xFF1A] = 0x7F;
		memory[0xFF1B] = 0xFF;
		memory[0xFF1C] = 0x9F;
		memory[0xFF1E] = 0xBF;
		memory[0xFF20] = 0xFF;
		memory[0xFF21] = 0x00;
		memory[0xFF22] = 0x00;
		memory[0xFF23] = 0xBF;
		memory[0xFF24] = 0x77;
		memory[0xFF25] = 0xF3;
		memory[0xFF26] = 0xF1;
		memory[0xFF40] = 0x91;
		memory[0xFF42] = 0x00;
		memory[0xFF43] = 0x00;
		memory[0xFF45] = 0x00;
		memory[0xFF47] = 0xFC;
		memory[0xFF48] = 0xFF;
		memory[0xFF49] = 0xFF;
		memory[0xFF4A] = 0x00;
		memory[0xFF4B] = 0x00;
		memory[0xFFFF] = 0x00;
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

		registerInstruction!(0x70, "LD (HL), B", 0)(&ld_regptr_reg!("hl", "b"));
		registerInstruction!(0x71, "LD (HL), C", 0)(&ld_regptr_reg!("hl", "c"));
		registerInstruction!(0x72, "LD (HL), D", 0)(&ld_regptr_reg!("hl", "d"));
		registerInstruction!(0x73, "LD (HL), E", 0)(&ld_regptr_reg!("hl", "e"));
		registerInstruction!(0x74, "LD (HL), H", 0)(&ld_regptr_reg!("hl", "h"));
		registerInstruction!(0x75, "LD (HL), L", 0)(&ld_regptr_reg!("hl", "l"));

		registerInstruction!(0x76, "HALT", 0)(&halt);

		registerInstruction!(0x77, "LD (HL), A", 0)(&ld_regptr_reg!("hl", "a"));
		registerInstruction!(0x78, "LD A, B", 0)(&ld_reg_reg!("a", "b"));
		registerInstruction!(0x79, "LD A, C", 0)(&ld_reg_reg!("a", "c"));
		registerInstruction!(0x7A, "LD A, D", 0)(&ld_reg_reg!("a", "d"));
		registerInstruction!(0x7B, "LD A, E", 0)(&ld_reg_reg!("a", "e"));
		registerInstruction!(0x7C, "LD A, H", 0)(&ld_reg_reg!("a", "h"));
		registerInstruction!(0x7D, "LD A, L", 0)(&ld_reg_reg!("a", "l"));
		registerInstruction!(0x7E, "LD A, (HL)", 0)(&ld_reg_regptr!("a", "hl"));
		registerInstruction!(0x7F, "LD A, A", 0)(&nop);

		registerInstruction!(0x80, "ADD A, B", 0)(&add_reg_reg!("a", "b"));
		registerInstruction!(0x81, "ADD A, C", 0)(&add_reg_reg!("a", "c"));
		registerInstruction!(0x82, "ADD A, D", 0)(&add_reg_reg!("a", "d"));
		registerInstruction!(0x83, "ADD A, E", 0)(&add_reg_reg!("a", "e"));
		registerInstruction!(0x84, "ADD A, H", 0)(&add_reg_reg!("a", "h"));
		registerInstruction!(0x85, "ADD A, L", 0)(&add_reg_reg!("a", "l"));
		registerInstruction!(0x86, "ADD A, (HL)", 0)(&add_reg_regptr!("a", "hl"));
		registerInstruction!(0x87, "ADD A, A", 0)(&add_reg_reg!("a", "a"));

		registerInstruction!(0x88, "ADC A, B", 0)(&adc_a_reg!"b");
		registerInstruction!(0x89, "ADC A, C", 0)(&adc_a_reg!"c");
		registerInstruction!(0x8A, "ADC A, D", 0)(&adc_a_reg!"d");
		registerInstruction!(0x8B, "ADC A, E", 0)(&adc_a_reg!"e");
		registerInstruction!(0x8C, "ADC A, H", 0)(&adc_a_reg!"h");
		registerInstruction!(0x8D, "ADC A, L", 0)(&adc_a_reg!"l");
		registerInstruction!(0x8E, "ADC A, (HL)", 0)(&adc_a_regptr!"hl");
		registerInstruction!(0x8F, "ADC A, A", 0)(&adc_a_reg!"a");

		registerInstruction!(0x90, "SUB A, B", 0)(&sub_a_reg!"b");
		registerInstruction!(0x91, "SUB A, C", 0)(&sub_a_reg!"c");
		registerInstruction!(0x92, "SUB A, D", 0)(&sub_a_reg!"d");
		registerInstruction!(0x93, "SUB A, E", 0)(&sub_a_reg!"e");
		registerInstruction!(0x94, "SUB A, H", 0)(&sub_a_reg!"h");
		registerInstruction!(0x95, "SUB A, L", 0)(&sub_a_reg!"l");
		registerInstruction!(0x96, "SUB A, (HL)", 0)(&sub_a_regptr!"hl");
		registerInstruction!(0x97, "SUB A, A", 0)(&sub_a_reg!"a");

		registerInstruction!(0x98, "SBC A, B", 0)(&sbc_a_reg!"b");
		registerInstruction!(0x99, "SBC A, C", 0)(&sbc_a_reg!"c");
		registerInstruction!(0x9A, "SBC A, D", 0)(&sbc_a_reg!"d");
		registerInstruction!(0x9B, "SBC A, E", 0)(&sbc_a_reg!"e");
		registerInstruction!(0x9C, "SBC A, H", 0)(&sbc_a_reg!"h");
		registerInstruction!(0x9D, "SBC A, L", 0)(&sbc_a_reg!"l");
		registerInstruction!(0x9E, "SBC A, (HL)", 0)(&sbc_a_regptr!"hl");
		registerInstruction!(0x9F, "SBC A, A", 0)(&sbc_a_reg!"a");

		registerInstruction!(0xA0, "AND A, B", 0)(&and_a_reg!"b");
		registerInstruction!(0xA1, "AND A, C", 0)(&and_a_reg!"c");
		registerInstruction!(0xA2, "AND A, D", 0)(&and_a_reg!"d");
		registerInstruction!(0xA3, "AND A, E", 0)(&and_a_reg!"e");
		registerInstruction!(0xA4, "AND A, H", 0)(&and_a_reg!"h");
		registerInstruction!(0xA5, "AND A, L", 0)(&and_a_reg!"l");
		registerInstruction!(0xA6, "AND A, (HL)", 0)(&and_a_regptr!"hl");
		registerInstruction!(0xA7, "AND A, A", 0)(&and_a_reg!"a");

		registerInstruction!(0xA8, "XOR A, B", 0)(&xor_a_reg!"b");
		registerInstruction!(0xA9, "XOR A, C", 0)(&xor_a_reg!"c");
		registerInstruction!(0xAA, "XOR A, D", 0)(&xor_a_reg!"d");
		registerInstruction!(0xAB, "XOR A, E", 0)(&xor_a_reg!"e");
		registerInstruction!(0xAC, "XOR A, H", 0)(&xor_a_reg!"h");
		registerInstruction!(0xAD, "XOR A, L", 0)(&xor_a_reg!"l");
		registerInstruction!(0xAE, "XOR A, (HL)", 0)(&xor_a_regptr!"hl");
		registerInstruction!(0xAF, "XOR A, A", 0)(&xor_a_reg!"a");

		registerInstruction!(0xB0, "OR A, B", 0)(&or_a_reg!"b");
		registerInstruction!(0xB1, "OR A, C", 0)(&or_a_reg!"c");
		registerInstruction!(0xB2, "OR A, D", 0)(&or_a_reg!"d");
		registerInstruction!(0xB3, "OR A, E", 0)(&or_a_reg!"e");
		registerInstruction!(0xB4, "OR A, H", 0)(&or_a_reg!"h");
		registerInstruction!(0xB5, "OR A, L", 0)(&or_a_reg!"l");
		registerInstruction!(0xB6, "OR A, (HL)", 0)(&or_a_regptr!"hl");
		registerInstruction!(0xB7, "OR A, A", 0)(&or_a_reg!"a");

		registerInstruction!(0xB8, "CP A, B", 0)(&cp_a_reg!"b");
		registerInstruction!(0xB9, "CP A, C", 0)(&cp_a_reg!"c");
		registerInstruction!(0xBA, "CP A, D", 0)(&cp_a_reg!"d");
		registerInstruction!(0xBB, "CP A, E", 0)(&cp_a_reg!"e");
		registerInstruction!(0xBC, "CP A, H", 0)(&cp_a_reg!"h");
		registerInstruction!(0xBD, "CP A, L", 0)(&cp_a_reg!"l");
		registerInstruction!(0xBE, "CP A, (HL)", 0)(&cp_a_regptr!"hl");
		registerInstruction!(0xBF, "CP A, A", 0)(&cp_a_reg!"a");

		registerInstruction!(0xC0, "RET NZ", 0)(&ret_nz);
		registerInstruction!(0xC1, "POP BC", 0)(&pop_reg!"bc");
		registerInstruction!(0xC2, "JP NZ, 0x%X", 2)(&jp_nz_nn);
		registerInstruction!(0xC3, "JP 0x%X", 2)(&jp_nn);
		registerInstruction!(0xC4, "CALL NZ, 0x%X", 2)(&call_nz_nn);
		registerInstruction!(0xC5, "PUSH BC", 0)(&push_reg!"bc");
		registerInstruction!(0xC6, "ADD A, 0x%X", 1)(&add_reg_n!"a");
		registerInstruction!(0xC7, "RST 0x00", 0)(&rst!0x00);
		registerInstruction!(0xC8, "RET Z", 0)(&ret_z);
		registerInstruction!(0xC9, "RET", 0)(&ret);
		registerInstruction!(0xCA, "JP Z, 0x%X", 2)(&jp_z_nn);
		registerInstruction!(0xCB, "CB 0x%X", 1)(&cb_n);
		registerInstruction!(0xCC, "CALL Z, 0x%X", 2)(&call_z_nn);
		registerInstruction!(0xCD, "CALL 0x%X", 2)(&call_nn);
		registerInstruction!(0xCE, "ADC 0x%X", 1)(&adc_a_n);
		registerInstruction!(0xCF, "RST 0x08", 0)(&rst!0x08);
		registerInstruction!(0xD0, "RET NC", 0)(&ret_nc);
		registerInstruction!(0xD1, "POP DE", 0)(&pop_reg!"de");
		registerInstruction!(0xD2, "JP NC, 0x%X", 2)(&jp_nc_nn);
		registerInstruction!(0xD3, "UNKNOWN", 0)(&nop);
		registerInstruction!(0xD4, "CALL NC, 0x%X", 2)(&call_nc_nn);
		registerInstruction!(0xD5, "PUSH DE", 0)(&push_reg!"de");
		registerInstruction!(0xD6, "SUB 0x%X", 1)(&sub_a_n);
		registerInstruction!(0xD7, "RST 0x10", 0)(&rst!0x10);
		registerInstruction!(0xD8, "RET C", 0)(&ret_c);
		registerInstruction!(0xD9, "RETI", 0)(&reti);
		registerInstruction!(0xDA, "JP C, 0x%X", 2)(&jp_c_nn);
		registerInstruction!(0xDB, "UNKNOWN", 0)(&nop);
		registerInstruction!(0xDC, "CALL C, 0x%X", 2)(&call_c_nn);
		registerInstruction!(0xDD, "UNKNOWN", 0)(&nop);
		registerInstruction!(0xDE, "SBC 0x%X", 1)(&sbc_a_n);
		registerInstruction!(0xDF, "RST 0x18", 0)(&rst!0x18);
		registerInstruction!(0xE0, "LD (0xFF00 + 0x%X), A", 1)(&ld_ffn_reg!"a");
		registerInstruction!(0xE1, "POP HL", 0)(&pop_reg!"hl");
		registerInstruction!(0xE2, "LD (0xFF00 + C), A", 0)(&ld_ffreg_reg!("c", "a"));
		registerInstruction!(0xE3, "UNKNOWN", 0)(&nop);
		registerInstruction!(0xE4, "UNKNOWN", 0)(&nop);
		registerInstruction!(0xE5, "PUSH HL", 0)(&push_reg!"hl");
		registerInstruction!(0xE6, "AND 0x%X", 1)(&and_a_n);
		registerInstruction!(0xE7, "RST 0x20", 0)(&rst!0x20);
		registerInstruction!(0xE8, "ADD SP, 0x%X", 1)(&add_reg_n!"sp");
		registerInstruction!(0xE9, "JP HL", 0)(&jp_reg!"hl");
		registerInstruction!(0xEA, "LD (0x%X), A", 2)(&ld_nnptr_reg!"a");
		registerInstruction!(0xEB, "UNKNOWN", 0)(&nop);
		registerInstruction!(0xEC, "UNKNOWN", 0)(&nop);
		registerInstruction!(0xED, "UNKNOWN", 0)(&nop);
		registerInstruction!(0xEE, "XOR 0x%X", 1)(&xor_a_n);
		registerInstruction!(0xEF, "RST 0x28", 0)(&rst!0x28);
		registerInstruction!(0xF0, "LD A, (0xFF00 + 0x%X)", 1)(&ld_reg_ffn!"a");
		registerInstruction!(0xF1, "POP AF", 0)(&pop_reg!"af");
		registerInstruction!(0xF2, "LD A, (0xFF00 + C)", 0)(&ld_reg_ffreg!("a", "c"));
		registerInstruction!(0xF3, "DI", 0)(&di);
		registerInstruction!(0xF4, "UNKNOWN", 0)(&nop);
		registerInstruction!(0xF5, "PUSH AF", 0)(&push_reg!"af");
		registerInstruction!(0xF6, "OR A, 0x%X", 1)(&or_a_n);
		registerInstruction!(0xF7, "RST 0x30", 0)(&rst!0x30);
		registerInstruction!(0xF8, "LD HL, SP + 0x%X", 1)(&ld_hl_spn);
		registerInstruction!(0xF9, "LD SP, HL", 0)(&ld_reg_reg!("sp", "hl"));
		registerInstruction!(0xFA, "LD A, (0x%X)", 2)(&ld_reg_nnptr!"a");
		registerInstruction!(0xFB, "EI", 0)(&ei);
		registerInstruction!(0xFC, "UNKNOWN", 0)(&nop);
		registerInstruction!(0xFD, "UNKNOWN", 0)(&nop);
		registerInstruction!(0xFE, "CP 0x%X", 1)(&cp_n);
		registerInstruction!(0xFF, "RST 0x38", 0)(&rst!0x38);
	}

	void registerInstruction(ubyte opcode, string disassembly, ubyte length, T...)(void delegate(T) execute) {
		static if(length == 1)
			static assert(is(typeof(execute) : void delegate(ubyte)), "Invalid delegate type. For operand size 1, it must be void delegate(ubyte).");
		static if(length == 2)
			static assert(is(typeof(execute) : void delegate(ushort)), "Invalid delegate type. For operand size 2, it must be void delegate(ushort).");

		assert(instructions[opcode] is null, "Instruction already registered.");

		instructions[opcode] = new Instruction(disassembly, length, cast(void delegate())execute);
	}

	void registerExtendedInstructions() {
		registerExtendedInstructionSet!(0x00, "RLC", rlc);
//		registerExtendedInstruction!(0x00, "RLC B", 0)(&rlc_reg!"b");
//		registerExtendedInstruction!(0x01, "RLC C", 0)(&rlc_reg!"c");
//		registerExtendedInstruction!(0x02, "RLC D", 0)(&rlc_reg!"d");
//		registerExtendedInstruction!(0x03, "RLC E", 0)(&rlc_reg!"e");
//		registerExtendedInstruction!(0x04, "RLC H", 0)(&rlc_reg!"h");
//		registerExtendedInstruction!(0x05, "RLC L", 0)(&rlc_reg!"l");
//		registerExtendedInstruction!(0x06, "RLC (HL)", 0)(&rlc_regptr!"hl");
//		registerExtendedInstruction!(0x07, "RLC A", 0)(&rlc_reg!"a");

		registerExtendedInstructionSet!(0x08, "RRC", rrc);
//		registerExtendedInstruction!(0x08, "RRC B", 0)(&rrc_reg!"b");
//		registerExtendedInstruction!(0x09, "RRC C", 0)(&rrc_reg!"c");
//		registerExtendedInstruction!(0x0A, "RRC D", 0)(&rrc_reg!"d");
//		registerExtendedInstruction!(0x0B, "RRC E", 0)(&rrc_reg!"e");
//		registerExtendedInstruction!(0x0C, "RRC H", 0)(&rrc_reg!"h");
//		registerExtendedInstruction!(0x0D, "RRC L", 0)(&rrc_reg!"l");
//		registerExtendedInstruction!(0x0E, "RRC (HL)", 0)(&rrc_regptr!"hl");
//		registerExtendedInstruction!(0x0F, "RRC A", 0)(&rrc_reg!"a");

		registerExtendedInstructionSet!(0x10, "RL", rl);
//		registerExtendedInstruction!(0x10, "RL B", 0)(&rl_reg!"b");
//		registerExtendedInstruction!(0x11, "RL C", 0)(&rl_reg!"c");
//		registerExtendedInstruction!(0x12, "RL D", 0)(&rl_reg!"d");
//		registerExtendedInstruction!(0x13, "RL E", 0)(&rl_reg!"e");
//		registerExtendedInstruction!(0x14, "RL H", 0)(&rl_reg!"h");
//		registerExtendedInstruction!(0x15, "RL L", 0)(&rl_reg!"l");
//		registerExtendedInstruction!(0x16, "RL (HL)", 0)(&rl_regptr!"hl");
//		registerExtendedInstruction!(0x17, "RL A", 0)(&rl_reg!"a");

		registerExtendedInstructionSet!(0x18, "RR", rr);
//		registerExtendedInstruction!(0x18, "RR B", 0)(&rr_reg!"b");
//		registerExtendedInstruction!(0x19, "RR C", 0)(&rr_reg!"c");
//		registerExtendedInstruction!(0x1A, "RR D", 0)(&rr_reg!"d");
//		registerExtendedInstruction!(0x1B, "RR E", 0)(&rr_reg!"e");
//		registerExtendedInstruction!(0x1C, "RR H", 0)(&rr_reg!"h");
//		registerExtendedInstruction!(0x1D, "RR L", 0)(&rr_reg!"l");
//		registerExtendedInstruction!(0x1E, "RR (HL)", 0)(&rr_regptr!"hl");
//		registerExtendedInstruction!(0x1F, "RR A", 0)(&rr_reg!"a");

		registerExtendedInstructionSet!(0x20, "SLA", sla);
//		registerExtendedInstruction!(0x20, "SLA B", 0)(&rr_reg!"a");
//		registerExtendedInstruction!(0x21, "SLA C", 0)(&rr_reg!"a");
//		registerExtendedInstruction!(0x22, "SLA D", 0)(&rr_reg!"a");
//		registerExtendedInstruction!(0x23, "SLA E", 0)(&rr_reg!"a");
//		registerExtendedInstruction!(0x24, "SLA H", 0)(&rr_reg!"a");
//		registerExtendedInstruction!(0x25, "SLA L", 0)(&rr_reg!"a");
//		registerExtendedInstruction!(0x26, "SLA (HL)", 0)(&rr_reg!"a");
//		registerExtendedInstruction!(0x27, "SLA A", 0)(&rr_reg!"a");

		registerExtendedInstructionSet!(0x28, "SRA", sra);

		registerExtendedInstructionSet!(0x30, "SWAP", swap);

	}

	void registerExtendedInstruction(ubyte opcode, string disassembly, ubyte length, T...)(void delegate(T) execute) {
		static if(length == 1)
			static assert(is(typeof(execute) : void delegate(ubyte)), "Invalid delegate type. For operand size 1, it must be void delegate(ubyte).");
		static if(length == 2)
			static assert(is(typeof(execute) : void delegate(ushort)), "Invalid delegate type. For operand size 2, it must be void delegate(ushort).");
		
		assert(extendedInstructions[opcode] is null, "Instruction already registered.");
		
		extendedInstructions[opcode] = new Instruction(disassembly, length, cast(void delegate())execute);
	}

	/*
	 * Instruction handler templates
	 */

	void setRegister(string register, alias fun)() {
		mixin(`registers.` ~ register ~ ` = fun(registers.` ~ register ~ `);`);
	}

	void setRegisterPtr(string register, alias fun)() {
		mixin(`memory[registers.` ~ register ~ `] = fun(memory[registers.` ~ register ~ `]);`);
	}

	/// Registers handlers for registers: B, C, D, E, H, L, (HL), A.
	void registerInstructionSet(int firstOpcode, string operation, alias fun)() {
		registerInstruction!(firstOpcode + 0, operation ~ " B", 0)(&setRegister!("b", fun));
		registerInstruction!(firstOpcode + 1, operation ~ " C", 0)(&setRegister!("c", fun));
		registerInstruction!(firstOpcode + 2, operation ~ " D", 0)(&setRegister!("d", fun));
		registerInstruction!(firstOpcode + 3, operation ~ " E", 0)(&setRegister!("e", fun));
		registerInstruction!(firstOpcode + 4, operation ~ " H", 0)(&setRegister!("h", fun));
		registerInstruction!(firstOpcode + 5, operation ~ " L", 0)(&setRegister!("l", fun));
		registerInstruction!(firstOpcode + 6, operation ~ " (HL)", 0)(&setRegisterPtr!("hl", fun));
		registerInstruction!(firstOpcode + 7, operation ~ " A", 0)(&setRegister!("a", fun));
	}

	/// Registers extended handlers for registers: B, C, D, E, H, L, (HL), A.
	void registerExtendedInstructionSet(int firstOpcode, string operation, alias fun)() {
		registerExtendedInstruction!(firstOpcode + 0, operation ~ " B", 0)(&setRegister!("b", fun));
		registerExtendedInstruction!(firstOpcode + 1, operation ~ " C", 0)(&setRegister!("c", fun));
		registerExtendedInstruction!(firstOpcode + 2, operation ~ " D", 0)(&setRegister!("d", fun));
		registerExtendedInstruction!(firstOpcode + 3, operation ~ " E", 0)(&setRegister!("e", fun));
		registerExtendedInstruction!(firstOpcode + 4, operation ~ " H", 0)(&setRegister!("h", fun));
		registerExtendedInstruction!(firstOpcode + 5, operation ~ " L", 0)(&setRegister!("l", fun));
		registerExtendedInstruction!(firstOpcode + 6, operation ~ " (HL)", 0)(&setRegisterPtr!("hl", fun));
		registerExtendedInstruction!(firstOpcode + 7, operation ~ " A", 0)(&setRegister!("a", fun));
	}

	/*
	 * Instruction handlers
	 */

	// NOP
	void nop() {
	}

	// LD reg, nn
	void ld_reg_nn(string register)(ushort value) {
		mixin(`registers.` ~ register ~ ` = value;`);
	}
	
	// LD reg, (nn)
	void ld_reg_nnptr(string register)(ushort value) {
		mixin(`registers.` ~ register ~ ` = memory[value];`);
	}

	// LD reg, n
	void ld_reg_n(string register)(ubyte value) {
		mixin(`registers.` ~ register ~ ` = value;`);
	}

	// LD (reg), nn
	void ld_regptr_nn(string register)(ushort value) {
		mixin(`memory[registers.` ~ register ~ `] = value;`);
	}

	// LD (reg), n
	void ld_regptr_n(string register)(ubyte value) {
		mixin(`memory[registers.` ~ register ~ `] = value;`);
	}

	// LD (reg), reg
	void ld_regptr_reg(string register1, string register2)(ushort value) {
		mixin(`memory[registers.` ~ register1 ~ `] = registers.` ~ register2 ~ `;`);
	}

	// LDI (reg), reg
	void ldi_regptr_reg(string register1, string register2)(ushort value) {
		mixin(`memory[registers.` ~ register1 ~ `] = registers.` ~ register2 ~ `; registers.` ~ register1 ~ ` = inc(registers.` ~ register1 ~ `);`);
	}

	// LDD (reg), reg
	void ldd_regptr_reg(string register1, string register2)(ushort value) {
		mixin(`memory[registers.` ~ register1 ~ `] = registers.` ~ register2 ~ `; registers.` ~ register1 ~ ` = dec(registers.` ~ register1 ~ `);`);
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
		mixin(`registers.` ~ register1 ~ ` = memory[registers.` ~ register2 ~ `]; registers.` ~ register2 ~ ` = inc(registers.` ~ register2 ~ `);`);
	}

	// LDD reg, (reg)
	void ldd_reg_regptr(string register1, string register2)() {
		mixin(`registers.` ~ register1 ~ ` = memory[registers.` ~ register2 ~ `]; registers.` ~ register2 ~ ` = dec(registers.` ~ register2 ~ `);`);
	}

	// LD (nn), reg
	void ld_nnptr_reg(string register)(ushort value) {
		mixin(`memory[value] = registers.` ~ register ~ `;`);
	}

	// INC reg
	void inc_reg(string register)() {
		mixin(`registers.` ~ register ~ ` = inc(registers.` ~ register ~ `);`);
	}

	// DEC reg
	void dec_reg(string register)() {
		mixin(`registers.` ~ register ~ ` = dec(registers.` ~ register ~ `);`);
	}

	// ADD reg, reg
	void add_reg_reg(string register1, string register2)() {
		mixin(`registers.` ~ register1 ~ ` = add(registers.` ~ register1 ~ `, registers.` ~ register2 ~ `);`);
	}

	// ADD reg, (reg)
	void add_reg_regptr(string register1, string register2)() {
		mixin(`registers.` ~ register1 ~ ` = add(registers.` ~ register1 ~ `, cast(ubyte)memory[registers.` ~ register2 ~ `]);`);
	}

	// ADD reg, n
	void add_reg_n(string register1)(ubyte value) {
		mixin(`registers.` ~ register1 ~ ` = add(registers.` ~ register1 ~ `, value);`);
	}

	// INC (reg)
	void inc_regptr(string register)() {
		mixin(`memory[registers.` ~ register ~ `] = cast(ubyte)(inc(memory[registers.` ~ register ~ `]));`);
	}

	// DEC (reg)
	void dec_regptr(string register)() {
		mixin(`memory[registers.` ~ register ~ `] = cast(ubyte)(dec(memory[registers.` ~ register ~ `]));`);
	}

	// ADC A, reg
	void adc_a_reg(string register)() {
		mixin(`adc_a(registers.` ~ register ~ `);`);
	}

	// ADC A, (reg)
	void adc_a_regptr(string register)() {
		mixin(`adc_a(memory[registers.` ~ register ~ `]);`);
	}

	// ADC A, n
	void adc_a_n(ubyte value) {
		mixin(`adc_a(value);`);
	}

	// SUB A, reg
	void sub_a_reg(string register)() {
		mixin(`sub_a(registers.` ~ register ~ `);`);
	}

	// SUB A, (reg)
	void sub_a_regptr(string register)() {
		mixin(`sub_a(memory[registers.` ~ register ~ `]);`);
	}

	// SUB A, n
	void sub_a_n(ubyte value) {
		sub_a(value);
	}

	// SBC A, reg
	void sbc_a_reg(string register)() {
		mixin(`sbc_a(registers.` ~ register ~ `);`);
	}
	
	// SBC A, (reg)
	void sbc_a_regptr(string register)() {
		mixin(`sbc_a(memory[registers.` ~ register ~ `]);`);
	}

	// SBC A, n
	void sbc_a_n(ubyte value) {
		sbc_a(value);
	}

	// AND A, reg
	void and_a_reg(string register)() {
		mixin(`and_a(registers.` ~ register ~ `);`);
	}

	// AND A, (reg)
	void and_a_regptr(string register)() {
		mixin(`and_a(memory[registers.` ~ register ~ `]);`);
	}
	
	// AND A, n
	void and_a_n(ubyte value) {
		and_a(value);
	}

	// XOR A, reg
	void xor_a_reg(string register)() {
		mixin(`xor_a(registers.` ~ register ~ `);`);
	}
	
	// XOR A, (reg)
	void xor_a_regptr(string register)() {
		mixin(`xor_a(memory[registers.` ~ register ~ `]);`);
	}
	
	// XOR A, n
	void xor_a_n(ubyte value) {
		xor_a(value);
	}

	// OR A, reg
	void or_a_reg(string register)() {
		mixin(`or_a(registers.` ~ register ~ `);`);
	}
	
	// OR A, (reg)
	void or_a_regptr(string register)() {
		mixin(`or_a(memory[registers.` ~ register ~ `]);`);
	}
	
	// OR A, n
	void or_a_n(ubyte value) {
		or_a(value);
	}

	// CP A, reg
	void cp_a_reg(string register)() {
		mixin(`cp_a(registers.` ~ register ~ `);`);
	}
	
	// CP A, (reg)
	void cp_a_regptr(string register)() {
		mixin(`cp_a(memory[registers.` ~ register ~ `]);`);
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
		stopped = true;
		writeln("STOP - Not implemented");
	}

	// RLA
	void rla() {
		// TODO
		stopped = true;
		writeln("RLA - Not implemented");
	}

	// JR n
	void jr_n(ubyte value) {
		registers.pc += cast(byte)value;
	}

	// RRA
	void rra() {
		// TODO
		stopped = true;
		writeln("RRA - Not implemented");
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

	// HALT
	void halt() {
		if(interrupts.master)
			registers.pc--;
	}

	// RET NZ
	void ret_nz() {
		if(!registers.flagZero)
			registers.pc = stackPop!ushort;
	}

	// POP reg
	void pop_reg(string register)() {
		mixin("registers." ~ register ~ " = stackPop!(typeof(registers." ~ register ~ "));");
	}

	// PUSH reg
	void push_reg(string register)() {
		mixin("stackPush(registers." ~ register ~ ");");
	}

	// JP nz, nn
	void jp_nz_nn(ushort address) {
		if(!registers.flagZero)
			registers.pc = address;
	}

	// JP nn
	void jp_nn(ushort address) {
		registers.pc = address;
	}

	// CALL NZ, nn
	void call_nz_nn(ushort address) {
		if(!registers.flagZero) {
			stackPush(registers.pc);
			registers.pc = address;
		}
	}

	// RST n
	void rst(ubyte address)() {
		stackPush(registers.pc);
		registers.pc = address;
	}

	// RET Z
	void ret_z() {
		if(registers.flagZero)
			registers.pc = stackPop!ushort;
	}

	// RET
	void ret() {
		registers.pc = stackPop!ushort;
	}

	// JP Z, nn
	void jp_z_nn(ushort address) {
		if(registers.flagZero)
			registers.pc = address;
	}

	// CB n
	void cb_n(ubyte value) {
		writeln("CB");

		//log("Executing: 0x", opcode.to!string(16));
		
		if(auto instruction = extendedInstructions[value]) {
			if(logging)
				logInstruction(instruction);
			executeExtendedInstruction(instruction);
		}
		else
			log("Unknown extended instruction: 0x", value.to!string(16));
	}

	// CALL Z, nn
	void call_z_nn(ushort address) {
		if(registers.flagZero) {
			stackPush(registers.pc);
			registers.pc = address;
		}
	}

	// CALL nn
	void call_nn(ushort address) {
		stackPush(registers.pc);
		registers.pc = address;
	}

	// RET NC
	void ret_nc() {
		if(!registers.flagCarry)
			registers.pc = stackPop!ushort;
	}

	// JP NC, nn
	void jp_nc_nn(ushort address) {
		if(!registers.flagCarry)
			registers.pc = address;
	}

	// CALL NC, nn
	void call_nc_nn(ushort address) {
		if(!registers.flagCarry) {
			stackPush(registers.pc);
			registers.pc = address;
		}
	}

	// RET C
	void ret_c() {
		if(registers.flagCarry)
			registers.pc = stackPop!ushort;
	}

	// RETI
	void reti() {
		interrupts.master = 1;
		registers.pc = stackPop!ushort;
	}

	// JP C, nn
	void jp_c_nn(ushort address) {
		if(registers.flagCarry)
			registers.pc = address;
	}

	// CALL C, nn
	void call_c_nn(ushort address) {
		if(registers.flagCarry) {
			stackPush(registers.pc);
			registers.pc = address;
		}
	}

	// LD (0xFF00 + n), reg
	void ld_ffn_reg(string reg)(ubyte offset) {
		memory[0xFF00 + offset] = mixin("registers." ~ reg);
	}

	// LD (0xFF00 + reg), reg
	void ld_ffreg_reg(string register1, string register2)() {
		memory[0xFF00 + mixin("registers." ~ register1)] = mixin("registers." ~ register2);
	} 

	// JP reg
	void jp_reg(string register)() {
		registers.pc = mixin("registers." ~ register);
	}

	// LD reg, (0xFF00 + n)
	void ld_reg_ffn(string register)(ubyte value) {
		mixin(`registers.` ~ register ~ ` = memory[0xFF00 + value];`);
	}
	
	// LD reg, (0xFF00 + reg)
	void ld_reg_ffreg(string register1, string register2)() {
		mixin(`registers.` ~ register1 ~ ` = memory[0xFF00 + registers.` ~ register2 ~ `];`);
	}
	
	// DI
	void di() {
		interrupts.master = 0;
	}
	
	// LD HL, SP + n
	void ld_hl_spn(ubyte value) {
		int result = registers.sp + cast(byte)value;
		
		registers.flagCarry = (result & 0xFFFFFFFF) > 0;
		registers.flagHalfCarry = (registers.sp & 0x0F) + (value & 0x0F) > 0x0F;
		registers.flagZero = false;
		registers.flagNegative = false;
		
		registers.hl = result & 0xFFFF;
	}
	
	// EI
	void ei() {
		interrupts.master = 1;	
	}
	
	// CP n
	void cp_n(ubyte value) {
		registers.flagNegative = true;
		registers.flagZero = registers.a == value;
		registers.flagCarry = value > registers.a;
		registers.flagHalfCarry = (value & 0x0F) > (registers.a & 0x0F);
	}

	/*
	 * Extended instructions
	 */

	// RLC reg
	void rlc_reg(string register)() {
		mixin("registers." ~ register) = rlc(mixin("registers." ~ register));
	}

	// RLC regptr
	void rlc_regptr(string register)() {
		memory[mixin("registers." ~ register)] = rlc(memory[mixin("registers." ~ register)]);
	}

	// RRC reg
	void rrc_reg(string register)() {
		mixin("registers." ~ register) = rrc(mixin("registers." ~ register));
	}

	// RRC regptr
	void rrc_regptr(string register)() {
		memory[mixin("registers." ~ register)] = rrc(memory[mixin("registers." ~ register)]);
	}

	// RL reg
	void rl_reg(string register)() {
		mixin("registers." ~ register) = rl(mixin("registers." ~ register));
	}

	// RL regptr
	void rl_regptr(string register)() {
		memory[mixin("registers." ~ register)] = rl(memory[mixin("registers." ~ register)]);
	}

	// RR reg
	void rr_reg(string register)() {
		mixin("registers." ~ register) = rr(mixin("registers." ~ register));
	}
	
	// RR regptr
	void rr_regptr(string register)() {
		memory[mixin("registers." ~ register)] = rr(memory[mixin("registers." ~ register)]);
	}

	/*
	 * Instruction handler helpers
	 */

	auto inc(T)(T value) {
		registers.flagHalfCarry = (value & 0x0F) == 0x0F;
		
		value++;
		
		registers.flagZero = value == 0;
		registers.flagNegative = false; // TODO: Make sure this is proper

		return value;
	}

	auto dec(T)(T value) {
		registers.flagHalfCarry = (value & 0x0F) != 0;

		value--;

		registers.flagZero = value == 0;
		registers.flagNegative = true; // TODO: Make sure this is proper

		return value;
	}

	T add(T)(T value1, T value2) {
		uint result = value1 + value2;

		registers.flagZero = result == 0;
		registers.flagNegative = false;
		registers.flagHalfCarry = ((result & 0x0F) + (value2 & 0x0F)) > 0x0F;

		static if(is(T : ubyte)) {
			registers.flagCarry = (result & 0xFFFFFF00) != 0;
			return cast(ubyte)(result & 0xFF);
		}
		else static if(is(T : ushort)) {
			registers.flagCarry = (result & 0xFFFF0000) != 0;
			return cast(ushort)(result & 0xFFFF);
		}
	}

	void adc_a(T)(T value) {
		value += registers.flagCarry ? 1 : 0;

		int result = cast(int)registers.a + value;

		registers.flagCarry = (result & 0xFF00) != 0;
		registers.flagHalfCarry = ((value & 0xF) + (registers.a & 0xF)) != 0;
		registers.flagZero = value == 0;
		registers.flagNegative = false;
	}

	void sub_a(T)(T value) {
		registers.flagNegative = true;
		registers.flagCarry = value > registers.a;
		registers.flagHalfCarry = (value & 0x0F) > (registers.a & 0x0f);

		registers.a -= value;

		registers.flagZero = registers.a == 0;
	}

	void sbc_a(T)(T value) {
		value += registers.flagCarry ? 1 : 0;

		registers.flagCarry = value > registers.a;
		registers.flagHalfCarry = ((value & 0xF) > (registers.a & 0xF)) != 0;
		registers.flagZero = value == registers.a;
		registers.flagNegative = true;

		registers.a -= value;
	}

	void and_a(T)(T value) {
		registers.a &= value;

		registers.flagCarry = false;
		registers.flagNegative = false;
		registers.flagHalfCarry = true;
		registers.flagZero = registers.a == 0;
	}

	void xor_a(T)(T value) {
		registers.a ^= value;
		
		registers.flagCarry = false;
		registers.flagNegative = false;
		registers.flagHalfCarry = false;
		registers.flagZero = registers.a == 0;
	}

	void or_a(T)(T value) {
		registers.a |= value;
		
		registers.flagCarry = false;
		registers.flagNegative = false;
		registers.flagHalfCarry = false;
		registers.flagZero = registers.a == 0;
	}

	void cp_a(T)(T value) {
		registers.flagZero = registers.a == value;
		registers.flagCarry = value > registers.a;
		registers.flagHalfCarry = (value & 0x0F) > (registers.a & 0x0F);
		registers.flagNegative = true;
	}

	ubyte rlc(ubyte value) {
		int carry = (value & 0x80) >> 7;
		
		registers.flagCarry = (value & 0x80) > 0;
		
		value <<= 1;
		value += carry;
		
		registers.flagZero = value == 0;
		registers.flagHalfCarry = false;
		
		return value;
	}

	ubyte rrc(ubyte value) {
		int carry = value & 0x01;
		
		value >>= 1;

		registers.flagCarry = carry > 0;

		if(carry)
			value |= 0x80;

		registers.flagZero = value == 0;

		registers.flagNegative = false;
		registers.flagHalfCarry = false;

		return value;
	}

	ubyte rl(ubyte value) {
		int carry = registers.flagCarry ? 1 : 0;

		registers.flagCarry = (value & 0x80) > 0;

		value <<= 1;
		value += carry;

		registers.flagZero = value == 0;

		registers.flagNegative = false;
		registers.flagHalfCarry = false;
		
		return value;
	}

	ubyte rr(ubyte value) {
		value >>= 1;

		if(registers.flagCarry)
			value |= 0x80;

		registers.flagCarry = (value & 0x01) > 0;

		registers.flagZero = value == 0;

		registers.flagNegative = false;
		registers.flagHalfCarry = false;

		return value;
	}

	ubyte sla(ubyte value) {
		registers.flagCarry = (value & 0x80) != 0;
		
		value <<= 1;
		
		registers.flagZero = value == 0;
		
		registers.flagNegative = 0;
		registers.flagHalfCarry = 0;
		
		return value;
	}

	ubyte sra(ubyte value) {
		registers.flagCarry = value & 0x01;
		
		value = (value & 0x80) | (value >> 1);
		
		registers.flagZero = value == 0;
		
		registers.flagNegative = 0;
		registers.flagHalfCarry = 0;
		
		return value;
	}

	ubyte swap(ubyte value) {
		value = ((value & 0xf) << 4) | ((value & 0xf0) >> 4);
		
		registers.flagZero = value == 0;
		
		registers.flagNegative = 0;
		registers.flagCarry = 0;
		registers.flagHalfCarry = 0;
		
		return value;
	}

	/*
	 * End Instruction handlers
	 */

	void doFixedCycleCount() {
		foreach(i; 0 .. fixedCycleCount)
			doCycle();
	}

	void doCycle() {
		if(stopped)
			return;

		auto opcode = memory[registers.pc];
		registers.pc++;

		//log("Executing: 0x", opcode.to!string(16));

		if(auto instruction = instructions[opcode]) {
			if(logging)
				logInstruction(instruction);
			executeInstruction(instruction);
		}
		else
			log("Unknown opcode: 0x", opcode.to!string(16));
	}

	void executeInstruction(Instruction instruction) {
		// TODO: Debug - Remove later
		//if(registers.pc == 0x2B5)
		//	logging = true;

		//writeln("bc: ", registers.bc.to!string(16));
		//writeln("af: ", registers.af.to!string(16));
		//writeln("pc: ", registers.pc.to!string(16));

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

	void executeExtendedInstruction(Instruction instruction) {
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
		ushort value = (memory[cast(ushort)(registers.pc + 1)] << 8) | cast(ushort)memory[registers.pc];
		registers.pc += 2;
		return value;
	}

	ubyte readByte(ushort address) {
		ubyte value = memory[address];
		return value;
	}
	
	ushort readShort(ushort address) {
		ushort value = (memory[cast(ushort)(address + 1)] << 8) | cast(ushort)memory[address];
		return value;
	}

	ubyte readByteNoMove() {
		ubyte value = memory[registers.pc];
		return value;
	}
	
	ushort readShortNoMove() {
		ushort value = (memory[cast(ushort)(registers.pc + 1)] << 8) | cast(ushort)memory[registers.pc];
		return value;
	}

	void logInstruction(Instruction instruction) {
		writef("0x%X: ", registers.pc - 1);

		if(instruction.length == 0)
			writefln(format(instruction.disassembly));
		else if(instruction.length == 1)
			writefln(format(instruction.disassembly, readByteNoMove));
		else if(instruction.length == 2)
			writefln(format(instruction.disassembly, readShortNoMove));
	}

	auto stackPop(T)() {
		static if(is(T : ubyte)) {
			auto value = readByte(registers.sp);
			registers.sp++;
			return value;
		}
		else {
			auto value = readShort(registers.sp);
			registers.sp += 2;
			return value;
		}
	}

	void stackPush(T)(T value) {
		static if(is(T : ubyte)) {
			registers.sp--;
			memory[registers.sp] = value;
		}
		else {
			registers.sp -= 2;
			memory[registers.sp] = cast(ubyte)(value & 0xFF);
			memory[cast(ushort)(registers.sp + 1)] = cast(ubyte)((value >> 8) & 0xFF);
		}
	}

}