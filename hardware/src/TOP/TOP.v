












/ This is a simple example.
// You can make a your own header file and set its path to settings.
// (Preferences > Package Settings > Verilog Gadget > Settings - User)
//
//      "header": "Packages/Verilog Gadget/template/verilog_header.v"
//
// -----------------------------------------------------------------------------
// Copyright (c) 2014-2020 All rights reserved
// -----------------------------------------------------------------------------
// Author : zhouchch@pku.edu.cn
// File   : CCU.v
// Create : 2020-07-14 21:09:52
// Revise : 2020-08-13 10:33:19
// -----------------------------------------------------------------------------
`define CEIL(a, b) ( \
 (a % b)? (a / b + 1) : (a / b) \
)
`define PLL
module TOP #(
    // HW-Modules

    // FPS
    parameter NUM_FPC        = 4, 
    parameter NUMSRAM_RDCRD  = 1, // NUM_FPC/8
    parameter NUMSRAM_DIST   = 1, // NUM_FPC/8
    parameter NUMMASK_PROC   = 64, // Reduce BW and Combinational Area
    
    // KNN
    parameter NUM_SORT_CORE  = 8, //
    parameter KNNCRD_MAXPARA = 2, // Max Number of SRAM for CrdRd
    parameter CRD_MAXDIM     = 32,

    // ITF
    parameter PORT_WIDTH     = 128, 
    parameter DRAM_ADDR_WIDTH= 32,
    parameter ASYNC_FIFO_ADDR_WIDTH = 4, // 200MHz -> 5MHz
    parameter FBDIV_WIDTH    = 3,

    // GLB
    parameter SRAM_WIDTH     = 256, 
    parameter SRAM_WORD      = 1024/NUM_FPC/2, // P/Core/2
    parameter ADDR_WIDTH     = 16,
    parameter GLB_NUM_RDPORT = 5,
    parameter GLB_NUM_WRPORT = 6, 
    parameter NUM_BANK       = NUM_FPC/2, // 32B*Core/2

    // CCU
    parameter NUM_MODULE     = 3,
    parameter BYTE_WIDTH     = 8,
    parameter CCUISA_WIDTH   = PORT_WIDTH*1,
    parameter FPSISA_WIDTH   = PORT_WIDTH*16,
    parameter KNNISA_WIDTH   = PORT_WIDTH*2,
    parameter SYAISA_WIDTH   = PORT_WIDTH*3,
    parameter POLISA_WIDTH   = PORT_WIDTH*9,
    parameter GICISA_WIDTH   = PORT_WIDTH*2,
    parameter MONISA_WIDTH   = PORT_WIDTH*1,
    parameter MAXISA_WIDTH   = PORT_WIDTH*16,
    parameter FPSISAFIFO_ADDR_WIDTH = 1,
    parameter KNNISAFIFO_ADDR_WIDTH = 3,
    parameter SYAISAFIFO_ADDR_WIDTH = 3,
    parameter POLISAFIFO_ADDR_WIDTH = 1,
    parameter GICISAFIFO_ADDR_WIDTH = 3,
    parameter MONISAFIFO_ADDR_WIDTH = 1,

    // UNT
    parameter SHF_ADDR_WIDTH= 8,

    // Direct Output Mon
    parameter MONSEL_WIDTH   = 4,

    // NetWork Parameters
    parameter NUM_LAYER_WIDTH= 20,
    parameter CRD_WIDTH      = 8,   
    parameter CRD_DIM        = 3,  
    parameter IDX_WIDTH      = 16,
    parameter MAP_WIDTH      = 5,
    parameter ACT_WIDTH      = 8,
    parameter CHN_WIDTH      = 16,
    parameter QNTSL_WIDTH    = 16,
    parameter MASK_ADDR_WIDTH= $clog2(2**IDX_WIDTH*NUM_SORT_CORE/SRAM_WIDTH),
    parameter OPNUM          = NUM_MODULE
    )( // 5 + 6 + 128 + 20 = 159
    input                           I_BypAsysnFIFO_PAD,// Hyper
    input                           I_BypOE_PAD       , 
    input                           I_SysRst_n_PAD    , 
    input                           I_SwClk_PAD       ,
    input                           I_SysClk_PAD      , 
    input                           I_OffClk_PAD      ,

    `ifdef PLL
        input                           I_BypPLL_PAD  , 
        input [FBDIV_WIDTH      -1 : 0] I_FBDIV_PAD   ,
        output                          O_PLLLock_PAD ,
    `endif

    output                          O_DatOE_PAD       ,

    input                           I_OffOE_PAD       , // Transfer-Control
    input                           I_DatVld_PAD      ,
    input                           I_DatLast_PAD     ,
    output                          O_DatRdy_PAD      ,
    output                          O_DatVld_PAD      , 
    output                          O_DatLast_PAD     , 
    input                           I_DatRdy_PAD      , 

    input                           I_ISAVld_PAD      , // Transfer-Data
    output                          O_CmdVld_PAD      ,
    inout   [PORT_WIDTH     -1 : 0] IO_Dat_PAD        ,

    input [MONSEL_WIDTH     -1 : 0] I_MonSel_PAD      ,
    output                          O_MonDat_PAD         
);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam GLBWRIDX_GICGLB = 0; 
localparam GLBWRIDX_FPSMSK = 1; 
localparam GLBWRIDX_FPSCRD = 2; 
localparam GLBWRIDX_FPSDST = 3; 
localparam GLBWRIDX_FPSIDX = 4; 
localparam GLBWRIDX_BLKCRD = 5;

localparam GLBRDIDX_GICGLB = 0; 
localparam GLBRDIDX_FPSMSK = 1; 
localparam GLBRDIDX_FPSCRD = 2; 
localparam GLBRDIDX_FPSDST = 3; 
localparam GLBRDIDX_BLKCRD = 4;

localparam DISTSQR_WIDTH     = CRD_WIDTH*2 + $clog2(CRD_DIM);
//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================

// --------------------------------------------------------------------------------------------------------------------
// TOP
wire                            clk;
wire                            rst_n;
genvar                          gv_i;
wire [OPNUM             -1 : 0] CCUITF_CfgRdy ;
wire [4                 -1 : 0] CCUITF_MonState ;

// --------------------------------------------------------------------------------------------------------------------
// CCU 
    // Configure
wire [PORT_WIDTH              -1 : 0] ITFCCU_ISARdDat   ;             
wire                                  ITFCCU_ISARdDatVld;          
wire                                  ITFCCU_ISARdDatLast;          
wire                                  CCUITF_ISARdDatRdy;
wire                                  CCUGIC_CfgVld     ;
wire                                  GICCCU_CfgRdy     ; 

wire [NUM_FPC                 -1 : 0] CCUFPS_CfgVld ;
wire [NUM_FPC                 -1 : 0] FPSCCU_CfgRdy ;        
wire                                  CCUBLK_CfgVld ;
wire                                  BLKCCU_CfgRdy ;

wire  [GICISA_WIDTH           -1 : 0] CCUGIC_CfgInfo;
wire  [FPSISA_WIDTH           -1 : 0] CCUFPS_CfgInfo;     
wire  [KNNISA_WIDTH           -1 : 0] CCUBLK_CfgInfo;                    

// --------------------------------------------------------------------------------------------------------------------
// FPS
wire [IDX_WIDTH           -1 : 0] FPSGLB_MaskRdAddr       ;
wire                              FPSGLB_MaskRdAddrVld    ;
wire                              GLBFPS_MaskRdAddrRdy    ;
wire [SRAM_WIDTH          -1 : 0] GLBFPS_MaskRdDat        ;    
wire                              GLBFPS_MaskRdDatVld     ;    
wire                              FPSGLB_MaskRdDatRdy     ;    

wire [IDX_WIDTH           -1 : 0] FPSGLB_MaskWrAddr       ;
wire [SRAM_WIDTH          -1 : 0] FPSGLB_MaskWrDat        ;   
wire                              FPSGLB_MaskWrDatVld     ;
wire                              GLBFPS_MaskWrDatRdy     ; 

wire [IDX_WIDTH           -1 : 0] FPSGLB_CrdRdAddr        ;
wire                              FPSGLB_CrdRdAddrVld     ;
wire                              GLBFPS_CrdRdAddrRdy     ;
wire [SRAM_WIDTH*NUMSRAM_RDCRD-1 : 0] GLBFPS_CrdRdDat     ;    
wire                              GLBFPS_CrdRdDatVld      ;    
wire                              FPSGLB_CrdRdDatRdy      ;    

wire [IDX_WIDTH           -1 : 0] FPSGLB_CrdWrAddr        ;
wire [SRAM_WIDTH          -1 : 0] FPSGLB_CrdWrDat         ;   
wire                              FPSGLB_CrdWrDatVld      ;
wire                              GLBFPS_CrdWrDatRdy      ;  

wire [IDX_WIDTH           -1 : 0] FPSGLB_DistRdAddr       ;
wire                              FPSGLB_DistRdAddrVld    ;
wire                              GLBFPS_DistRdAddrRdy    ;
wire [SRAM_WIDTH*NUMSRAM_DIST-1 : 0] GLBFPS_DistRdDat        ;    
wire                              GLBFPS_DistRdDatVld     ;    
wire                              FPSGLB_DistRdDatRdy     ;    

wire [IDX_WIDTH           -1 : 0] FPSGLB_DistWrAddr       ;
wire [SRAM_WIDTH*NUMSRAM_DIST-1 : 0] FPSGLB_DistWrDat        ;   
wire                              FPSGLB_DistWrDatVld     ;
wire                              GLBFPS_DistWrDatRdy     ;

wire [IDX_WIDTH           -1 : 0] FPSGLB_IdxWrAddr        ;
wire [SRAM_WIDTH          -1 : 0] FPSGLB_IdxWrDat         ;   
wire                              FPSGLB_IdxWrDatVld      ;
wire                              GLBFPS_IdxWrDatRdy      ;
wire [2                   -1 : 0] ArbIdx_FKNCIM;

// --------------------------------------------------------------------------------------------------------------------
// BLK
wire [IDX_WIDTH           -1 : 0] BLKGLB_CrdRdAddr   ;
wire                              BLKGLB_CrdRdAddrVld;
wire                              GLBBLK_CrdRdAddrRdy;
wire [SRAM_WIDTH          -1 : 0] GLBBLK_CrdRdDat    ;    
wire                              GLBBLK_CrdRdDatVld ;    
wire                              BLKGLB_CrdRdDatRdy ;  

wire [IDX_WIDTH           -1 : 0] BLKGLB_CrdWrAddr    ;
wire [SRAM_WIDTH          -1 : 0] BLKGLB_CrdWrDat     ;   
wire                              BLKGLB_CrdWrDatVld  ;     
wire                              GLBBLK_CrdWrDatRdy  ;

// --------------------------------------------------------------------------------------------------------------------
// GIC
wire                                                GICITF_CmdVld   ;
wire [PORT_WIDTH                            -1 : 0] GICITF_Dat      ;
wire                                                GICITF_DatVld   ;
wire                                                GICITF_DatLast  ;
wire                                                ITFGIC_DatRdy   ;

wire [PORT_WIDTH                            -1 : 0] ITFGIC_Dat      ;
wire                                                ITFGIC_DatVld   ;
wire                                                ITFGIC_DatLast  ;
wire                                                GICITF_DatRdy   ;

wire [ADDR_WIDTH                            -1 : 0] GICGLB_RdAddr    ;
wire                                                GICGLB_RdAddrVld ;
wire                                                GLBGIC_RdAddrRdy ;
wire [SRAM_WIDTH                            -1 : 0] GLBGIC_RdDat     ;
wire                                                GLBGIC_RdDatVld  ;
wire                                                GICGLB_RdDatRdy  ;
wire                                                GLBGIC_RdEmpty   ;

wire [ADDR_WIDTH                            -1 : 0] GICGLB_WrAddr    ;
wire [SRAM_WIDTH                            -1 : 0] GICGLB_WrDat     ; 
wire                                                GICGLB_WrDatVld  ; 
wire                                                GLBGIC_WrDatRdy  ;
wire                                                GLBGIC_WrFull    ;

// --------------------------------------------------------------------------------------------------------------------
// GLB
// Configure
wire [(GLB_NUM_RDPORT + GLB_NUM_WRPORT) -1 : 0][NUM_BANK-1 : 0] TOPGLB_CfgPortBankFlag;
wire [(GLB_NUM_RDPORT + GLB_NUM_WRPORT)                 -1 : 0] TOPGLB_CfgPortOffEmptyFull;
// Data
wire [GLB_NUM_WRPORT    -1 : 0][SRAM_WIDTH          -1 : 0] TOPGLB_WrPortDat    ;
wire [GLB_NUM_WRPORT                                -1 : 0] TOPGLB_WrPortDatVld ;
wire [GLB_NUM_WRPORT                                -1 : 0] GLBTOP_WrPortDatRdy ;
wire [GLB_NUM_WRPORT    -1 : 0][ADDR_WIDTH          -1 : 0] TOPGLB_WrPortAddr   ;
wire [GLB_NUM_WRPORT                                -1 : 0] GLBTOP_WrFull ;

wire [GLB_NUM_RDPORT    -1 : 0][ADDR_WIDTH          -1 : 0] TOPGLB_RdPortAddr   ;
wire [GLB_NUM_RDPORT                                -1 : 0] TOPGLB_RdPortAddrVld;
wire [GLB_NUM_RDPORT                                -1 : 0] GLBTOP_RdPortAddrRdy;
wire [GLB_NUM_RDPORT    -1 : 0][SRAM_WIDTH          -1 : 0] GLBTOP_RdPortDat    ;
wire [GLB_NUM_RDPORT                                -1 : 0] GLBTOP_RdPortDatVld ;
wire [GLB_NUM_RDPORT                                -1 : 0] TOPGLB_RdPortDatRdy ;
wire [GLB_NUM_RDPORT                                -1 : 0] GLBTOP_RdEmpty      ;

//=====================================================================================================================
// Logic Design： TOP
//=====================================================================================================================

//=====================================================================================================================
// Logic Design: CCU
//=====================================================================================================================
CCU#(
    .SRAM_WIDTH              ( SRAM_WIDTH       ),
    .PORT_WIDTH              ( PORT_WIDTH       ),
    .ADDR_WIDTH              ( ADDR_WIDTH       ),
    .DRAM_ADDR_WIDTH         ( DRAM_ADDR_WIDTH  ),
    .GLB_NUM_RDPORT          ( GLB_NUM_RDPORT   ),
    .GLB_NUM_WRPORT          ( GLB_NUM_WRPORT   ),
    .IDX_WIDTH               ( IDX_WIDTH        ),
    .CHN_WIDTH               ( CHN_WIDTH        ),
    .QNTSL_WIDTH             ( QNTSL_WIDTH      ),
    .ACT_WIDTH               ( ACT_WIDTH        ),
    .MAP_WIDTH               ( MAP_WIDTH        ),
    .NUM_LAYER_WIDTH         ( NUM_LAYER_WIDTH  ),
    .NUM_MODULE              ( NUM_MODULE       ),
    .OPNUM                   ( OPNUM            ),
    .NUM_FPC                 ( NUM_FPC          ),
    .CCUISA_WIDTH            ( CCUISA_WIDTH     ),
    .FPSISA_WIDTH            ( FPSISA_WIDTH     ),
    .KNNISA_WIDTH            ( KNNISA_WIDTH     ),
    .SYAISA_WIDTH            ( SYAISA_WIDTH     ),
    .POLISA_WIDTH            ( POLISA_WIDTH     ),
    .GICISA_WIDTH            ( GICISA_WIDTH     ),
    .MAXISA_WIDTH            ( MAXISA_WIDTH     ),
    .FPSISAFIFO_ADDR_WIDTH   ( FPSISAFIFO_ADDR_WIDTH ),
    .KNNISAFIFO_ADDR_WIDTH   ( KNNISAFIFO_ADDR_WIDTH ),
    .SYAISAFIFO_ADDR_WIDTH   ( SYAISAFIFO_ADDR_WIDTH ),
    .POLISAFIFO_ADDR_WIDTH   ( POLISAFIFO_ADDR_WIDTH ),
    .GICISAFIFO_ADDR_WIDTH   ( GICISAFIFO_ADDR_WIDTH )
)u_CCU(
    .clk                     ( clk                  ),
    .rst_n                   ( rst_n                ),
    .CCUITF_CfgRdy           ( CCUITF_CfgRdy        ),
    .CCUITF_MonState         ( CCUITF_MonState      ),
    .ITFCCU_ISARdDat         ( ITFCCU_ISARdDat      ),
    .ITFCCU_ISARdDatVld      ( ITFCCU_ISARdDatVld   ),
    .ITFCCU_ISARdDatLast     ( ITFCCU_ISARdDatLast  ),
    .CCUITF_ISARdDatRdy      ( CCUITF_ISARdDatRdy   ),
    .CCUGIC_CfgVld           ( CCUGIC_CfgVld        ),
    .GICCCU_CfgRdy           ( GICCCU_CfgRdy        ),
    .CCUGIC_CfgInfo          ( CCUGIC_CfgInfo       ),
    .CCUFPS_CfgVld           ( CCUFPS_CfgVld        ),
    .FPSCCU_CfgRdy           ( FPSCCU_CfgRdy        ),
    .CCUFPS_CfgInfo          ( CCUFPS_CfgInfo       ),
    .CCUBLK_CfgVld           ( CCUBLK_CfgVld        ),
    .BLKCCU_CfgRdy           ( BLKCCU_CfgRdy        ),
    .CCUBLK_CfgInfo          ( CCUBLK_CfgInfo       )
);

//=====================================================================================================================
// Logic Design: FPS
//=====================================================================================================================

// FPS Reads Mask from GLB
assign #0.2 TOPGLB_RdPortAddr   [GLBRDIDX_FPSMSK]   = FPSGLB_MaskRdAddr;
assign #0.2 TOPGLB_RdPortAddrVld[GLBRDIDX_FPSMSK]   = FPSGLB_MaskRdAddrVld;
assign #0.2 GLBFPS_MaskRdAddrRdy                    = GLBTOP_RdPortAddrRdy[GLBRDIDX_FPSMSK];

assign #0.2 GLBFPS_MaskRdDat                        = GLBTOP_RdPortDat[GLBRDIDX_FPSMSK];
assign #0.2 GLBFPS_MaskRdDatVld                     = GLBTOP_RdPortDatVld[GLBRDIDX_FPSMSK];
assign #0.2 TOPGLB_RdPortDatRdy [GLBRDIDX_FPSMSK]   = FPSGLB_MaskRdDatRdy;

// FPS Writes Mask to GLB
assign #0.2 TOPGLB_WrPortAddr   [GLBWRIDX_FPSMSK]   = FPSGLB_MaskWrAddr;
assign #0.2 TOPGLB_WrPortDat    [GLBWRIDX_FPSMSK]   = FPSGLB_MaskWrDat;
assign #0.2 TOPGLB_WrPortDatVld [GLBWRIDX_FPSMSK]   = FPSGLB_MaskWrDatVld;
assign #0.2 GLBFPS_MaskWrDatRdy                     = GLBTOP_WrPortDatRdy[GLBWRIDX_FPSMSK];

// Read Crd
generate
    for(gv_i=0; gv_i<NUMSRAM_RDCRD; gv_i =gv_i +1) begin: GEN_FPSGLB_CrdRdPort
        assign #0.2 TOPGLB_RdPortAddr    [GLBRDIDX_FPSCRD + gv_i]    = FPSGLB_CrdRdAddr;
        assign #0.2 TOPGLB_RdPortAddrVld [GLBRDIDX_FPSCRD + gv_i]    = FPSGLB_CrdRdAddrVld;
        assign #0.2 TOPGLB_RdPortDatRdy  [GLBRDIDX_FPSCRD + gv_i]    = FPSGLB_CrdRdDatRdy;
    end
endgenerate
assign #0.2 GLBFPS_CrdRdAddrRdy                      = GLBTOP_RdPortAddrRdy[GLBRDIDX_FPSCRD]; // one of
assign #0.2 GLBFPS_CrdRdDat                          = GLBTOP_RdPortDat    [GLBRDIDX_FPSCRD +: NUMSRAM_RDCRD];
assign #0.2 GLBFPS_CrdRdDatVld                       = GLBTOP_RdPortDatVld [GLBRDIDX_FPSCRD];

// Read Dist
generate
    for(gv_i=0; gv_i<NUMSRAM_DIST; gv_i =gv_i +1) begin: GEN_FPSGLB_DistRdPort
        assign #0.2 TOPGLB_RdPortAddr    [GLBRDIDX_FPSDST + gv_i]   = FPSGLB_DistRdAddr;
        assign #0.2 TOPGLB_RdPortAddrVld [GLBRDIDX_FPSDST + gv_i]   = FPSGLB_DistRdAddrVld;
        assign #0.2 TOPGLB_RdPortDatRdy  [GLBRDIDX_FPSDST + gv_i]   = FPSGLB_DistRdDatRdy;
    end
endgenerate
assign #0.2 GLBFPS_DistRdAddrRdy = GLBTOP_RdPortAddrRdy  [GLBRDIDX_FPSDST];
assign #0.2 GLBFPS_DistRdDat     = GLBTOP_RdPortDat      [GLBRDIDX_FPSDST +: NUMSRAM_RDCRD];
assign #0.2 GLBFPS_DistRdDatVld  = GLBTOP_RdPortDatVld   [GLBRDIDX_FPSDST];

// Write Crd
assign #0.2 TOPGLB_WrPortAddr   [GLBWRIDX_FPSCRD]   = FPSGLB_CrdWrAddr  ;
assign #0.2 TOPGLB_WrPortDat    [GLBWRIDX_FPSCRD]   = FPSGLB_CrdWrDat   ;
assign #0.2 TOPGLB_WrPortDatVld [GLBWRIDX_FPSCRD]   = FPSGLB_CrdWrDatVld;
assign #0.2 GLBFPS_CrdWrDatRdy                      = GLBTOP_WrPortDatRdy[GLBWRIDX_FPSCRD];

// Write Dist
generate
    for(gv_i=0; gv_i<NUMSRAM_DIST; gv_i =gv_i +1) begin: GEN_FPSGLB_DistWrPort
        assign #0.2 TOPGLB_WrPortAddr    [GLBWRIDX_FPSDST + gv_i]    = FPSGLB_DistWrAddr;
        assign #0.2 TOPGLB_WrPortDat     [GLBWRIDX_FPSDST + gv_i]    = FPSGLB_DistWrDat[SRAM_WIDTH*gv_i +: SRAM_WIDTH];
        assign #0.2 TOPGLB_WrPortDatVld  [GLBWRIDX_FPSDST + gv_i]    = FPSGLB_DistWrDatVld;
    end
endgenerate
assign #0.2 GLBFPS_DistWrDatRdy  = GLBTOP_WrPortDatRdy[GLBWRIDX_FPSDST];

// Write Idx
assign #0.2 TOPGLB_WrPortAddr   [GLBWRIDX_FPSIDX]   = FPSGLB_IdxWrAddr  ;
assign #0.2 TOPGLB_WrPortDat    [GLBWRIDX_FPSIDX]   = FPSGLB_IdxWrDat   ;
assign #0.2 TOPGLB_WrPortDatVld [GLBWRIDX_FPSIDX]   = FPSGLB_IdxWrDatVld;
assign #0.2 GLBFPS_IdxWrDatRdy                      = GLBTOP_WrPortDatRdy[GLBWRIDX_FPSIDX];

FPS #(
    .FPSISA_WIDTH         ( FPSISA_WIDTH),
    .SRAM_WIDTH           ( SRAM_WIDTH  ),
    .IDX_WIDTH            ( IDX_WIDTH   ),
    .CRD_WIDTH            ( CRD_WIDTH   ),
    .CRD_DIM              ( CRD_DIM     ),
    .NUM_FPC              ( NUM_FPC     ),
    .NUMSRAM_RDCRD        ( NUMSRAM_RDCRD),
    .NUMSRAM_DIST         ( NUMSRAM_DIST ),
    .NUMMASK_PROC         ( NUMMASK_PROC)
)u_FPS(
    .clk                    ( clk                   ),
    .rst_n                  ( rst_n                 ),
    .CCUFPS_CfgVld          ( CCUFPS_CfgVld         ),
    .FPSCCU_CfgRdy          ( FPSCCU_CfgRdy         ),
    .CCUFPS_CfgInfo         ( CCUFPS_CfgInfo        ),
    .FPSGLB_MaskRdAddr      ( FPSGLB_MaskRdAddr     ),
    .FPSGLB_MaskRdAddrVld   ( FPSGLB_MaskRdAddrVld  ),
    .GLBFPS_MaskRdAddrRdy   ( GLBFPS_MaskRdAddrRdy  ),
    .GLBFPS_MaskRdDat       ( GLBFPS_MaskRdDat      ),
    .GLBFPS_MaskRdDatVld    ( GLBFPS_MaskRdDatVld   ),
    .FPSGLB_MaskRdDatRdy    ( FPSGLB_MaskRdDatRdy   ),
    .FPSGLB_MaskWrAddr      ( FPSGLB_MaskWrAddr     ),
    .FPSGLB_MaskWrDat       ( FPSGLB_MaskWrDat      ),
    .FPSGLB_MaskWrDatVld    ( FPSGLB_MaskWrDatVld   ),
    .GLBFPS_MaskWrDatRdy    ( GLBFPS_MaskWrDatRdy   ),
    .FPSGLB_CrdRdAddr       ( FPSGLB_CrdRdAddr      ),
    .FPSGLB_CrdRdAddrVld    ( FPSGLB_CrdRdAddrVld   ),
    .GLBFPS_CrdRdAddrRdy    ( GLBFPS_CrdRdAddrRdy   ),
    .GLBFPS_CrdRdDat        ( GLBFPS_CrdRdDat       ),
    .GLBFPS_CrdRdDatVld     ( GLBFPS_CrdRdDatVld    ),
    .FPSGLB_CrdRdDatRdy     ( FPSGLB_CrdRdDatRdy    ),
    .FPSGLB_CrdWrAddr       ( FPSGLB_CrdWrAddr      ),
    .FPSGLB_CrdWrDat        ( FPSGLB_CrdWrDat       ),
    .FPSGLB_CrdWrDatVld     ( FPSGLB_CrdWrDatVld    ),
    .GLBFPS_CrdWrDatRdy     ( GLBFPS_CrdWrDatRdy    ),
    .FPSGLB_DistRdAddr      ( FPSGLB_DistRdAddr     ),
    .FPSGLB_DistRdAddrVld   ( FPSGLB_DistRdAddrVld  ),
    .GLBFPS_DistRdAddrRdy   ( GLBFPS_DistRdAddrRdy  ),
    .GLBFPS_DistRdDat       ( GLBFPS_DistRdDat      ),
    .GLBFPS_DistRdDatVld    ( GLBFPS_DistRdDatVld   ),
    .FPSGLB_DistRdDatRdy    ( FPSGLB_DistRdDatRdy   ),
    .FPSGLB_DistWrAddr      ( FPSGLB_DistWrAddr     ),
    .FPSGLB_DistWrDat       ( FPSGLB_DistWrDat      ),
    .FPSGLB_DistWrDatVld    ( FPSGLB_DistWrDatVld   ),
    .GLBFPS_DistWrDatRdy    ( GLBFPS_DistWrDatRdy   ),
    .FPSGLB_IdxWrAddr       ( FPSGLB_IdxWrAddr      ),
    .FPSGLB_IdxWrDat        ( FPSGLB_IdxWrDat       ),
    .FPSGLB_IdxWrDatVld     ( FPSGLB_IdxWrDatVld    ),
    .GLBFPS_IdxWrDatRdy     ( GLBFPS_IdxWrDatRdy    )
);

//=====================================================================================================================
// Logic Design: KNN
//=====================================================================================================================
// Read Mask
assign #0.2 TOPGLB_RdPortAddr   [GLBRDIDX_BLKCRD]   = BLKGLB_CrdRdAddr   ;
assign #0.2 TOPGLB_RdPortAddrVld[GLBRDIDX_BLKCRD]   = BLKGLB_CrdRdAddrVld;
assign #0.2 TOPGLB_RdPortDatRdy [GLBRDIDX_BLKCRD]   = BLKGLB_CrdRdDatRdy ;
assign #0.2 GLBBLK_CrdRdAddrRdy                    = GLBTOP_RdPortAddrRdy [GLBRDIDX_BLKCRD];
assign #0.2 GLBBLK_CrdRdDat                        = GLBTOP_RdPortDat     [GLBRDIDX_BLKCRD];
assign #0.2 GLBBLK_CrdRdDatVld                     = GLBTOP_RdPortDatVld  [GLBRDIDX_BLKCRD];

// Write Map
assign #0.2 TOPGLB_WrPortAddr   [GLBWRIDX_BLKCRD]   = BLKGLB_CrdWrAddr;
assign #0.2 TOPGLB_WrPortDat    [GLBWRIDX_BLKCRD]   = BLKGLB_CrdWrDat;
assign #0.2 TOPGLB_WrPortDatVld [GLBWRIDX_BLKCRD]   = BLKGLB_CrdWrDatVld;
assign #0.2 GLBBLK_CrdWrDatRdy                      = GLBTOP_WrPortDatRdy[GLBWRIDX_BLKCRD];

SHF#(
    .DATA_WIDTH          ( ACT_WIDTH        ),
    .SRAM_WIDTH          ( SRAM_WIDTH       ),
    .ADDR_WIDTH          ( ADDR_WIDTH       ),
    .SHIFTISA_WIDTH      ( KNNISA_WIDTH     ),
    .SHF_ADDR_WIDTH      ( SHF_ADDR_WIDTH   )
)u_SHF(
    .clk                 ( clk                 ),
    .rst_n               ( rst_n               ),
    .CCUSHF_CfgVld       ( CCUBLK_CfgVld       ),
    .SHFCCU_CfgRdy       ( BLKCCU_CfgRdy       ),
    .CCUSHF_CfgInfo      ( CCUBLK_CfgInfo      ),
    .SHFGLB_InRdAddr     ( BLKGLB_CrdRdAddr    ),
    .SHFGLB_InRdAddrVld  ( BLKGLB_CrdRdAddrVld ),
    .GLBSHF_InRdAddrRdy  ( GLBBLK_CrdRdAddrRdy ),
    .GLBSHF_InRdDat      ( GLBBLK_CrdRdDat     ),
    .GLBSHF_InRdDatVld   ( GLBBLK_CrdRdDatVld  ),
    .SHFGLB_InRdDatRdy   ( BLKGLB_CrdRdDatRdy  ),
    .SHFGLB_OutWrAddr    ( BLKGLB_CrdWrAddr    ),
    .SHFGLB_OutWrDat     ( BLKGLB_CrdWrDat     ),
    .SHFGLB_OutWrDatVld  ( BLKGLB_CrdWrDatVld  ),
    .GLBSHF_OutWrDatRdy  ( GLBBLK_CrdWrDatRdy  )
);

//=====================================================================================================================
// Logic Design: GLB
//=====================================================================================================================
GLB#(
    .NUM_BANK                ( NUM_BANK         ),
    .SRAM_WIDTH              ( SRAM_WIDTH       ),
    .SRAM_WORD               ( SRAM_WORD        ),
    .ADDR_WIDTH              ( ADDR_WIDTH       ),
    .NUM_WRPORT              ( GLB_NUM_WRPORT   ),
    .NUM_RDPORT              ( GLB_NUM_RDPORT   )
)u_GLB(
    .clk                        ( clk                       ),
    .rst_n                      ( rst_n                     ),
    .TOPGLB_CfgPortBankFlag     ( TOPGLB_CfgPortBankFlag    ),
    .TOPGLB_CfgPortOffEmptyFull ( TOPGLB_CfgPortOffEmptyFull),
    .TOPGLB_WrPortDat           ( TOPGLB_WrPortDat          ),
    .TOPGLB_WrPortDatVld        ( TOPGLB_WrPortDatVld       ),
    .GLBTOP_WrPortDatRdy        ( GLBTOP_WrPortDatRdy       ),
    .TOPGLB_WrPortAddr          ( TOPGLB_WrPortAddr         ),
    .GLBTOP_WrFull              ( GLBTOP_WrFull             ),
    .TOPGLB_RdPortAddr          ( TOPGLB_RdPortAddr         ),
    .TOPGLB_RdPortAddrVld       ( TOPGLB_RdPortAddrVld      ),
    .GLBTOP_RdPortAddrRdy       ( GLBTOP_RdPortAddrRdy      ),
    .GLBTOP_RdPortDat           ( GLBTOP_RdPortDat          ),
    .GLBTOP_RdPortDatVld        ( GLBTOP_RdPortDatVld       ),
    .TOPGLB_RdPortDatRdy        ( TOPGLB_RdPortDatRdy       ),
    .GLBTOP_RdEmpty             ( GLBTOP_RdEmpty            )
);

assign #0.2 {
    TOPGLB_CfgPortOffEmptyFull[GLBWRIDX_FPSCRD                 ],
    TOPGLB_CfgPortOffEmptyFull[GLBWRIDX_FPSIDX                 ],
    TOPGLB_CfgPortOffEmptyFull[GLB_NUM_WRPORT + GLBRDIDX_FPSDST +: NUMSRAM_DIST],
    TOPGLB_CfgPortOffEmptyFull[GLBWRIDX_FPSDST                  +: NUMSRAM_DIST],
    TOPGLB_CfgPortOffEmptyFull[GLB_NUM_WRPORT + GLBRDIDX_FPSMSK],
    TOPGLB_CfgPortOffEmptyFull[GLBWRIDX_FPSMSK                 ],
    TOPGLB_CfgPortOffEmptyFull[GLB_NUM_WRPORT + GLBRDIDX_FPSCRD +: NUMSRAM_RDCRD] 
} = CCUFPS_CfgInfo[FPSISA_WIDTH -1 -: 16];
assign #0.2 {
    TOPGLB_CfgPortBankFlag    [GLBWRIDX_FPSCRD                 ],
    TOPGLB_CfgPortBankFlag    [GLBWRIDX_FPSIDX                 ],
    TOPGLB_CfgPortBankFlag    [GLB_NUM_WRPORT + GLBRDIDX_FPSDST+: NUMSRAM_DIST],
    TOPGLB_CfgPortBankFlag    [GLBWRIDX_FPSDST                 +: NUMSRAM_DIST],
    TOPGLB_CfgPortBankFlag    [GLB_NUM_WRPORT + GLBRDIDX_FPSMSK],
    TOPGLB_CfgPortBankFlag    [GLBWRIDX_FPSMSK                 ],
    TOPGLB_CfgPortBankFlag    [GLB_NUM_WRPORT + GLBRDIDX_FPSCRD+: NUMSRAM_RDCRD] 
} = CCUFPS_CfgInfo[FPSISA_WIDTH -17 -: NUM_BANK*(4 + NUMSRAM_RDCRD + NUMSRAM_DIST*2)];

assign #0.2 {
    TOPGLB_CfgPortOffEmptyFull[GLB_NUM_WRPORT + GLBRDIDX_BLKCRD],
    TOPGLB_CfgPortOffEmptyFull[GLBWRIDX_BLKCRD                 ]
} = CCUBLK_CfgInfo[KNNISA_WIDTH -1 -: 8];
assign #0.2 {
    TOPGLB_CfgPortBankFlag    [GLB_NUM_WRPORT + GLBRDIDX_BLKCRD],
    TOPGLB_CfgPortBankFlag    [GLBWRIDX_BLKCRD                 ]
} = CCUBLK_CfgInfo[KNNISA_WIDTH -9 -: NUM_BANK*2];

assign #0.2 { 
    TOPGLB_CfgPortOffEmptyFull  [GLB_NUM_WRPORT + GLBRDIDX_GICGLB   ],
    TOPGLB_CfgPortOffEmptyFull  [GLBWRIDX_GICGLB                    ]
} = CCUGIC_CfgInfo[GICISA_WIDTH -1 -: 8];
assign #0.2 {
    TOPGLB_CfgPortBankFlag      [GLB_NUM_WRPORT + GLBRDIDX_GICGLB   ],
    TOPGLB_CfgPortBankFlag      [GLBWRIDX_GICGLB                    ]
} = CCUGIC_CfgInfo[GICISA_WIDTH -9 -: NUM_BANK*2];

//=====================================================================================================================
// Logic Design: GIC
//=====================================================================================================================
// GLB RdPort
assign #0.2 TOPGLB_RdPortAddr   [GLBRDIDX_GICGLB]   = GICGLB_RdAddr;
assign #0.2 TOPGLB_RdPortAddrVld[GLBRDIDX_GICGLB]   = GICGLB_RdAddrVld;
assign #0.2 GLBGIC_RdAddrRdy                        = GLBTOP_RdPortAddrRdy  [GLBRDIDX_GICGLB];
assign #0.2 GLBGIC_RdDat                            = GLBTOP_RdPortDat      [GLBRDIDX_GICGLB];
assign #0.2 GLBGIC_RdDatVld                         = GLBTOP_RdPortDatVld   [GLBRDIDX_GICGLB];
assign #0.2 TOPGLB_RdPortDatRdy [GLBRDIDX_GICGLB]   = GICGLB_RdDatRdy;
assign #0.2 GLBGIC_RdEmpty                          = GLBTOP_RdEmpty        [GLBRDIDX_GICGLB];

// GLB WrPort
assign #0.2 TOPGLB_WrPortAddr   [GLBWRIDX_GICGLB]   = GICGLB_WrAddr;
assign #0.2 TOPGLB_WrPortDat    [GLBWRIDX_GICGLB]   = GICGLB_WrDat;
assign #0.2 TOPGLB_WrPortDatVld [GLBWRIDX_GICGLB]   = GICGLB_WrDatVld;
assign #0.2 GLBGIC_WrDatRdy                         = GLBTOP_WrPortDatRdy   [GLBWRIDX_GICGLB];
assign #0.2 GLBGIC_WrFull                           = GLBTOP_WrFull         [GLBWRIDX_GICGLB];

GIC#(
    .GICISA_WIDTH     ( GICISA_WIDTH    ),
    .PORT_WIDTH       ( PORT_WIDTH      ),
    .SRAM_WIDTH       ( SRAM_WIDTH      ),
    .ADDR_WIDTH       ( ADDR_WIDTH      ),
    .DRAM_ADDR_WIDTH  ( DRAM_ADDR_WIDTH )
)u_GIC(
    .clk                ( clk               ),
    .rst_n              ( rst_n             ),
    .CCUGIC_CfgVld      ( CCUGIC_CfgVld     ),
    .GICCCU_CfgRdy      ( GICCCU_CfgRdy     ),
    .CCUGIC_CfgInfo     ( CCUGIC_CfgInfo    ),
    .GICITF_CmdVld      ( GICITF_CmdVld     ),
    .GICITF_Dat         ( GICITF_Dat        ),
    .GICITF_DatVld      ( GICITF_DatVld     ),
    .GICITF_DatLast     ( GICITF_DatLast    ),
    .ITFGIC_DatRdy      ( ITFGIC_DatRdy     ),
    .ITFGIC_Dat         ( ITFGIC_Dat        ),
    .ITFGIC_DatVld      ( ITFGIC_DatVld     ),
    .ITFGIC_DatLast     ( ITFGIC_DatLast    ),
    .GICITF_DatRdy      ( GICITF_DatRdy     ),
    .GICGLB_RdAddr      ( GICGLB_RdAddr     ),
    .GICGLB_RdAddrVld   ( GICGLB_RdAddrVld  ),
    .GLBGIC_RdAddrRdy   ( GLBGIC_RdAddrRdy  ),
    .GLBGIC_RdDat       ( GLBGIC_RdDat      ),
    .GLBGIC_RdDatVld    ( GLBGIC_RdDatVld   ),
    .GICGLB_RdDatRdy    ( GICGLB_RdDatRdy   ),
    .GLBGIC_RdEmpty     ( GLBGIC_RdEmpty    ),
    .GICGLB_WrAddr      ( GICGLB_WrAddr     ),
    .GICGLB_WrDat       ( GICGLB_WrDat      ),
    .GICGLB_WrDatVld    ( GICGLB_WrDatVld   ),
    .GLBGIC_WrDatRdy    ( GLBGIC_WrDatRdy   ),
    .GLBGIC_WrFull      ( GLBGIC_WrFull     )
);

//=====================================================================================================================
// Logic Design: ITF
//=====================================================================================================================
ITF #(
    .PORT_WIDTH             ( PORT_WIDTH            ),
    .OPNUM                  ( OPNUM                 ),
    .ASYNC_FIFO_ADDR_WIDTH  ( ASYNC_FIFO_ADDR_WIDTH ),
    .FBDIV_WIDTH            ( FBDIV_WIDTH           ),
    .MONSEL_WIDTH           ( MONSEL_WIDTH          ) 
) u_ITF(
    .I_BypAsysnFIFO_PAD ( I_BypAsysnFIFO_PAD),
    .I_BypOE_PAD        ( I_BypOE_PAD       ),
    .I_SwClk_PAD        ( I_SwClk_PAD       ),
    .I_SysRst_n_PAD     ( I_SysRst_n_PAD    ),
    .I_SysClk_PAD       ( I_SysClk_PAD      ),
    .I_OffClk_PAD       ( I_OffClk_PAD      ),
    .O_DatOE_PAD        ( O_DatOE_PAD       ),
    .I_OffOE_PAD        ( I_OffOE_PAD       ),
    .I_DatVld_PAD       ( I_DatVld_PAD      ),
    .I_DatLast_PAD      ( I_DatLast_PAD     ),
    .O_DatRdy_PAD       ( O_DatRdy_PAD      ),
    .O_DatVld_PAD       ( O_DatVld_PAD      ),
    .O_DatLast_PAD      ( O_DatLast_PAD     ),
    .I_DatRdy_PAD       ( I_DatRdy_PAD      ),
    .I_ISAVld_PAD       ( I_ISAVld_PAD      ),
    .O_CmdVld_PAD       ( O_CmdVld_PAD      ),
    .IO_Dat_PAD         ( IO_Dat_PAD        ),
    .I_MonSel_PAD       ( I_MonSel_PAD      ),
    .O_MonDat_PAD       ( O_MonDat_PAD      ),
    `ifdef PLL
        .I_BypPLL_PAD       ( I_BypPLL_PAD      ),
        .I_FBDIV_PAD        ( I_FBDIV_PAD       ),
        .O_PLLLock_PAD      ( O_PLLLock_PAD     ),
    `endif
    .CCUITF_CfgRdy      ( CCUITF_CfgRdy     ),
    .CCUITF_MonState    ( CCUITF_MonState   ),
    .ITFCCU_ISARdDat    ( ITFCCU_ISARdDat   ),
    .ITFCCU_ISARdDatVld ( ITFCCU_ISARdDatVld),
    .ITFCCU_ISARdDatLast( ITFCCU_ISARdDatLast),
    .CCUITF_ISARdDatRdy ( CCUITF_ISARdDatRdy),
    .GICITF_Dat         ( GICITF_Dat        ),
    .GICITF_DatVld      ( GICITF_DatVld     ),
    .GICITF_DatLast     ( GICITF_DatLast    ),
    .GICITF_CmdVld      ( GICITF_CmdVld     ),
    .ITFGIC_DatRdy      ( ITFGIC_DatRdy     ),
    .ITFGIC_Dat         ( ITFGIC_Dat        ),
    .ITFGIC_DatVld      ( ITFGIC_DatVld     ),
    .ITFGIC_DatLast     ( ITFGIC_DatLast    ),
    .GICITF_DatRdy      ( GICITF_DatRdy     ),
    .MONITF_Dat         ( {PORT_WIDTH{1'b0}}),
    .MONITF_DatVld      ( 1'b0              ),
    .MONITF_DatLast     ( 1'b0              ),
    .ITFMON_DatRdy      (                   ),
    .clk                ( clk               ),
    .rst_n              ( rst_n             )
);

endmodule
