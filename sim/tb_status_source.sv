`timescale 1ns/1ps
// Unit-level stimulus at BMP/SD completion boundaries, not a card model.
module tb_status_source;
    reg clk=0,rst=1,key_auto=1;
    always #5 clk=~clk;
    wire [7:0] status;
    wire valid;
    integer i,checks=0;
    reg test_passed=0;
    sd_card_bmp #(.CLK_FREQ_HZ(1000)) dut (
        .clk(clk),.rst(rst),.key_next(1'b1),.key_auto(key_auto),
        .state_code(),.pixel_count_debug(),.bmp_width(16'd640),.bmp_height(16'd480),
        .display_valid(valid),.osd_status(status),.write_finish_toggle(1'b0),
        .write_buf_idx(),.disp_buf_idx(),.write_req(),.write_req_ack(1'b0),
        .write_en(),.write_data(),.SD_nCS(),.SD_DCLK(),.SD_MOSI(),.SD_MISO(1'b1));
    initial begin
        force dut.sd_init_done=1'b1;
        force dut.bmp_ready=1'b0;
        force dut.scan_done=1'b1;
        force dut.img_found_count=3'd4;
        force dut.first_image_committed=1'b1;
        force dut.bmp_load_done=1'b0;
        force dut.bmp_load_error=1'b0;
        force dut.bmp_data_wr_en=1'b0;
        repeat(3) @(negedge clk); rst=0;
        if(status[6:0]!==0) $fatal(1,"FAIL initial invalid");
        for(i=0;i<4;i=i+1) begin
            @(negedge clk);
            force dut.load_busy=1;
            force dut.load_idx=i[1:0];
            force dut.pending_buf_idx={1'b0,i[0]};
            force dut.source_done_seen=0;
            force dut.write_done_seen=0;
            force dut.write_finish_pulse=0;
            repeat(4) @(negedge clk);
            if(i==0 && valid) $fatal(1,"FAIL load start exposed image");
            force dut.source_done_seen=1;
            repeat(4) @(negedge clk);
            if(i==0 && valid) $fatal(1,"FAIL source completion exposed image");
            force dut.write_finish_pulse=1;
            @(negedge clk);
            if(!valid || status[5:4]!=={1'b0,i[0]} ||
                (i[0] ? status[3:2] : status[1:0])!==i[1:0])
                $fatal(1,"FAIL commit tag i=%0d status=%h",i,status);
            checks=checks+1;
            force dut.load_busy=0;
            force dut.source_done_seen=0;
            force dut.write_finish_pulse=0;
        end
        // Real debounce and AUTO state machine, without waiting 20 real ms.
        @(negedge clk); key_auto=0;
        repeat(30) @(negedge clk);
        if(!status[7]) $fatal(1,"FAIL AUTO ON");
        key_auto=1; repeat(30) @(negedge clk);
        key_auto=0; repeat(30) @(negedge clk);
        if(status[7]) $fatal(1,"FAIL AUTO OFF");
        test_passed=1;
        $display("SIM PASS status source: commits=%0d, no early exposure, AUTO debounce ON/OFF",checks);
        $finish;
    end
    initial begin #100000; $fatal(1,"FAIL timeout"); end
endmodule
