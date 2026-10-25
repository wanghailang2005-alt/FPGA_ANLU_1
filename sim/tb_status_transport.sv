`timescale 1ns/1ps
module tb_status_transport;
    reg sd_clk=0, mem_clk=0, pixel_clk=0, rst=1;
    always #5 sd_clk=~sd_clk;
    always #4 mem_clk=~mem_clk;
    always #20 pixel_clk=~pixel_clk;
    reg [7:0] source=0;
    wire [7:0] coherent;
    wire [3:0] selected, received;
    reg request=0;
    wire ack;
    wire [20:0] address;
    reg [7:0] sent;
    integer checks=0, i;
    reg test_passed=0;
    osd_status_cdc #(.WIDTH(8)) a(sd_clk,mem_clk,rst,source,coherent);
    osd_status_cdc #(.WIDTH(4)) b(mem_clk,pixel_clk,rst,selected,received);
    frame_fifo_read reader (
        .rst(rst),.mem_clk(mem_clk),.Sdr_init_done(1'b1),
        .Sdr_init_ref_vld(1'b0),.Sdr_busy(1'b0),.Sdr_rd_en(1'b0),
        .App_wr_busy(1'b1),.O_rd_busy(),.App_rd_en(),.App_rd_addr(address),
        .read_req(request),.read_req_ack(ack),.read_finish(),
        .read_addr_0(21'd1000),.read_addr_1(21'd5000),
        .read_addr_2(21'd9000),.read_addr_3(21'd13000),
        .read_addr_index(coherent[5:4]),.read_status(coherent),
        .read_frame_status(selected),.read_len(21'd307200),.fifo_aclr(),
        .wrusedw(10'd512));

    task settle;
        input [7:0] value;
        begin
            @(negedge sd_clk); source=value;
            repeat(30) @(negedge mem_clk);
            if(coherent!==value) $fatal(1,"FAIL mailbox convergence");
        end
    endtask
    task frame_request;
        input [7:0] value;
        reg [3:0] expected;
        begin
            settle(value);
            expected={value[7:6],value[4] ? value[3:2] : value[1:0]};
            @(negedge pixel_clk); request=1;
            wait(ack); @(negedge pixel_clk); request=0;
            wait(!ack); repeat(30) @(negedge pixel_clk);
            if(received!==expected || selected!==expected)
                $fatal(1,"FAIL frame tag got=%h expected=%h",received,expected);
            if(address!==(value[4] ? 21'd5000 : 21'd1000))
                $fatal(1,"FAIL bank/tag mismatch");
            checks=checks+1;
        end
    endtask
    initial begin
        repeat(5) @(negedge sd_clk); rst=0;
        frame_request(8'h00); // no valid image
        for(i=0;i<8;i=i+1) begin
            // Alternate banks, all indices and both AUTO states.
            sent={i[2],1'b1,1'b0,i[0],i[1:0],~i[1:0]};
            frame_request(sent);
            // A new commit during active video MUST NOT retag old pixels.
            settle(~sent);
            repeat(10) @(negedge pixel_clk);
            if(received!=={sent[7:6],sent[4]?sent[3:2]:sent[1:0]})
                $fatal(1,"FAIL tag changed without new frame read");
            checks=checks+1;
        end
        // Burst state changes coalesce; destination must eventually get latest.
        for(i=0;i<100;i=i+1) begin
            @(negedge sd_clk); source=i;
        end
        settle(8'hd6);
        #3 rst=1; #1;
        if(coherent!==0 || received!==0 || selected!==0) $fatal(1,"FAIL reset");
        repeat(5) @(negedge sd_clk); rst=0;
        frame_request(8'hd7);
        test_passed=1;
        $display("SIM PASS status transport checks=%0d; asynchronous clocks, bank/tag, mid-frame commit, reset",checks);
        $finish;
    end
    initial begin #1000000; $fatal(1,"FAIL timeout"); end
endmodule
