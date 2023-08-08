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
// File   : .v
// Create : 2020-07-14 21:09:52
// Revise : 2020-08-13 10:33:19
// -----------------------------------------------------------------------------
`define PLL
module ITF #(
    parameter PORT_WIDTH            = 128,
    parameter OPNUM                 = 5,
    parameter ASYNC_FIFO_ADDR_WIDTH = 4,
    parameter FBDIV_WIDTH           = 5,
    parameter MONSEL_WIDTH          = 4
    )(
        
    // PAD
    input                           I_BypAsysnFIFO_PAD,// Hyper
    input                           I_BypOE_PAD       , 
    input                           I_SysRst_n_PAD    , 
    input                           I_SwClk_PAD       ,
    input                           I_SysClk_PAD      , 
    input                           I_OffClk_PAD      ,
    // output                          O_SysClk_PAD      ,
    // output                          O_OffClk_PAD      ,
    `ifdef PLL
        input                           I_BypPLL_PAD      , 
        input [FBDIV_WIDTH      -1 : 0] I_FBDIV_PAD       ,
        output                          O_PLLLock_PAD     ,
    `endif

    // output [OPNUM           -1 : 0] O_CfgRdy_PAD      , // Monitor
    // output [8               -1 : 0] O_MonState_PAD    , // Monitor
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
    output                          O_MonDat_PAD      ,

    // CCU
    input  [OPNUM           -1 : 0] CCUITF_CfgRdy     ,
    input  [4               -1 : 0] CCUITF_MonState   ,
    output reg[PORT_WIDTH   -1 : 0] ITFCCU_ISARdDat   ,       
    output reg                      ITFCCU_ISARdDatVld,          
    output reg                      ITFCCU_ISARdDatLast,          
    input                           CCUITF_ISARdDatRdy,

    // GIC-Global Buffer Interface Controller
    input [PORT_WIDTH       -1 : 0] GICITF_Dat      ,
    input                           GICITF_DatVld   ,
    input                           GICITF_DatLast  ,
    input                           GICITF_CmdVld   ,
    output                          ITFGIC_DatRdy   ,

    output  [PORT_WIDTH     -1 : 0] ITFGIC_Dat      ,
    output                          ITFGIC_DatVld   ,
    output                          ITFGIC_DatLast  ,
    input                           GICITF_DatRdy   ,

    // Monitor
    input [PORT_WIDTH       -1 : 0] MONITF_Dat      ,
    input                           MONITF_DatVld   ,
    input                           MONITF_DatLast  ,
    output                          ITFMON_DatRdy   ,

    output                          clk             ,
    output                          rst_n            

);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam INPUT_PAD    = 1'b1;
localparam OUTPUT_PAD   = 1'b0;

localparam IDLE     = 0;
localparam IN2CHIP  = 1;
localparam OUT2OFF  = 2;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
wire                          I_BypAsysnFIFO;
wire                          I_BypOE       ;
wire                          I_SwClk       ;
wire                          I_SysRst_n    ;
wire                          I_SysClk      ;
wire                          I_OffClk      ;
wire [OPNUM           -1 : 0] O_CfgRdy      ;
wire [2+2+4           -1 : 0] O_MonState    ;
reg                           O_MonDat;
wire [MONSEL_WIDTH      -1 : 0] I_MonSel;
wire                          I_OffOE       ;
wire                          I_DatVld      ;
wire                          I_DatLast     ;
wire                          O_DatRdy      ;
wire                          O_DatVld      ;
wire                          I_DatRdy      ;
wire                          I_ISAVld      ;
wire                          O_CmdVld      ;
wire  [PORT_WIDTH     -1 : 0] I_Dat         ;
wire  [PORT_WIDTH     -1 : 0] O_Dat         ;
`ifdef PLL
    wire                          I_BypPLL      ;
    wire [FBDIV_WIDTH     -1 : 0] I_FBDIV       ;
    wire                          O_PLLLock     ;
`endif
wire                        fifo_async_IN2CHIP_push ;
wire                        fifo_async_IN2CHIP_pop  ;
wire [PORT_WIDTH + 2-1 : 0] fifo_async_IN2CHIP_din  ;
wire [PORT_WIDTH + 2-1 : 0] fifo_async_IN2CHIP_dout ;
wire                        fifo_async_IN2CHIP_empty;
wire                        fifo_async_IN2CHIP_full ;

wire                        fifo_async_OUT2OFF_push ;
wire                        fifo_async_OUT2OFF_pop  ;
wire [PORT_WIDTH + 2-1 : 0] fifo_async_OUT2OFF_din  ;
wire [PORT_WIDTH + 2-1 : 0] fifo_async_OUT2OFF_dout ;
wire                        fifo_async_OUT2OFF_empty;
wire                        fifo_async_OUT2OFF_full ;

wire                        oEPad;

genvar                      gv_i;
reg [2              -1 : 0] state_core       ;
reg [2              -1 : 0] next_state_core  ;
reg [2              -1 : 0] state_off       ;
reg [2              -1 : 0] next_state_off  ;

//=====================================================================================================================
// Logic Design: OffClk Domain
//=====================================================================================================================
// --------------------------------------------------------------------------------------------------------------------
// PAD
PDUW08DGZ_V_G inst_I_BypAsysnFIFO_PAD(.I(1'b0   ), .OEN(INPUT_PAD   ), .REN(1'b0), .PAD(I_BypAsysnFIFO_PAD  ), .C(I_BypAsysnFIFO));
PDUW08DGZ_V_G inst_I_BypOE_PAD      (.I(1'b0    ), .OEN(INPUT_PAD   ), .REN(1'b0), .PAD(I_BypOE_PAD         ), .C(I_BypOE       ));
PDUW08DGZ_V_G inst_I_SysRst_n_PAD   (.I(1'b0    ), .OEN(INPUT_PAD   ), .REN(1'b0), .PAD(I_SysRst_n_PAD      ), .C(I_SysRst_n    ));
PDUW08DGZ_V_G inst_I_SwClk_PAD      (.I(1'b0    ), .OEN(INPUT_PAD   ), .REN(1'b0), .PAD(I_SwClk_PAD         ), .C(I_SwClk       ));
PDUW08DGZ_V_G inst_I_SysClk_PAD     (.I(1'b0    ), .OEN(INPUT_PAD   ), .REN(1'b0), .PAD(I_SysClk_PAD        ), .C(I_SysClk      ));
PDUW08DGZ_V_G inst_I_OffClk_PAD     (.I(1'b0    ), .OEN(INPUT_PAD   ), .REN(1'b0), .PAD(I_OffClk_PAD        ), .C(I_OffClk      ));
PDUW08DGZ_V_G inst_I_OffOE_PAD      (.I(1'b0    ), .OEN(INPUT_PAD   ), .REN(1'b0), .PAD(I_OffOE_PAD         ), .C(I_OffOE       ));
PDUW08DGZ_V_G inst_I_DatLast_PAD    (.I(1'b0    ), .OEN(INPUT_PAD   ), .REN(1'b0), .PAD(I_DatLast_PAD       ), .C(I_DatLast     ));
PDUW08DGZ_V_G inst_I_DatVld_PAD     (.I(1'b0    ), .OEN(INPUT_PAD   ), .REN(1'b0), .PAD(I_DatVld_PAD        ), .C(I_DatVld      ));
PDUW08DGZ_V_G inst_I_DatRdy_PAD     (.I(1'b0    ), .OEN(INPUT_PAD   ), .REN(1'b0), .PAD(I_DatRdy_PAD        ), .C(I_DatRdy      ));
PDUW08DGZ_V_G inst_I_ISAVld_PAD     (.I(1'b0    ), .OEN(INPUT_PAD   ), .REN(1'b0), .PAD(I_ISAVld_PAD        ), .C(I_ISAVld      ));

// PDUW08DGZ_V_G inst_O_SysClk_PAD     (.I(clk     ), .OEN(OUTPUT_PAD  ), .REN(1'b0), .PAD(O_SysClk_PAD        ), .C(              ));
// PDUW08DGZ_V_G inst_O_OffClk_PAD     (.I(OffClk  ), .OEN(OUTPUT_PAD  ), .REN(1'b0), .PAD(O_OffClk_PAD        ), .C(              ));
PDUW08DGZ_V_G inst_O_DatOE_PAD      (.I(oEPad   ), .OEN(OUTPUT_PAD  ), .REN(1'b0), .PAD(O_DatOE_PAD         ), .C(              ));
PDUW08DGZ_V_G inst_O_DatVld_PAD     (.I(O_DatVld), .OEN(OUTPUT_PAD  ), .REN(1'b0), .PAD(O_DatVld_PAD        ), .C(              ));
PDUW08DGZ_V_G inst_O_DatLast_PAD    (.I(O_DatLast),.OEN(OUTPUT_PAD  ), .REN(1'b0), .PAD(O_DatLast_PAD       ), .C(              ));
PDUW08DGZ_V_G inst_O_DatRdy_PAD     (.I(O_DatRdy), .OEN(OUTPUT_PAD  ), .REN(1'b0), .PAD(O_DatRdy_PAD        ), .C(              ));
PDUW08DGZ_V_G inst_O_CmdVld_PAD     (.I(O_CmdVld), .OEN(OUTPUT_PAD  ), .REN(1'b0), .PAD(O_CmdVld_PAD        ), .C(              ));

// generate
//     for (gv_i = 0; gv_i < OPNUM; gv_i = gv_i + 1) begin: GEN_O_CfgRdy_PAD
//         PDUW08DGZ_V_G inst_O_CfgRdy_PAD     (.I(O_CfgRdy[gv_i]    ), .OEN(OUTPUT_PAD), .REN(1'b0),  .PAD(O_CfgRdy_PAD[gv_i]    ), .C( ));
//     end 
// endgenerate

`ifdef PLL
    PDUW08DGZ_H_G inst_I_BypPLL_PAD     (.I(1'b0    ), .OEN(INPUT_PAD   ), .REN(1'b0), .PAD(I_BypPLL_PAD        ), .C(I_BypPLL      ));
    generate
        for (gv_i = 0; gv_i < FBDIV_WIDTH; gv_i = gv_i + 1) begin: GEN_I_FBDIV_PAD
            PDUW08DGZ_H_G inst_I_FBDIV_PAD      (.I(1'b0    ), .OEN(INPUT_PAD   ), .REN(1'b0), .PAD(I_FBDIV_PAD[gv_i]         ), .C(I_FBDIV[gv_i] ));
        end 
    endgenerate
    PDUW08DGZ_H_G inst_O_PLLLock_PAD    (.I(O_PLLLock), .OEN(OUTPUT_PAD ), .REN(1'b0), .PAD(O_PLLLock_PAD       ), .C(              ));
`endif

// generate
//     for (gv_i = 0; gv_i < 8; gv_i = gv_i + 1) begin: GEN_O_MonState_PAD
//         PDUW08DGZ_H_G inst_O_MonState_PAD     (.I(O_MonState[gv_i]    ), .OEN(OUTPUT_PAD), .REN(1'b0),  .PAD(O_MonState_PAD[gv_i]    ), .C( ));
//     end 
// endgenerate

generate
    for (gv_i = 0; gv_i < 20; gv_i = gv_i + 1) begin: IO_Dat_PAD_0_19
        PDUW08DGZ_V_G inst_IO_Dat_PAD_0_19  (.I(O_Dat[gv_i]), .OEN(!oEPad), .REN(1'b0), .PAD(IO_Dat_PAD[gv_i]), .C(I_Dat[gv_i]));
    end
endgenerate

generate
    for (gv_i = 20; gv_i < 60; gv_i = gv_i + 1) begin: IO_Dat_PAD_20_59
        PDUW08DGZ_H_G inst_IO_Dat_PAD_20_59 (.I(O_Dat[gv_i]), .OEN(!oEPad), .REN(1'b0), .PAD(IO_Dat_PAD[gv_i]), .C(I_Dat[gv_i]));
    end
endgenerate

generate
    for (gv_i = 60; gv_i < 90; gv_i = gv_i + 1) begin: IO_Dat_PAD_60_89
        PDUW08DGZ_V_G inst_IO_Dat_PAD_60_89 (.I(O_Dat[gv_i]), .OEN(!oEPad), .REN(1'b0), .PAD(IO_Dat_PAD[gv_i]), .C(I_Dat[gv_i]));
    end
endgenerate

generate
    for (gv_i = 90; gv_i < 128; gv_i = gv_i + 1) begin: IO_Dat_PAD_90_127
        PDUW08DGZ_H_G inst_IO_Dat_PAD_90_127(.I(O_Dat[gv_i]), .OEN(!oEPad), .REN(1'b0), .PAD(IO_Dat_PAD[gv_i]), .C(I_Dat[gv_i]));
    end
endgenerate

generate
    for (gv_i = 0; gv_i < MONSEL_WIDTH; gv_i = gv_i + 1) begin: GEN_I_MonSel_PAD
        PDUW08DGZ_H_G inst_I_MonSel_PAD     (.I(1'b0    ), .OEN(INPUT_PAD   ), .REN(1'b0), .PAD(I_MonSel_PAD[gv_i]        ), .C(I_MonSel[gv_i]      ));
    end
endgenerate
PDUW08DGZ_H_G inst_O_MonDat_PAD     (.I(O_MonDat    ), .OEN(OUTPUT_PAD), .REN(1'b0),  .PAD(O_MonDat_PAD    ), .C( ));

 // module PDUW08DGZ_H_G (
//     input  I, 
//     input  OEN, 
//     input  REN, 
//     inout  PAD, 
//     output C
    
// );

//     // reg PAD;
//     // reg C;

//     assign PAD = OEN == 0 ? I : 1'bz;
//     assign C   = OEN == 0 ? I : PAD;

// endmodule : PDUW08DGZ_H_G   

assign oEPad       = I_BypOE? I_OffOE : O_DatVld;

// --------------------------------------------------------------------------------------------------------------------
// Clk Generation
CLK#(
    .FBDIV_WIDTH ( FBDIV_WIDTH )
) u_CLK(
    .I_BypAsysnFIFO(I_BypAsysnFIFO),
    .I_SwClk     ( I_SwClk      ),
    .I_SysRst_n  ( I_SysRst_n   ),
    .I_SysClk    ( I_SysClk     ),
    .I_OffClk    ( I_OffClk     ),
    `ifdef PLL
        .I_BypPLL    ( I_BypPLL     ),
        .I_FBDIV     ( I_FBDIV      ),
        .O_PLLLock   ( O_PLLLock    ),
    `endif 
    .SysRst_n    ( rst_n        ),
    .SysClk      ( clk          ),
    .OffClk      ( OffClk       ) 
);
// --------------------------------------------------------------------------------------------------------------------
// FSM
always @(*) begin
    case ( state_off )
        IDLE:   if ( I_DatVld )
                    next_state_off <= IN2CHIP;
                else if ( I_BypAsysnFIFO? (GICITF_DatVld | MONITF_DatVld) : !fifo_async_OUT2OFF_empty )
                    next_state_off <= OUT2OFF;
                else
                    next_state_off <= IDLE;

        IN2CHIP:if( I_DatLast & (I_DatVld & O_DatRdy) )
                    next_state_off <= IDLE;
                else
                    next_state_off <= IN2CHIP;

        OUT2OFF:if( O_DatLast & (O_DatVld & I_DatRdy) )
                    next_state_off <= IDLE;
                else
                    next_state_off <= OUT2OFF;

        default:    next_state_off <= IDLE;
    endcase
end
always @ ( posedge OffClk or negedge rst_n ) begin
    if ( !rst_n ) begin
        state_off <= IDLE;
    end else begin
        state_off <= next_state_off;
    end
end

// --------------------------------------------------------------------------------------------------------------------
// IN2CHIP
assign O_DatRdy = 
    state_off == IN2CHIP? 
        (I_BypAsysnFIFO? 
            (I_ISAVld? 
                CCUITF_ISARdDatRdy 
                : GICITF_DatRdy
            ) 
            : !fifo_async_IN2CHIP_full 
        )
        : 1'b0;
assign fifo_async_IN2CHIP_push  = !I_BypAsysnFIFO & I_DatVld & O_DatRdy;
assign fifo_async_IN2CHIP_din   = fifo_async_IN2CHIP_push? {I_Dat, I_ISAVld, I_DatLast} : 0;

// --------------------------------------------------------------------------------------------------------------------
// OUT2OFF
assign {O_Dat, O_CmdVld, O_DatLast, O_DatVld}= 
    state_off == OUT2OFF? 
        (I_BypAsysnFIFO? 
            (MONITF_DatVld? 
                {MONITF_Dat, 1'b0, MONITF_DatLast, MONITF_DatVld} 
                :GICITF_DatVld? 
                    {GICITF_Dat, GICITF_CmdVld, GICITF_DatLast, GICITF_DatVld} 
                    : 0
            )
            :{fifo_async_OUT2OFF_dout, !fifo_async_OUT2OFF_empty} 
        ) 
        :{ {PORT_WIDTH{1'b0}}, 1'b0, 1'b0, 1'b0};
assign fifo_async_OUT2OFF_pop   = !I_BypAsysnFIFO & I_DatRdy & O_DatVld;

//=====================================================================================================================
// Logic Design: CoreClk Domain
//=====================================================================================================================
// --------------------------------------------------------------------------------------------------------------------
// FSM
always @(*) begin
    case ( state_core )
        IDLE:   if ( I_BypAsysnFIFO? I_DatVld : !fifo_async_IN2CHIP_empty )
                    next_state_core <= IN2CHIP;
                else if ( GICITF_DatVld | MONITF_DatVld )
                    next_state_core <= OUT2OFF;
                else
                    next_state_core <= IDLE;

        IN2CHIP:if( (ITFGIC_DatLast & (ITFGIC_DatVld & GICITF_DatRdy)) | (ITFCCU_ISARdDatLast & (ITFCCU_ISARdDatVld & CCUITF_ISARdDatRdy)) )
                    next_state_core <= IDLE;
                else
                    next_state_core <= IN2CHIP;

        OUT2OFF:if( (GICITF_DatLast & (GICITF_DatVld & ITFGIC_DatRdy)) | (MONITF_DatLast & (MONITF_DatVld & ITFMON_DatRdy)) )
                    next_state_core <= IDLE;
                else
                    next_state_core <= OUT2OFF;

        default:    next_state_core <= IDLE;
    endcase
end
always @ ( posedge clk or negedge rst_n ) begin
    if ( !rst_n ) begin
        state_core <= IDLE;
    end else begin
        state_core <= next_state_core;
    end
end

// --------------------------------------------------------------------------------------------------------------------
// Async
DELAY#(
    .NUM_STAGES ( 1     ),
    .DATA_WIDTH ( OPNUM )
)u_DELAY_O_CfgRdy(
    .CLK        ( clk           ),
    .RST_N      ( rst_n         ),
    .DIN        ( CCUITF_CfgRdy ),
    .DOUT       ( O_CfgRdy      )
);
DELAY#(
    .NUM_STAGES ( 1     ),
    .DATA_WIDTH ( 2 + 2 + 4 )
)u_DELAY_O_MonState(
    .CLK        ( clk           ),
    .RST_N      ( rst_n         ),
    .DIN        ( {state_off[0 +: 2], state_core[0 +: 2], CCUITF_MonState}),
    .DOUT       ( O_MonState    )
);
always@(*) begin
    case(I_MonSel)
        4'd0 : O_MonDat = O_CfgRdy  [0];
        4'd1 : O_MonDat = O_CfgRdy  [1];
        4'd2 : O_MonDat = O_CfgRdy  [2];
        // 4'd3 : O_MonDat = O_CfgRdy  [3];
        // 4'd4 : O_MonDat = O_CfgRdy  [4];
        // 4'd5 : O_MonDat = O_CfgRdy  [5];
        4'd6 : O_MonDat = O_MonState[0];
        4'd7 : O_MonDat = O_MonState[1];
        4'd8 : O_MonDat = O_MonState[2];
        4'd9 : O_MonDat = O_MonState[3];
        4'd10: O_MonDat = O_MonState[4];
        4'd11: O_MonDat = O_MonState[5];
        4'd12: O_MonDat = O_MonState[6];
        4'd13: O_MonDat = O_MonState[7];
        4'd14: O_MonDat = OffClk;
        4'd15: O_MonDat = clk;

        default: O_MonDat = clk;
    endcase
end

// --------------------------------------------------------------------------------------------------------------------
// IN2CHIP
// GIC
assign fifo_async_IN2CHIP_pop   = state_core == IN2CHIP & !I_BypAsysnFIFO & !fifo_async_IN2CHIP_empty  
                                        & (ITFCCU_ISARdDatVld & CCUITF_ISARdDatRdy | ITFGIC_DatVld & GICITF_DatRdy );

assign {ITFGIC_Dat, ITFGIC_DatVld, ITFGIC_DatLast} = 
    state_core == IN2CHIP? 
        (I_BypAsysnFIFO? 
            (I_ISAVld?
                0
                :{I_Dat, I_DatVld, I_DatLast}
            )
            :(fifo_async_IN2CHIP_dout[1]?
                0
                :{fifo_async_IN2CHIP_dout[2 +: PORT_WIDTH], !fifo_async_IN2CHIP_empty, fifo_async_IN2CHIP_dout[0]}
            ) 
        ) 
        : 0;

// CCU
always@(*) begin
    if(state_core == IN2CHIP) begin
        if(I_BypAsysnFIFO) begin
            if(I_ISAVld)
                {ITFCCU_ISARdDat, ITFCCU_ISARdDatVld, ITFCCU_ISARdDatLast} <= {I_Dat, I_DatVld, I_DatLast};
            else
                {ITFCCU_ISARdDat, ITFCCU_ISARdDatVld, ITFCCU_ISARdDatLast} <= 0;
        end else begin
            if(fifo_async_IN2CHIP_dout[1])
                {ITFCCU_ISARdDat, ITFCCU_ISARdDatVld, ITFCCU_ISARdDatLast} <= {fifo_async_IN2CHIP_dout[2 +: PORT_WIDTH], !fifo_async_IN2CHIP_empty, fifo_async_IN2CHIP_dout[0]};
            else
                {ITFCCU_ISARdDat, ITFCCU_ISARdDatVld, ITFCCU_ISARdDatLast} <= 0;
        end
    end else
        {ITFCCU_ISARdDat, ITFCCU_ISARdDatVld, ITFCCU_ISARdDatLast} <= 0;
end

// --------------------------------------------------------------------------------------------------------------------
// OUT2OFF
// GIC
assign ITFGIC_DatRdy           = state_core == OUT2OFF? (I_BypAsysnFIFO? I_DatRdy : !fifo_async_OUT2OFF_full) : 1'b0;

// MON
assign ITFMON_DatRdy           = state_core == OUT2OFF? (I_BypAsysnFIFO? I_DatRdy : !fifo_async_OUT2OFF_full) : 1'b0;

assign fifo_async_OUT2OFF_push = !I_BypAsysnFIFO & (GICITF_DatVld & ITFGIC_DatRdy | MONITF_DatVld & ITFMON_DatRdy);
assign fifo_async_OUT2OFF_din  = fifo_async_OUT2OFF_push? 
                                    (MONITF_DatVld? 
                                        {MONITF_Dat, 1'b0, MONITF_DatLast} 
                                        : GICITF_DatVld? 
                                            {GICITF_Dat, GICITF_CmdVld, GICITF_DatLast} 
                                            : 0
                                    )
                                    : 0;

//=====================================================================================================================
// Sub-Module : ASync FIFOs
//=====================================================================================================================
// --------------------------------------------------------------------------------------------------------------------
// IN2CHIP
fifo_async_fwft#(
    .DATA_WIDTH ( PORT_WIDTH + 2           ),
    .ADDR_WIDTH ( ASYNC_FIFO_ADDR_WIDTH )
)u_fifo_async_fwft_IN2CHIP(
    .rst_n      ( rst_n                     ),
    .wr_clk     ( OffClk                    ),
    .rd_clk     ( clk                       ),
    .push       ( fifo_async_IN2CHIP_push   ),
    .pop        ( fifo_async_IN2CHIP_pop    ),
    .data_in    ( fifo_async_IN2CHIP_din    ),
    .data_out   ( fifo_async_IN2CHIP_dout   ),
    .empty      ( fifo_async_IN2CHIP_empty  ),
    .full       ( fifo_async_IN2CHIP_full   ) 
);

// --------------------------------------------------------------------------------------------------------------------
// OUT2OFF
fifo_async_fwft#(
    .DATA_WIDTH ( PORT_WIDTH + 2        ),
    .ADDR_WIDTH ( ASYNC_FIFO_ADDR_WIDTH )
)u_fifo_async_fwft_OUT2OFF(
    .rst_n      ( rst_n                     ),
    .wr_clk     ( clk                       ),
    .rd_clk     ( OffClk                    ),
    .push       ( fifo_async_OUT2OFF_push   ),
    .pop        ( fifo_async_OUT2OFF_pop    ),
    .data_in    ( fifo_async_OUT2OFF_din    ),
    .data_out   ( fifo_async_OUT2OFF_dout   ),
    .empty      ( fifo_async_OUT2OFF_empty  ),
    .full       ( fifo_async_OUT2OFF_full   ) 
);

endmodule
