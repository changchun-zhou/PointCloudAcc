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
module GLB #(
    parameter NUM_BANK     = 32,
    parameter SRAM_WIDTH   = 256,
    parameter SRAM_WORD    = 128, // MUST 2**
    parameter ADDR_WIDTH   = 16,

    parameter NUM_WRPORT   = 3,
    parameter NUM_RDPORT   = 4,
    parameter MAXPAR       = 32,
    
    parameter CLOCK_PERIOD = 10

    )(
    input                                               clk                 ,
    input                                               rst_n               ,

    // Configure
    input [NUM_BANK * (NUM_RDPORT + NUM_WRPORT) -1 : 0] TOPGLB_CfgPortBankFlag,
    input [($clog2(MAXPAR) + 1)*(NUM_RDPORT + NUM_WRPORT)-1 : 0] TOPGLB_CfgPortParBank,

    // Data
    input  wire [SRAM_WIDTH*MAXPAR*NUM_WRPORT   -1 : 0] TOPGLB_WrPortDat    ,
    input  wire [NUM_WRPORT                     -1 : 0] TOPGLB_WrPortDatVld ,
    output wire [NUM_WRPORT                     -1 : 0] GLBTOP_WrPortDatRdy ,
    input  wire [ADDR_WIDTH*NUM_WRPORT          -1 : 0] TOPGLB_WrPortAddr   ,
    output      [NUM_WRPORT                     -1 : 0] GLBTOP_WrFull ,

    input  wire [ADDR_WIDTH*NUM_RDPORT          -1 : 0] TOPGLB_RdPortAddr   ,
    input  wire [NUM_RDPORT                     -1 : 0] TOPGLB_RdPortAddrVld,
    output wire [NUM_RDPORT                     -1 : 0] GLBTOP_RdPortAddrRdy,
    output wire [SRAM_WIDTH*MAXPAR*NUM_RDPORT   -1 : 0] GLBTOP_RdPortDat    ,
    output wire [NUM_RDPORT                     -1 : 0] GLBTOP_RdPortDatVld ,
    input  wire [NUM_RDPORT                     -1 : 0] TOPGLB_RdPortDatRdy ,
    output      [NUM_RDPORT                     -1 : 0] GLBTOP_RdEmpty 
);

//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam SRAM_DEPTH_WIDTH = $clog2(SRAM_WORD);

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
wire [ADDR_WIDTH                -1 : 0] WrPortAddr_Array[0 : NUM_WRPORT -1];
wire [SRAM_WIDTH*MAXPAR         -1 : 0] WrPortDat_Array [0 : NUM_WRPORT -1];
wire [NUM_BANK                  -1 : 0] WrPortBankEn  [0 : NUM_WRPORT   -1];
wire [NUM_WRPORT                -1 : 0] WrPortEn;

wire [ADDR_WIDTH                -1 : 0] RdPortAddr_Array[0 : NUM_RDPORT -1];
reg  [SRAM_WIDTH*MAXPAR         -1 : 0] RdPortDat_Array [0 : NUM_RDPORT -1];
wire [NUM_BANK                  -1 : 0] RdPortBankEn  [0 : NUM_RDPORT   -1];
wire [NUM_RDPORT                -1 : 0] RdPortEn;

wire [NUM_BANK                  -1 : 0] Bank_rvalid;
wire [NUM_BANK                  -1 : 0] Bank_arready;
wire [NUM_BANK                  -1 : 0] Bank_wready;
wire [SRAM_WIDTH                -1 : 0] Bank_rdata_array[0 : NUM_BANK     -1];
wire [$clog2(NUM_WRPORT)        -1 : 0] BankWrPortIdx [0 : NUM_BANK     -1];
wire [$clog2(NUM_RDPORT)        -1 : 0] BankRdPortIdx [0 : NUM_BANK     -1];
wire [(NUM_WRPORT+NUM_RDPORT)   -1 : 0] BankPortFlag  [0 : NUM_BANK     -1];
wire [ADDR_WIDTH                -1 : 0] BankWrAddr_Array[0 : NUM_BANK   -1];
wire [ADDR_WIDTH                -1 : 0] BankRdAddr_Array[0 : NUM_BANK   -1];
wire [NUM_BANK                  -1 : 0] BankRdEn;

genvar      gv_i;
genvar      gv_j;
integer     int_i;

//=====================================================================================================================
// Logic Design
//=====================================================================================================================


generate
    for(gv_i=0; gv_i<NUM_BANK; gv_i=gv_i+1) begin: GEN_BANK

        wire                            wvalid;
        wire                            wready;
        wire                            arvalid;
        wire                            arready;
        wire                            rvalid;
        wire                            rready;
        wire [SRAM_DEPTH_WIDTH  -1 : 0] waddr;
        wire [SRAM_DEPTH_WIDTH  -1 : 0] araddr;
        wire [SRAM_WIDTH        -1 : 0] wdata;
        wire [SRAM_WIDTH        -1 : 0] rdata;
        reg  [$clog2(NUM_BANK)  -1 : 0] BankWrPortParIdx;
        reg  [ADDR_WIDTH        -1 : 0] BankRdAddr_d;
        reg  [ADDR_WIDTH        -1 : 0] BankWrAddr_d;

        RAM_HS#(
            .SRAM_BIT     ( SRAM_WIDTH  ),
            .SRAM_BYTE    ( 1           ),
            .SRAM_WORD    ( SRAM_WORD   ),
            .CLOCK_PERIOD ( CLOCK_PERIOD)
        )u_RAM_HS(
            .clk          ( clk          ),
            .rst_n        ( rst_n        ),
            .wvalid       ( wvalid       ),
            .wready       ( wready       ),
            .waddr        ( waddr        ),
            .wdata        ( wdata        ),
            .arvalid      ( arvalid      ),
            .arready      ( arready      ),
            .araddr       ( araddr       ),
            .rvalid       ( rvalid       ),
            .rready       ( rready       ),
            .rdata        ( rdata        )
        );
        //=====================================================================================================================
        // Logic Design: Write
        //=====================================================================================================================
        assign wvalid = WrPortBankEn[BankWrPortIdx[gv_i]][gv_i];
        assign waddr   = WrPortAddr_Array[BankWrPortIdx[gv_i]]; // Cut MSB
        assign Bank_wready[gv_i] = wready;

        always @(*) begin
            BankWrPortParIdx = 0;
            for(int_i=0; int_i<NUM_BANK; int_i=int_i+1) begin
                if(int_i < gv_i)
                    BankWrPortParIdx = BankWrPortParIdx + WrPortBankEn[BankWrPortIdx[gv_i]][int_i];
            end
        end
        assign wdata = WrPortDat_Array[BankWrPortIdx[gv_i]][SRAM_WIDTH*BankWrPortParIdx +: SRAM_WIDTH];

        assign BankWrAddr_Array[gv_i] = wvalid? WrPortAddr_Array[BankWrPortIdx[gv_i]] : BankWrAddr_d;
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n)
                BankWrAddr_d <= 0;
            else if (wvalid & wready ) // Handshake
                BankWrAddr_d <= WrPortAddr_Array[BankWrPortIdx[gv_i]];
        end

        //=====================================================================================================================
        // Logic Design: Read
        //=====================================================================================================================
        // Bank
        assign arvalid  = RdPortBankEn[BankRdPortIdx[gv_i]][gv_i];    
        assign araddr   = RdPortAddr_Array[BankRdPortIdx[gv_i]]; 
        assign Bank_arready[gv_i]  = arready;

        assign rready = TOPGLB_RdPortDatRdy[BankRdPortIdx[gv_i]];
        assign Bank_rvalid[gv_i]  = rvalid;
        assign Bank_rdata_array[gv_i]   = rdata;

        // Output
        assign BankRdAddr_Array[gv_i] = arvalid? RdPortAddr_Array[BankRdPortIdx[gv_i]] : BankRdAddr_d;
        assign BankRdEn[gv_i] =  arvalid & arready;

        always @(posedge clk or negedge rst_n) begin
            if(!rst_n)
                BankRdAddr_d <= 0;
            else if (arvalid & arready ) // Handshake
                BankRdAddr_d <= RdPortAddr_Array[BankRdPortIdx[gv_i]];
        end

        prior_arb#(
            .REQ_WIDTH ( NUM_WRPORT )
        )u_prior_arb_BankWrPortIdx(
            .req ( BankPortFlag[gv_i][0 +: NUM_WRPORT] ),
            .gnt (  ),
            .arb_port  ( BankWrPortIdx[gv_i]  )
        );

        prior_arb#(
            .REQ_WIDTH ( NUM_RDPORT )
        )u_prior_arb_BankRdPortIdx(
            .req ( BankPortFlag[gv_i][NUM_WRPORT +: NUM_RDPORT] ),
            .gnt (  ),
            .arb_port  ( BankRdPortIdx[gv_i]  )
        );

        for(gv_j=0; gv_j<NUM_WRPORT+NUM_RDPORT; gv_j=gv_j+1) begin
            assign BankPortFlag[gv_i][gv_j] = TOPGLB_CfgPortBankFlag[NUM_BANK*gv_j + gv_i];
        end

    end
endgenerate

//=====================================================================================================================
// Logic Design 4: Read Port
//=====================================================================================================================


generate
    for(gv_j=0; gv_j<NUM_RDPORT; gv_j=gv_j+1) begin: GEN_RDPORT
        wire [$clog2(NUM_BANK)      -1 : 0] PortCur1stBankIdx;
        wire [$clog2(NUM_BANK)      -1 : 0] RdPort1stBankIdx;
        wire                                Empty;
        wire [NUM_BANK              -1 : 0] RdPortHitBank;
        wire                                RdPortAlloc;
        wire [$clog2(NUM_BANK)          : 0] RdPortNumBank;
        wire [ADDR_WIDTH            -1 : 0] RdPortAddrVldRange;


        // Map RdPort to Bank
        assign RdPortAddrVldRange =  RdPortAlloc? (SRAM_WORD*RdPortNumBank/TOPGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*(NUM_WRPORT+gv_j) +: ($clog2(MAXPAR) + 1)]) : SRAM_WORD; // Cut address to a relative(valid) range in NumBank/ParBank; Default: SRAM_WORD
        assign RdPortAddr_Array[gv_j] = TOPGLB_RdPortAddr[ADDR_WIDTH*gv_j +: ADDR_WIDTH];
        assign PortCur1stBankIdx = RdPort1stBankIdx + (RdPortAddr_Array[gv_j] % RdPortAddrVldRange >> SRAM_DEPTH_WIDTH)*TOPGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*(NUM_WRPORT+gv_j) +: ($clog2(MAXPAR) + 1)];

        // To Bank
        for(gv_i=0; gv_i<NUM_BANK; gv_i=gv_i+1) begin
                assign RdPortHitBank[gv_i] = PortCur1stBankIdx <= gv_i & gv_i < PortCur1stBankIdx + TOPGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*(NUM_WRPORT+gv_j) +: ($clog2(MAXPAR) + 1)];
        end
        assign RdPortEn[gv_j] = TOPGLB_RdPortAddrVld[gv_j] & GLBTOP_RdPortAddrRdy[gv_j]; // addr handshake : enable of (add+1)
        assign RdPortBankEn[gv_j] = {NUM_BANK{RdPortEn[gv_j]}} & RdPortHitBank; // 32bits

        // To Output
        assign Empty = RdPortAddr_Array[gv_j] >= BankWrAddr_Array[PortCur1stBankIdx];
        assign GLBTOP_RdPortAddrRdy[gv_j] = RdPortAlloc & !Empty & Bank_arready[PortCur1stBankIdx];
        assign GLBTOP_RdEmpty[gv_j] = Empty;

        assign GLBTOP_RdPortDatVld[gv_j] = RdPortAlloc & Bank_rvalid[PortCur1stBankIdx];
        for(gv_i=0; gv_i<MAXPAR; gv_i=gv_i+1) begin
            assign GLBTOP_RdPortDat[SRAM_WIDTH*(MAXPAR*gv_j + gv_i) +: SRAM_WIDTH] =  Bank_rdata_array[PortCur1stBankIdx+gv_i];
        end

        assign RdPortAlloc = |TOPGLB_CfgPortBankFlag[NUM_BANK*(gv_j+NUM_WRPORT) +: NUM_BANK];

        prior_arb#(
            .REQ_WIDTH ( NUM_BANK )
        )u_prior_arb_RdPort1stBankIdx(
            .req ( TOPGLB_CfgPortBankFlag[NUM_BANK*(gv_j+NUM_WRPORT) +: NUM_BANK] ),
            .gnt (  ),
            .arb_port  ( RdPort1stBankIdx  )
        );
        CNT1 #(
            .DATA_WIDTH(NUM_BANK)
        ) u_CNT1_RdPortNumBank(
            .din(TOPGLB_CfgPortBankFlag[NUM_BANK*(gv_j+NUM_WRPORT) +: NUM_BANK]),
            .dout(RdPortNumBank)
        );
    end

endgenerate

//=====================================================================================================================
// Logic Design 5: Write Port
//=====================================================================================================================

generate
    for(gv_j=0; gv_j<NUM_WRPORT; gv_j=gv_j+1) begin: GEN_WRPORT
        wire [$clog2(NUM_BANK)  -1 : 0] PortCur1stBankIdx;
        wire [$clog2(NUM_BANK)  -1 : 0] WrPort1stBankIdx;
        wire [$clog2(NUM_RDPORT)-1 : 0] WrPortMthRdBankIdx;
        wire                            Full;
        wire [NUM_BANK          -1 : 0] WrPortHitBank;
        wire                            WrPortAlloc;
        wire [$clog2(NUM_BANK)     : 0] WrPortNumBank;
        wire [ADDR_WIDTH        -1 : 0] WrPortAddrVldSpace;

        // Map WrPort to Bank
        assign WrPortAddrVldSpace = WrPortAlloc? (SRAM_WORD*WrPortNumBank/TOPGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*(gv_j) +: ($clog2(MAXPAR) + 1)]) : SRAM_WORD;// Cut address to a relative(valid) range in NumBank/ParBank
        assign PortCur1stBankIdx = WrPort1stBankIdx + (WrPortAddr_Array[gv_j] % WrPortAddrVldSpace  >> SRAM_DEPTH_WIDTH)*TOPGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*gv_j +: ($clog2(MAXPAR) + 1)];

        // To Bank
        assign WrPortEn[gv_j] =  TOPGLB_WrPortDatVld[gv_j]  & GLBTOP_WrPortDatRdy[gv_j];
        assign WrPortDat_Array[gv_j] = TOPGLB_WrPortDat[SRAM_WIDTH*MAXPAR*gv_j +: SRAM_WIDTH*MAXPAR];
        assign WrPortAddr_Array[gv_j] = TOPGLB_WrPortAddr[ADDR_WIDTH*gv_j +: ADDR_WIDTH];
        for(gv_i=0; gv_i<NUM_BANK; gv_i=gv_i+1) begin
                assign WrPortHitBank[gv_i] = PortCur1stBankIdx <= gv_i & gv_i < PortCur1stBankIdx + TOPGLB_CfgPortParBank[($clog2(MAXPAR) + 1)*gv_j +: ($clog2(MAXPAR) + 1)];
        end
        assign WrPortBankEn[gv_j] = {NUM_BANK{WrPortEn[gv_j]}} & WrPortHitBank; // 32bits

        // To Output
        assign Full = (WrPortAddr_Array[gv_j] - BankRdAddr_Array[PortCur1stBankIdx]) == WrPortAddrVldSpace ;
        assign GLBTOP_WrPortDatRdy[gv_j] = WrPortAlloc & !Full & !(BankRdEn[PortCur1stBankIdx]) ;
        assign GLBTOP_WrFull[gv_j] = Full;

        assign WrPortAlloc = |TOPGLB_CfgPortBankFlag[NUM_BANK*gv_j +: NUM_BANK];

        prior_arb#(
            .REQ_WIDTH ( NUM_BANK )
        )u_prior_arb_WrPort1stBankIdx(
            .req ( TOPGLB_CfgPortBankFlag[NUM_BANK*gv_j +: NUM_BANK]),
            .gnt (  ),
            .arb_port  ( WrPort1stBankIdx  )
        );
        CNT1 #(
            .DATA_WIDTH(NUM_BANK)
        ) u_CNT1_WrPortNumBank(
            .din(TOPGLB_CfgPortBankFlag[NUM_BANK*gv_j +: NUM_BANK]),
            .dout(WrPortNumBank)
        );

    end
endgenerate



//=====================================================================================================================
// Debug
//=====================================================================================================================
`ifdef SIM
    DEC2D #(
        .WIDTH(NUM_BANK),
        .DEPTH(NUM_WRPORT+NUM_RDPORT)
    ) u_DEC2D_CCUGLB_CfgPortBankFlag(
        .IN(TOPGLB_CfgPortBankFlag)
    );
`endif

endmodule
