
DATA = gfx.chr

rotating-pacman.nes: rotating-pacman.asm $(DATA)
	asm6 $< $@ rotating-pacman.lst

clean:
	@rm -f rotating-pacman.lst rotating-pacman.nes
