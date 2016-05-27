module gbemu.registers;

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
			ubyte d;
			ubyte e;
		}
		ushort ed;
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
}

unittest {
	Registers registers;
	
	registers.a = 0x12;
	registers.f = 0x34;
	assert(registers.af == 0x1234);

	registers.b = 0x12;
	registers.c = 0x34;
	assert(registers.bc == 0x1234);

	registers.e = 0x12;
	registers.d = 0x34;
	assert(registers.ed == 0x1234);

	registers.h = 0x12;
	registers.l = 0x34;
	assert(registers.hl == 0x1234);
}