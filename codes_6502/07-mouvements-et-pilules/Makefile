
DATA = gfx.chr

test: mouvements-et-pilules.nes
	@nestopia $< 1>/dev/null 2>/dev/null

mouvements-et-pilules.nes: mouvements-et-pilules.asm $(DATA)
	../asm6 $< $@ mouvements-et-pilules.lst

clean:
	@rm -f mouvements-et-pilules.lst mouvements-et-pilules.nes

debug:
	@awk '/0[0-9A-F]{4} +[a-z0-9_]+ +ds.[bw]/{print "$$" substr($$1,2,5) "#" $$2 "#"}' mouvements-et-pilules.lst > mouvements-et-pilules.nes.ram.nl
	wine /home/dindinx/bin/fceux.exe &
