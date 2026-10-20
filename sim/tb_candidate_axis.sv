`timescale 1ns/1ps
module tb_candidate_axis;
    reg clk=0;
    always #5 clk=~clk;
    reg rst=1, vs=0, de=0;
    reg [23:0] rgb=0;
    wire user,valid,last;
    wire [23:0] data;
    reg test_passed=0;
    integer line_i,x,checks=0;
    video_rgb_to_axis_640x480 dut (
        .I_clk(clk),.I_rst(rst),.I_vs(vs),.I_de(de),.I_rgb(rgb),
        .O_video_user(user),.O_video_valid(valid),.O_video_last(last),.O_video_data(data)
    );
    initial begin #50000; $fatal(1,"FAIL timeout"); end
    initial begin
        repeat(2)@(negedge clk);
        rst=0;vs=1;
        repeat(3)@(negedge clk);
        for(line_i=0;line_i<2;line_i=line_i+1)begin
            for(x=0;x<640;x=x+1)begin
                @(negedge clk);de=1;rgb=line_i*640+x;
                @(posedge clk);#1;
                checks=checks+1;
                if(valid!==1 || data!==rgb || last!==(x==639) ||
                   user!==((line_i==0)&&(x==0)))
                    $fatal(1,"FAIL AXIS line=%0d x=%0d valid=%b last=%b expected_last=%b user=%b",
                           line_i,x,valid,last,(x==639),user);
            end
            @(negedge clk);de=0;rgb=0;
            repeat(4)@(negedge clk);
            if(valid!==0 || last!==0 || user!==0)$fatal(1,"FAIL blanking");
        end
        test_passed=1;
        $display("SIM PASS: candidate AXIS checks=%0d, line end at pixel 639",checks);
        $finish;
    end
endmodule
