`timescale  1 ns / 100 ps

`define CLOCK_PERIOD 5 // Core clock: <= 1000/16=60 when PLL
`define OFFCLOCK_PERIOD 100 // 
`define PLL
`define SIM
// `define FUNC_SIM
`define POST_SIM
// `define PSEUDO_DATA
`define ASSERTION_ON

`define CEIL(a, b) ( \
 (a % b)? (a / b + 1) : (a / b) \
)
module TOP_tb();
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
parameter PORT_WIDTH        = 128   ;
parameter ADDR_WIDTH        = 16    ;
parameter DRAM_ADDR_WIDTH   = 32    ;
parameter OPNUM             = 3     ;
parameter FBDIV_WIDTH    = 3;
parameter FPSISA_WIDTH   = PORT_WIDTH*16;
parameter KNNISA_WIDTH   = PORT_WIDTH*2;
parameter SYAISA_WIDTH   = PORT_WIDTH*3;
parameter POLISA_WIDTH   = PORT_WIDTH*9;
parameter GICISA_WIDTH   = PORT_WIDTH*2;
parameter MONISA_WIDTH   = PORT_WIDTH*1;

// parameter ISANUM[0]   = 20;
// parameter ISANUM[1]   = 32;
// parameter ISANUM[2]   = 32;
// parameter ISANUM[3]   = 18;
// parameter ISANUM[4]   = 18;
// parameter ISANUM[5]   = 20;
localparam [OPNUM -1 : 0][32 -1 : 0] ISANUM = {
    32'd18, // GIC
    32'd32, // BLK
    32'd23  // FPS
};

// MON
parameter CCUMON_WIDTH  = 128*2;
parameter GICMON_WIDTH  = 128*2;
parameter GLBMON_WIDTH  = 128*11;
parameter POLMON_WIDTH  = 128*2;
parameter SYAMON_WIDTH  = 128*2;
parameter KNNMON_WIDTH  = 128*2;
parameter FPSMON_WIDTH  = 128*2;

parameter MDUMONSUM_WIDTH  = CCUMON_WIDTH + GICMON_WIDTH + GLBMON_WIDTH + POLMON_WIDTH + SYAMON_WIDTH + KNNMON_WIDTH + FPSMON_WIDTH;
parameter TOPMON_WIDTH     = PORT_WIDTH*`CEIL(MDUMONSUM_WIDTH, PORT_WIDTH);

localparam [OPNUM -1 : 0][DRAM_ADDR_WIDTH -1 : 0] ISABASEADDR = {
    32'd0 + FPSISA_WIDTH/PORT_WIDTH*ISANUM[0] + KNNISA_WIDTH/PORT_WIDTH*ISANUM[1], 
    32'd0 + FPSISA_WIDTH/PORT_WIDTH*ISANUM[0], 
    32'd0
};

localparam [OPNUM -1 : 0][32 -1 : 0] ISANUMWORD = {
    GICISA_WIDTH/PORT_WIDTH, 
    KNNISA_WIDTH/PORT_WIDTH, 
    FPSISA_WIDTH/PORT_WIDTH
};

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
// TOP Inputs
reg                             I_BypAsysnFIFO;
reg                             I_BypOE;
reg                             I_OffOE;
reg                             I_SysClk;
reg                             I_OffClk;
wire                            O_SysClk;
wire                            O_OffClk;
      
reg                             I_BypPLL;      
reg [FBDIV_WIDTH        -1 : 0] I_FBDIV;       
reg                             I_SwClk;  

reg [4                  -1 : 0] I_MonSel;
// TOP Outputs
wire                            O_DatOE;
wire                            O_CmdVld;

// TOP Bidirs
wire  [PORT_WIDTH       -1 : 0] IO_Dat;
wire                            O_DatVld ;
wire                            I_DatVld_tmp ;
wire                            I_DatRdy_tmp ;
wire                            O_DatRdy ;
wire                            I_DatLast_tmp;
wire                            I_DatVld;
wire                            I_DatLast;
wire                            I_DatRdy;
wire                            I_ISAVld;
wire                            O_DatLast;

reg                             rst_n ;
wire                            O_PLLLock;
reg [PORT_WIDTH         -1 : 0] Dram[0 : 2**18-1];
wire[DRAM_ADDR_WIDTH    -1 : 0] DatAddr;

reg [4                  -1 : 0] ISAIdx;
reg [4                  -1 : 0] ISAIdx_tmp;
reg [4                  -1 : 0] ISAIdx_d;
reg [32                 -1 : 0] ISADelay;
wire[OPNUM  -1 : 0][ADDR_WIDTH  -1 : 0] ISAAddr;
wire[OPNUM              -1 : 0] Overflow_ISA;
wire [OPNUM             -1 : 0] O_CfgRdy;
wire                            I_ISAVld_tmp;
wire                            Overflow_DatAddr;
wire [OPNUM     -1 : 0][ADDR_WIDTH     -1 : 0] Mon_CntISA; 

localparam IDLE         = 3'b000;
localparam ISASND       = 3'b001;
// localparam ISAWAITCFG   = 3'b010;
localparam DATCMD       = 3'b011;
localparam DATIN2CHIP   = 3'b100;
localparam DATOUT2OFF   = 3'b101;

reg [ 3     -1 : 0] state       ;
reg [ 3     -1 : 0] next_state  ;

//=====================================================================================================================
// Logic Design: Debounce
//=====================================================================================================================
initial begin
    I_OffClk = 1;
    forever #(`OFFCLOCK_PERIOD/2) I_OffClk=~I_OffClk;
end

initial begin
    I_SysClk = 1;
    @(posedge I_OffClk); // wait I_FBDIV
    `ifdef PLL
        if(!I_BypPLL)
            forever #(`CLOCK_PERIOD*{I_FBDIV, 5'd0}/2)   I_SysClk=~I_SysClk;
        else
            forever #(`CLOCK_PERIOD/2)  I_SysClk=~I_SysClk;
    `else
        forever #(`CLOCK_PERIOD/2)  I_SysClk=~I_SysClk;
    `endif
end

initial begin
    rst_n                         = 1;
    #(`OFFCLOCK_PERIOD*2)  rst_n  =  0;
    #(`OFFCLOCK_PERIOD*10) rst_n  =  1;
end

initial begin
    I_BypAsysnFIFO  = 1'b0;
    I_BypOE         = 1'b0;
    I_OffOE         = 1'b0;
    I_SwClk         = 1'b0;
    I_BypPLL        = 1'b0;
    I_FBDIV         = 3'd1;
    I_MonSel        = 4'd0;

    @(posedge rst_n);
    `ifdef PLL
        if(!I_BypPLL) begin
            wait(O_PLLLock);
            I_SwClk     = 1'b1;
        end else
            I_SwClk     = 1'b1;
    `else
        I_SwClk = 1'b1;
    `endif
end

initial begin
    $readmemh("../TOP/Dram.txt", Dram);
end

reg [32 + 4     -1 : 0] ISA_Serial [0 : 2**8   -1];
initial begin
    $readmemh("../TOP/ISA.txt", ISA_Serial);
end

initial begin
    $shm_open("TEMPLATE.shm");
    $shm_probe(TOP_tb.u_TOP, "AS");
end


reg [16     -1 : 0] cntISA;
reg                 TrigLoop;
wire                IsaSndEn;
initial
begin
    cntISA = 0;
    ISAIdx = 7; // Invalid
    ISADelay = 0;
    TrigLoop = 0;
    @(posedge rst_n);
    repeat(10) @(posedge I_OffClk);
    forever begin
        wait (state == IDLE & IsaSndEn);
        if (cntISA >= 120) begin
            TrigLoop = 1;
            repeat(2) @(posedge I_OffClk);
            TrigLoop = 0;
            cntISA = 1;// Not Need Initialize banks again
            #(`OFFCLOCK_PERIOD*2)  rst_n  =  0;
            #(`OFFCLOCK_PERIOD*10) rst_n  =  1;
        end

        @ (negedge I_OffClk );
        // $stop;
        ISAIdx  = ISA_Serial[cntISA][0 +:  4]; // Low 4 bit ISA
        ISADelay= ISA_Serial[cntISA][4 +: 32];// High 32 bit Delay
        if (ISAIdx <= OPNUM -1) // Valid ISA
            wait (state == ISASND);

        // Delay
        ISAIdx = 6; // DO NOT DELETE!
        ISAIdx_tmp = ISAIdx;
        repeat(ISADelay) @(posedge u_TOP.clk);
        // repeat(ISADelay) @(posedge O_SysClk);
        ISAIdx = ISAIdx_tmp;
        cntISA = cntISA + 1;
    end
end

integer i;
initial begin
    forever begin
        @(posedge I_OffClk);
        for(i=0; i<OPNUM; i=i+1) begin
            if(Mon_CntISA[i] >= ISANUM[i]) begin
                $display("ISA out of range, [%d]", i);
                $stop;
            end
        end
    end
end

`ifdef POST_SIM
    initial begin 
        $sdf_annotate ("/workspace/home/zhoucc/Proj_HW/PointCloudAcc/hardware/work/synth/TOP/Date230805_0220_Periodclk5_Periodsck10_PLL1_group_Track3vt_MaxDynPwr0_OptWgt0.5_Note_FPS_FROZEN_V9_PLL&REDUCEPAD/gate/TOP.sdf", u_TOP, , "TOP_sdf.log", "MAXIMUM", "1.0:1.0:1.0", "FROM_MAXIMUM");
    end 

    reg EnTcf;
    initial begin
        EnTcf = 1'b0;
    end
`endif


//=====================================================================================================================
// Logic Design 1: FSM=ITF
//=====================================================================================================================
assign IsaSndEn = (!O_CmdVld & !O_DatVld) & u_TOP.u_ITF.O_CfgRdy[2]; // No output & No GIC and MON;
always @(*) begin
    case ( state )
        IDLE:   if ( TrigLoop )
                    next_state <= IDLE;
                else if( O_CmdVld )
                    next_state <= DATCMD;
                else if (O_DatVld ) // !CmdVld: MonDat
                    next_state <= DATOUT2OFF;
                else if ( IsaSndEn & ISAIdx <= OPNUM -1 )
                    next_state <= ISASND;
                else
                    next_state <= IDLE;

        // ISA
        ISASND: if( (I_DatLast_tmp & I_DatVld_tmp & O_DatRdy) | O_DatVld ) // O_DatVld Forces state to shut down ISASND
                    next_state <= IDLE;
                else
                    next_state <= ISASND;

        // Data
        DATCMD :if( O_DatOE & O_DatVld & I_DatRdy_tmp) begin
                    if ( IO_Dat[0] ) // 
                        next_state <= DATOUT2OFF;
                    else
                        next_state <= DATIN2CHIP;
                end else
                    next_state <= DATCMD;

        DATIN2CHIP:   if( I_DatLast_tmp & (I_DatVld_tmp & O_DatRdy) )
                    next_state <= IDLE;
                else
                    next_state <= DATIN2CHIP;

        DATOUT2OFF:   if( O_DatLast & (O_DatVld & I_DatRdy_tmp) )
                    next_state <= IDLE;
                else
                    next_state <= DATOUT2OFF;

        default:    next_state <= IDLE;
    endcase
end
always @ ( posedge I_OffClk or negedge rst_n ) begin
    if ( !rst_n ) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

//=====================================================================================================================
// Logic Design: ISA 
//=====================================================================================================================
genvar gv_i;
generate
    for(gv_i = 0; gv_i < OPNUM; gv_i = gv_i + 1) begin: GEN_ISAAddr
        reg  [ADDR_WIDTH     -1 : 0] ISAAddr_r; // Last
        wire [ADDR_WIDTH     -1 : 0] MaxCnt; 
        wire [ADDR_WIDTH     -1 : 0] Default;

        assign MaxCnt   = 2**ADDR_WIDTH -1;
        assign Default  = ISABASEADDR[gv_i];

        counter#(
            .COUNT_WIDTH ( ADDR_WIDTH )
        )u_counter_MduISARdAddr(
            .CLK       ( I_OffClk       ),
            .RESET_N   ( rst_n          ),
            .CLEAR     ( TrigLoop       ),
            .DEFAULT   ( Default        ),
            .INC       ( I_ISAVld_tmp & (I_DatVld_tmp & O_DatRdy) & (ISAIdx_d == gv_i) ),
            .DEC       ( 1'b0           ),
            .MIN_COUNT ( {ADDR_WIDTH{1'b0}}),
            .MAX_COUNT ( MaxCnt         ),
            .OVERFLOW  (                ),
            .UNDERFLOW (                ),
            .COUNT     ( ISAAddr[gv_i]  )
        );
        always @(posedge I_OffClk or rst_n) begin
            if (!rst_n) begin
                ISAAddr_r <= Default;
            end else if(TrigLoop) begin
                ISAAddr_r <= Default;
            end else if(state == IDLE) begin
                ISAAddr_r <= ISAAddr[gv_i];
            end
        end
        assign Overflow_ISA[gv_i] = ISAAddr[gv_i] - ISAAddr_r == ISANUMWORD[ISAIdx_d] - 1;
        assign Mon_CntISA[gv_i] = (ISAAddr[gv_i] - ISABASEADDR[gv_i])/ISANUMWORD[gv_i];

    end
endgenerate
assign I_ISAVld_tmp = state == ISASND;
always @(posedge I_OffClk or rst_n) begin
    if (!rst_n) begin
        ISAIdx_d <= 0;
    end else if(state == IDLE && next_state == ISASND) begin
        ISAIdx_d <= ISAIdx;
    end
end

//=====================================================================================================================
// Logic Design: DATA 
//=====================================================================================================================
reg [DRAM_ADDR_WIDTH        -1 : 0] MaxAddr;
wire[DRAM_ADDR_WIDTH        -1 : 0] default_addr;
always @(posedge I_OffClk or rst_n) begin
    if (!rst_n) begin
        MaxAddr <= 0;
    end else if(state==DATCMD & (next_state == DATIN2CHIP | next_state == DATOUT2OFF)) begin
        MaxAddr <= IO_Dat[1 +: DRAM_ADDR_WIDTH] + IO_Dat[1 + DRAM_ADDR_WIDTH +: ADDR_WIDTH]*2 -1; // 256bit -> 128bit
    end else if(state==IDLE & next_state == DATOUT2OFF) begin // Mondat
        MaxAddr <= TOPMON_WIDTH/PORT_WIDTH -1; // 6 PORT_WIDTH
    end
end
assign default_addr = state==DATCMD & (next_state == DATIN2CHIP | next_state == DATOUT2OFF) ? IO_Dat[1 +: DRAM_ADDR_WIDTH] : 0;
counter#(
    .COUNT_WIDTH ( DRAM_ADDR_WIDTH )
)u_counter_addr(
    .CLK       ( I_OffClk       ),
    .RESET_N   ( rst_n          ),
    .CLEAR     ( state==DATCMD & (next_state == DATIN2CHIP | next_state == DATOUT2OFF) | state == IDLE & next_state == DATOUT2OFF ),
    .DEFAULT   ( default_addr   ),
    .INC       ( (state == DATIN2CHIP | state == DATOUT2OFF) & (I_DatVld_tmp & O_DatRdy | O_DatVld & I_DatRdy_tmp) ),
    .DEC       ( 1'b0           ),
    .MIN_COUNT ( {DRAM_ADDR_WIDTH{1'b0}}),
    .MAX_COUNT ( MaxAddr        ),
    .OVERFLOW  ( Overflow_DatAddr),
    .UNDERFLOW (                ),
    .COUNT     ( DatAddr        )
);

// `ifndef PSEUDO_DATA
//     always @(posedge I_OffClk or rst_n) begin
//         if(state == DATOUT2OFF) begin
//             if(O_DatVld & I_DatRdy_tmp)
//                 Dram[DatAddr] <= IO_Dat;
//         end
//     end
// `endif

//=====================================================================================================================
// Logic Design : Interface
//=====================================================================================================================
// DRAM READ
assign I_DatVld_tmp  = state == ISASND | state== DATIN2CHIP;
assign I_DatLast_tmp = (I_ISAVld_tmp? Overflow_ISA[ISAIdx_d] : Overflow_DatAddr);


wire [PORT_WIDTH    -1 : 0] TEST28 = Dram[28];

// DRAM WRITE
assign I_DatRdy_tmp = I_ISAVld_tmp? 1'bz : (O_DatOE? O_CmdVld & state==DATCMD | !O_CmdVld & state==DATOUT2OFF: 1'bz);


// Delay In2Chip
assign #2 I_DatVld = I_DatVld_tmp;
assign #2 I_DatLast= I_DatLast_tmp;
assign #2 I_DatRdy = I_DatRdy_tmp;
assign #2 I_ISAVld = I_ISAVld_tmp;
assign #2 IO_Dat    = (state == ISASND | state == DATIN2CHIP)?
                        (I_ISAVld_tmp? Dram[ISAAddr[ISAIdx_d]] : Dram[DatAddr[0 +: 13]])
                        : {PORT_WIDTH{1'bz}}; // 8196
TOP u_TOP (
    .I_BypAsysnFIFO_PAD ( I_BypAsysnFIFO),
    .I_BypOE_PAD        ( I_BypOE       ),
    .I_SwClk_PAD        ( I_SwClk       ),
    .I_SysRst_n_PAD     ( rst_n         ),
    .I_SysClk_PAD       ( I_SysClk      ),
    .I_OffClk_PAD       ( I_OffClk      ),
    `ifdef PLL
        .I_BypPLL_PAD       ( I_BypPLL      ),
        .I_FBDIV_PAD        ( I_FBDIV       ),
        .O_PLLLock_PAD      ( O_PLLLock     ), 
    `endif
    // .O_SysClk_PAD       ( O_SysClk      ),
    // .O_OffClk_PAD       ( O_OffClk      ),
    // .O_CfgRdy_PAD       ( O_CfgRdy      ),
    // .O_MonState_PAD     (               ),
    .O_DatOE_PAD        ( O_DatOE       ),
    .I_OffOE_PAD        ( I_OffOE       ),
    .I_DatVld_PAD       ( I_DatVld      ),
    .I_DatLast_PAD      ( I_DatLast     ),
    .O_DatRdy_PAD       ( O_DatRdy      ),
    .O_DatVld_PAD       ( O_DatVld      ), 
    .O_DatLast_PAD      ( O_DatLast     ), 
    .I_DatRdy_PAD       ( I_DatRdy      ),
    .I_ISAVld_PAD       ( I_ISAVld      ),
    .O_CmdVld_PAD       ( O_CmdVld      ),
    .IO_Dat_PAD         ( IO_Dat        ),
    .I_MonSel_PAD       ( I_MonSel      ),
    .O_MonDat_PAD       ( O_MonDat      )
);

endmodule