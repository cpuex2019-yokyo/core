`ifndef _VIRTIO_DEFINITION_
 `define _VIRTIO_DEFINITION_ 1

localparam STATUS_ACKNOWLEDGE = 32'd01;
localparam STATUS_DRIVER = 32'd02;
localparam STAUTS_FAILED = 32'd128;
localparam STATUS_FETATURES_OK = 32'd8;
localparam STATUS_DRIVER_OK = 32'd4;
localparam DEVICE_NEEDS_RESET = 32'd64;

`endif
