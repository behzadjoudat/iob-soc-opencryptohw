`timescale 1 ns / 1 ps
`include "system.vh"
`include "iob_lib.vh"
`include "iob_intercon.vh"

//do not remove line below
//PHEADER

module system 
  (
   //do not remove line below
   //PIO


`ifdef USE_DDR //AXI MASTER INTERFACE

   //address write
   output [2*1-1:0]        m_axi_awid,
   output [2*`DDR_ADDR_W-1:0]  m_axi_awaddr,
   output [2*8-1:0]        m_axi_awlen,
   output [2*3-1:0]        m_axi_awsize,
   output [2*2-1:0]        m_axi_awburst,
   output [2*1-1:0]        m_axi_awlock,
   output [2*4-1:0]        m_axi_awcache,
   output [2*3-1:0]        m_axi_awprot,
   output [2*4-1:0]        m_axi_awqos,
   output [2*1-1:0]      m_axi_awvalid,
   input [2*1-1:0]       m_axi_awready,

   //write
   output [2*32-1:0]   m_axi_wdata,
   output [2*32/8-1:0] m_axi_wstrb,
   output [2*1-1:0]      m_axi_wlast,
   output [2*1-1:0]      m_axi_wvalid,
   input [2*1-1:0]       m_axi_wready,

   //write response
    input [2*1-1:0]      m_axi_bid,
   input [2*2-1:0]       m_axi_bresp,
   input [2*1-1:0]       m_axi_bvalid,
   output [2*1-1:0]      m_axi_bready,

   //address read
   output [2*1-1:0]        m_axi_arid,
   output [2*`DDR_ADDR_W-1:0]  m_axi_araddr,
   output [2*8-1:0]        m_axi_arlen,
   output [2*3-1:0]        m_axi_arsize,
   output [2*2-1:0]        m_axi_arburst,
   output [2*1-1:0]        m_axi_arlock,
   output [2*4-1:0]        m_axi_arcache,
   output [2*3-1:0]        m_axi_arprot,
   output [2*4-1:0]        m_axi_arqos,
   output [2*1-1:0]      m_axi_arvalid,
   input [2*1-1:0]       m_axi_arready,

   //read
    input [2*1-1:0]      m_axi_rid,
   input [2*32-1:0]  m_axi_rdata,
   input [2*2-1:0]       m_axi_rresp,
   input [2*1-1:0]       m_axi_rlast,
   input [2*1-1:0]       m_axi_rvalid,
   output [2*1-1:0]      m_axi_rready,
`endif //  `ifdef USE_DDR
   input                    clk,
   input                    reset,
   output                   trap
   );

   localparam ADDR_W=32;
   localparam DATA_W=32;
   
   //
   // SYSTEM RESET
   //

   wire                      boot;
   wire                      boot_reset;   
   wire                      cpu_reset = reset | boot_reset;
   
   //
   //  CPU
   //

   // instruction bus
   wire [`REQ_W-1:0]         cpu_i_req;
   wire [`RESP_W-1:0]        cpu_i_resp;

   // data cat bus
   wire [`REQ_W-1:0]         cpu_d_req;
   wire [`RESP_W-1:0]        cpu_d_resp;
   
   //instantiate the cpu
   iob_VexRiscv cpu
       (
        .clk     (clk),
        .rst     (cpu_reset),
        .boot    (boot),
        .trap    (trap),
        
        //instruction bus
        .ibus_req(cpu_i_req),
        .ibus_resp(cpu_i_resp),
        
        //data bus
        .dbus_req(cpu_d_req),
        .dbus_resp(cpu_d_resp)
        );


   //   
   // SPLIT INTERNAL AND EXTERNAL MEMORY BUSES
   //

   //internal memory instruction bus
   wire [`REQ_W-1:0]         int_mem_i_req;
   wire [`RESP_W-1:0]        int_mem_i_resp;
   //external memory instruction bus
`ifdef RUN_EXTMEM
   wire [`REQ_W-1:0]         ext_mem_i_req;
   wire [`RESP_W-1:0]        ext_mem_i_resp;
`endif

   // INSTRUCTION BUS
   iob_split 
     #(
`ifdef RUN_EXTMEM
           .N_SLAVES(2),
`else
           .N_SLAVES(1),
`endif
           .P_SLAVES(`E_BIT)
           )
   ibus_split
     (
      .clk    ( clk                              ),
      .rst    ( reset                            ),
      // master interface
      .m_req  ( cpu_i_req                        ),
      .m_resp ( cpu_i_resp                       ),
      
      // slaves interface
`ifdef RUN_EXTMEM
      .s_req  ( {ext_mem_i_req, int_mem_i_req}   ),
      .s_resp ( {ext_mem_i_resp, int_mem_i_resp} )
`else
      .s_req  (  int_mem_i_req                   ),
      .s_resp ( int_mem_i_resp                   )
`endif
      );


   // DATA BUS

   //internal memory data bus
   wire [`REQ_W-1:0]         int_mem_d_req;
   wire [`RESP_W-1:0]        int_mem_d_resp;

`ifdef USE_DDR
   //external memory data bus
   wire [`REQ_W-1:0]         ext_mem_d_req;
   wire [`RESP_W-1:0]        ext_mem_d_resp;
`endif

   //peripheral bus
   wire [`REQ_W-1:0]         pbus_req;
   wire [`RESP_W-1:0]        pbus_resp;

   iob_split 
     #(
`ifdef USE_DDR
       .N_SLAVES(3), //E,P,I
`else
       .N_SLAVES(2),//P,I
`endif
       .P_SLAVES(`E_BIT)
       )
   dbus_split    
     (
      .clk    ( clk                      ),
      .rst    ( reset                    ),

      // master interface
      .m_req  ( cpu_d_req                                  ),
      .m_resp ( cpu_d_resp                                 ),

      // slaves interface
`ifdef USE_DDR
      .s_req  ( {ext_mem_d_req, pbus_req, int_mem_d_req}   ),
      .s_resp ({ext_mem_d_resp, pbus_resp, int_mem_d_resp} )
`else
      .s_req  ({pbus_req, int_mem_d_req}                   ),
      .s_resp ({pbus_resp, int_mem_d_resp}                 )
`endif
      );
   

   //   
   // SPLIT PERIPHERAL BUS
   //

   //slaves bus
   wire [`N_SLAVES*`REQ_W-1:0] slaves_req;
   wire [`N_SLAVES*`RESP_W-1:0] slaves_resp;

   iob_split 
     #(
       .N_SLAVES(`N_SLAVES),
       .P_SLAVES(`P_BIT-1)
       )
   pbus_split
     (
      .clk    ( clk                      ),
      .rst    ( reset                    ),
      // master interface
      .m_req   ( pbus_req    ),
      .m_resp  ( pbus_resp   ),
      
      // slaves interface
      .s_req   ( slaves_req  ),
      .s_resp  ( slaves_resp )
      );

   
   //
   // INTERNAL SRAM MEMORY
   //
   
   int_mem int_mem0 
     (
      .clk                  (clk ),
      .rst                  (reset),
      .boot                 (boot),
      .cpu_reset            (boot_reset),

      // instruction bus
      .i_req                (int_mem_i_req),
      .i_resp               (int_mem_i_resp),

      //data bus
      .d_req                (int_mem_d_req),
      .d_resp               (int_mem_d_resp)
      );

`ifdef USE_DDR
   //
   // EXTERNAL DDR MEMORY
   //
   ext_mem ext_mem0 
     (
      .clk                  (clk),
      .rst                  (cpu_reset),
      
 `ifdef RUN_EXTMEM
      // instruction bus
      .i_req                ({ext_mem_i_req[`valid(0)], ext_mem_i_req[`address(0, `FIRM_ADDR_W)-2], ext_mem_i_req[`write(0)]}),
      .i_resp               (ext_mem_i_resp),
 `endif
      //data bus
      .d_req                ({ext_mem_d_req[`valid(0)], ext_mem_d_req[`address(0, `DCACHE_ADDR_W+1)-2], ext_mem_d_req[`write(0)]}),
      .d_resp               (ext_mem_d_resp),

      //AXI INTERFACE 
      //address write
      .axi_awid(m_axi_awid[0*1+:1]), 
      .axi_awaddr(m_axi_awaddr[0*`DDR_ADDR_W+:`DDR_ADDR_W]), 
      .axi_awlen(m_axi_awlen[0*8+:8]), 
      .axi_awsize(m_axi_awsize[0*3+:3]), 
      .axi_awburst(m_axi_awburst[0*2+:2]), 
      .axi_awlock(m_axi_awlock[0*1+:1]), 
      .axi_awcache(m_axi_awcache[0*4+:4]), 
      .axi_awprot(m_axi_awprot[0*3+:3]),
      .axi_awqos(m_axi_awqos[0*4+:4]), 
      .axi_awvalid(m_axi_awvalid[0*1+:1]), 
      .axi_awready(m_axi_awready[0*1+:1]), 
        //write
      .axi_wdata(m_axi_wdata[0*32+:32]), 
      .axi_wstrb(m_axi_wstrb[0*32/8+:32/8]), 
      .axi_wlast(m_axi_wlast[0*1+:1]), 
      .axi_wvalid(m_axi_wvalid[0*1+:1]), 
      .axi_wready(m_axi_wready[0*1+:1]), 
      //write response
      .axi_bid(m_axi_bid[0]), 
      .axi_bresp(m_axi_bresp[0*2+:2]), 
      .axi_bvalid(m_axi_bvalid[0*1+:1]), 
      .axi_bready(m_axi_bready[0*1+:1]), 
      //address read
      .axi_arid(m_axi_arid[0*1+:1]), 
      .axi_araddr(m_axi_araddr[0*`DDR_ADDR_W+:`DDR_ADDR_W]), 
      .axi_arlen(m_axi_arlen[0*8+:8]), 
      .axi_arsize(m_axi_arsize[0*3+:3]), 
      .axi_arburst(m_axi_arburst[0*2+:2]), 
      .axi_arlock(m_axi_arlock[0*1+:1]), 
      .axi_arcache(m_axi_arcache[0*4+:4]), 
      .axi_arprot(m_axi_arprot[0*3+:3]), 
      .axi_arqos(m_axi_arqos[0*4+:4]), 
      .axi_arvalid(m_axi_arvalid[0*1+:1]), 
      .axi_arready(m_axi_arready[0*1+:1]), 
      //read 
      .axi_rid(m_axi_rid[0]), 
      .axi_rdata(m_axi_rdata[0*32+:32]), 
      .axi_rresp(m_axi_rresp[0*2+:2]), 
      .axi_rlast(m_axi_rlast[0*1+:1]), 
      .axi_rvalid(m_axi_rvalid[0*1+:1]),  
      .axi_rready(m_axi_rready[0*1+:1])
      );
`endif

   //peripheral instances are inserted here
   
endmodule
 
