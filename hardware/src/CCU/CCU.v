// This is a simple example.
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
module CCU #(
    parameter SRAM_WIDTH            = 256,
    parameter PORT_WIDTH            = 128,
    parameter POOL_CORE             = 6,
    parameter BYTE_WIDTH            = 8,

    parameter ADDR_WIDTH            = 16,
    parameter DRAM_ADDR_WIDTH       = 32,
    parameter GLB_NUM_RDPORT        = 12,
    parameter GLB_NUM_WRPORT        = 13,
    parameter IDX_WIDTH             = 16,
    parameter CHN_WIDTH             = 16,
    parameter QNTSL_WIDTH           = 16,
    parameter ACT_WIDTH             = 8,
    parameter MAP_WIDTH             = 5,
    parameter NUM_LAYER_WIDTH       = 20,
    parameter NUM_MODULE            = 6,
    parameter NUM_FPC               = 8,
    parameter OPNUM                 = NUM_MODULE,

    parameter CCUISA_WIDTH          = PORT_WIDTH*1,
    parameter FPSISA_WIDTH          = PORT_WIDTH*16,
    parameter KNNISA_WIDTH          = PORT_WIDTH*2,
    parameter SYAISA_WIDTH          = PORT_WIDTH*3,
    parameter POLISA_WIDTH          = PORT_WIDTH*9,
    parameter GICISA_WIDTH          = PORT_WIDTH*2,
    parameter MONISA_WIDTH          = PORT_WIDTH*1,
    parameter MAXISA_WIDTH          = PORT_WIDTH*16,

    parameter FPSISAFIFO_ADDR_WIDTH = 1,
    parameter KNNISAFIFO_ADDR_WIDTH = 1,
    parameter SYAISAFIFO_ADDR_WIDTH = 1,
    parameter POLISAFIFO_ADDR_WIDTH = 1,
    parameter GICISAFIFO_ADDR_WIDTH = 1,
    parameter MONISAFIFO_ADDR_WIDTH = 1,

    parameter CCUMON_WIDTH          = 128*2
    )(
    input                                   clk                 ,
    input                                   rst_n               ,

    output [OPNUM                   -1 : 0] CCUITF_CfgRdy       ,
    output [4                       -1 : 0] CCUITF_MonState     , // {|POLCCU_CfgRdy, |FPSCCU_CfgRdy, state}
    input  [PORT_WIDTH              -1 : 0] ITFCCU_ISARdDat     ,       
    input                                   ITFCCU_ISARdDatVld  , 
    input                                   ITFCCU_ISARdDatLast ,         
    output                                  CCUITF_ISARdDatRdy  ,

    output                                  CCUGIC_CfgVld       ,
    input                                   GICCCU_CfgRdy       ,  
    output [GICISA_WIDTH            -1 : 0] CCUGIC_CfgInfo      ,
                
    output  [NUM_FPC                -1 : 0] CCUFPS_CfgVld       ,
    input   [NUM_FPC                -1 : 0] FPSCCU_CfgRdy       ,   
    output [FPSISA_WIDTH            -1 : 0] CCUFPS_CfgInfo      ,     

    output                                  CCUBLK_CfgVld       ,
    input                                   BLKCCU_CfgRdy       ,  
    output [KNNISA_WIDTH            -1 : 0] CCUBLK_CfgInfo       
);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam OPCODE_WIDTH = 8;
localparam NUMWORD_WIDTH= 8;

localparam IDLE         = 2'b00;
localparam RECV         = 2'b01; // Receive
localparam REFN         = 2'b10; // Receive Finish

localparam [OPNUM    -1 : 0][16  -1 : 0] ISA_WIDTH = {
    GICISA_WIDTH[0 +: 16], 
    KNNISA_WIDTH[0 +: 16], 
    FPSISA_WIDTH[0 +: 16]
};
localparam [OPNUM    -1 : 0][8   -1 : 0] ISAFIFO_ADDR_WIDTH = {
    GICISAFIFO_ADDR_WIDTH[0 +: 8], 
    KNNISAFIFO_ADDR_WIDTH[0 +: 8], 
    FPSISAFIFO_ADDR_WIDTH[0 +: 8]
};

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
reg   [OPCODE_WIDTH                 -1 : 0] opCode;
integer                                     int_i;
reg   [OPNUM                        -1 : 0] cfgVld; 
wire [OPNUM                         -1 : 0] cfgRdy;
reg  [OPNUM    -1 : 0][MAXISA_WIDTH -1 : 0] cfgInfo;

wire                                        FPS_CfgVld;
wire                                        POL_CfgVld;
wire  [OPNUM                        -1 : 0] SIPO_InRdy;
wire [OPNUM                         -1 : 0] SIPO_OUT_VLD;
wire [OPNUM                         -1 : 0] SIPO_OUT_RDY;

//=====================================================================================================================
// Logic Design 1: FSM
//=====================================================================================================================
reg [2      -1 : 0] state       ;
reg [2      -1 : 0] next_state  ;
always @(*) begin
    case ( state )
        IDLE:   if(ITFCCU_ISARdDatVld)
                        next_state <= RECV; //
                    else
                        next_state <= IDLE;
        RECV:   if (SIPO_OUT_VLD[opCode]) begin
                    if (SIPO_OUT_RDY[opCode])
                        next_state <= IDLE;
                    else 
                        next_state <= REFN;
                end else
                    next_state <= RECV;
        REFN:   if (SIPO_OUT_RDY[opCode])
                    next_state <= IDLE;
                else 
                    next_state <= REFN;

        default :       next_state <= IDLE;
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
// Logic Design
//=====================================================================================================================
assign CCUITF_ISARdDatRdy   = state == RECV & next_state == RECV; // SIPO Ready

assign CCUITF_CfgRdy= cfgRdy;
assign cfgRdy       = {GICCCU_CfgRdy,BLKCCU_CfgRdy, &FPSCCU_CfgRdy};

assign CCUITF_MonState = {|FPSCCU_CfgRdy, state};

assign {CCUGIC_CfgVld,CCUBLK_CfgVld, FPS_CfgVld} = cfgVld;
assign CCUFPS_CfgVld = {NUM_FPC{FPS_CfgVld}};

//=====================================================================================================================
// Logic Design: s2
//=====================================================================================================================
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        opCode <= {OPCODE_WIDTH{1'b1}};
    end else if(next_state == IDLE) begin // HS
        opCode <= {OPCODE_WIDTH{1'b1}};
    end else if(state == IDLE & next_state == RECV) begin
        opCode <= ITFCCU_ISARdDat[0 +: OPCODE_WIDTH];
    end
end

genvar gv;
generate
    for(gv=0; gv<OPNUM; gv=gv+1) begin: GEN_ISADEC
        wire [ISA_WIDTH[gv]     -1 : 0] SIPO_OUT_DAT;
        wire [ISA_WIDTH[gv]     -1 : 0] FIFO_data_out;
        wire                            FIFO_Reset;
        wire                            FIFO_push;
        wire                            FIFO_pop;
        wire                            FIFO_empty;
        wire                            FIFO_full;
        wire                            cfgEnable;

        SIPO#(
            .DATA_IN_WIDTH ( PORT_WIDTH  ),
            .DATA_OUT_WIDTH ( ISA_WIDTH[gv]  )
        )u_SIPO_ISA(
            .CLK          ( clk            ),
            .RST_N        ( rst_n          ),
            .RESET        ( state == IDLE  ),
            .IN_VLD       ( (ITFCCU_ISARdDatVld & CCUITF_ISARdDatRdy) & opCode == gv ), // Should Input & This ISA SIPO
            .IN_LAST      ( 1'b0           ),
            .IN_DAT       ( ITFCCU_ISARdDat),
            .IN_RDY       ( SIPO_InRdy[gv] ),
            .OUT_DAT      ( SIPO_OUT_DAT   ),
            .OUT_VLD      ( SIPO_OUT_VLD[gv]   ),
            .OUT_LAST     (                ),
            .OUT_RDY      ( SIPO_OUT_RDY[gv])
        );
        assign SIPO_OUT_RDY[gv] = FIFO_push;

        assign FIFO_Reset = (SIPO_OUT_DAT[OPCODE_WIDTH] & SIPO_OUT_VLD[gv]) & !FIFO_empty; // empty == 1->FIFO_Reset==0->FIFO_push=1, SIPO_OUT_RDY=1
        assign FIFO_push= !FIFO_Reset & SIPO_OUT_VLD[gv] & !FIFO_full;
        FIFO_FWFT#(
            .DATA_WIDTH ( ISA_WIDTH[gv] ),
            .ADDR_WIDTH ( ISAFIFO_ADDR_WIDTH[gv] )
        )u_FIFO_FWFT(
            .clk        ( clk            ),
            .Reset      ( FIFO_Reset     ),
            .rst_n      ( rst_n          ),
            .push       ( FIFO_push      ),
            .pop        ( FIFO_pop       ),
            .data_in    ( SIPO_OUT_DAT   ),
            .data_out   ( FIFO_data_out  ),
            .empty      ( FIFO_empty     ),
            .full       ( FIFO_full      ),
            .fifo_count (                )
        );
        
        assign FIFO_pop = cfgEnable;
        assign  cfgEnable = (FIFO_data_out[OPCODE_WIDTH] | (cfgRdy[gv] & !cfgVld[gv]) ) & !FIFO_empty; // Force reset or cfgrdy: After cfgEnable -> cfgVld&cfgRdy -> module finishes(cfgRdy=1) and not given cfgVld
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                cfgInfo[gv] <= 0;
            end else if( cfgEnable) begin
                cfgInfo[gv] <= FIFO_data_out;
            end else if( cfgRdy[gv] & !cfgVld[gv] ) begin 
                // After cfgEnable -> cfgVld&cfgRdy -> module finishes(cfgRdy=1) and not given cfgVld
                cfgInfo[gv] <= 0;
            end
        end
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                cfgVld[gv] <= 0;
            end else if( cfgVld[gv] & cfgRdy[gv] ) begin
                cfgVld[gv] <= 1'b0;
            end else if( cfgEnable ) begin
                cfgVld[gv] <= 1'b1;
            end
        end
        
    end
endgenerate

assign CCUFPS_CfgInfo = cfgInfo[0];
assign CCUBLK_CfgInfo = cfgInfo[1];
assign CCUGIC_CfgInfo = cfgInfo[2];

endmodule
