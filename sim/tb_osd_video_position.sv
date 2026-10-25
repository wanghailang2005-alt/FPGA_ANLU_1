`timescale 1ns/1ps
module tb_osd_video_position;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1, enable = 1;
    reg [23:0] in_rgb = 0;
    reg in_de = 0, in_hs = 0, in_vs = 0;
    reg exp_valid = 0, exp_tick = 0;
    reg [9:0] exp_x = 0;
    reg [8:0] exp_y = 0;
    reg enable_d1 = 0;
    wire [23:0] p_rgb, pp_rgb, out_rgb;
    wire p_de,p_hs,p_vs,p_valid,p_tick;
    wire pp_de,pp_hs,pp_vs,pp_valid,pp_tick;
    wire [9:0] p_x,pp_x,out_x;
    wire [8:0] p_y,pp_y,out_y;
    wire out_de,out_hs,out_vs;
    reg test_passed = 0;
    reg [47:0] expect_position;
    reg [45:0] q0=0,q1=0,q2=0,expected;
    integer tag0=5,tag1=5,tag2=5,out_tag,frame_tag=5;
    integer checks=0,ticks=0,frame_i,h,v,i;
    integer complete_pixels[0:4];
    reg lock_expected=0;
    reg [7:0] r,g,b;
    osd_video_position position (
        .clk(clk),.rst(rst),.in_rgb(in_rgb),
        .in_de(in_de),.in_hs(in_hs),.in_vs(in_vs),
        .out_rgb(p_rgb),.out_de(p_de),.out_hs(p_hs),.out_vs(p_vs),
        .out_x(p_x),.out_y(p_y),.position_valid(p_valid),.frame_tick(p_tick)
    );
    // Same source with inverted VS verifies the positive-polarity parameter.
    osd_video_position #(.VS_ACTIVE(1'b1)) position_positive (
        .clk(clk),.rst(rst),.in_rgb(in_rgb),
        .in_de(in_de),.in_hs(in_hs),.in_vs(~in_vs),
        .out_rgb(pp_rgb),.out_de(pp_de),.out_hs(pp_hs),.out_vs(pp_vs),
        .out_x(pp_x),.out_y(pp_y),.position_valid(pp_valid),.frame_tick(pp_tick)
    );
    always @(posedge clk or posedge rst)
        if (rst) enable_d1 <= 0;
        else enable_d1 <= enable;
    osd_overlay overlay (
        .clk(clk),.rst(rst),.enable(enable_d1 && p_valid),
        .in_rgb(p_rgb),.in_de(p_de),.in_hs(p_hs),.in_vs(p_vs),
        .in_x(p_x),.in_y(p_y),.out_rgb(out_rgb),
        .out_de(out_de),.out_hs(out_hs),.out_vs(out_vs),
        .out_x(out_x),.out_y(out_y)
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
                if (foreground) reference_rgb = 24'h000000;
            end
        end
    endfunction

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            q0=0;q1=0;q2=0;
            tag0=5;tag1=5;tag2=5;
            #1;
            checks=checks+1;
            if ({p_valid,p_tick,p_de,p_hs,p_vs,p_x,p_y,p_rgb} !== 48'd0 ||
                {pp_valid,pp_tick,pp_de,pp_hs,pp_vs,pp_x,pp_y,pp_rgb} !== 48'd0 ||
                {out_de,out_hs,out_vs,out_x,out_y,out_rgb} !== 46'd0)
                $fatal(1,"FAIL reset");
        end else begin
            expect_position={exp_valid,exp_tick,in_de,in_hs,in_vs,exp_x,exp_y,in_rgb};
            expected=q2; q2=q1; q1=q0;
            q0={in_de,in_hs,in_vs,exp_x,exp_y,
                reference_rgb(enable && exp_valid,in_de,exp_x,exp_y,in_rgb)};
            out_tag=tag2;tag2=tag1;tag1=tag0;tag0=frame_tag;
            #1;
            checks=checks+3;
            if ({p_valid,p_tick,p_de,p_hs,p_vs,p_x,p_y,p_rgb} !== expect_position)
                $fatal(1,"FAIL position t=%0t expected=%012h got=%012h",
                       $time,expect_position,{p_valid,p_tick,p_de,p_hs,p_vs,p_x,p_y,p_rgb});
            if ({pp_valid,pp_tick,pp_de,pp_hs,~pp_vs,pp_x,pp_y,pp_rgb} !== expect_position)
                $fatal(1,"FAIL positive VS polarity");
            if ({out_de,out_hs,out_vs,out_x,out_y,out_rgb} !== expected)
                $fatal(1,"FAIL four-stage chain t=%0t expected=%012h got=%012h",
                       $time,expected,{out_de,out_hs,out_vs,out_x,out_y,out_rgb});
            if (p_tick) ticks=ticks+1;
            if(out_de && out_tag<5) complete_pixels[out_tag]=complete_pixels[out_tag]+1;
        end
    end
    initial begin
        #25000000;
        $fatal(1,"FAIL timeout");
    end
    initial begin
        for(i=0;i<5;i=i+1)complete_pixels[i]=0;
        #2;
        if($test$plusargs("FORCE_FAIL"))$fatal(1,"FAIL intentional harness check");
        repeat(2)@(negedge clk);
        rst=0;
        // Initial active/reset level is not an entire pulse. It must not lock.
        repeat(4)@(negedge clk);
        in_vs=1;
        repeat(3)@(negedge clk);
        for(i=0;i<5;i=i+1)begin
            @(negedge clk);
            in_de=1;in_rgb=24'h123456;
        end
        @(negedge clk);
        in_de=0;
        repeat(4)@(negedge clk);

        // Five actual frames. First frame acquires lock; frame 3 resets mid-line.
        // Frame 2 is bypass. Frames 1/2/4 must each retain exactly 307200 pixels.
        for(frame_i=0;frame_i<5;frame_i=frame_i+1)
            for(v=0;v<525;v=v+1)
                for(h=0;h<800;h=h+1)begin
                    @(negedge clk);
                    frame_tag=frame_i;
                    enable=(frame_i!=2);
                    in_de=(h<640 && v<480);
                    in_hs=!(h>=656 && h<752);
                    in_vs=!(v>=490 && v<492);
                    exp_tick=(v==492 && h==0);
                    if(exp_tick)lock_expected=1;
                    if(frame_i==3 && v==21 && h==100)begin
                        lock_expected=0;
                        rst=1;
                    end
                    if(frame_i==3 && v==21 && h==103)rst=0;
                    exp_valid=lock_expected && in_de;
                    exp_x=exp_valid ? h : 0;
                    exp_y=exp_valid ? v : 0;
                    r=(h*3+v+frame_i*13)%240;
                    g=(h+v*5+frame_i*17)%240;
                    b=(h*7+v*3+frame_i*11)%240;
                    in_rgb={r,g,b};
                end
        @(negedge clk);
        frame_tag=5;in_de=0;in_hs=1;in_vs=1;in_rgb=0;
        exp_valid=0;exp_tick=0;exp_x=0;exp_y=0;
        repeat(5)@(negedge clk);
        if(complete_pixels[1]!=307200 || complete_pixels[2]!=307200 ||
           complete_pixels[4]!=307200)
            $fatal(1,"FAIL complete frame counts %0d %0d %0d",
                   complete_pixels[1],complete_pixels[2],complete_pixels[4]);
        if(ticks!=5)$fatal(1,"FAIL VS must tick once per frame, ticks=%0d",ticks);

        // Counters must invalidate, not wrap, after an overlong active line.
        for(i=0;i<642;i=i+1)begin
            @(negedge clk);
            in_de=1;in_rgb=24'h234567;
            exp_valid=(i<640);
            exp_x=exp_valid ? i : 0;exp_y=0;
        end
        @(negedge clk);
        in_de=0;exp_valid=0;exp_x=0;
        repeat(2)@(negedge clk);
        in_de=1;exp_valid=1;exp_x=0;exp_y=1;
        @(negedge clk);
        in_de=0;exp_valid=0;exp_x=0;exp_y=0;
        repeat(6)@(negedge clk);
        test_passed=1;
        $display("SIM PASS: position/overlay checks=%0d frame_ticks=%0d complete_frames=%0d/%0d/%0d; both VS polarities, startup, mid-frame reset, overlong line, four stages.",
                 checks,ticks,complete_pixels[1],complete_pixels[2],complete_pixels[4]);
        $finish;
    end
endmodule
