`timescale 1ns/1ps
module tb_stall_diagnostics;
    reg clk=0,rst=1,key_auto=1;
    always #5 clk=~clk;
    wire [3:0] state;
    wire [19:0] debug_data;
    wire [7:0] status;
    reg [79:0] probe=80'h0a234123456789abcdef0;
    reg [2:0] write_probe=3'b110;
    integer page;
    reg [19:0] page_expected;
    reg test_passed=0;
    integer checks=0;
    reg [19:0] saved_flags;
    sd_card_bmp #(.CLK_FREQ_HZ(1000)) dut (
        .clk(clk),.rst(rst),.key_next(1'b1),.key_auto(key_auto),
        .state_code(state),.pixel_count_debug(debug_data),
        .bmp_width(16'd640),.bmp_height(16'd480),.display_valid(),
        .storage_diag_sd(probe),.storage_diag_write(write_probe),
        .osd_status(status),.write_finish_toggle(1'b0),
        .write_buf_idx(),.disp_buf_idx(),.write_req(),.write_req_ack(1'b0),
        .write_en(),.write_data(),.SD_nCS(),.SD_DCLK(),.SD_MOSI(),.SD_MISO(1'b1));
    function [19:0] reversed;
        input [19:0] v;
        reversed={v[3:0],v[7:4],v[11:8],v[15:12],v[19:16]};
    endfunction
    task reset_case;
        begin
            rst=1; key_auto=1;
            repeat(3) @(negedge clk); rst=0;
            force dut.sd_init_done=1;
            force dut.scan_done=1;
            force dut.scan_kicked=1;
            force dut.img_found_count=4;
            force dut.first_image_committed=1;
            force dut.display_valid=1; // BUG TRIGGER: already displaying a picture
            force dut.bmp_ready=1;
            force dut.bmp_load_done=0;
            force dut.bmp_load_error=0;
            force dut.bmp_data_wr_en=0;
            force dut.write_done_seen=0;
            force dut.write_finish_pulse=0;
            force dut.load_idx=2;
            force dut.disp_buf_idx=1;
            force dut.load_busy=1;
            @(negedge clk); release dut.load_busy;
        end
    endtask
    initial begin
        reset_case();
        force dut.source_done_seen=1;
        force dut.pixel_write_count=307200;
        repeat(3) @(negedge clk);
        if(state!==6) $fatal(1,"FAIL subsequent frame must expose wait-write code 6");
        repeat(2050) @(negedge clk);
        if(!dut.diag_snapshot_valid || dut.diag_snapshot_pixels!==307200 || !dut.load_busy)
            $fatal(1,"FAIL full-frame stall snapshot or unintended recovery");
        if(debug_data!==reversed(20'h4b000)) $fatal(1,"FAIL count page");
        saved_flags=dut.diag_snapshot_flags;
        if(saved_flags[19:16]!==4'hf || saved_flags[15:12]!==4'hc)
            $fatal(1,"FAIL frozen completion flags");
        key_auto=0; repeat(30) @(negedge clk);
        if(!status[7] || !dut.load_busy || dut.diag_snapshot_flags!==saved_flags)
            $fatal(1,"FAIL AUTO must remain usable while stalled; snapshot frozen");
        repeat(1000) @(negedge clk);
        if(!dut.diag_flag_page || debug_data!==reversed(saved_flags))
            $fatal(1,"FAIL flags page");
        if(dut.diag_storage_snapshot!==probe || dut.diag_write_snapshot!==write_probe)
            $fatal(1,"FAIL storage snapshot");
        checks=checks+1;

        for(page=2;page<=6;page=page+1) begin
            while(dut.diag_probe_page!=page) @(negedge clk);
            case(page)
                2: page_expected=probe[19:0];
                3: page_expected=probe[39:20];
                4: page_expected={4'hc,probe[67:64],probe[49:40],2'b0};
                5: page_expected={4'hd,probe[75:68],write_probe,5'd0};
                6: page_expected={4'he,probe[59:50],6'd0};
            endcase
            #1; if(debug_data!==reversed(page_expected)) $fatal(1,"FAIL probe page %0d",page);
        end
        probe=0; write_probe=0;
        repeat(3) @(negedge clk);
        if(dut.diag_storage_snapshot!==80'h0a234123456789abcdef0)
            $fatal(1,"FAIL probe snapshot must remain frozen");
        reset_case();
        force dut.source_done_seen=1;
        force dut.pixel_write_count=300000;
        repeat(2050) @(negedge clk);
        if(state!==7 || dut.diag_snapshot_pixels!==300000 || !dut.load_busy)
            $fatal(1,"FAIL short frame diagnosis");
        checks=checks+1;

        reset_case();
        force dut.source_done_seen=0;
        force dut.pixel_write_count=307200;
        repeat(2050) @(negedge clk);
        if(state!==9 || dut.diag_snapshot_flags[15:12]!==4'h8 || !dut.load_busy)
            $fatal(1,"FAIL idle reader without source completion diagnosis");
        checks=checks+1;
        rst=1; #1;
        if(dut.diag_snapshot_valid) $fatal(1,"FAIL reset clears snapshot");
        test_passed=1;
        $display("SIM PASS stall diagnostics cases=%0d: full/short/missing source; AUTO responsive, no recovery, frozen snapshot",checks);
        $finish;
    end
    initial begin #200000; $fatal(1,"FAIL timeout"); end
endmodule
