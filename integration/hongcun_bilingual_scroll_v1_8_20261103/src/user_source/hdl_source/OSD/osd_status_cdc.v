`timescale 1ns/1ps
// Bundled-data mailbox: payload is held until acknowledgement returns.
// Common asynchronous reset is required for both clock domains.
// Intermediate source updates may coalesce; this carries state, not events.
module osd_status_cdc #(parameter WIDTH=8) (
    input wire src_clk, dst_clk, rst,
    input wire [WIDTH-1:0] src_data,
    output reg [WIDTH-1:0] dst_data
);
    reg [WIDTH-1:0] held_data;
    reg request, acknowledge;
    (* ASYNC_REG="TRUE" *) reg ack_meta, ack_sync;
    (* ASYNC_REG="TRUE" *) reg req_meta, req_sync;
    always @(posedge src_clk or posedge rst) begin
        if (rst) begin
            held_data<=0; request<=0; ack_meta<=0; ack_sync<=0;
        end else begin
            ack_meta<=acknowledge; ack_sync<=ack_meta;
            if (request==ack_sync && held_data!=src_data) begin
                held_data<=src_data;
                request<=~request;
            end
        end
    end
    always @(posedge dst_clk or posedge rst) begin
        if (rst) begin
            req_meta<=0; req_sync<=0; acknowledge<=0; dst_data<=0;
        end else begin
            req_meta<=request; req_sync<=req_meta;
            if (req_sync!=acknowledge) begin
                dst_data<=held_data;
                acknowledge<=req_sync;
            end
        end
    end
endmodule
