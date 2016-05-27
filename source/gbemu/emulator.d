module gbemu.emulator;

import std.stdio, std.datetime, std.file, core.thread, std.experimental.logger, derelict.sdl2.sdl, derelict.opengl3.gl;
import gbemu.cpu, gbemu.memory;

class Emulator
{
	SDL_Window* window;
	SDL_Renderer* renderer;
	
	bool running = true;

	Cpu cpu;
	Memory memory;

	this()
	{
		prepareLogger();
		memory = new Memory();
		cpu = new Cpu(this);
	}

	private void prepareLogger() {
		auto logger = new MultiLogger();
		sharedLog = logger;
		logger.insertLogger("file", new FileLogger("log.txt"));
		logger.insertLogger("console", new FileLogger(stdout));
	}

	void start() {
		log("Starting Game Boy emulator");
		loadLibraries();
		openWindow();
		enterLoop();
	}

	private void loadLibraries() {
		log("Loading libraries");
		DerelictSDL2.load("lib/SDL2.dll");
		DerelictGL.load();
	}
	
	private void openWindow() {
		SDL_GL_SetAttribute(SDL_GL_RED_SIZE, 8);
		SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE, 8);
		SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE, 8);
		SDL_GL_SetAttribute(SDL_GL_ALPHA_SIZE, 8);
		SDL_GL_SetAttribute(SDL_GL_BUFFER_SIZE, 32);
		SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
		
		log("Creating window");
		SDL_CreateWindowAndRenderer(800, 600, SDL_WINDOW_OPENGL, &window, &renderer);
		log("Creating OpenGL context");
		SDL_GL_CreateContext(window);
	}
	
	private void enterLoop() {
		log("Entering main loop");
		
		while(running) {
			updateEvents();
			cpu.doCycle();
			render();
			limitFps();
		}
	}

	private void updateEvents() {
		SDL_Event event;
		
		while(SDL_PollEvent(&event)) {
			switch(event.type) {
				case SDL_QUIT:
					running = false;
					break;
					
				default:
					break;
			}
		}
	}
	
	private void render() {
		glClearColor(0.1f, 0.1f, 0.1f, 1f);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		glViewport(0, 0, 800, 600);
		glOrtho(0, 800, 0, 600, -1, 1);
		glMatrixMode(GL_MODELVIEW);
		
		glRasterPos3f(0, 600, 0);
		glPixelZoom(5f, -5f);
		//glDrawPixels(screen.width, screen.height, GL_GREEN, GL_UNSIGNED_BYTE, screen.dataPointer);
		
		SDL_GL_SwapWindow(window);
	}
	
	private void limitFps() {
		static StopWatch sw = StopWatch();
		enum maxFPS = 60;
		
		if(maxFPS != -1) {
			long desiredNs = 1_000_000_000 / maxFPS; // How much time the frame should take
			
			if(desiredNs - sw.peek.nsecs >= 0)
				Thread.sleep(nsecs(desiredNs - sw.peek.nsecs));
			
			sw.reset();
			sw.start();
		}
	}

	void loadRom(string name) {
		log("Opening ROM ", name);
		loadRom(cast(ubyte[])read(name));
	}

	void loadRom(ubyte[] data) {
		import std.conv : to;
		assert(data.length <= 0x8000, "ROM too big. Size below 0x8000 expected. Got 0x" ~ data.length.to!string(16) ~ ".");
		memory.cartridge[0 .. data.length] = data;
	}
}

