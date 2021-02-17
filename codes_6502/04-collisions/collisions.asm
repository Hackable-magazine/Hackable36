;; Pacman sur NES
;; Gestion des collisions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Quelques définitions
; Les registres (adresses) du PPU
PPUCTRL   EQU $2000
PPUMASK   EQU $2001
PPUSTATUS EQU $2002
OAMADDR   EQU $2003
OAMDATA   EQU $2004
PPUSCROLL EQU $2005
PPUADDR   EQU $2006
PPUDATA   EQU $2007
; Quelques adresses/registres de l'APU
OAMDMA    EQU $4014
JOYPAD1   EQU $4016

;; Pour les sprites de Pacman
SPR_PAC_NW_Y    EQU $200
SPR_PAC_NW_TILE EQU $201
SPR_PAC_NW_ATTR EQU $202
SPR_PAC_NW_X    EQU $203
SPR_PAC_NE_Y    EQU $204
SPR_PAC_NE_TILE EQU $205
SPR_PAC_NE_ATTR EQU $206
SPR_PAC_NE_X    EQU $207
SPR_PAC_SW_Y    EQU $208
SPR_PAC_SW_TILE EQU $209
SPR_PAC_SW_ATTR EQU $20a
SPR_PAC_SW_X    EQU $20b
SPR_PAC_SE_Y    EQU $20c
SPR_PAC_SE_TILE EQU $20d
SPR_PAC_SE_ATTR EQU $20e
SPR_PAC_SE_X    EQU $20f

; Les valeurs possibles de pac_orientation
PACMAN_FACING_LEFT   EQU 0
PACMAN_FACING_RIGHT  EQU 1
PACMAN_FACING_UP     EQU 2
PACMAN_FACING_DOWN   EQU 3

  ENUM $0000  ; Les variables "rapides"
vbl_cnt        DS.B 1 ; Compteur de VBL (50 Hz)
vbl_flag       DS.B 1 ; Mis à 1 par la VBL
scroll_offset  DS.B 1 ; Le décalage de l'écran
  ; Variables pour les paramètres de fonctions
param_x        DS.B 1 ; Position en X de la case à tester
param_y        DS.B 1 ;             Y
tmp_var        DS.B 1 ; Variable temporaire
  ENDE

  ENUM $0300  ; Les variables "normales"
pac_position_x  DS.B 1 ; Coordonnée en X de la case où est Pacman
pac_position_y  DS.B 1 ;               Y
pac_sub_step_x  DS.B 1 ; Coordonnée en X dans la case (de -7 à +7)
pac_sub_step_y  DS.B 1 ;               Y
pac_direction_x DS.B 1 ; Direction en X (-1, 0 ou 1)
pac_direction_y DS.B 1 ;              Y
pac_next_dir_x  DS.B 1 ; Prochaine direction en X
pac_next_dir_y  DS.B 1 ;                        Y
pac_orientation DS.B 1 ; voir plus haut
pac_anim        DS.B 1 ; animation de la bouche de Pacman
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
  ; on n'efface pas $0200,X (voir plus bas)
  STA $0300,X  ; Efface l'adresse 768 + X
  STA $0400,X  ;   etc.
  STA $0500,X
  STA $0600,X
  STA $0700,X
  INX          ; Incrémente X
  BNE -        ; et boucle tant que X ne revient pas à 0

;; On initialise tout le segment "sprites" à 255
  LDA #255     ; X vaut déjà 0
- STA $0200,X  ; On place des 255
  INX          ;   sur tout ce segment
  BNE -        ;     boucle tant que X ne revient pas à 0

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

  JSR init_pac ; Initialisation des variables de pacman

;; Avant de rebrancher le PPU
  LDA #%10010000 ; Réactivation, avec les tuiles de fond en $1000
  STA PPUCTRL
  LDA #%00011110 ; Selection de l'affichage des tuiles et des sprites
  STA PPUMASK

  JMP mainloop

init_pac:
  LDA #15             ; On initialise la position
  STA pac_position_x  ;   de Pacman à
  LDA #23             ;   (15, 23)
  STA pac_position_y
  LDA #0              ; Et tout le reste à 0
  STA pac_direction_x
  STA pac_direction_y
  STA pac_sub_step_x
  STA pac_sub_step_y
  STA pac_next_dir_x
  STA pac_next_dir_y
  STA pac_orientation
  STA pac_anim
  RTS

;; La routine VBL
VBL:
  PHA ; Sauvegarde de A sur la pile

  ; Envoi des 64 sprites par DMA
  LDA #0       ; Poids faible d'abord
  STA OAMADDR  ;
  LDA #2       ; Puis le poids fort.
  STA OAMDMA

  LDA #1            ; On indique à la partie principale
  STA vbl_flag      ;   que la VBL a eu lieu
  INC vbl_cnt       ; Et On incrémente le compteur de VBL

  BIT PPUSTATUS     ; Resynchronisation au cas où...
  LDA #0            ; On ne se décale pas du tout en X
  STA PPUSCROLL     ;
  LDA scroll_offset ; Et la variable de décalage est
  STA PPUSCROLL     ;   utilisé comme scrolling vertical

  PLA ; Récupération de A
  RTI

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
  LDA JOYPAD1        ; Lecture du bouton Up
  AND #1             ; S'il n'est pas pressé
  BEQ +              ;    On passe à la suite
  LDA #0             ; Sinon, on enregistre l'envie
  STA pac_next_dir_x ;    d'aller en haut :
  LDA #-1            ;     dx = 0, dy = -1
  STA pac_next_dir_y
+

  ; Test du bouton Down
  LDA JOYPAD1        ; Lecture du bouton Up
  AND #1             ; S'il n'est pas pressé
  BEQ +              ;    On passe à la suite
  LDA #0             ; Sinon, on enregistre l'envie
  STA pac_next_dir_x ;    d'aller en bas :
  LDA #1             ;     dx = 0, dy = 1
  STA pac_next_dir_y
+

  ; Test du bouton Left
  LDA JOYPAD1        ; Lecture du bouton Left
  AND #1             ; S'il n'est pas pressé
  BEQ +              ;    On passe à la suite
  LDA #-1            ; Sinon, on enregistre l'envie
  STA pac_next_dir_x ;    d'aller à gauche :
  LDA #0             ;     dx = -1, dy = 0
  STA pac_next_dir_y
+

  ; Test du bouton Right
  LDA JOYPAD1        ; Lecture du bouton Right
  AND #1             ; S'il n'est pas pressé
  BEQ +              ;    On passe à la suite
  LDA #1             ; Sinon, on enregistre l'envie
  STA pac_next_dir_x ;    d'aller à droite :
  LDA #0             ;     dx = 1, dy = 0
  STA pac_next_dir_y
+

  JSR move_pacman          ; Déplacement du pacman
  JSR update_scroll_offset ; Gestion du défilement vertical
  JSR draw_pacman          ; Affichage de Pacman
  ; et on reboucle sans fin
  JMP mainloop

; Gestion du déplacement de Pacman
move_pacman:
  LDA pac_direction_x ; Si on ne bouge ni en X
  ORA pac_direction_y ;   ni en Y,
  BEQ no_move         ;     on saute un bout de code

  INC pac_anim        ; On change l'animation du pacman

  ; Et on met à jour sa forme suivant la direction
  LDA pac_direction_x      ; Si Pacman ne va pas
  CMP #-1                  ;   vers la gauche,
  BNE +                    ;   on passe à la suite
  LDX #PACMAN_FACING_LEFT  ; Sinon, on met à jour
  STX pac_orientation      ;   la variable pac_orientation
  JMP end_shape            ;   et c'est terminé

+ CMP #1                   ; Même chose
  BNE +                    ;   pour
  LDX #PACMAN_FACING_RIGHT ;     la droite
  STX pac_orientation
  JMP end_shape

+ LDA pac_direction_y      ; Et verticalement,
  CMP #-1                  ; On fait le même test
  BNE +                    ;   pour le haut...
  LDX #PACMAN_FACING_UP
  STX pac_orientation
  JMP end_shape

+ CMP #1                   ; ... et pour
  BNE +                    ;       le bas
  LDX #PACMAN_FACING_DOWN
  STX pac_orientation
+
end_shape:

; Avancement du Pacman d'un pixel dans la direction courante :
  LDA pac_sub_step_x  ; On avance la sous-position en x
  CLC                 ;   de -1, 0 ou +1
  ADC pac_direction_x ;   suivant la direction actuelle
  STA pac_sub_step_x

  LDA pac_sub_step_y  ; même chose en Y
  CLC
  ADC pac_direction_y
  STA pac_sub_step_y

no_move:
  ; Vérification du cas où on est sur une nouvelle case
  LDA pac_sub_step_x ; L'un de ces deux est null
  ORA pac_sub_step_y ; Si en les additionnants...
  AND #7             ;   on a un multiple de 8
  BEQ +              ; alors on passe à la suite
  RTS                ; Sinon, on a fini de traiter les mouvements
+
  LDA pac_position_x  ; On avance alors la position
  CLC                 ;  (en nombre de cases) en X
  ADC pac_direction_x ;  de -1, 0 ou +1
  STA pac_position_x  ;  suivant la direction actuelle

  LDA pac_position_y  ; Et on fait la même chose
  CLC                 ;   en Y
  ADC pac_direction_y
  STA pac_position_y

  ; Et On remet à 0 les sous-positions :
  LDA #0
  STA pac_sub_step_x
  STA pac_sub_step_y

; On vérifie si on n'essaie pas de foncer dans un mur
  LDA pac_position_x ; param_x = pac_position_x + pac_next_dir_x
  CLC
  ADC pac_next_dir_x
  STA param_x

  LDA pac_position_y ; param_y = pac_position_y + pac_next_dir_y
  CLC
  ADC pac_next_dir_y
  STA param_y

  JSR check_for_wall     ; Si (param_x, param_y) est un mur
  BNE dont_set_direction ;   on évite d'y aller !

set_direction:
  ; S'il n'y a pas de mur, on peut y aller
  LDA pac_next_dir_x  ; on copie la prochaine
  STA pac_direction_x ;  direction souhaitée
  LDA pac_next_dir_y  ;  dans la nouvelle
  STA pac_direction_y ;  direction courante

dont_set_direction:
  ; On continue dans la même direction,
  ; mais on vérifie si on ne fonce pas dans un mur
  LDA pac_position_x ; param_x = pac_position_x + pac_direction_x
  CLC
  ADC pac_direction_x
  STA param_x

  LDA pac_position_y ; param_y = pac_position_y + pac_direction_y
  CLC
  ADC pac_direction_y
  STA param_y

  JSR check_for_wall       ; S'il n'y a pas de mur,
  BEQ dont_reset_direction ;   tout va bien et on continue

reset_direction:
  LDA #0                   ; Sinon, on s'arrête
  STA pac_direction_x      ;   En mettant tout à zéro
  STA pac_direction_y

dont_reset_direction:
  ;; Prise en compte du tunnel
  ; Vers la gauche
  LDA pac_position_x  ; Si on est à la position X = 1
  CMP #1
  BNE no_left_tunnel
  LDA pac_direction_x ; Et qu'on va vers la gauche,
  CMP #-1
  BNE no_left_tunnel
  LDA #30             ; On se téléporte en X = 30
  STA pac_position_x
no_left_tunnel:

  ; Vers la droite
  LDA pac_position_x  ; Si on est à la position X = 30
  CMP #30
  BNE no_right_tunnel
  LDA pac_direction_x ; Et qu'on va vers la droite,
  CMP #1
  BNE no_right_tunnel
  LDA #1              ; On se téléporte en X = 1
  STA pac_position_x
no_right_tunnel:

  RTS

; Table de conversion entre un numéro de bit et une puissance de 2
bits:
 DC.B %10000000
 DC.B %01000000
 DC.B %00100000
 DC.B %00010000
 DC.B %00001000
 DC.B %00000100
 DC.B %00000010
 DC.B %00000001

; Teste si la case (param_x, param_y) est occupée par un mur.
; Après un appel à cette fonction, on pourra utiliser
; BNE ou BEQ pour gérer les cas "mur" ou "pas de mur"
check_for_wall:
  LDA param_y ; on multiplie param_y par 4
  ASL
  ASL
  STA tmp_var ; tmp_var = Y * 4

  LDA param_x ; on divise param_x par 8
  LSR
  LSR
  LSR
  CLC
  ADC tmp_var ; tmp_var = Y * 4 + X / 8
  TAX
  LDA wall_mask_8bit,X ; On récupère le bon octet
  STA tmp_var          ; de la table des murs

  LDA param_x  ; Et la coordonnée en X modulo 8
  AND #7       ;   nous donne le bit à tester
  TAX
  LDA bits,X
  AND tmp_var  ; Positionne le flag Z s'il n'y a pas de mur.
  RTS

; Mise à jour du défilement vertical
update_scroll_offset:
  LDA pac_position_y ; Si on est à en dessous
  CMP #18            ;   de la ligne 18,
  BMI +              ;   on met le défilement
  LDA #40            ;   à 40 (valeur maximale)
  STA scroll_offset
  RTS

+ CMP #5             ; Au dessus de la ligne 5
  BPL +              ;   le défilement est nul
  LDA #0
  STA scroll_offset
  RTS

+ ASL                ; Entre les deux, on calcule
  ASL                ;   la position de Pacman au
  ASL                ;   pixel près
  CLC                ;   8 * position + sub_steap
  ADC pac_sub_step_y ; Et on utilise cette position
  SBC #40            ;  en respectant les deux bornes
  BPL +              ;  0 et 40
  LDA #0             ;  comme valeur de défilement
+ CMP #40
  BMI +
  LDA #40
+ STA scroll_offset
  RTS


;; Affichage du Pacman
;; On doit renseigner le X, le Y,
;;   le numéro de tuile et l'attributs
;;   de chacun des 4 sprites qui composent Pacman
draw_pacman:
  ; D'abord les positions en X
  LDA pac_position_x  ; On récupère la position (en cases)
  ASL                 ;  en X de Pacman
  ASL                 ;   que l'on multiplie
  ASL                 ;   par 8
  CLC                 ;   et on ajoute
  ADC pac_sub_step_x  ;   la sous-position
  SBC #4              ;  et on enlève 4 pixels
  STA SPR_PAC_NW_X    ;  pour la partie gauche
  STA SPR_PAC_SW_X    ;     des sprites
  CLC
  ADC #8              ;  et on ajoute 8 pixels
  STA SPR_PAC_NE_X    ;    pour les sprites
  STA SPR_PAC_SE_X    ;    de la partie droite

  ;
  LDA pac_position_y  ; Même chose en Y
  CLC                 ; On tient compte des 2 lignes
  ADC #2              ;    au dessus du labyrinthe
  ASL                 ; Multiplication par 8
  ASL
  ASL
  CLC                 ; On ajoute la sous-position
  ADC pac_sub_step_y  ;  à l'intérieur de la case
  SEC                 ; Et on prend en compte le
  SBC scroll_offset   ;   décalage de l'écran.
  SBC #4              ; Puis on enlève 4 pixels
  STA SPR_PAC_NW_Y   ; ... pour la partie haute
  STA SPR_PAC_NE_Y
  CLC
  ADC #8
  STA SPR_PAC_SW_Y   ; ... et la partie basse
  STA SPR_PAC_SE_Y

  ; Le reste dépend de l'animation (ouvert, fermé)
  ; et de l'orientation
  LDA pac_anim        ; On change l'animation
  LSR                 ;   une fois sur deux
  CLC                 ; On se décale de 1 pour
  ADC #1              ;   commencer par la bonne position
  AND #3              ; On ne garde que les valeurs de 0 à 3
  CMP #3              ;   et on transforme les 3
  BNE +               ;    en 1
  LDA #1              ;     pour avoir la séquence
+ ASL                 ;       0,1,2,1,0,1,2,1,0,1,2,1,0,1,etc.
  ASL                 ;     et on multiplie par huit pour avoir
  ASL                 ;       0,8,16,8,0,8,16,8,0,8,16,8,etc.

  LDX pac_orientation      ; Il reste à vérifier l'orientation de Pacman
  CPX #PACMAN_FACING_LEFT  ; S'il va à gauche,
  BNE +
  TAY                 ; On copie A dans Y
  STY SPR_PAC_NW_TILE ;  qui contient le numéro de la tuile North West (NW)
  INY                 ; Et les suivantes
  STY SPR_PAC_NE_TILE ;  se suivent
  INY                 ;    dans l'ordre
  STY SPR_PAC_SW_TILE ;  NW, NE, SW et SE
  INY                 ; Par exemple, si A vaut 8
  STY SPR_PAC_SE_TILE ;  on utilisera les tuiles 8, 9, 10, 11
  LDY #0              ; Pas de symétrie si on va à gauche
  JMP draw_pacman_attributes

+
  CPX #PACMAN_FACING_RIGHT
  BNE +               ; Si on va à droite, on change
  TAY                 ;   juste l'ordre des tuiles
  STY SPR_PAC_NE_TILE ;     entre Est et Ouest :
  INY                 ;     NE, NW, SE, SW
  STY SPR_PAC_NW_TILE
  INY
  STY SPR_PAC_SE_TILE
  INY
  STY SPR_PAC_SW_TILE
  LDY #$40            ; Et on symétrise tout horizontalement
  JMP draw_pacman_attributes

+
  CPX #PACMAN_FACING_UP ; Si on va vers le haut,
  BNE +
  CLC                   ;   on ajoute 4 pour sélectionner
  ADC #4                ;    les tuiles de la position
  TAY                   ;      verticale.
  STY SPR_PAC_NW_TILE   ; Et le reste est identique.
  INY
  STY SPR_PAC_NE_TILE
  INY
  STY SPR_PAC_SW_TILE
  INY
  STY SPR_PAC_SE_TILE
  LDY #0                ; Pas de symétrie
  JMP draw_pacman_attributes

+
  CPX #PACMAN_FACING_DOWN ; Et vers le bas,
  BNE +                   ; C'est comme pour vers le haut
  CLC
  ADC #4
  TAY
  STY SPR_PAC_SW_TILE     ; mais on échange nord et sud
  INY                     ; pour avoir l'ordre SW, SE, NW, NE
  STY SPR_PAC_SE_TILE
  INY
  STY SPR_PAC_NW_TILE
  INY
  STY SPR_PAC_NE_TILE
  LDY #$80             ; Et on symétrise verticalement

draw_pacman_attributes:
  STY SPR_PAC_NW_ATTR  ; On stocke donc le même attribut
  STY SPR_PAC_NE_ATTR  ; pour les quatre tuiles :
  STY SPR_PAC_SW_ATTR  ; 0 si on va en haut ou à gauche
  STY SPR_PAC_SE_ATTR  ; $40 pour la droite, $80 pour le bas.
+ RTS

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

; Table des murs, un bit par case
wall_mask_8bit:
  DC.B %11111111,%11111111,%11111111,%11111111 ; ligne 0
  DC.B %11100000,%00000001,%10000000,%00000111 ; ligne 1
  DC.B %11101111,%01111101,%10111110,%11110111 ; ligne 2
  DC.B %11101111,%01111101,%10111110,%11110111 ; ligne 3
  DC.B %11101111,%01111101,%10111110,%11110111 ; ligne 4
  DC.B %11100000,%00000000,%00000000,%00000111 ; ligne 5
  DC.B %11101111,%01101111,%11110110,%11110111 ; ligne 6
  DC.B %11101111,%01101111,%11110110,%11110111 ; ligne 7
  DC.B %11100000,%01100001,%10000110,%00000111 ; ligne 8
  DC.B %11111111,%01111101,%10111110,%11111111 ; ligne 9
  DC.B %11111111,%01111101,%10111110,%11111111 ; ligne 10
  DC.B %11111111,%01100000,%00000110,%11111111 ; ligne 11
  DC.B %11111111,%01101110,%01110110,%11111111 ; ligne 12
  DC.B %11111111,%01101000,%00010110,%11111111 ; ligne 13
  DC.B %00000000,%00001000,%00010000,%00000000 ; ligne 14
  DC.B %11111111,%01101111,%11110110,%11111111 ; ligne 15
  DC.B %11111111,%01101111,%11110110,%11111111 ; ligne 16
  DC.B %11111111,%01100000,%00000110,%11111111 ; ligne 17
  DC.B %11111111,%01101111,%11110110,%11111111 ; ligne 18
  DC.B %11111111,%01101111,%11110110,%11111111 ; ligne 19
  DC.B %11100000,%00000001,%10000000,%00000111 ; ligne 20
  DC.B %11101111,%01111101,%10111110,%11110111 ; ligne 21
  DC.B %11101111,%01111101,%10111110,%11110111 ; ligne 22
  DC.B %11100011,%00000000,%00000000,%11000111 ; ligne 23
  DC.B %11111011,%01101111,%11110110,%11011111 ; ligne 24
  DC.B %11111011,%01101111,%11110110,%11011111 ; ligne 25
  DC.B %11100000,%01100001,%10000110,%00000111 ; ligne 26
  DC.B %11101111,%11111101,%10111111,%11110111 ; ligne 27
  DC.B %11101111,%11111101,%10111111,%11110111 ; ligne 28
  DC.B %11100000,%00000000,%00000000,%00000111 ; ligne 29
  DC.B %11111111,%11111111,%11111111,%11111111 ; ligne 30

  ;; Les vecteurs du 6502
  ORG $FFFA
  DC.W VBL    ; Appelé à chaque début d'image
  DC.W RESET  ; Appelé au lancement
  DC.W $0000  ; Inutilisé

  INCBIN "gfx.chr"  ; la ROM du PPU

