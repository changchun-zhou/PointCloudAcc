# Check List:
# 1. PLL: 
#   TOP.v, ITF.v, and CLK.v: `define PLL; 
#   TOP.sdc: False Path
# 2. RAM.v: `define RTSELDB (Debuging)
#    TapeOut: ndef for synth and Force to 10 when Simulation
#    RTSEL: 00 tapeout, 10: Only synth for Simulation
# 3. PERIOD_CLK

set DESIGN_NAME="TOP"
################################################################################
set VT="3vt"
set PERIOD_CLK="5"
set PERIOD_SCK="10" # <= 100MHz
set PLL="1"
set UNGROUP="group"
set MAXPOWER="0" # 100MHz -> 100mW
set OPTWGT="0.5" # Larger optimization weight, lower leakage(1/20~1/10 of Total Synth Power)
set NOTE="FPS_V9_64Cores"
set SDC_FILE=./TOP.sdc

################################################################################
if ($VT == "3vt") then
    set TECH_SETTING=tech_settings.tcl
else if($VT == "rvt") then
    set TECH_SETTING=tech_settings_rvt.tcl  
else 
    echo "<<<<<<<<<<<<<<<<<<<error VT>>>>>>>>>>>>>>>>>>>>>>"
    exit  
endif 

if($PERIOD_CLK == "") then 
    echo "<<<<<<<<<<<<<<<<<<<empty PERIOD_CLK>>>>>>>>>>>>>>>>>>>>>>"
    exit
endif

set DATE_VALUE = `date "+%y%m%d_%H%M" ` 
set SYNTH_OUTDIR = ../../work/synth
set SYNTH_PROJDIR = ${SYNTH_OUTDIR}/$DESIGN_NAME/Date${DATE_VALUE}_Periodclk${PERIOD_CLK}_Periodsck${PERIOD_SCK}_PLL${PLL}_${UNGROUP}_Track${VT}_MaxDynPwr${MAXPOWER}_OptWgt${OPTWGT}_Note_${NOTE}
rm -rf ${SYNTH_PROJDIR}
mkdir -p ${SYNTH_OUTDIR}/$DESIGN_NAME ${SYNTH_PROJDIR}

rm ./config_temp.tcl
rm ./define.vh

echo "set DESIGN_NAME   $DESIGN_NAME"   >> ./config_temp.tcl
echo "set PERIOD_CLK    $PERIOD_CLK"    >> ./config_temp.tcl
echo "set PERIOD_SCK    $PERIOD_SCK"    >> ./config_temp.tcl
echo "set PLL           $PLL"           >> ./config_temp.tcl
echo "set MAXPOWER      $MAXPOWER"      >> ./config_temp.tcl
echo "set OPTWGT        $OPTWGT"        >> ./config_temp.tcl
echo "set DATE_VALUE    $DATE_VALUE"    >> ./config_temp.tcl
echo "set TECH_SETTING  $TECH_SETTING"  >> ./config_temp.tcl
echo "set SDC_FILE      $SDC_FILE"      >> ./config_temp.tcl
echo "set SYNTH_PROJDIR $SYNTH_PROJDIR" >> ./config_temp.tcl
echo "              "                   >> ./define.vh # Create

cp -r ../../src ${SYNTH_PROJDIR}
cp -r ../synth ${SYNTH_PROJDIR}

if( $UNGROUP == "group") then 
  echo "set UNGROUP none" >> ./config_temp.tcl
else if( $UNGROUP == "ungroup") then 
  echo "set UNGROUP both" >> ./config_temp.tcl
else
    echo "<<<<<<<<<<<<<<<<<<<error UNGROUP>>>>>>>>>>>>>>>>>>>>>>"
    exit  
endif 

echo "<<<<<<<<<<<<<<<<<<<rc syn>>>>>>>>>>>>>>>>>>>>>>"
genus -legacy_ui -no_gui -overwrite -f ./script/syn_RISC.scr -log ${SYNTH_PROJDIR}/$DESIGN_NAME.log
