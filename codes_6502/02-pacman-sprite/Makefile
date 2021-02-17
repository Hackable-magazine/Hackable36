
DATA = gfx.chr

pacman-sprite.nes: pacman-sprite.asm $(DATA)
	asm6 $< $@ pacman-sprite.lst

clean:
	@rm -f pacman-sprite.lst pacman-sprite.nes
