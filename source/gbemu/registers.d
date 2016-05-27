module gbemu.registers;

enum Flags {
	zero = 1 << 7,
	negative = 1 << 6,
	halfCarry = 1 << 5,
	carry = 1 << 4,
}

struct Registers {
	union {
		struct {
			ubyte f;
			ubyte a;
		}
		ushort af;
	}
	
	union {
		struct {
			ubyte c;
			ubyte b;
		}
		ushort bc;
	}
	
	union {
		struct {
			ubyte e;
			ubyte d;
		}
		ushort de;
	}

	union {
		struct {
			ubyte l;
			ubyte h;
		}
		ushort hl;
	}

	ushort sp;
	ushort pc;

	@property
	bool flagZero() {
		return (f & Flags.zero) > 0;
	}

	@property
	void flagZero(bool value) {
		if(value)
			f |= Flags.zero;
		else
			f &= ~(Flags.zero);
	}

	@property
	bool flagNegative() {
		return (f & Flags.negative) > 0;
	}
	
	@property
	void flagNegative(bool value) {
		if(value)
			f |= Flags.negative;
		else
			f &= ~(Flags.negative);
	}

	@property
	bool flagHalfCarry() {
		return (f & Flags.halfCarry) > 0;
	}
	
	@property
	void flagHalfCarry(bool value) {
		if(value)
			f |= Flags.halfCarry;
		else
			f &= ~(Flags.halfCarry);
	}

	@property
	bool flagCarry() {
		return (f & Flags.carry) > 0;
	}
	
	@property
	void flagCarry(bool value) {
		if(value)
			f |= Flags.carry;
		else
			f &= ~(Flags.carry);
	}
}

unittest {
	Registers registers;
	
	registers.a = 0x12;
	registers.f = 0x34;
	assert(registers.af == 0x1234);

	registers.b = 0x12;
	registers.c = 0x34;
	assert(registers.bc == 0x1234);

	registers.d = 0x12;
	registers.e = 0x34;
	assert(registers.de == 0x1234);

	registers.h = 0x12;
	registers.l = 0x34;
	assert(registers.hl == 0x1234);
}