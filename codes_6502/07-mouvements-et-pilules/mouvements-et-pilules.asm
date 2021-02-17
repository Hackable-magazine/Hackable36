;; Pacman sur NES
;; Mouvement des fantômes et gestion des pilules
;;
;; Ce qu'il reste à faire :
;; - Les différents comportement de chasse des fantômes
;; - Déplacements à des vitesses différentes
;; - Intro du jeu
;; - Gestion et affichage du score
;; - Intermission (animation entre les niveaux)
;; - Fin du jeu (mort de pacman ou passage au niveau suivant)
;; - Musique et bruitages
;; - Supprimer les (nombreux !) bugs
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

;; Pour les sprites de Pacman et des fantômes
SPR_NW_Y    EQU $200
SPR_NW_TILE EQU $201
SPR_NW_ATTR EQU $202
SPR_NW_X    EQU $203
SPR_NE_Y    EQU $204
SPR_NE_TILE EQU $205
SPR_NE_ATTR EQU $206
SPR_NE_X    EQU $207
SPR_SW_Y    EQU $208
SPR_SW_TILE EQU $209
SPR_SW_ATTR EQU $20a
SPR_SW_X    EQU $20b
SPR_SE_Y    EQU $20c
SPR_SE_TILE EQU $20d
SPR_SE_ATTR EQU $20e
SPR_SE_X    EQU $20f

; Les valeurs possibles de pac_orientation
PACMAN_FACING_LEFT   EQU 0
PACMAN_FACING_RIGHT  EQU 1
PACMAN_FACING_UP     EQU 2
PACMAN_FACING_DOWN   EQU 3

; Les modes de déplacement des fantômes
GM_CORNER     EQU 0   ; Aller dans son coin
GM_CHASE      EQU 1   ; Pourchasser pacman
GM_FRIGHTENED EQU 2   ; Errer au hasard (Pacman vient de manger une pac-gomme)
GM_EATEN      EQU 3   ; Retour à l'enclos après avoir été mangé
GM_IN_PEN     EQU 4   ; Dans l'enclos, avec une bonne envie de sortir
GM_WAITING    EQU 5   ; Dans l'enclos, immobile, en attendant de sortir

; Nombre total de pilules dans le labyrinthe (pour tester la fin du niveau)
TOTAL_NB_PILLS EQU 244
; Différents timers (probablement à améliorer)
FRIGHTENED_TIMER_HIGH EQU 3   ; Temps pendant lequel les fantômes restent effrayés
FRIGHTENED_TIMER_LOW  EQU 10  ; 3*256+10 = 778 frames
CHASE_TIMER_HIGH      EQU 7   ; Temps pendant lequel les fantômes pourchassent Pacman
CHASE_TIMER_LOW       EQU 23  ;   avant de repasser en mode "coin"
CORNER_TIMER_HIGH     EQU 8   ; Temps pendant lequel les fantômes vont dans leur coin
CORNER_TIMER_LOW      EQU 47  ;   avant de repasser en mode pourchasse

  ENUM $0000  ; Les variables "rapides"
seed                         DS.B 1  ; Valeur aléatoire courante
vbl_cnt                      DS.B 1  ; Compteur de VBL (50 Hz)
vbl_flag                     DS.B 1  ; Mis à 1 par la VBL
scroll_offset                DS.B 1  ; Le décalage de l'écran
jump_address_pointer         DS.B 2  ; Pointeur sur l'adresse de saut pour la fonction on_goto
jump_address                 DS.B 2  ; Adresse de saut pour la fonction on_goto
  ; Variables pour les paramètres de fonctions
param_x                      DS.B 1  ; Position en X de la case à tester
param_y                      DS.B 1  ;             Y
tmp_var                      DS.B 10 ; Variables locales
  ; Variables pour l'algo des fantômes
ghost_current                DS.B 1  ; Numéro du fantôme actuel (de 0 à 3)
ghost_direction_index        DS.B 1  ; Numéro de la direction actuelle (de 0 à 3, voir direction_table_x et direction_table_y)
ghost_direction_min_index    DS.B 1  ; Numéro de la direction qui a la plus petite distance
ghost_new_position_x         DS.B 1  ; Position en X du fantôme courant s'il allait dans la direction actuelle
ghost_new_position_y         DS.B 1  ;             Y
ghost_distance_x_to_target   DS.B 2  ; (carré de la) distance entre le fantôme et sa cible, en X
ghost_distance_y_to_target   DS.B 2  ; (carré de la) distance entre le fantôme et sa cible, en Y
ghost_distance_to_target     DS.B 2  ; (carré de la) distance entre le fantôme et sa cible
ghost_distance_min_to_target DS.B 2  ; Minimum des (carrés des) distances entre le fantôme et sa cible
ghost_anim_offset            DS.B 1  ; Animation des fantômes (direction du regard et animation de la robe)
  ENDE

  ENUM $0300  ; Les variables "normales"
pac_position_x   DS.B 1 ; Coordonnée en X de la case où est Pacman
pac_position_y   DS.B 1 ;               Y
pac_sub_step_x   DS.B 1 ; Coordonnée en X dans la case (de -7 à +7)
pac_sub_step_y   DS.B 1 ;               Y
pac_direction_x  DS.B 1 ; Direction en X (-1, 0 ou 1)
pac_direction_y  DS.B 1 ;              Y
pac_next_dir_x   DS.B 1 ; Prochaine direction en X
pac_next_dir_y   DS.B 1 ;                        Y
pac_orientation  DS.B 1 ; voir plus haut
pac_anim         DS.B 1 ; animation de la bouche de Pacman

; Les variables des fantômes
ghost_position_x  DS.B 4 ; Position en X des 4 fantômes
ghost_position_y  DS.B 4 ;             Y
ghost_direction_x DS.B 4 ; Direction en X des 4 fantômes
ghost_direction_y DS.B 4 ; Direction en X des 4 fantômes
ghost_sub_step_x  DS.B 4 ; Coordonnée en X dans la case (de -7 à +7)
ghost_sub_step_y  DS.B 4 ;               Y
ghost_target_x    DS.B 4 ; La cible courante (en X) des 4 fantômes
ghost_target_y    DS.B 4 ;                       Y
ghost_mode        DS.B 4 ; Mode de déplacement des fantômes (voir les constantes GM_*)
ghost_timer       DS.B 4 ; Temps de transitions des modes de déplacement des fantômes
ghost_timer_high  DS.B 4 ; Partie hautes de ces temps

; Pilules
eaten_pills       DS.B 1 ; Nombre de pilules déjà mangées
  ENDE

  ENUM $0400 ; L'état actuel des pilules
pills                DS.B 4 * 31 ; Copie en RAM des positions des pilules (champ de bits)
deleted_pill_address DS.B 2      ; Adresse dans la mémoire du PPU de la dernière pilule avalée
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

  JSR init_pac    ; Initialisation des variables de pacman
  JSR init_ghosts ; Initialisation des variables des fantômes
  LDA #0          ; Initialisation du
  STA eaten_pills ;   nombre de pilules mangées

; Initialisation des pilules (pour pouvoir les effacer une par une de cette table)
  LDX #0               ; On copie la table des pilules
- LDA starting_pills,x ;   depuis la ROM
  STA pills,x          ;   vers la RAM
  INX                  ;
  CPX #4 * 31          ; 124 octets à copier
  BNE -

;; Avant de rebrancher le PPU
  LDA #%10010000 ; Réactivation, avec les tuiles de fond en $1000
  STA PPUCTRL
  LDA #%00011110 ; Sélection de l'affichage des tuiles et des sprites
  STA PPUMASK

  JSR rand_init  ; Initialisation du générateur de nombres pseudo-aléatoires

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

  ; Initialisation des positions des fantômes
init_ghosts:
  LDX #0
- LDA ghost_default_values,X ; On prend les valeurs par défaut en ROM
  STA ghost_position_x,X     ;   pour initialiser les propriétés des fantômes en RAM
  INX
  CPX #11 * 4                ; Il y a 11 propriétés
  BNE -
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

  ; Effaçage de la pilule
  LDA deleted_pill_address   ; On efface la dernière
  STA PPUADDR                ;  pilule mangée à chaque frame
  LDA deleted_pill_address+1 ; (plus facile à gérer ainsi)
  STA PPUADDR
  LDA #0                     ; la tuile 0 contient juste du vide (noir)
  STA PPUDATA

  BIT PPUSTATUS     ; Resynchronisation au cas où...
  LDA #0            ; On ne se décale pas du tout en X
  STA PPUSCROLL     ;
  LDA scroll_offset ; Et la variable de décalage est
  STA PPUSCROLL     ;   utilisé comme scrolling vertical

  LDA #%10010000 ; Réactivation, avec les tuiles de fond en $1000
  STA PPUCTRL
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
  JSR move_ghosts          ; Déplacement (Intelligence ?) des fantômes
  JSR draw_ghosts          ; Affichage des 4 fantômes
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

  JSR remove_pill
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

  LDA param_y            ; On test spécifiquement
  CMP #12                ;  la barrière de l'enclos
  BNE set_direction      ;  aux positions (15,12) et (16,12)
  LDA param_x            ;  car Pacman n'as pas le droit
  CMP #15                ;  d'aller là.
  BEQ dont_set_direction
  CMP #16
  BEQ dont_set_direction

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
  LDA pac_position_x  ; Si on est à la position X = 2
  CMP #2
  BNE no_left_tunnel
  LDA pac_direction_x ; Et qu'on va vers la gauche,
  CMP #-1
  BNE no_left_tunnel
  LDA #29             ; On se téléporte en X = 29
  STA pac_position_x
no_left_tunnel:

  ; Vers la droite
  LDA pac_position_x  ; Si on est à la position X = 29
  CMP #29
  BNE no_right_tunnel
  LDA pac_direction_x ; Et qu'on va vers la droite,
  CMP #1
  BNE no_right_tunnel
  LDA #2              ; On se téléporte en X = 2
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

; Gestion de tout ce qu'il se passe quand on avale éventuellement une pilule.
current_mask EQU tmp_var+1 ; renommage de cette variable pour cette fonction (plus parlant)
remove_pill:
  ; on efface la pilule dans l'écran en renseignant deleted_pill_address
  ; qui est l'adresse dans la RAM du PPU de la pilule qu'on efface sans arrêt
  LDA pac_position_y  ; On commence par déterminer si on
  CMP #28             ;  est dans la partie haute ou basse de l'écran
  BMI +               ; Dans la partie basse,
  LDA #$28            ;   l'adresse commence par $28..
  JMP ++
+
  CLC                 ; Dans la partie haute,
  ADC #2              ; On prend en compte les deux lignes vides
  LSR                 ; avant de diviser la position par 8
  LSR                 ;  en divisant 3 fois par 2
  LSR                 ; pour avoir l'octet de poids fort de l'adresse
  CLC                 ; (les lignes font 32 octets et 32*8 = 256)
  ADC #$20            ; Ajout de la base, l'adresse commencera alors par $20.. $21.., $22.. ou $23..
++
  STA deleted_pill_address

  ; Calcul de l'octet de poids faible de la position de la pilule à effacer
  LDA pac_position_y  ; Si on est dans la partie bassee de l'écran,
  CMP #28             ;  (au dessous de la 28e ligne)
  BMI +
  SEC
  SBC #28             ; on enlève 28
  JMP ++
+
  CLC
  ADC #2              ; Sinon on ajoute 2 (toujours pour les deux lignes vides...)
++
  ASL                 ; Et on multiplie par 32
  ASL                 ; en multipliant
  ASL                 ;  5 fois de suite par 2
  ASL
  ASL
  CLC
  ADC pac_position_x  ; avant d'ajouter la position de Pacman en X
  STA deleted_pill_address + 1

  ; Maintenant, on teste si la pilule à cette position a déjà été mangée ou pas
  LDA pac_position_x  ; On commence par récupérer les 3 bits de la position en X
  AND #7              ; (x modulo 8)
  TAX                 ; et on convertit ça en un bit, pour pouvoir tester facilement
  LDA bits,x
  STA current_mask    ; current_mask contient alors %01000000 ou %00010000 par exemple.
  LDA pac_position_x  ; Puis on cherche quel octet de la table des pilules
  LSR                 ; correspond à la position actuelle
  LSR                 ; en divisant la position X par 8 (3 divisions par 2)
  LSR
  STA tmp_var
  LDA pac_position_y  ; Et en multipliant Y par 4 (4 octets (=32 bits) par ligne)
  ASL
  ASL
  CLC
  ADC tmp_var         ; tmp_var = Y / 4 + X * 8
  TAX
  LDA pills,x
  AND current_mask    ; et on test s'il y a un 1 ou pas à cette position.
  BNE +               ; Si ce n'est pas le cas, la pilule a déjà été mangée,
  RTS                 ;  et on a terminé de traiter tout ça.
+
  ; On met à jour la table pour enlever ce "1" qu'on vient de trouver
  LDA current_mask    ; On inverse le mask
  EOR #$ff            ;  pour avoir des 1 partout sauf à l'emplacement de la pilule
  STA current_mask
  LDA pills,x         ; Et on utilise cette valeur pour
  AND current_mask    ;  n'effacer éventuellement que ce bit.
  STA pills,x

  ; Mise à jour du nombre pilules mangées
  INC eaten_pills     ; Une de plus !
  LDA eaten_pills     ; Si on les a toutes mangées,
- CMP #TOTAL_NB_PILLS ; Pour l'instant, on stoppe le programme en bouclant sur place
  BEQ -               ; Mais il faudrait passer au niveau suivant !

  ; Traitement des Pac-gommes
  LDA #0              ; Les pac-gommes sont aux coordonnées
  STA tmp_var         ; (3,3), (3,23), (28,3) et (28,23)
  LDA pac_position_x  ; On commence par tester
  CMP #3              ;   la position en X
  BNE +               ;   et on si on est en 3
  INC tmp_var
+ CMP #28             ;   ou en 28,
  BNE +
  INC tmp_var         ; On ajoute 1 à tmp_var
+ LDA pac_position_y  ; Et en Y,
  CMP #3              ;   si on est en 3
  BNE +
  INC tmp_var
  INC tmp_var
+ CMP #23             ;   ou en 23,
  BNE +
  INC tmp_var         ; On ajoute 2 à tmp_var
  INC tmp_var
+ LDA tmp_var
  CMP #3              ; Si tmp_var vaut 3, c'est qu'on ajouté 1 puis 2, on est sur une pac-gomme !
  BNE +
  LDA #GM_FRIGHTENED        ; Les 4 fantômes passent alors dans le mode effrayé
  STA ghost_mode
  STA ghost_mode+1
  STA ghost_mode+2
  STA ghost_mode+3

  LDA #FRIGHTENED_TIMER_HIGH ; Mise en place du timer du mode GM_FRIGHTENED
  STA ghost_timer_high       ;   pour les 4 fantômes
  STA ghost_timer_high + 1
  STA ghost_timer_high + 2
  STA ghost_timer_high + 3
  LDA #FRIGHTENED_TIMER_LOW
  STA ghost_timer
  STA ghost_timer + 1
  STA ghost_timer + 2
  STA ghost_timer + 3

  JSR inc_score_big_pill  ; Et on augmente le score en fonction
  RTS
+
  JSR inc_score_pill      ; Sinon, on augmente juste le score pour la pilule avalée.
  RTS

inc_score_big_pill:
  ; À remplir pour augmenter le score quand on mange une pac-gomme
  RTS
inc_score_pill:
  ; À remplir pour augmenter le score quand on mange une pilule
  RTS

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
  CLC                ;   8 * position + sub_step
  ADC pac_sub_step_y ; Et on utilise cette position
  SBC #40            ;  en respectant les deux bornes
  BPL +              ;  0 et 40
  LDA #0             ;  comme valeur de défilement
+ CMP #40
  BMI +
  LDA #40
+ STA scroll_offset
  RTS

; Gestion des déplacements des fantômes
move_ghosts:
  LDX #0
  STX ghost_current       ; On va avoir le même code pour chaque fantôme (4 tour de boucle)
move_ghosts_loop:
  LDX ghost_current
  JSR update_mode         ; On vérifie si on doit changer de mode de déplacement
  JSR set_target          ; Mise à jour de la cible de ce fantôme
  LDA ghost_mode,X        ; Si le fantôme est en mode
  CMP #GM_WAITING         ;   WAITING, c'est qu'il ne bouge pas,
  BNE +
  JMP move_ghosts_next    ;   on passe alors directement au fantôme suivant
+
  CLC
  LDA ghost_sub_step_x,X  ; Comme pour Pacman, on commence par avancer à l'intérieur d'une case
  ADC ghost_direction_x,X ; En X
  STA ghost_sub_step_x,X
  CLC
  LDA ghost_sub_step_y,X
  ADC ghost_direction_y,X ; Ou en Y
  STA ghost_sub_step_y,X

  ; Vérifie si on est sur une "case pleine"
  ORA ghost_sub_step_x,X  ; Si on est toujours entre deux cases,
  AND #7
  BEQ +
  JMP move_ghosts_next    ;  ... on passe directement au fantôme suivant

+ ; Traitement des "cases pleines"
  LDA #0                  ; On remet à zéro les sous-positions
  STA ghost_sub_step_x,X  ;   en X
  STA ghost_sub_step_y,X  ;   et en Y

  CLC
  LDA ghost_position_x,X  ; Et on avance d'une case dans la direction actuelle
  ADC ghost_direction_x,X ;   en X
  STA ghost_position_x,X
  CLC
  LDA ghost_position_y,X
  ADC ghost_direction_y,X ;   et en Y
  STA ghost_position_y,X

; Choix de la nouvelle direction,
; Implémentation d'une petite intelligence des fantômes
  LDA #4                               ; Initialisation de l'index de direction à 4
  STA ghost_direction_min_index        ;   qui est une direction inexistante (plus facile pour débugger)
  LDA #42                              ; Initialisation de la distance la plus courte entre une position
  STA ghost_distance_min_to_target     ;   du fantôme et sa cible à une grande valeur (42 * 257)
  STA ghost_distance_min_to_target + 1 ;   pour être sûr d'en trouver une plus petite

  LDA #0                               ; On boucle sur les quatre
  STA ghost_direction_index            ;   directions possibles
ghost_move_direction_loop:
  LDX ghost_current
  LDY ghost_direction_index

  LDA ghost_position_x,X               ; Calcul de la position du fantôme s'il prenait cette direction
  CLC
  ADC direction_table_x,Y
  STA ghost_new_position_x             ; On garde cette nouvelle position dans ghost_new_position_[xy]
  STA param_x                          ; et dans param_x/param_y

  LDA ghost_position_y,X
  CLC
  ADC direction_table_y,Y
  STA ghost_new_position_y
  STA param_y
  JSR check_for_wall                   ; Teste si la nouvelle position est un mur
  BEQ +                                ; Si c'est le cas, cette direction n'est pas désirable,
  JMP ghost_move_direction_next        ;   et on passe à la suivante.
+
  ; Test de la porte de l'enclos
  LDX ghost_current                    ; La barrière de l'enclos : les cases (15,12) et (16,12)
  LDA ghost_mode,X                     ;   sont spéciales, les fantômes ne peuvent la franchir
  CMP #GM_IN_PEN                       ;   que pour sortir, s'ils sont dedans...
  BEQ ++
  CMP #GM_EATEN                        ;   ou pour rentrer mais uniquement quand ils se sont faits mangés
  BEQ ++
  LDA param_y
  CMP #12
  BNE ++
  LDA param_x
  CMP #15
  BNE +
  JMP ghost_move_direction_next        ; Sinon, on passe directement à la direction suivante.
+
  CMP #16
  BNE +
  JMP ghost_move_direction_next
+
++
  LDX ghost_current
  ; On va pas dans l'mur, continuons!
  ; Vérification des demi-tours
  LDA ghost_direction_x,X        ; Si, en additionnant la direction actuelle
  CLC
  ADC direction_table_x,Y        ;   et la direction testée, on trouve 0
  BNE ghost_move_no_u_turn       ;   en X
  LDA ghost_direction_y,X
  CLC
  ADC direction_table_y,Y
  BNE ghost_move_no_u_turn       ;   et en Y, c'est qu'on essaie de faire demi-tour
  JMP ghost_move_direction_next  ;   ce qui est interdit pour les fantômes
ghost_move_no_u_turn:

  LDA ghost_mode,X               ; Si le fantôme est effrayé,
  CMP #GM_FRIGHTENED
  BNE +
  JSR rand                       ; Il erre au hasard.
  STA ghost_distance_to_target
  JSR rand
  AND #31
  STA ghost_distance_to_target + 1 ; et la distance calculée devient aléatoire
  JMP move_ghosts_test_distance    ; puis on passe à la suite
+
  ; Sinon, on calcule vraiment la distance |x|*|x| + |y|*|y|
  ; D'abord, |x|
  LDA ghost_target_x,X      ; On calcule la différence entre la cible
  SEC
  SBC ghost_new_position_x  ;   et la position
  BPL +                     ;   et si c'est négatif,
  EOR #$ff                  ;   on change le signe (complément à 1
  CLC                       ;
  ADC #1                    ;                       plus 1)
+ ; puis |x|*|x|
  TAY
  LDA square_table_low,Y           ; On élève ensuite cette valeur au carré
  STA ghost_distance_x_to_target   ;   en utilisant la table des carrés
  LDA square_table_high,Y          ;   qui est sur deux octets (les valeurs dépassent souvent 256)
  STA ghost_distance_x_to_target+1
  ; et |y|
  LDA ghost_target_y,X             ; Même chose en y
  SEC
  SBC ghost_new_position_y         ; Différence entre position et cible
  BPL +
  EOR #$ff                         ; Changement de signe éventuel
  CLC
  ADC #1
+ ; maintenant |y|*|y|
  TAY
  LDA square_table_low,Y           ; Mise au carré
  STA ghost_distance_y_to_target
  LDA square_table_high,Y
  STA ghost_distance_y_to_target+1

  ; |x|*|x| + |y|*|y|
  CLC
  LDA ghost_distance_x_to_target   ; On additionne les carrés en X et en Y
  ADC ghost_distance_y_to_target
  STA ghost_distance_to_target
  LDA ghost_distance_x_to_target+1
  ADC ghost_distance_y_to_target+1
  STA ghost_distance_to_target+1   ; Pour avoir le carré de la distance euclidienne

move_ghosts_test_distance:
  ; Compare avec la distance mini
  LDA ghost_distance_to_target       ; Si cette distance est plus petite
  CMP ghost_distance_min_to_target   ;  que la plus petite distance actuellement...
  LDA ghost_distance_to_target+1
  SBC ghost_distance_min_to_target+1
  BCS +
  LDA ghost_direction_index          ; On se souvient de l'indice de la direction
  STA ghost_direction_min_index      ;   qui a produit cette distance
  LDA ghost_distance_to_target       ; Et on met à jour la distance mini.
  STA ghost_distance_min_to_target
  LDA ghost_distance_to_target+1
  STA ghost_distance_min_to_target+1
+
ghost_move_direction_next:
  INC ghost_direction_index          ; Et on passe à la direction suivante
  LDA ghost_direction_index
  CMP #4                             ; Jusqu'à avoir fait le tour des 4 directions
  BEQ +
  JMP ghost_move_direction_loop
+
  LDX ghost_current                  ; Et on utilise tout cela
  LDY ghost_direction_min_index      ;   pour mettre à jour la nouvelle direction
  LDA direction_table_x,Y            ;   du fantôme
  STA ghost_direction_x,X
  LDA direction_table_y,Y
  STA ghost_direction_y,X

move_ghosts_next:
  ; Et juste avant de passer au fantôme suivant...
  LDX ghost_current
  ;; Prise en compte du tunnel pour les fantômes
  ; Vers la gauche
  LDA ghost_position_x,X  ; Si on est à la position X = 1
  CMP #1
  BNE ghost_no_left_tunnel
  LDA ghost_direction_x,X ; Et qu'on va vers la gauche,
  CMP #-1
  BNE ghost_no_left_tunnel
  LDA #30             ; On se téléporte en X = 30
  STA ghost_position_x,X
ghost_no_left_tunnel:

  ; Vers la droite
  LDA ghost_position_x,X  ; Si on est à la position X = 30
  CMP #30
  BNE ghost_no_right_tunnel
  LDA ghost_direction_x,X ; Et qu'on va vers la droite,
  CMP #1
  BNE ghost_no_right_tunnel
  LDA #1              ; On se téléporte en X = 1
  STA ghost_position_x,X
ghost_no_right_tunnel:

  INC ghost_current     ; Et on boucle sur les 4 fantômes.
  LDA ghost_current
  CMP #4
  BEQ +
  JMP move_ghosts_loop
+
  RTS

; Les tables des directions
; Dans l'ordre : gauche, droite, haut, bas.
direction_table_x:
  DC.B -1, 1, 0, 0
direction_table_y:
  DC.B 0, 0, -1, 1

; Table des carrés pour les calculs des distances
square_table_low: ; Octets de poids forts :
  DL 0, 1, 4, 9, 16, 25, 36, 49, 64, 81, 100, 121, 144, 169, 196, 225, 256, 289, 324, 361, 400, 441, 484, 529, 576, 625, 676, 729, 784, 841, 900, 961, 1024

square_table_high: ; Octets de poids faibles
  DH 0, 1, 4, 9, 16, 25, 36, 49, 64, 81, 100, 121, 144, 169, 196, 225, 256, 289, 324, 361, 400, 441, 484, 529, 576, 625, 676, 729, 784, 841, 900, 961, 1024


; Mise à jour du mode de déplacement d'un fantôme
update_mode:
  LDA ghost_mode,X             ; Suivant le mode actuel pour ce fantôme
  JSR on_goto                  ; On saute à telle ou telle sous-routine
  DC.W update_mode_corner
  DC.W update_mode_chase
  DC.W update_mode_frightened
  DC.W update_mode_eaten
  DC.W update_mode_in_pen
  DC.W update_mode_waiting

; Traitement du mode coins
update_mode_corner:
  DEC ghost_timer,X       ; On décrémente le timer correspondant
  BNE +
  DEC ghost_timer_high,X  ;   qui est sur 2 octets
  BNE +                   ; Si on arrive à zéro,
  LDA #GM_CHASE           ; On passe en mode pourchasse de Pacman
  STA ghost_mode,X
  LDA #CHASE_TIMER_HIGH   ; Et on réinitialise le timer
  STA ghost_timer_high,X
  LDA #CHASE_TIMER_LOW
  STA ghost_timer,X
+ RTS

; Traitement du mode pourchasse
update_mode_chase:
  DEC ghost_timer,X      ; On décrémente le timer correspondant
  BNE +
  DEC ghost_timer_high,X ;   qui est sur 2 octets
  BNE +                  ; Si on arrive à zéro,
  LDA #GM_CORNER         ; On passe en mode coin
  STA ghost_mode,X
  LDA #CORNER_TIMER_HIGH ; Et on réinitialise le timer
  STA ghost_timer_high,X
  LDA #CORNER_TIMER_LOW
  STA ghost_timer,X
+ RTS

; Traitement du mode "effrayé" (après une pac-gomme)
update_mode_frightened:
  LDA ghost_position_x,X  ; On vérifie si on est sur la même case
  CMP pac_position_x      ;   que pacman en X
  BNE +
  LDA ghost_position_y,X
  CMP pac_position_y      ;   et en Y
  BNE +
  LDA #GM_EATEN           ; Si c'est le cas, le fantôme est mangé !
  STA ghost_mode,X        ; Il faudrait ici augmenter le score...
  RTS
+
  DEC ghost_timer,X       ; Si le fantôme n'est pas mangé, il repassera
  BNE +
  DEC ghost_timer_high,X
  BNE +
  LDA #GM_CORNER          ;  dans le mode "coin" au bout d'un moment.
  STA ghost_mode,X        ;  et on réinitialise le timer
  LDA #CORNER_TIMER_HIGH
  STA ghost_timer_high,X
  LDA #CORNER_TIMER_LOW
  STA ghost_timer,X
+ RTS

; Traitement du mode "mangé", retour à la base.
update_mode_eaten:
  LDA ghost_position_y,X ; Si on est rentré dans l'enclos
  CMP #13
  BNE +
  LDA ghost_position_x,X
  CMP #15
  BNE +
  LDA #GM_WAITING        ; On passe en mode attente pendant 1,2 secondes
  STA ghost_mode,X
  LDA #60
  STA ghost_timer,X
+ RTS

; Traitement du mode "dans l'enclos"
update_mode_in_pen:
  LDA ghost_position_y,X  ; On essaie juste de sortir
  CMP #11                 ;   et si on est assez haut,
  BNE +
  LDA #GM_CORNER          ;   on repasse en mode coin
  STA ghost_mode,X
  LDA #CORNER_TIMER_HIGH
  STA ghost_timer_high,X
  LDA #CORNER_TIMER_LOW
  STA ghost_timer,X
+ RTS

; Traitement du mode "Attente"
update_mode_waiting:
  DEC ghost_timer,X     ; On décrémente juste le timer
  BNE +
  LDA #GM_IN_PEN        ; Avant de changer de mode pour sortir de l'enclos
  STA ghost_mode,X
+ RTS


; Mise à jour de la cible du fantôme courant
set_target:
  LDA ghost_mode,X           ; Suivant le mode de déplacement du fantôme
  JSR on_goto                ; On utilise telle ou telle fonction
  DC.W set_target_corner
  DC.W set_target_chase
  DC.W set_target_frightened
  DC.W set_target_eaten
  DC.W set_target_in_pen
  DC.W set_target_waiting

; Pour le mode "coin"
set_target_corner:
  LDA default_target_x,X    ; On copie juste les coordonnées du
  STA ghost_target_x,X      ;  coin préféré du fantôme dans la cible
  LDA default_target_y,X
  STA ghost_target_y,X
  RTS

; Pour le mode "pourchasse"
set_target_chase:
  LDA pac_position_x       ; La cible est simplement Pacman !
  STA ghost_target_x,X     ;  (À améliorer pour plus d'intelligence !)
  LDA pac_position_y
  STA ghost_target_y,X
  RTS

; Pour le mode effrayé
set_target_frightened:
  RTS                      ; Il n'y a pas de cible dans ce mode...

; Pour le mode "mangé";
set_target_eaten:          ; La cible est alors le centre
  LDA #15                  ;  de l'enclos.
  STA ghost_target_x,X
  LDA #13
  STA ghost_target_y,X
  RTS

; Pour le mode "attente"
set_target_waiting:
  RTS                      ; Il n'y a pas de cible dans ce mode...

; Pour le mode "dans l'enclos"
set_target_in_pen:
  LDA #15                 ; On vise une case au dessus de l'enclos pour arriver à sortir
  STA ghost_target_x,X
  LDA #10
  STA ghost_target_y,X
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
  STA SPR_NW_X    ;  pour la partie gauche
  STA SPR_SW_X    ;     des sprites
  CLC
  ADC #8          ;  et on ajoute 8 pixels
  STA SPR_NE_X    ;    pour les sprites
  STA SPR_SE_X    ;    de la partie droite

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
  STA SPR_NW_Y        ; ... pour la partie haute
  STA SPR_NE_Y
  CLC
  ADC #8
  STA SPR_SW_Y        ; ... et la partie basse
  STA SPR_SE_Y

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
  TAY             ; On copie A dans Y
  STY SPR_NW_TILE ;  qui contient le numéro de la tuile North West (NW)
  INY             ; Et les suivantes
  STY SPR_NE_TILE ;  se suivent
  INY             ;    dans l'ordre
  STY SPR_SW_TILE ;  NW, NE, SW et SE
  INY             ; Par exemple, si A vaut 8
  STY SPR_SE_TILE ;  on utilisera les tuiles 8, 9, 10, 11
  LDY #0          ; Pas de symétrie si on va à gauche
  JMP draw_pacman_attributes

+
  CPX #PACMAN_FACING_RIGHT
  BNE +             ; Si on va à droite, on change
  TAY               ;   juste l'ordre des tuiles
  STY SPR_NE_TILE   ;     entre Est et Ouest :
  INY               ;     NE, NW, SE, SW
  STY SPR_NW_TILE
  INY
  STY SPR_SE_TILE
  INY
  STY SPR_SW_TILE
  LDY #$40          ; Et on symétrise tout horizontalement
  JMP draw_pacman_attributes

+
  CPX #PACMAN_FACING_UP ; Si on va vers le haut,
  BNE +
  CLC               ;   on ajoute 4 pour sélectionner
  ADC #4            ;    les tuiles de la position
  TAY               ;      verticale.
  STY SPR_NW_TILE   ; Et le reste est identique.
  INY
  STY SPR_NE_TILE
  INY
  STY SPR_SW_TILE
  INY
  STY SPR_SE_TILE
  LDY #0            ; Pas de symétrie
  JMP draw_pacman_attributes

+
  CPX #PACMAN_FACING_DOWN ; Et vers le bas,
  BNE +                   ; C'est comme pour vers le haut
  CLC
  ADC #4
  TAY
  STY SPR_SW_TILE     ; mais on échange nord et sud
  INY                 ; pour avoir l'ordre SW, SE, NW, NE
  STY SPR_SE_TILE
  INY
  STY SPR_NW_TILE
  INY
  STY SPR_NE_TILE
  LDY #$80            ; Et on symétrise verticalement

draw_pacman_attributes:
  STY SPR_NW_ATTR  ; On stocke donc le même attribut
  STY SPR_NE_ATTR  ; pour les quatre tuiles :
  STY SPR_SW_ATTR  ; 0 si on va en haut ou à gauche
  STY SPR_SE_ATTR  ; $40 pour la droite, $80 pour le bas.
+ RTS

; Affichage des 4 fantômes
; Ici on appelle juste la sous fonction draw_one_ghost
; 4 fois, avec danx X le numéro de fantôme et dans Y
; l'emplacement en ram, dans la page $200 où seront
; stockées les informations (coordonnées x et y, tuile
; et attribut) de chaque sprite du fantôme
draw_ghosts:
  LDX #0             ; Le premier fantôme, Blinky,
  LDY #$10           ;  utilise de $210 à $21f
  JSR draw_one_ghost
  LDX #1             ; Le second, Pinky,
  LDY #$20           ;  utilise de $220 à $22f
  JSR draw_one_ghost
  LDX #2             ; Le troisième, Inky,
  LDY #$30           ;  utilise de $230 à $23f
  JSR draw_one_ghost
  LDX #3             ; Et le quatrième, Clyde,
  LDY #$40           ;  utilise de $240 à $24f
  JSR draw_one_ghost
  RTS

; Affiche un fantôme.
; Le numéro de fantôme doit être dans X
; Et l'endroit où seront stockées ses infos dans Y
draw_one_ghost:
  ; Rotation des associations fantôme <-> sprites
  TXA         ; On copie le numéro du fantôme dans A
  CLC         ;   et on ajoute une valeur qui change
  ADC vbl_cnt ;   toutes les frames
  AND #3      ; Puis, on se remet entre 0 et 3
  TAX         ; Avant de remettre la valeur dans X
  ; On commence par la coordonné en x
  LDA ghost_position_x,X ; La position x en cases
  ASL                    ;   est multipliée
  ASL                    ;   par 8
  ASL
  SBC #4                 ; Puis on enlève 4 pixels
  CLC     ; XXX
  ADC ghost_sub_step_x,X
  STA SPR_NW_X,Y         ; pour la partie gauche
  STA SPR_SW_X,Y         ;    des sprites
  CLC
  ADC #8                 ; Et on ajoute 8 pixels
  STA SPR_NE_X,Y         ;   pour la partie droite
  STA SPR_SE_X,Y

  ; la coordonnée en y
  LDA ghost_position_y,X ; Même chose en Y
  CLC                    ; On tient compte des 2 lignes vides
  ADC #2                 ;    au dessus du labyrinthe
  ASL                    ; Multiplication par 8
  ASL
  ASL
  SEC                    ; On prend en compte le
  SBC scroll_offset      ;   décalage de l'écran.
  SBC #4                 ; Puis on enlève 4 pixels
  CLC
  ADC ghost_sub_step_y,X
  STA SPR_NW_Y,Y
  STA SPR_NE_Y,Y
  CLC
  ADC #8                 ; Et 8 pixels plus bas
  STA SPR_SW_Y,Y         ;   pour la partie basse des fantômes
  STA SPR_SE_Y,Y

  ; Choix des tuiles
  LDA ghost_mode,X         ; Si le fantôme est dans l'état "mangé",
  CMP #GM_EATEN
  BNE +
  JMP draw_one_ghost_eaten ; on a un traitement particulier
+
  CMP #GM_FRIGHTENED       ; Si le fantôme est effrayé,
  BEQ +
  JMP draw_one_ghost_not_frightened ; on ne passe pas à la suite.
+ LDA #88                  ; Les tuiles des fantômes commencent au numéro 88
  STA ghost_anim_offset    ;
  LDA vbl_cnt
  AND #%1000
  BEQ +
  CLC
  LDA ghost_anim_offset    ; suivant l'animation on ajoute 4 ou non pour alterner
  ADC #4                   ; entre les deux formes de la robe des fantômes effrayés
  STA ghost_anim_offset
+
  LDA ghost_anim_offset    ; On renseigne alors les 4 tuiles pour ce fantôme
  CLC
  STA SPR_NW_TILE,Y  ; 88 ou 92
  ADC #1
  STA SPR_NE_TILE,Y  ; 89 ou 93
  ADC #1
  STA SPR_SW_TILE,Y  ; 90 ou 94
  ADC #1
  STA SPR_SE_TILE,Y  ; 91 ou 95

  LDA #3             ; Et la palette est toujours la 3 (la quatrième, avec du bleu)
  STA SPR_NW_ATTR,Y
  STA SPR_NE_ATTR,Y
  STA SPR_SW_ATTR,Y
  STA SPR_SE_ATTR,Y
  RTS

; Dessin d'un fantôme mangé (juste ses yeux)
draw_one_ghost_eaten:
  LDA #96                 ; Les tuiles des yeux qui regardent à droite commencent à 96
  STA ghost_anim_offset
  LDA ghost_direction_x,X
  CMP #-1
  BNE +
  LDA #100                ; Si le fantôme va à gauche, on prend les tuiles à partir de 100
  STA ghost_anim_offset
+
  LDA ghost_direction_y,X
  CMP #-1
  BNE +
  LDA #104                ; Si le fantôme va en haut, on prend les tuiles à partir de 104
  STA ghost_anim_offset
+
  LDA ghost_direction_y,X
  CMP #1
  BNE +
  LDA #108                ; Si le fantôme va vers le bas, on prend les tuiles à partir de 108
  STA ghost_anim_offset
+
  LDA ghost_anim_offset    ; On renseigne alors les 4 tuiles pour ce fantôme
  CLC
  STA SPR_NW_TILE,Y
  ADC #1
  STA SPR_NE_TILE,Y
  ADC #1
  STA SPR_SW_TILE,Y
  ADC #1
  STA SPR_SE_TILE,Y

  LDA #1             ; Et on choisit la palette 1 !
  STA SPR_NW_ATTR,Y
  STA SPR_NE_ATTR,Y
  STA SPR_SW_ATTR,Y
  STA SPR_SE_ATTR,Y
  RTS

; Dessin des fantômes en mode normal
draw_one_ghost_not_frightened:
  ; à partir de 24 pour les fantômes 0 et 2,
  ;       et de 56 pour les fantômes 1 et 3
  LDA #0                  ; Suivant la direction, on se décalera de 0 (droite)
  STA ghost_anim_offset
  LDA ghost_direction_x,X
  CMP #-1
  BNE +
  LDA #8                  ; 8 (gauche)
  STA ghost_anim_offset
+
  LDA ghost_direction_y,X
  CMP #-1
  BNE +
  LDA #16                 ; 16 (haut)
  STA ghost_anim_offset
+
  LDA ghost_direction_y,X
  CMP #1
  BNE +
  LDA #24                 ; ou 24 (bas)
  STA ghost_anim_offset
+

  LDA vbl_cnt
  AND #%1000
  BEQ +
  CLC
  LDA ghost_anim_offset    ; suivant l'animation on ajoute 4 ou non pour alterner
  ADC #4                   ; entre les deux formes de la robe des fantômes effrayés
  STA ghost_anim_offset
+
  TXA
  AND #1  ; Si le numéro de fantôme est impair
  BEQ +
  LDA #32 ; On se décale de 32
+ CLC     ; (sinon, A contient déjà 0)
  ADC #24 ; et On ajoute 24
  ADC ghost_anim_offset

  STA SPR_NW_TILE,Y  ; 24 ou 56 (plus animation)
  ADC #1
  STA SPR_NE_TILE,Y  ; 25 ou 57   "      "
  ADC #1
  STA SPR_SW_TILE,Y  ; 26 ou 58   "      "
  ADC #1
  STA SPR_SE_TILE,Y  ; 27 ou 59   "      "

  ; Palette : les deux premiers fantômes utilisent
  ; la palette 1, les deux autres la palette 2
  TXA        ; On copie le numéro de fantôme dans A
  AND #%10   ; et on ne garde que le bit 1
  LSR        ; A vaut alors 0 pour les deux premiers
  CLC        ;   fantômes et 1 pour les autres
  ADC #1     ; + 1, soit 1 ou 2, le bon numéro de palette
  STA SPR_NW_ATTR,Y
  STA SPR_NE_ATTR,Y
  STA SPR_SW_ATTR,Y
  STA SPR_SE_ATTR,Y
  RTS

; Fonction utilitaire
; Permet de sauter à une fonction en particulier en fonction de la valeur de A
on_goto:
  ASL                          ; On multiplie A par 2
  TAY
  PLA                          ; On récupère l'adresse des adresses des fonctions dans la pile
  STA jump_address_pointer     ; Poids faible d'abord
  PLA
  STA jump_address_pointer + 1 ; Poids fort ensuite
  INY
  LDA (jump_address_pointer),y ; Puis on récupère l'adresse de la fonction qu'on veut appeler
  STA jump_address             ; Poids faible
  INY
  LDA (jump_address_pointer),y
  STA jump_address + 1         ; et poids fort
  JMP (jump_address)           ; Et on saute à cette adresse

; Gestion des nombres aléatoire
rand_init:   ; Initialisation avec
  LDA #17    ;   un nombre que j'ai soigneusement choisi au hasard
rand_seed:
  STA seed
  RTS

; Des calculs compliqués juste pour avoir une suite aléatoire intéressante.
rand:
rand23:
  LDA seed
  ASL
  ASL
  CLC
  ADC seed
  CLC
  ADC #23
  STA seed ; la prochaine valeur aléatoire est stockée dans seed et dans A
  RTS

;; Les données
;; La palette de couleurs
palette:
  DC.B 14,17,25,48, 14,21,22,23, 14,25,26,27, 14,37,37,37
  DC.B 14,40,25,25, 14, 5,36,48, 14,60,23,48, 14, 2,49,25

; Les numéros des tuiles du labyrinthe
murs:
  DC.B "                                "
  DC.B "                                "
  DC.B 0,0, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 4, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 5,0,0
  DC.B 0,0, 6,30,30,30,30,30,30,30,30,30,30,30,30, 7, 8,30,30,30,30,30,30,30,30,30,30,30,30, 9,0,0
  DC.B 0,0, 6,30,12,10,10,13,30,12,10,10,10,13,30, 7, 8,30,12,10,10,10,13,30,12,10,10,13,30, 9,0,0
  DC.B 0,0, 6,31, 7, 0, 0, 8,30, 7, 0, 0, 0, 8,30, 7, 8,30, 7, 0, 0, 0, 8,30, 7, 0, 0, 8,31, 9,0,0
  DC.B 0,0, 6,30,14,11,11,15,30,14,11,11,11,15,30,14,15,30,14,11,11,11,15,30,14,11,11,15,30, 9,0,0
  DC.B 0,0, 6,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30, 9,0,0

  DC.B 0,0, 6,30,12,10,10,13,30,12,13,30,12,10,10,10,10,10,10,13,30,12,13,30,12,10,10,13,30, 9,0,0
  DC.B 0,0, 6,30,14,11,11,15,30, 7, 8,30,14,11,11,13,12,11,11,15,30, 7, 8,30,14,11,11,15,30, 9,0,0
  DC.B 0,0, 6,30,30,30,30,30,30, 7, 8,30,30,30,30, 7, 8,30,30,30,30, 7, 8,30,30,30,30,30,30, 9,0,0
  DC.B 0,0,16,17,17,17,17,13,30, 7,14,10,10,13, 0, 7, 8, 0,12,10,10,15, 8,30,12,17,17,17,17,18,0,0
  DC.B 0,0, 0, 0, 0, 0, 0, 6,30, 7,12,11,11,15, 0,14,15, 0,14,11,11,13, 8,30, 9, 0, 0, 0, 0, 0,0,0
  DC.B 0,0, 0, 0, 0, 0, 0, 6,30, 7, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 8,30, 9, 0, 0, 0, 0, 0,0,0
  DC.B 0,0, 0, 0, 0, 0, 0, 6,30, 7, 8, 0,19,17,23,29,29,24,17,20, 0, 7, 8,30, 9, 0, 0, 0, 0, 0,0,0
  DC.B 2,2, 2, 2, 2, 2, 2,15,30,14,15, 0, 9, 0, 0, 0, 0, 0, 0, 6, 0,14,15,30,14, 2, 2, 2, 2, 2,2,2

  DC.B 0,0, 0, 0, 0, 0, 0, 0,30, 0, 0, 0, 9, 0, 0, 0, 0, 0, 0, 6, 0, 0, 0,30, 0, 0, 0, 0, 0, 0,0,0
  DC.B 17,17,17,17,17,17,17,13,30,12,13, 0, 9, 0, 0, 0, 0, 0, 0, 6, 0,12,13,30,12,17,17,17,17,17,17,17
  DC.B 0,0, 0, 0, 0, 0, 0, 6,30, 7, 8, 0,21, 2, 2, 2, 2, 2, 2,22, 0, 7, 8,30, 9, 0, 0, 0, 0, 0,0,0
  DC.B 0,0, 0, 0, 0, 0, 0, 6,30, 7, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 8,30, 9, 0, 0, 0, 0, 0,0,0
  DC.B 0,0, 0, 0, 0, 0, 0, 6,30, 7, 8, 0,12,10,10,10,10,10,10,13, 0, 7, 8,30, 9, 0, 0, 0, 0, 0,0,0
  DC.B 0,0, 1, 2, 2, 2, 2,15,30,14,15, 0,14,11,11,13,12,11,11,15, 0,14,15,30,14, 2, 2, 2, 2, 5,0,0
  DC.B 0,0, 6,30,30,30,30,30,30,30,30,30,30,30,30, 7, 8,30,30,30,30,30,30,30,30,30,30,30,30, 9,0,0

  DC.B 0,0, 6,30,12,10,10,13,30,12,10,10,10,13,30, 7, 8,30,12,10,10,10,13,30,12,10,10,13,30, 9,0,0
  DC.B 0,0, 6,30,14,11,13, 8,30,14,11,11,11,15,30,14,15,30,14,11,11,11,15,30, 7,12,11,15,30, 9,0,0
  DC.B 0,0, 6,31,30,30, 7, 8,30,30,30,30,30,30,30, 0, 0,30,30,30,30,30,30,30, 7, 8,30,30,31, 9,0,0
  DC.B 0,0,25,10,13,30, 7, 8,30,12,13,30,12,10,10,10,10,10,10,13,30,12,13,30, 7, 8,30,12,10,27,0,0
  DC.B 0,0,26,11,15,30,14,15,30, 7, 8,30,14,11,11,13,12,11,11,15,30, 7, 8,30,14,15,30,14,11,28,0,0
  DC.B 0,0, 6,30,30,30,30,30,30, 7, 8,30,30,30,30, 7, 8,30,30,30,30, 7, 8,30,30,30,30,30,30, 9,0,0
  DC.B 0,0, 6,30,12,10,10,10,10,15,14,10,10,13,30, 7, 8,30,12,10,10,15,14,10,10,10,10,13,30, 9,0,0

murs2:
  DC.B 0,0, 6,30,14,11,11,11,11,11,11,11,11,15,30,14,15,30,14,11,11,11,11,11,11,11,11,15,30, 9,0,0
  DC.B 0,0, 6,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30,30, 9,0,0
  DC.B 0,0,16,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,18,0,0
  DC.B "                                "
  DC.B "                                "

; Table des murs, un bit par case, pour les collisions
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

; Table des pilules, au démarrage du jeu
starting_pills:
  DC.B %00000000,%00000000,%00000000,%00000000 ; ligne 0
  DC.B %00011111,%11111110,%01111111,%11111000 ; ligne 1
  DC.B %00010000,%10000010,%01000001,%00001000 ; ligne 2
  DC.B %00010000,%10000010,%01000001,%00001000 ; ligne 3
  DC.B %00010000,%10000010,%01000001,%00001000 ; ligne 4
  DC.B %00011111,%11111111,%11111111,%11111000 ; ligne 5
  DC.B %00010000,%10010000,%00001001,%00001000 ; ligne 6
  DC.B %00010000,%10010000,%00001001,%00001000 ; ligne 7
  DC.B %00011111,%10011110,%01111001,%11111000 ; ligne 8
  DC.B %00000000,%10000000,%00000001,%00000000 ; ligne 9
  DC.B %00000000,%10000000,%00000001,%00000000 ; ligne 10
  DC.B %00000000,%10000000,%00000001,%00000000 ; ligne 11
  DC.B %00000000,%10000000,%00000001,%00000000 ; ligne 12
  DC.B %00000000,%10000000,%00000001,%00000000 ; ligne 13
  DC.B %00000000,%10000000,%00000001,%00000000 ; ligne 14
  DC.B %00000000,%10000000,%00000001,%00000000 ; ligne 15
  DC.B %00000000,%10000000,%00000001,%00000000 ; ligne 16
  DC.B %00000000,%10000000,%00000001,%00000000 ; ligne 17
  DC.B %00000000,%10000000,%00000001,%00000000 ; ligne 18
  DC.B %00000000,%10000000,%00000001,%00000000 ; ligne 19
  DC.B %00011111,%11111110,%01111111,%11111000 ; ligne 20
  DC.B %00010000,%10000010,%01000001,%00001000 ; ligne 21
  DC.B %00010000,%10000010,%01000001,%00001000 ; ligne 22
  DC.B %00011100,%11111110,%01111111,%00111000 ; ligne 23
  DC.B %00000100,%10010000,%00001001,%00100000 ; ligne 24
  DC.B %00000100,%10010000,%00001001,%00100000 ; ligne 25
  DC.B %00011111,%10011110,%01111001,%11111000 ; ligne 26
  DC.B %00010000,%00000010,%01000000,%00001000 ; ligne 27
  DC.B %00010000,%00000010,%01000000,%00001000 ; ligne 28
  DC.B %00011111,%11111111,%11111111,%11111000 ; ligne 29
  DC.B %00000000,%00000000,%00000000,%00000000 ; ligne 30

ghost_default_values:
  DC.B 16, 16, 14, 18   ; position x
  DC.B 11, 14, 14, 14   ; position y
  DC.B  1,  0,  1, -1   ; direction x
  DC.B  0, -1,  0,  0   ; direction y
  DC.B  0,  0, -3, -3   ; sub_step x
  DC.B  0,  0,  0,  0   ; sub_step y
default_target_x:
  DC.B 28,  5,  5, 28   ; target x
default_target_y:
  DC.B  0, 33,  0, 33   ; target y  (-2)
  DC.B GM_CORNER, GM_WAITING, GM_WAITING, GM_WAITING ; mode de déplacement
  DC.B  0, 80, 160, 240 ; timer
  DC.B  3,  0,  0,  0   ; timer_high

  ;; Les vecteurs du 6502
  ORG $FFFA
  DC.W VBL    ; Appelé à chaque début d'image
  DC.W RESET  ; Appelé au lancement
  DC.W $0000  ; Inutilisé

  INCBIN "gfx.chr"  ; la ROM du PPU

