`timescale 1ns/1ps
module tb_candidate_video;
    reg video_clk=0;
    always #5 video_clk=~video_clk;
    reg rst_all=1, display_valid=0;
    reg [23:0] pattern=0;
    wire [23:0] vout_data=display_valid ? pattern : 24'd0;
    reg de=0,hs=0,vs=0;
    wire axis_user,axis_valid,axis_last;
    wire [23:0] axis_data;
    reg test_passed=0;
    reg [26:0] pipe0=0,pipe1=0,pipe2=0,pipe3=0,expected;
    integer frame_i=0,h=0,v=0,checks=0,pixels=0,lines=0,frames=0;
    integer source_h=0,source_v=0,source_frame=0;
    reg [7:0] r,g,b;
    `include "top_osd_insert.vh"
    video_rgb_to_axis_640x480 axis_adapter (
        .I_clk(video_clk),.I_rst(rst_all),
        .I_vs(osd_video_vs),.I_de(osd_video_de),.I_rgb(osd_video_rgb),
        .O_video_user(axis_user),.O_video_valid(axis_valid),
        .O_video_last(axis_last),.O_video_data(axis_data)
    );

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

    always @(posedge video_clk or posedge rst_all)begin
        if(rst_all)begin
            pipe0=0;pipe1=0;pipe2=0;pipe3=0;
            #1;
            if({axis_user,axis_valid,axis_last,axis_data}!==27'd0)
                $fatal(1,"FAIL chain reset");
        end else begin
            expected=pipe3;pipe3=pipe2;pipe2=pipe1;pipe1=pipe0;
            pipe0={(de && source_h==0 && source_v==0),de,(de && source_h==639),
                   reference_rgb((source_frame>0)&&display_valid,de,source_h,source_v,vout_data)};
            #1;
            checks=checks+1;
            if({axis_user,axis_valid,axis_last,axis_data}!==expected)
                $fatal(1,"FAIL candidate chain t=%0t expected=%07h actual=%07h",
                       $time,expected,{axis_user,axis_valid,axis_last,axis_data});
            if(axis_valid)pixels=pixels+1;
            if(axis_last)lines=lines+1;
            if(axis_user)frames=frames+1;
        end
    end
    initial begin #15000000;$fatal(1,"FAIL timeout");end
    initial begin
        repeat(2)@(negedge video_clk);
        rst_all=0;
        // No extra unmodeled cycles between release and the first source pixel.
        for(frame_i=0;frame_i<3;frame_i=frame_i+1)
            for(v=0;v<525;v=v+1)
                for(h=0;h<800;h=h+1)begin
                    if(!(frame_i==0 && v==0 && h==0))@(negedge video_clk);
                    de=(h<640 && v<480);
                    source_h=h;source_v=v;source_frame=frame_i;
                    hs=!(h>=656 && h<752);
                    vs=!(v>=490 && v<492);
                    if(frame_i==0 && v==100 && h==100)display_valid=1;
                    r=(h*3+v)%240;g=(h+v*5)%240;b=(h*7+v*3)%240;
                    pattern={r,g,b};
                end
        @(negedge video_clk);
        de=0;hs=1;vs=1;pattern=0;
        repeat(7)@(negedge video_clk);
        if(pixels!=921600 || lines!=1440 || frames!=3)
            $fatal(1,"FAIL counts pixels=%0d lines=%0d frames=%0d",pixels,lines,frames);
        test_passed=1;
        $display("SIM PASS: actual candidate insertion + corrected AXIS checks=%0d pixels=%0d LAST=%0d SOF=%0d; five stages, startup black, frame-gated text.",
                 checks,pixels,lines,frames);
        $finish;
    end
endmodule
