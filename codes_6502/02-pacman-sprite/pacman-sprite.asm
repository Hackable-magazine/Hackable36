;; Pacman sur NES
;; Affichage de pacman
;;;;;;;;;;;;;;;;;;;;;;

;; Quelques définitions
PPUCTRL   EQU $2000
PPUMASK   EQU $2001
PPUSTATUS EQU $2002
OAMADDR   EQU $2003
OAMDATA   EQU $2004
PPUSCROLL EQU $2005
PPUADDR   EQU $2006
PPUDATA   EQU $2007
JOYPAD1   EQU $4016

  ENUM $0000  ; Les variables "rapides"
vbl_cnt        DS.B 1 ; Compteur de VBL (50 Hz)
vbl_flag       DS.B 1 ; Mis à 1 par la VBL
scroll_offset  DS.B 1 ; Le décalage de l'écran
  ENDE

;; L'entête pour les émulateurs
   DC.B "NES", $1a ; L'entête doit toujours commencer ainsi
   DC.B 1          ; Le nombre de boitiers de 16 Ko de ROM CPU (1 ou 2)
   DC.B 1          ; Le nombre de boitiers de 8 Ko de ROM PPU
   DC.B 0          ; Direction de scrolling et type de cartouche
                   ; Ici, on veut le type le plus simple (0)
                   ;   avec un scrolling vertical (0 aussi)
   DS.B 9, $00     ; Puis juste 9 zéros pour faire 16 en tout

;; Début du programme
 BASE $C000
RESET:
  LDA #0      ; Remise à zéro
  STA vbl_cnt ;   du compteur de VBL
  STA PPUCTRL ;   du Controle du PPU
  STA PPUMASK ;   du Mask du PPU
  STA $4010   ; et de
  LDA #$40    ;   tout
  STA $4017   ;     l'APU

  LDX #$ff    ; Initialise la pile à 255
  TXS

;; On attend un peu que le PPU se réveille
  BIT PPUSTATUS
- BIT PPUSTATUS ; On boucle tant que le
  BPL -         ; PPU n'est pas prêt

;; Remise à zéro de toute la RAM
  LDA #0       ; Place 0 dans A
  TAX          ;   et dans X
- STA $0000,X  ; Efface l'adresse   0 + X
  STA $0100,X  ; Efface l'adresse 256 + X
  STA $0200,X  ; Efface l'adresse 512 + X
  STA $0300,X  ;   etc.
  STA $0400,X
  STA $0500,X
  STA $0600,X
  STA $0700,X
  INX          ; Incrémente X
  BNE -        ; et boucle tant que X ne revient pas à 0

;; On attend encore un peu le PPU, au cas où
  LDA PPUSTATUS

;; Chargement de la palette de couleurs
  LDA #$3F    ; On positionne le registre
  STA PPUADDR ;   d'adresse du PPU
  LDA #$00    ;   à la valeur $3F00
  STA PPUADDR

  LDX #0         ; Initialise X à 0
- LDA palette,X  ; On charge la Xième couleur
  STA PPUDATA    ;   pour l'envoyer au PPU
  INX            ; On passe à la couleur suivante
  CPX #32        ; Et ce, 32 fois
  BNE -          ; Boucle au - précédent

;; Effaçage des attributs
  LDA PPUSTATUS  ; On se resynchronise
  LDA #$23       ; Le registre d'adresse PPU
  STA PPUADDR    ;   est chargé avec la valeur
  LDA #$C0       ;   $23C0
  STA PPUADDR    ;   (attributs de la nametable 0)

  LDA #0         ; Initialise A
  TAX            ;   et X à zéro
- STA PPUDATA    ;   0 est envoyé au PPU
  INX            ; Et on boucle
  CPX #64        ;   64 fois
  BNE -

  LDA #$2B       ; Le registre d'adresse PPU
  STA PPUADDR    ;   est chargé avec la valeur
  LDA #$C0       ;   $2BC0
  STA PPUADDR    ;   (attributs de la nametable 2)

  LDA #0         ; Initialise A
  TAX            ;   et X à zéro
- STA PPUDATA    ;   0 est envoyé au PPU
  INX            ; Et on boucle
  CPX #64        ;   64 fois
  BNE -

  ;; Affichage du fond (murs)
  LDA PPUSTATUS  ; Resynchronisation
  LDA #$20       ;   On copie maintenant
  STA PPUADDR    ;     vers l'adresse $2000
  LDA #$00
  STA PPUADDR

  ; On veut copier 30 lignes de 32 colonnes
  ; Soit 960 octets = 3 * 256 + 192
  LDX #0      ; Copie des 256
- LDA murs,x  ;  premiers octets
  STA PPUDATA ;   depuis "murs"
  INX         ; Après 256 incrémentations...
  BNE -       ;  X revient à 0

- LDA murs+256,x ; Copie des 256
  STA PPUDATA    ;   octets suivants
  INX
  BNE -

- LDA murs+512,x ; Puis encore 256 octets
  STA PPUDATA
  INX
  BNE -

- LDA murs+768,x ; Et Finalement les 192 derniers
  STA PPUDATA
  INX
  CPX #192
  BNE -

; Il manque encore les 5 lignes du bas du labyrinthe
;   à partir de "murs2" vers l'adresse $2800 du PPU
  LDA #$28    ; Octet de poids fort
  STA PPUADDR
  LDA #0      ; Puis celui de poids faible
  STA PPUADDR

  LDX #0
- LDA murs2,x ; On prend les données depuis murs2
  STA PPUDATA
  INX
  CPX #5 * 32
  BNE -

  LDA #40           ; Initialisation du scrolling
  STA scroll_offset

  BIT PPUSTATUS ; Resynchronisation
- BIT PPUSTATUS ; On attend une dernière fois
  BPL -

;; Avant de rebrancher le PPU
  LDA #%10010000 ; Réactivation, avec les tuiles de fond en $1000
  STA PPUCTRL
  LDA #%00011110 ; Selection de l'affichage des tuiles et des sprites
  STA PPUMASK

  JMP mainloop

;; La routine VBL
VBL:
  PHA ; Sauvegarde de A sur la pile

  LDA #1            ; On indique à la partie principale
  STA vbl_flag      ;   que la VBL a eu lieu
  INC vbl_cnt       ; Et On incrémente le compteur de VBL

  JSR draw_pacman

  BIT PPUSTATUS     ; Resynchronisation au cas où...
  LDA #0            ; On ne se décale pas du tout en X
  STA PPUSCROLL     ;
  LDA scroll_offset ; Et la variable de décalage est
  STA PPUSCROLL     ;   utilisé comme scrolling vertical

  PLA ; Récupération de A
  RTI

draw_pacman:
  LDA #0
  STA OAMADDR

  LDA #128     ; Y
  STA OAMDATA
  LDA #8
  STA OAMDATA  ; Tile
  LDA #0
  STA OAMDATA  ; Attr
  LDA #128     ; X
  STA OAMDATA

  LDA #128     ; Y
  STA OAMDATA
  LDA #9
  STA OAMDATA  ; Tile
  LDA #0
  STA OAMDATA  ; Attr
  LDA #136     ; X
  STA OAMDATA

  LDA #136     ; Y
  STA OAMDATA
  LDA #10
  STA OAMDATA  ; Tile
  LDA #0
  STA OAMDATA  ; Attr
  LDA #128     ; X
  STA OAMDATA

  LDA #136     ; Y
  STA OAMDATA
  LDA #11
  STA OAMDATA  ; Tile
  LDA #0
  STA OAMDATA  ; Attr
  LDA #136     ; X
  STA OAMDATA

  RTS

;; La boucle principale du programme
mainloop:
- LDA vbl_flag ; On attend que la VBL ait lieu
  BEQ -
  LDA #0       ;  et on réinitialise le drapeau
  STA vbl_flag

  ; Gestion du JoyPad
  LDA #1      ; On réinitialise la lecture du Joypad
  STA JOYPAD1 ;   en écrivant un 1
  LDA #0      ;     suivi d'un 0
  STA JOYPAD1 ;       dans cette adresse

  ; Ensuite, on peut lire l'état de chaque bouton :
  LDA JOYPAD1 ; Lecture du bouton A (ignoré)
  LDA JOYPAD1 ; Lecture du bouton B (ignoré)
  LDA JOYPAD1 ; Lecture du bouton Select (ignoré)
  LDA JOYPAD1 ; Lecture du bouton Start (ignoré)

  ; Test du bouton Up
  LDA JOYPAD1       ; Lecture du bouton Up
  AND #1            ; S'il n'est pas pressé
  BEQ +             ;    On passe à la suite
  LDA scroll_offset ; Si l'offset est à zéro
  BEQ +             ;    On passe à la suite
  DEC scroll_offset ; Sinon on diminue cet offset
+

  ; Test du bouton Down
  LDA JOYPAD1       ; Player 1 - Down
  AND #1            ; S'il n'est pas pressé
  BEQ +             ;    On passe à la suite
  LDA scroll_offset ; Si l'offset
  CMP #40           ;   vaut 40 (5 lignes de 8 pixels)
  BEQ +             ;    On passe à la suite
  INC scroll_offset ; Sinon on l'augmente de 1
+
  ; et on reboucle sans fin
  JMP mainloop

;; Les données
palette:
  DC.B 14,17,25,48, 14,21,22,23, 14,25,26,27, 14,37,37,37
  DC.B 14,40,25,25, 14, 5,36,48, 14,60,23,48, 14, 2,49,25

murs:
  DC.B "                                "
  DC.B "                                "
  DC.B 0,0, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 4, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 5,0,0
  DC.B 0,0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9,0,0
  DC.B 0,0, 6, 0,12,10,10,13, 0,12,10,10,10,13, 0, 7, 8, 0,12,10,10,10,13, 0,12,10,10,13, 0, 9,0,0
  DC.B 0,0, 6, 0, 7, 0, 0, 8, 0, 7, 0, 0, 0, 8, 0, 7, 8, 0, 7, 0, 0, 0, 8, 0, 7, 0, 0, 8, 0, 9,0,0
  DC.B 0,0, 6, 0,14,11,11,15, 0,14,11,11,11,15, 0,14,15, 0,14,11,11,11,15, 0,14,11,11,15, 0, 9,0,0
  DC.B 0,0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9,0,0

  DC.B 0,0, 6, 0,12,10,10,13, 0,12,13, 0,12,10,10,10,10,10,10,13, 0,12,13, 0,12,10,10,13, 0, 9,0,0
  DC.B 0,0, 6, 0,14,11,11,15, 0, 7, 8, 0,14,11,11,13,12,11,11,15, 0, 7, 8, 0,14,11,11,15, 0, 9,0,0
  DC.B 0,0, 6, 0, 0, 0, 0, 0, 0, 7, 8, 0, 0, 0, 0, 7, 8, 0, 0, 0, 0, 7, 8, 0, 0, 0, 0, 0, 0, 9,0,0
  DC.B 0,0,16,17,17,17,17,13, 0, 7,14,10,10,13, 0, 7, 8, 0,12,10,10,15, 8, 0,12,17,17,17,17,18,0,0
  DC.B 0,0, 0, 0, 0, 0, 0, 6, 0, 7,12,11,11,15, 0,14,15, 0,14,11,11,13, 8, 0, 9, 0, 0, 0, 0, 0,0,0
  DC.B 0,0, 0, 0, 0, 0, 0, 6, 0, 7, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 8, 0, 9, 0, 0, 0, 0, 0,0,0
  DC.B 0,0, 0, 0, 0, 0, 0, 6, 0, 7, 8, 0,19,17,23,29,29,24,17,20, 0, 7, 8, 0, 9, 0, 0, 0, 0, 0,0,0
  DC.B 2,2, 2, 2, 2, 2, 2,15, 0,14,15, 0, 9, 0, 0, 0, 0, 0, 0, 6, 0,14,15, 0,14, 2, 2, 2, 2, 2,2,2

  DC.B 0,0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9, 0, 0, 0, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,0,0
  DC.B 17,17,17,17,17,17,17,13, 0,12,13, 0, 9, 0, 0, 0, 0, 0, 0, 6, 0,12,13, 0,12,17,17,17,17,17,17,17
  DC.B 0,0, 0, 0, 0, 0, 0, 6, 0, 7, 8, 0,21, 2, 2, 2, 2, 2, 2,22, 0, 7, 8, 0, 9, 0, 0, 0, 0, 0,0,0
  DC.B 0,0, 0, 0, 0, 0, 0, 6, 0, 7, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 8, 0, 9, 0, 0, 0, 0, 0,0,0
  DC.B 0,0, 0, 0, 0, 0, 0, 6, 0, 7, 8, 0,12,10,10,10,10,10,10,13, 0, 7, 8, 0, 9, 0, 0, 0, 0, 0,0,0
  DC.B 0,0, 1, 2, 2, 2, 2,15, 0,14,15, 0,14,11,11,13,12,11,11,15, 0,14,15, 0,14, 2, 2, 2, 2, 5,0,0
  DC.B 0,0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9,0,0
  DC.B 0,0, 6, 0,12,10,10,13, 0,12,10,10,10,13, 0, 7, 8, 0,12,10,10,10,13, 0,12,10,10,13, 0, 9,0,0

  DC.B 0,0, 6, 0,14,11,13, 8, 0,14,11,11,11,15, 0,14,15, 0,14,11,11,11,15, 0, 7,12,11,15, 0, 9,0,0
  DC.B 0,0, 6, 0, 0, 0, 7, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 8, 0, 0, 0, 9,0,0
  DC.B 0,0,25,10,13, 0, 7, 8, 0,12,13, 0,12,10,10,10,10,10,10,13, 0,12,13, 0, 7, 8, 0,12,10,27,0,0
  DC.B 0,0,26,11,15, 0,14,15, 0, 7, 8, 0,14,11,11,13,12,11,11,15, 0, 7, 8, 0,14,15, 0,14,11,28,0,0
  DC.B 0,0, 6, 0, 0, 0, 0, 0, 0, 7, 8, 0, 0, 0, 0, 7, 8, 0, 0, 0, 0, 7, 8, 0, 0, 0, 0, 0, 0, 9,0,0
  DC.B 0,0, 6, 0,12,10,10,10,10,15,14,10,10,13, 0, 7, 8, 0,12,10,10,15,14,10,10,10,10,13, 0, 9,0,0

murs2:
  DC.B 0,0, 6, 0,14,11,11,11,11,11,11,11,11,15, 0,14,15, 0,14,11,11,11,11,11,11,11,11,15, 0, 9,0,0
  DC.B 0,0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9,0,0
  DC.B 0,0,16,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,18,0,0
  DC.B "                                "
  DC.B "                                "

  ;; Les vecteurs du 6502
  ORG $FFFA
  DC.W VBL    ; Appelé à chaque début d'image
  DC.W RESET  ; Appelé au lancement
  DC.W $0000  ; Inutilisé

  INCBIN "gfx.chr"  ; la ROM du PPU

