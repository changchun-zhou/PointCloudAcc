// This is a simpleCCUGIC_InOut example.
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
module GIC #(
    parameter GICISA_WIDTH      = 128*2,
    parameter PORT_WIDTH        = 128,
    parameter SRAM_WIDTH        = 256,
    parameter DRAM_ADDR_WIDTH   = 32,
    parameter ADDR_WIDTH        = 16,
    parameter BYTE_WIDTH        = 8,
    parameter GICMON_WIDTH      = GICISA_WIDTH + 3
    )(
    input                                               clk             ,
    input                                               rst_n           ,

    input                                               CCUGIC_CfgVld      ,
    output                                              GICCCU_CfgRdy      ,  
    input   [GICISA_WIDTH                       -1 : 0] CCUGIC_CfgInfo      ,

    output reg                                          GICITF_CmdVld   ,
    output [PORT_WIDTH                          -1 : 0] GICITF_Dat      ,
    output                                              GICITF_DatVld   ,
    output                                              GICITF_DatLast  ,
    input                                               ITFGIC_DatRdy   ,

    input  [PORT_WIDTH                          -1 : 0] ITFGIC_Dat      ,
    input                                               ITFGIC_DatVld   ,
    input                                               ITFGIC_DatLast   ,
    output                                              GICITF_DatRdy   ,

    output [ADDR_WIDTH                          -1 : 0] GICGLB_RdAddr    ,
    output                                              GICGLB_RdAddrVld ,
    input                                               GLBGIC_RdAddrRdy ,
    input  [SRAM_WIDTH                          -1 : 0] GLBGIC_RdDat     ,
    input                                               GLBGIC_RdDatVld  ,
    output                                              GICGLB_RdDatRdy  ,
    input                                               GLBGIC_RdEmpty   ,

    output [ADDR_WIDTH                          -1 : 0] GICGLB_WrAddr    ,
    output [SRAM_WIDTH                          -1 : 0] GICGLB_WrDat     , 
    output                                              GICGLB_WrDatVld  , 
    input                                               GLBGIC_WrDatRdy  ,
    input                                               GLBGIC_WrFull        

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam IDLE     = 3'b000;
localparam CMD      = 3'b001;
localparam IN2CHIP  = 3'b010;
localparam OUT2OFF  = 3'b011;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
reg  [PORT_WIDTH            -1 : 0] Cmd;
wire                                Out2Off;
wire [ADDR_WIDTH +1         -1 : 0] CntGLBAddr;
wire [BYTE_WIDTH            -1 : 0] CCUGIC_CfgInOut       ; // 0: IN2CHIP; 1: OUT2OFF
wire [DRAM_ADDR_WIDTH       -1 : 0] CCUGIC_CfgDRAMBaseAddr;
wire [ADDR_WIDTH            -1 : 0] CCUGIC_CfgGLBBaseAddr ;
wire [ADDR_WIDTH            -1 : 0] CCUGIC_CfgNum         ; 
wire                                CCUGIC_CfgStop;

wire                        SIPO_DatInRdy;
wire [SRAM_WIDTH    -1 : 0] SIPO_DatOut;
wire                        SIPO_DatOutVld;
wire                        SIPO_DatOutLast;
wire                        SIPO_DatOutRdy;
wire                        PISO_DatInLast;
wire                        PISO_DatInRdy;
wire [PORT_WIDTH    -1 : 0] PISO_DatOut;
wire                        PISO_DatOutVld;
wire                        PISO_DatOutLast;

wire                            fwft_push; 
wire                            fwft_pop;  
wire [SRAM_WIDTH + 1    -1 : 0] fwft_din;  
wire [SRAM_WIDTH + 1    -1 : 0] fwft_dout; 
wire                            fwft_empty;
wire                            fwft_full; 
wire                            fwft_dout_last; 

//=====================================================================================================================
// Logic Design: ISA Decode
//=====================================================================================================================
assign {
    CCUGIC_CfgGLBBaseAddr   , // 16
    CCUGIC_CfgDRAMBaseAddr  , // 32
    CCUGIC_CfgNum           , // 16
    CCUGIC_CfgInOut           // 8 0: IN2CHIP; 1: OUT2OFF
} = CCUGIC_CfgInfo[GICISA_WIDTH -1 : 16];
assign CCUGIC_CfgStop = CCUGIC_CfgInfo[9]; //[8]==1: Rst, [9]==1: Stop
//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================
reg [ 3     -1 : 0] state       ;
reg [ 3     -1 : 0] next_state  ;
always @(*) begin
    case ( state )
        IDLE:   if( (CCUGIC_CfgVld & !CCUGIC_CfgStop) & GICCCU_CfgRdy ) // Start
                    next_state <= CMD;
                else
                    next_state <= IDLE;
        CMD :   if(CCUGIC_CfgVld)
                    next_state <= IDLE;
                else if( ITFGIC_DatRdy) begin
                    if ( CCUGIC_CfgInOut[0] )
                        next_state <= OUT2OFF;
                    else
                        next_state <= IN2CHIP;
                end else
                    next_state <= CMD;
        IN2CHIP:if(CCUGIC_CfgVld)
                    next_state <= IDLE;
                else if( fwft_dout_last & (GICGLB_WrDatVld & GLBGIC_WrDatRdy) ) // End
                    next_state <= IDLE;
                else
                    next_state <= IN2CHIP;
        OUT2OFF:if(CCUGIC_CfgVld)
                    next_state <= IDLE;
                else if( GICITF_DatLast & (GICITF_DatVld & ITFGIC_DatRdy) ) // fetched by Off-chip
                    next_state <= IDLE;
                else
                    next_state <= OUT2OFF;
        default:    next_state <= IDLE;
    endcase
end
always @ ( posedge clk or negedge rst_n ) begin
    if ( !rst_n ) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

//=====================================================================================================================
// Logic Design:
//=====================================================================================================================
assign GICCCU_CfgRdy = state == IDLE;
// Reg Update
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        Cmd <= {PORT_WIDTH{1'b0}};
    end else if ( next_state == IDLE )begin 
        Cmd <= {PORT_WIDTH{1'b0}};
    end else if(state == IDLE && next_state == CMD) begin
        Cmd <= {CCUGIC_CfgNum, CCUGIC_CfgDRAMBaseAddr, CCUGIC_CfgInOut[0]};
    end
end

assign GICITF_CmdVld = state == CMD;

//=====================================================================================================================
// Logic Design: // Input to on-chip
//=====================================================================================================================
// Combinational Logic
assign GICITF_DatRdy = state == IN2CHIP & SIPO_DatInRdy;
SIPO#(
    .DATA_IN_WIDTH ( PORT_WIDTH     ),
    .DATA_OUT_WIDTH ( SRAM_WIDTH    )
)u_SIPO_IN2CHIP(
    .CLK          ( clk            ),
    .RST_N        ( rst_n          ),
    .RESET        ( state == IDLE  ),
    .IN_VLD       ( ITFGIC_DatVld & state == IN2CHIP ),
    .IN_LAST      ( ITFGIC_DatLast ),
    .IN_DAT       ( ITFGIC_Dat     ),
    .IN_RDY       ( SIPO_DatInRdy  ),
    .OUT_DAT      ( SIPO_DatOut    ),
    .OUT_VLD      ( SIPO_DatOutVld ),
    .OUT_LAST     ( SIPO_DatOutLast),
    .OUT_RDY      ( SIPO_DatOutRdy )
);

FIFO_FWFT#(
    .DATA_WIDTH ( SRAM_WIDTH + 1),
    .ADDR_WIDTH ( 1 )
)u_FIFO_FWFT_GIC2GLB(
    .clk        ( clk           ),
    .Reset      ( state == IDLE ),
    .rst_n      ( rst_n         ),
    .push       ( fwft_push     ),
    .pop        ( fwft_pop      ),
    .data_in    ( fwft_din      ),
    .data_out   ( fwft_dout     ),
    .empty      ( fwft_empty    ),
    .full       ( fwft_full     ),
    .fifo_count (               )
);

assign fwft_push        = !fwft_full & SIPO_DatOutVld;
assign SIPO_DatOutRdy   = !fwft_full;
assign fwft_din         = {SIPO_DatOut, SIPO_DatOutLast};

assign GICGLB_WrDatVld  = state == IN2CHIP? !fwft_empty : 0;
assign fwft_pop         = state == IN2CHIP? GLBGIC_WrDatRdy & GICGLB_WrDatVld : 0;
assign GICGLB_WrDat     = state == IN2CHIP? fwft_dout[1 +: SRAM_WIDTH] : 0;
assign GICGLB_WrAddr    = CntGLBAddr;

assign fwft_dout_last   = state == IN2CHIP? fwft_dout[0] : 0;

//=====================================================================================================================
// Logic Design: Out to off-chip
//=====================================================================================================================
assign GICGLB_RdAddr    = CntGLBAddr; 
assign GICGLB_RdAddrVld = state == OUT2OFF & CntGLBAddr < CCUGIC_CfgNum;
assign GICGLB_RdDatRdy  = state == OUT2OFF & PISO_DatInRdy;

assign PISO_DatInLast   = CntGLBAddr == CCUGIC_CfgNum; // Last Data follows Last Addr + 1

PISO_NOCACHE #(
    .DATA_IN_WIDTH ( SRAM_WIDTH ),
    .DATA_OUT_WIDTH ( PORT_WIDTH )
)u_PISO_OUT2OFF(
    .CLK          ( clk         ),
    .RST_N        ( rst_n       ),
    .RESET        ( state == IDLE  ),
    .IN_VLD       ( state == OUT2OFF & GLBGIC_RdDatVld),
    .IN_LAST      ( PISO_DatInLast),
    .IN_DAT       ( GLBGIC_RdDat  ),
    .IN_RDY       ( PISO_DatInRdy ),
    .OUT_DAT      ( PISO_DatOut   ), // On-chip output to Off-chip 
    .OUT_VLD      ( PISO_DatOutVld),
    .OUT_LAST     ( PISO_DatOutLast),
    .OUT_RDY      ( ITFGIC_DatRdy )
);

assign GICITF_Dat       = state==CMD? Cmd   : state==OUT2OFF?   PISO_DatOut    : 0;
assign GICITF_DatVld    = state==CMD? 1'b1  : state==OUT2OFF?   PISO_DatOutVld : 0;
assign GICITF_DatLast   = state==CMD? 1'b1  : state==OUT2OFF?   PISO_DatOutLast: 0;

//=====================================================================================================================
// Logic Design: GLB Address Genration
//=====================================================================================================================
wire [ADDR_WIDTH + 1    -1 : 0] MaxCnt= 2**(ADDR_WIDTH + 1)- 1;
counter#(
    .COUNT_WIDTH ( ADDR_WIDTH + 1)
)u_counter_CntGLBAddr(
    .CLK       ( clk            ),
    .RESET_N   ( rst_n          ),
    .CLEAR     ( state == IDLE  ),
    .DEFAULT   ( {1'b0, CCUGIC_CfgGLBBaseAddr}),
    .INC       ( (GICGLB_WrDatVld & GLBGIC_WrDatRdy) | GICGLB_RdAddrVld & GLBGIC_RdAddrRdy),
    .DEC       ( 1'b0           ),
    .MIN_COUNT ( {ADDR_WIDTH + 1{1'b0}}),
    .MAX_COUNT ( MaxCnt         ),
    .OVERFLOW  (                ),
    .UNDERFLOW (                ),
    .COUNT     ( CntGLBAddr     )
);

//=====================================================================================================================
// Debug
//=====================================================================================================================
wire Debug_IO_Uti;
assign Debug_IO_Uti = (GICITF_DatVld & ITFGIC_DatRdy) | (ITFGIC_DatVld & GICITF_DatRdy);


endmodule
