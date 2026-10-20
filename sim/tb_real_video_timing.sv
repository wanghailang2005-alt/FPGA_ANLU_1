`timescale 1ns/1ps
module tb_real_video_timing;
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
    `include "top_osd_insert.vh"
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
    reg [26:0] pipe0=0,pipe1=0,pipe2=0,pipe3=0,expected;
    // Independent artwork fixtures for the eight letters in HELLO FPGA.
    function [63:0] bitmap;
        input [7:0] code;
        begin
            case (code)
                "H": bitmap = 64'h6666667e66666600;
                "E": bitmap = 64'h7e60607860607e00;
                "L": bitmap = 64'h6060606060607e00;
                "O": bitmap = 64'h3c66666666663c00;
                "F": bitmap = 64'h7e60607860606000;
                "P": bitmap = 64'h7c66667c60606000;
                "G": bitmap = 64'h3c66606e66663c00;
                "A": bitmap = 64'h183c667e66666600;
                default: bitmap = 0;
            endcase
        end
    endfunction

    function [23:0] reference_rgb;
        input en, de;
        input [9:0] x;
        input [8:0] y;
        input [23:0] background;
        reg [79:0] message;
        reg [63:0] whole;
        integer index, local_col, local_row;
        reg foreground;
        begin
            message = "HELLO FPGA";
            reference_rgb = de ? background : 24'd0;
            if (en && de && x >= 16 && x < 96 && y >= 16 && y < 32) begin
                index = (x - 16) / 8;
                local_col = (x - 16) % 8;
                local_row = (y - 16) / 2;
                whole = bitmap((message >> ((9-index)*8)) & 255);
                foreground = (whole >> (63 - local_row*8 - local_col)) & 1;
                if (foreground) reference_rgb = 24'hFFFFFF;
            end
        end
    endfunction


    initial begin
        if($test$plusargs("NO_OSD"))
            image_file=$fopen("real_timing_negative.ppm","w");
        else image_file=$fopen("../evidence/real_timing_osd.ppm","w");
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
        $display("SIM PASS real source: checks=%0d pixels=%0d LAST=%0d SOF=%0d ticks=%0d positions=%0d text=%0d preview=%0d",
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
                    if(axis_data==24'hffffff)text_pixels=text_pixels+1;
                    if(frames==3)begin
                        $fwrite(image_file,"%0d %0d %0d\n",axis_data[23:16],axis_data[15:8],axis_data[7:0]);
                        captured=captured+1;
                    end
                end
            end
        end
    end
    // First image commits partway through its first frame.
    initial begin
        wait(!rst_all);
        wait(pixels==10000);
        @(negedge video_clk);display_valid=1;
    end
endmodule
