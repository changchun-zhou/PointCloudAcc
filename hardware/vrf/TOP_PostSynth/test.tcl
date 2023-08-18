# stop -condition { #EnTcf == 1'b0 }
run 100
# force TOP_tb.u_TOP.u_GLB.@{\GEN_BANK[0].u_SPRAM_HS }.u_RAM.@{\genblk1.GLB_BANK }.RTSEL_i = 2'b10;
# force TOP_tb.u_TOP.u_GLB.@{\GEN_BANK[1].u_SPRAM_HS }.u_RAM.@{\genblk1.GLB_BANK }.RTSEL_i = 2'b10;
# force TOP_tb.u_TOP.u_GLB.@{\GEN_BANK[2].u_SPRAM_HS }.u_RAM.@{\genblk1.GLB_BANK }.RTSEL_i = 2'b10;
# force TOP_tb.u_TOP.u_GLB.@{\GEN_BANK[3].u_SPRAM_HS }.u_RAM.@{\genblk1.GLB_BANK }.RTSEL_i = 2'b10;
# force TOP_tb.u_TOP.u_GLB.@{\GEN_BANK[4].u_SPRAM_HS }.u_RAM.@{\genblk1.GLB_BANK }.RTSEL_i = 2'b10;
# force TOP_tb.u_TOP.u_GLB.@{\GEN_BANK[5].u_SPRAM_HS }.u_RAM.@{\genblk1.GLB_BANK }.RTSEL_i = 2'b10;
# force TOP_tb.u_TOP.u_GLB.@{\GEN_BANK[6].u_SPRAM_HS }.u_RAM.@{\genblk1.GLB_BANK }.RTSEL_i = 2'b10;
# force TOP_tb.u_TOP.u_GLB.@{\GEN_BANK[7].u_SPRAM_HS }.u_RAM.@{\genblk1.GLB_BANK }.RTSEL_i = 2'b10;
# force TOP_tb.u_TOP.u_GLB.@{\GEN_BANK[8].u_SPRAM_HS }.u_RAM.@{\genblk1.GLB_BANK }.RTSEL_i = 2'b10;
# force TOP_tb.u_TOP.u_GLB.@{\GEN_BANK[9].u_SPRAM_HS }.u_RAM.@{\genblk1.GLB_BANK }.RTSEL_i = 2'b10;
# force TOP_tb.u_TOP.u_GLB.@{\GEN_BANK[10].u_SPRAM_HS }.u_RAM.@{\genblk1.GLB_BANK }.RTSEL_i = 2'b10;
# force TOP_tb.u_TOP.u_GLB.@{\GEN_BANK[11].u_SPRAM_HS }.u_RAM.@{\genblk1.GLB_BANK }.RTSEL_i = 2'b10;
# force TOP_tb.u_TOP.u_GLB.@{\GEN_BANK[12].u_SPRAM_HS }.u_RAM.@{\genblk1.GLB_BANK }.RTSEL_i = 2'b10;
# force TOP_tb.u_TOP.u_GLB.@{\GEN_BANK[13].u_SPRAM_HS }.u_RAM.@{\genblk1.GLB_BANK }.RTSEL_i = 2'b10;
# force TOP_tb.u_TOP.u_GLB.@{\GEN_BANK[14].u_SPRAM_HS }.u_RAM.@{\genblk1.GLB_BANK }.RTSEL_i = 2'b10;
# force TOP_tb.u_TOP.u_GLB.@{\GEN_BANK[15].u_SPRAM_HS }.u_RAM.@{\genblk1.GLB_BANK }.RTSEL_i = 2'b10;

# dumptcf -scope TOP_tb.u_TOP -output tcf_period10_0703.dump -overwrite
# dumptcf -scope TOP_tb.u_TOP -output ../../work/synth/TOP/Date230817_2034_Periodclk5_Periodsck10_PLL1_group_Track3vt_MaxDynPwr0_OptWgt0.5_Note_FPS_V9_PLL&REDUCEPAD_4Cores/dump/tcf_period5_range10000clks_instance_u_TOP_actFPS1cfg256cp128lp.dump -overwrite
# run
# dumptcf -end
