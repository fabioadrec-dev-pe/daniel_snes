; WRAM. Direct page $0000; OAM at $0200; stack $1FFF. Maps/objects in $7E2000+.

.ENUM $0000
    frame_counter   dw
    game_state      db
    nmi_ready       db
    joy_current     dw
    joy_previous    dw
    joy_pressed     dw
    joy2_current    dw
    joy2_previous   dw
    joy2_pressed    dw
    boot_timer      dw
    state_timer     dw

    stage_index     db
    lives           db
    coins           db
    time_sec        dw
    time_frames     db
    score_lo        dw
    score_hi        db
    hud_dirty       db
    paused          db

    map_cols        dw
    map_rows        db
    boss_flag       db
    n_enemies       db
    n_coins         db
    n_chk           db
    goal_x          dw
    goal_y          dw
    respawn_x       dw
    respawn_y       dw
    chk_reached     db
    cam_x           dw
    last_cam_mt     dw
    nmi_col_need    db
    nmi_col_mc      dw
    world_w         dw

    pl_x            dw
    pl_y            dw
    pl_xf           db
    pl_yf           db
    pl_vx           dw
    pl_vy           dw
    pl_flags        db          ; bit0 on_ground, bit1 face_r, bit2 jump_held, bit3 dead, bit4 win, bit5 hurt
    pl_frame        db
    pl_invuln       db
    pl_anim         db

    tmp0            dw
    tmp1            dw
    tmp2            dw
    tmp_row         dw
    tmp_col         dw
    tile_px         dw
    tile_py         dw
    spr_x           dw
    spr_y           db
    spr_tile        dw
    spr_attr        db
    spr_large       db
    spr_index       dw
    oam_next        dw
    dma_src         dw
    dma_bank        db
    dma_len         dw
    dma_dst         dw
    mul_a           db
    hit_l           db
    hit_r           db
    hit_u           db
    hit_d           db
    coin_drawn      db
    blink           db
    debug_step      db
    tile_id         db
    obj_i           db              ; current enemy index (update/draw/stomp)
    col_tiles       dsb 14              ; one BG1 metatile column, prepared on main thread
    street_scroll   dw              ; Mode 7 M7Y during STATE_STREETS
    street_div      db              ; frame divider for crawl speed
    street_next     dw              ; frames on this screen (mosaic)
    street_src      dw              ; unused (kept for DP layout)
    street_map_row  db
    street_row_need db
    menu_sel        db              ; highlighted option
    menu_cheat      db              ; secret-code progress 0..6
    menu_unlock     db              ; 1 = FASE/VIDAS visible
    menu_stage      db              ; 1..TOTAL_STAGES
    menu_lives      db              ; 1..9
    menu_swallow    db              ; 1 = JUMP was the cheat step this frame
.ENDE

.ENUM $0200
    oam_buffer      dsb 512
    oam_hi          dsb 32
.ENDE

.ENUM $0500
    hud_buf         dsb 64
.ENDE
.DEFINE PF_GROUND   $01
.DEFINE PF_FACE_R   $02
.DEFINE PF_JUMPHELD $04
.DEFINE PF_DEAD     $08
.DEFINE PF_WIN      $10
.DEFINE PF_HURT     $20
