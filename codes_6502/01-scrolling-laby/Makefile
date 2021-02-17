
DATA = gfx.chr

scrolling-laby.nes: scrolling-laby.asm $(DATA)
	asm6 $< $@ scrolling-laby.lst

clean:
	@rm -f scrolling-laby.lst scrolling-laby.nes
