
set SYNTH_PROJDIR = "../../work/synth/TOP/Date230805_0220_Periodclk5_Periodsck10_PLL1_group_Track3vt_MaxDynPwr0_OptWgt0.5_Note_FPS_FROZEN_V9_PLL&REDUCEPAD"
set TCF_DUMP_NAME = "tcf_period5_range25clks_FPSact100.dump"

set NOTE = ${TCF_DUMP_NAME}_report
set TCF_DUMP = ${SYNTH_PROJDIR}/dump/${TCF_DUMP_NAME}
set DESIGN_NAME = "TOP"
set clk = "I_SysClk_PAD"
set TECH_SETTING="tech_settings.tcl"
set INST = "TOP"
set TCF_INST = "u_TOP"
################################################################################
rm ./config_temp.tcl

echo "set DESIGN_NAME $DESIGN_NAME"     >> ./config_temp.tcl
echo "set clk $clk"                     >> ./config_temp.tcl
echo "set NOTE $NOTE"                   >> ./config_temp.tcl
echo "set TECH_SETTING $TECH_SETTING"   >> ./config_temp.tcl
echo "set SYNTH_PROJDIR $SYNTH_PROJDIR" >> ./config_temp.tcl
echo "set INST $INST"                   >> ./config_temp.tcl
echo "set TCF_INST $TCF_INST"           >> ./config_temp.tcl
echo "set TCF_DUMP $TCF_DUMP"           >> ./config_temp.tcl

genus -legacy_ui -no_gui -overwrite -f ./script/syn_RISC_power.scr -log ${SYNTH_PROJDIR}/report/${NOTE}/${INST}_power.log
