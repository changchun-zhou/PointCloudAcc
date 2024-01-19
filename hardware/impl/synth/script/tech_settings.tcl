## Select the technology library
#
#search path library files
set_attribute lib_search_path { \
	/materials/technology/tsmc28/TSMC_28_IP/STD_CELL/tcbn28hpcplusbwp7t30p140_190a/tcbn28hpcplusbwp7t30p140_180a_ecsm/digital/Front_End/timing_power_noise/ECSM/tcbn28hpcplusbwp7t30p140_180a \
	/materials/technology/tsmc28/TSMC_28_IP/STD_CELL/tcbn28hpcplusbwp7t30p140hvt_190a/tcbn28hpcplusbwp7t30p140hvt_180a_ecsm/digital/Front_End/timing_power_noise/ECSM/tcbn28hpcplusbwp7t30p140hvt_180a \
	/materials/technology/tsmc28/TSMC_28_IP/STD_CELL/tcbn28hpcplusbwp7t30p140uhvt_190a/tcbn28hpcplusbwp7t30p140uhvt_180b_ecsm/digital/Front_End/timing_power_noise/ECSM/tcbn28hpcplusbwp7t30p140uhvt_180b \
	/materials/technology/tsmc28/TSMC_28_IP/STD_IO/tphn28hpcpgv18_170d/tphn28hpcpgv18_170a_nldm/digital/Front_End/timing_power_noise/NLDM/tphn28hpcpgv18_170a \
    ../../project/lib/mem/ts1n28hpcpuhdhvtb64x128m4sso_170a/NLDM \
	../../project/lib/mem/ts1n28hpcpuhdhvtb128x256m1sso_170a/NLDM \
	../../project/lib/mem/ts1n28hpcpuhdhvtb16x8m2sso_170a/NLDM \
	../../project/lib/mem/ts1n28hpcpuhdhvtb256x8m4sso_170a/NLDM \
	../../project/lib/mem/tsdn28hpcpuhdb256x10m4m_170a/NLDM \
	../../project/lib/mem/tsdn28hpcpuhdb32x128m4m_170a/NLDM \
	../../project/lib/mem/ts1n28hpcpuhdhvtb32x256m1sso_170a/NLDM \
	../../project/lib/mem/ts1n28hpcpuhdhvtb8x256m1sso_170a/NLDM \
	../../project/lib/mem/ts1n28hpcpuhdhvtb64x256m1sso_170a/NLDM \
    ../../project/lib/PLL/lib/ \
	} ;

#target library
set_attribute library { \
	tcbn28hpcplusbwp7t30p140tt0p9v25c_ecsm.lib \
	tcbn28hpcplusbwp7t30p140hvttt0p9v25c_ecsm.lib \
	tcbn28hpcplusbwp7t30p140uhvttt0p9v25c_ecsm.lib \
	tphn28hpcpgv18tt0p9v1p8v25c.lib \
	ts1n28hpcpuhdhvtb128x256m1sso_170a_tt0p9v25c.lib \
	ts1n28hpcpuhdhvtb256x8m4sso_170a_tt0p9v25c.lib \
	ts1n28hpcpuhdhvtb32x256m1sso_170a_tt0p9v25c.lib \
	ts1n28hpcpuhdhvtb8x256m1sso_170a_tt0p9v25c.lib \
	ts1n28hpcpuhdhvtb64x256m1sso_170a_tt0p9v25c.lib \
	tsdn28hpcpuhdb32x128m4m_170a_tt0p9v25c.lib \
    PLLTS28HPMFRAC_TT0P9V1P8V25C.lib \
	} ;	
	

#set operating conditions
#find /lib* -operating_condition *
#ls -attribute /libraries/tcbn28hpcplusbwp7t30p140ssg0p81v125c_ecsm/operating_conditions/ssg0p81v125c
#-----------------------------------------------------------------------
# Physical libraries
#-----------------------------------------------------------------------
# LEF for standard cells and macros

set tech_lef { \
	/workspace/home/liumin/SSCNNv2/3_TSMC/tsmcn28_7t10lm5X2Y2RUTRDL.tlef \
	/materials/technology/tsmc28/TSMC_28_IP/STD_CELL/tcbn28hpcplusbwp7t30p140_190a/tcbn28hpcplusbwp7t30p140_110a_sef/digital/Back_End/lef/tcbn28hpcplusbwp7t30p140_110a/lef/tcbn28hpcplusbwp7t30p140.lef \
	/materials/technology/tsmc28/TSMC_28_IP/STD_CELL/tcbn28hpcplusbwp7t30p140hvt_190a/tcbn28hpcplusbwp7t30p140hvt_110a_sef/digital/Back_End/lef/tcbn28hpcplusbwp7t30p140hvt_110a/lef/tcbn28hpcplusbwp7t30p140hvt.lef \
	/materials/technology/tsmc28/TSMC_28_IP/STD_CELL/tcbn28hpcplusbwp7t30p140uhvt_190a/tcbn28hpcplusbwp7t30p140uhvt_140b_sef/digital/Back_End/lef/tcbn28hpcplusbwp7t30p140uhvt_140b/lef/tcbn28hpcplusbwp7t30p140uhvt.lef \
    /materials/technology/tsmc28/TSMC_28_IP/STD_IO/tphn28hpcpgv18_170d/tphn28hpcpgv18_110a_sefu10lm/digital/Back_End/lef/tphn28hpcpgv18_110a/mt_2/10lm/lef/tphn28hpcpgv18_10lm.lef\
	../../project/lib/mem/ts1n28hpcpuhdhvtb64x128m4sso_170a/LEF/ts1n28hpcpuhdhvtb64x128m4sso_170a.lef \
	../../project/lib/mem/ts1n28hpcpuhdhvtb128x256m1sso_170a/LEF/ts1n28hpcpuhdhvtb128x256m1sso_170a.lef \
	../../project/lib/mem/ts1n28hpcpuhdhvtb16x8m2sso_170a/LEF/ts1n28hpcpuhdhvtb16x8m2sso_170a.lef \
	../../project/lib/mem/ts1n28hpcpuhdhvtb256x8m4sso_170a/LEF/ts1n28hpcpuhdhvtb256x8m4sso_170a.lef \
	../../project/lib/mem/tsdn28hpcpuhdb256x10m4m_170a/LEF/tsdn28hpcpuhdb256x10m4m_170a.lef \
	../../project/lib/mem/ts1n28hpcpuhdhvtb32x256m1sso_170a/LEF/ts1n28hpcpuhdhvtb32x256m1sso_170a.lef \
	../../project/lib/mem/ts1n28hpcpuhdhvtb8x256m1sso_170a/LEF/ts1n28hpcpuhdhvtb8x256m1sso_170a.lef \
	../../project/lib/mem/ts1n28hpcpuhdhvtb64x256m1sso_170a/LEF/ts1n28hpcpuhdhvtb64x256m1sso_170a.lef \
	../../project/lib/mem/tsdn28hpcpuhdb32x128m4m_170a/LEF/tsdn28hpcpuhdb32x128m4m_170a.lef \
    ../../project/lib/PLL/lef/PLLTS28HPMFRAC.lef \
};