`ifndef _VIRTIO_DEFINITION_
 `define _VIRTIO_DEFINITION_ 1

localparam STATUS_ACKNOWLEDGE = 32'd01;
localparam STATUS_DRIVER = 32'd02;
localparam STAUTS_FAILED = 32'd128;
localparam STATUS_FETATURES_OK = 32'd8;
localparam STATUS_DRIVER_OK = 32'd4;
localparam DEVICE_NEEDS_RESET = 32'd64;

localparam QUEUE_ALIGN = 4096;

localparam VIRTIO_BLK_T_IN = 0;
localparam VIRTIO_BLK_T_OUT = 1;

typedef struct {
   reg [63:0]  addr;
   reg [31:0]  len;
   reg [15:0]  flags;
   reg [15:0]  next;
} VRingDesc;

typedef struct {
   reg [31:0]  btype;
   reg [31:0]  reserved;
   reg [63:0]  sector;
} OutHDR;

typedef struct {
   reg [31:0]  id;
   reg [31:0]  len;
} VRingUsedElem;

localparam VIRTIO_BLK_T_IN = 0;
localparam VIRTIO_BLK_T_OUT = 1;

`endif
