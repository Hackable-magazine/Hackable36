
DATA = gfx.chr

collisions.nes: collisions.asm $(DATA)
	asm6 $< $@ collisions.lst

clean:
	@rm -f collisions.lst collisions.nes
