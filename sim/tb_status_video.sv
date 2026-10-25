`timescale 1ns/1ps
module tb_status_video;
    localparam OSD_STATUS_MODE=1;
    reg video_clk=0;
    always #20 video_clk=~video_clk;
    reg rst_all=1, display_valid=0;
    wire hs0,vs0,de0,hs,vs,de,read_req,read_en;
    wire [23:0] raw_rgb;
    wire [23:0] vout_data=display_valid ? raw_rgb : 24'd0;
    // Constant dark-blue SDRAM substitute isolates timing and overlay.
    // The real timing generators and video delay are compiled unchanged.
    video_timing_data timing_source(.video_clk(video_clk),.rst(rst_all),
        .read_req(read_req),.read_req_ack(read_req),.hs(hs0),.vs(vs0),.de(de0));
    video_delay delay_source(.video_clk(video_clk),.rst(rst_all),
        .read_en(read_en),.read_data(24'h183048),.hs(hs0),.vs(vs0),.de(de0),
        .hs_r(hs),.vs_r(vs),.de_r(de),.vout_data(raw_rgb));
    reg memory_clk=0;
    always #4 memory_clk=~memory_clk;
    reg [3:0] memory_frame_status=0;
    wire [3:0] osd_pixel_status;
    osd_status_cdc #(.WIDTH(4)) status_cross (
        .src_clk(memory_clk),.dst_clk(video_clk),.rst(rst_all),
        .src_data(memory_frame_status),.dst_data(osd_pixel_status));
    `include "top_status_insert.vh"
    wire axis_user,axis_valid,axis_last;
    wire [23:0] axis_data;
    video_rgb_to_axis_640x480 axis_adapter(.I_clk(video_clk),.I_rst(rst_all),
        .I_vs(osd_video_vs),.I_de(osd_video_de),.I_rgb(osd_video_rgb),
        .O_video_user(axis_user),.O_video_valid(axis_valid),
        .O_video_last(axis_last),.O_video_data(axis_data));
    reg test_passed=0;
    integer cycles=0,checks=0,source_frame=0,x=0,y=0;
    integer pixels=0,lines=0,frames=0,ticks=0,positions=0,text_pixels=0,captured=0;
    integer image_file;
    reg prev_de=0,prev_vs=1;
    reg [3:0] expected_status=0;
    reg [26:0] pipe0=0,pipe1=0,pipe2=0,pipe3=0,expected;
    // Independent artwork fixtures for the eight letters in HELLO FPGA.
    function [63:0] bitmap;
        input [7:0] code;
        begin
            case (code)
                8'h20: bitmap = 64'h0000000000000000;
                8'h2b: bitmap = 64'h0018187e18180000;
                8'h2d: bitmap = 64'h0000007e00000000;
                8'h2e: bitmap = 64'h0000000000181800;
                8'h2f: bitmap = 64'h0003060c18306000;
                8'h30: bitmap = 64'h3c666e7666663c00;
                8'h31: bitmap = 64'h1818381818187e00;
                8'h32: bitmap = 64'h3c66060c30607e00;
                8'h33: bitmap = 64'h3c66061c06663c00;
                8'h34: bitmap = 64'h060e1e667f060600;
                8'h35: bitmap = 64'h7e607c0606663c00;
                8'h36: bitmap = 64'h3c66607c66663c00;
                8'h37: bitmap = 64'h7e660c1818181800;
                8'h38: bitmap = 64'h3c66663c66663c00;
                8'h39: bitmap = 64'h3c66663e06663c00;
                8'h3a: bitmap = 64'h0018180018180000;
                8'h3b: bitmap = 64'h0018180018183000;
                8'h41: bitmap = 64'h183c667e66666600;
                8'h42: bitmap = 64'h7c66667c66667c00;
                8'h43: bitmap = 64'h3c66606060663c00;
                8'h44: bitmap = 64'h786c6666666c7800;
                8'h45: bitmap = 64'h7e60607860607e00;
                8'h46: bitmap = 64'h7e60607860606000;
                8'h47: bitmap = 64'h3c66606e66663c00;
                8'h48: bitmap = 64'h6666667e66666600;
                8'h49: bitmap = 64'h3c18181818183c00;
                8'h4a: bitmap = 64'h1e0c0c0c0c6c3800;
                8'h4b: bitmap = 64'h666c7870786c6600;
                8'h4c: bitmap = 64'h6060606060607e00;
                8'h4d: bitmap = 64'h63777f6b63636300;
                8'h4e: bitmap = 64'h66767e7e6e666600;
                8'h4f: bitmap = 64'h3c66666666663c00;
                8'h50: bitmap = 64'h7c66667c60606000;
                8'h51: bitmap = 64'h3c666666663c0e00;
                8'h52: bitmap = 64'h7c66667c786c6600;
                8'h53: bitmap = 64'h3c66603c06663c00;
                8'h54: bitmap = 64'h7e18181818181800;
                8'h55: bitmap = 64'h6666666666663c00;
                8'h56: bitmap = 64'h66666666663c1800;
                8'h57: bitmap = 64'h6363636b7f776300;
                8'h58: bitmap = 64'h66663c183c666600;
                8'h59: bitmap = 64'h6666663c18181800;
                8'h5a: bitmap = 64'h7e060c1830607e00;
                default: bitmap = 64'h0000000000000000;
            endcase
        end
    endfunction

    function [23:0] reference_rgb;
        input en, de;
        input [9:0] x;
        input [8:0] y;
        input [23:0] background;
        reg [63:0] message;
        reg [63:0] whole;
        integer index, local_col, local_row;
        reg foreground;
        begin
            reference_rgb=de ? background : 24'd0;
            if(en && de && x>=16 && x<80 &&
                ((y>=16 && y<32) || (y>=40 && y<56))) begin
                if(y<32) begin
                    message={"IMG:",(expected_status[2] ? (8'h31+{6'd0,expected_status[1:0]}):8'h2d),"   "};
                    local_row=(y-16)/2;
                end else begin
                    message=expected_status[3] ? "AUTO:ON " : "AUTO:OFF";
                    local_row=(y-40)/2;
                end
                index=(x-16)/8; local_col=(x-16)%8;
                whole=bitmap((message >> ((7-index)*8)) & 255);
                foreground=(whole >> (63-local_row*8-local_col)) & 1;
                if(foreground) reference_rgb=0;
            end
        end
    endfunction


    initial begin
        if($test$plusargs("NO_OSD"))
            image_file=$fopen("real_timing_negative.ppm","w");
        else image_file=$fopen("../evidence/status_video.ppm","w");
        if(!image_file)$fatal(1,"FAIL opening preview");
        $fwrite(image_file,"P3\n640 480\n255\n");
        repeat(8)@(negedge video_clk);
        rst_all=0;
        wait(source_frame==4);
        repeat(10)@(negedge video_clk);
        if(pixels!=1228800 || lines!=1920 || frames!=4 || ticks<3 ||
           captured!=307200 || text_pixels==0 || positions!=921600)
            $fatal(1,"FAIL counts pixels=%0d LAST=%0d SOF=%0d ticks=%0d positions=%0d text=%0d captured=%0d",
                pixels,lines,frames,ticks,positions,text_pixels,captured);
        $fclose(image_file);
        test_passed=1;
        $display("SIM PASS dynamic real source: checks=%0d pixels=%0d LAST=%0d SOF=%0d ticks=%0d positions=%0d text=%0d preview=%0d",
            checks,pixels,lines,frames,ticks,positions,text_pixels,captured);
        $finish;
    end
    // Negative control: reproduce a permanently disabled subtitle.
    initial if($test$plusargs("NO_OSD")) force osd_enable_frame=1'b0;
    initial begin #100000000;$fatal(1,"FAIL timeout");end
    // Independent coordinates follow observed active-pixel and line edges,
    // rather than the OSD counters or generator's internal counters.
    always @(posedge video_clk)begin
        if(!rst_all)begin
            cycles=cycles+1;
            if(cycles>32)begin
                if(prev_vs && !vs)begin x=0;y=0;end
                if(!de && prev_de)begin
                    if(x!=640)$fatal(1,"FAIL real line length %0d",x);
                    x=0;y=y+1;
                    if(y==480)source_frame=source_frame+1;
                end
                if(de && !prev_de && y==0) expected_status=memory_frame_status;
                expected=pipe3;pipe3=pipe2;pipe2=pipe1;pipe1=pipe0;
                pipe0={(de && x==0 && y==0),de,(de && x==639),
                    reference_rgb(source_frame>=1,de,x,y,vout_data)};
                if(de)begin
                    if(y>=480)$fatal(1,"FAIL real frame height");
                    x=x+1;
                end
                prev_de=de;prev_vs=vs;
                #1;
                checks=checks+1;
                if(osd_frame_tick)begin
                    ticks=ticks+1;
                    $display("FRAME tick=%0d display_sync=%b enable=%b t=%0t",ticks,osd_display_sync,osd_enable_frame,$time);
                end
                if(osd_pos_de)begin
                    if(source_frame>=1 && !osd_position_valid)
                        $fatal(1,"FAIL missing position after acquisition");
                    if(osd_position_valid)positions=positions+1;
                end
                if({axis_user,axis_valid,axis_last,axis_data}!==expected)
                    $fatal(1,"FAIL real chain t=%0t expected=%07h actual=%07h enable=%b position=%b",
                        $time,expected,{axis_user,axis_valid,axis_last,axis_data},osd_enable_frame,osd_position_valid);
                if(axis_user)frames=frames+1;
                if(axis_last)lines=lines+1;
                if(axis_valid)begin
                    pixels=pixels+1;
                    if(axis_data==24'h000000)text_pixels=text_pixels+1;
                    if(frames==3)begin
                        $fwrite(image_file,"%0d %0d %0d\n",axis_data[23:16],axis_data[15:8],axis_data[7:0]);
                        captured=captured+1;
                    end
                end
            end
        end
    end
    initial begin
        wait(!rst_all);
        wait(pixels==10000); @(negedge memory_clk); memory_frame_status=4'b0100;
        wait(pixels==400000); @(negedge memory_clk); memory_frame_status=4'b1101;
        wait(pixels==750000); @(negedge memory_clk); memory_frame_status=4'b0111;
    end
    // First image commits partway through its first frame.
    initial begin
        wait(!rst_all);
        wait(pixels==10000);
        @(negedge video_clk);display_valid=1;
    end
endmodule
