
DATA = gfx.chr

fantomes.nes: fantomes.asm $(DATA)
	asm6 $< $@ fantomes.lst

clean:
	@rm -f fantomes.lst fantomes.nes
