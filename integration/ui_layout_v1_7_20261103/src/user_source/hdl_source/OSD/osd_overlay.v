`timescale 1ns/1ps
// Four-region UI: photo, sidebar, audio band, opaque bilingual subtitle band.
// RGB/DE/HS/VS/X/Y retain three matched register stages.
// enable must be stable for an active frame; frame-boundary control is upstream.
//
// text_mode  : 0=文字关闭 1=只显示固定状态 OSD 2=只显示滚动字幕 3=两者同时
// scroll_speed: 0=慢(1 像素/帧) 1=中(2 像素/帧) 2=快(4 像素/帧)
// scroll_dir : 0=向左 1=向右
//
// 滚动位置只在每帧消隐边界（VS 起始沿）更新一次，一帧有效区内保持不变。
// 方向改变时保留当前位置，下一帧起反向移动；字幕完全移出后从另一侧进入。
// Brightness and contrast feedback remain in the right sidebar.
// sub_mode 控制中英双语字幕层：0=关闭 1=只中文 2=只英文 3=双语上下叠加。
module osd_overlay #(parameter STATUS_MODE=0, parameter SCROLL_ENABLE=1) (
    input wire clk,
    input wire rst,
    input wire enable,
    // Frame-stable: compact bilingual card beside the audio spectrum panel.
    input wire compact_layout,
    input wire [1:0] scale_mode,
    input wire interpolation,
    input wire [2:0] transition_mode,
    input wire image_valid,
    input wire [1:0] image_index,
    input wire auto_play,
    input wire [3:0] sw_code,
    input wire [3:0] setting_value,
    input wire [3:0] brightness,
    input wire [3:0] contrast,
    input wire [1:0] sub_mode,
    input wire [1:0] text_mode,
    input wire [1:0] scroll_speed,
    input wire scroll_dir,
    input wire [23:0] in_rgb,
    input wire in_de, in_hs, in_vs,
    input wire [9:0] in_x,
    input wire [8:0] in_y,
    output reg [23:0] out_rgb,
    output reg out_de, out_hs, out_vs,
    output reg [9:0] out_x,
    output reg [8:0] out_y
);
    wire text_valid, glyph_valid, pixel_on;
    wire [7:0] char_code;
    wire [2:0] glyph_x;
    wire [3:0] glyph_y;

    // ==== 以下由 tools/gen_captions.py 自动生成，请勿手工修改 ====
    // 素材包「古村落」4 条解说字幕：126 个字格，93 个不同字形
    localparam integer ZH_TOTAL  = 126;
    localparam integer ZH_GLYPHS = 93;

    // 字幕序号 -> 该字幕在字格序列中的起点 / 长度
    function [7:0] cap_start;
        input [1:0] c;
        begin
            case (c)
                2'd0: cap_start = 8'd0;
                2'd1: cap_start = 8'd30;
                2'd2: cap_start = 8'd70;
                2'd3: cap_start = 8'd91;
                default: cap_start = 8'd0;
            endcase
        end
    endfunction

    function [7:0] cap_len;
        input [1:0] c;
        begin
            case (c)
                2'd0: cap_len = 8'd30;
                2'd1: cap_len = 8'd40;
                2'd2: cap_len = 8'd21;
                2'd3: cap_len = 8'd35;
                default: cap_len = 8'd0;
            endcase
        end
    endfunction

    // 字格序号 -> 字形序号
    function [6:0] cap_char;
        input [7:0] idx;
        begin
            case (idx)
                8'd0: cap_char = 7'd0;
                8'd1: cap_char = 7'd1;
                8'd2: cap_char = 7'd2;
                8'd3: cap_char = 7'd3;
                8'd4: cap_char = 7'd4;
                8'd5: cap_char = 7'd5;
                8'd6: cap_char = 7'd6;
                8'd7: cap_char = 7'd7;
                8'd8: cap_char = 7'd8;
                8'd9: cap_char = 7'd9;
                8'd10: cap_char = 7'd2;
                8'd11: cap_char = 7'd10;
                8'd12: cap_char = 7'd11;
                8'd13: cap_char = 7'd12;
                8'd14: cap_char = 7'd13;
                8'd15: cap_char = 7'd14;
                8'd16: cap_char = 7'd15;
                8'd17: cap_char = 7'd16;
                8'd18: cap_char = 7'd17;
                8'd19: cap_char = 7'd18;
                8'd20: cap_char = 7'd2;
                8'd21: cap_char = 7'd19;
                8'd22: cap_char = 7'd20;
                8'd23: cap_char = 7'd21;
                8'd24: cap_char = 7'd22;
                8'd25: cap_char = 7'd23;
                8'd26: cap_char = 7'd24;
                8'd27: cap_char = 7'd25;
                8'd28: cap_char = 7'd1;
                8'd29: cap_char = 7'd26;
                8'd30: cap_char = 7'd27;
                8'd31: cap_char = 7'd28;
                8'd32: cap_char = 7'd29;
                8'd33: cap_char = 7'd30;
                8'd34: cap_char = 7'd31;
                8'd35: cap_char = 7'd32;
                8'd36: cap_char = 7'd33;
                8'd37: cap_char = 7'd2;
                8'd38: cap_char = 7'd34;
                8'd39: cap_char = 7'd35;
                8'd40: cap_char = 7'd36;
                8'd41: cap_char = 7'd37;
                8'd42: cap_char = 7'd38;
                8'd43: cap_char = 7'd39;
                8'd44: cap_char = 7'd40;
                8'd45: cap_char = 7'd41;
                8'd46: cap_char = 7'd42;
                8'd47: cap_char = 7'd2;
                8'd48: cap_char = 7'd19;
                8'd49: cap_char = 7'd20;
                8'd50: cap_char = 7'd21;
                8'd51: cap_char = 7'd22;
                8'd52: cap_char = 7'd43;
                8'd53: cap_char = 7'd18;
                8'd54: cap_char = 7'd44;
                8'd55: cap_char = 7'd45;
                8'd56: cap_char = 7'd26;
                8'd57: cap_char = 7'd2;
                8'd58: cap_char = 7'd46;
                8'd59: cap_char = 7'd47;
                8'd60: cap_char = 7'd9;
                8'd61: cap_char = 7'd43;
                8'd62: cap_char = 7'd18;
                8'd63: cap_char = 7'd35;
                8'd64: cap_char = 7'd48;
                8'd65: cap_char = 7'd49;
                8'd66: cap_char = 7'd50;
                8'd67: cap_char = 7'd51;
                8'd68: cap_char = 7'd52;
                8'd69: cap_char = 7'd53;
                8'd70: cap_char = 7'd0;
                8'd71: cap_char = 7'd1;
                8'd72: cap_char = 7'd54;
                8'd73: cap_char = 7'd55;
                8'd74: cap_char = 7'd56;
                8'd75: cap_char = 7'd57;
                8'd76: cap_char = 7'd58;
                8'd77: cap_char = 7'd2;
                8'd78: cap_char = 7'd59;
                8'd79: cap_char = 7'd60;
                8'd80: cap_char = 7'd61;
                8'd81: cap_char = 7'd1;
                8'd82: cap_char = 7'd62;
                8'd83: cap_char = 7'd63;
                8'd84: cap_char = 7'd17;
                8'd85: cap_char = 7'd18;
                8'd86: cap_char = 7'd49;
                8'd87: cap_char = 7'd64;
                8'd88: cap_char = 7'd65;
                8'd89: cap_char = 7'd66;
                8'd90: cap_char = 7'd67;
                8'd91: cap_char = 7'd30;
                8'd92: cap_char = 7'd31;
                8'd93: cap_char = 7'd11;
                8'd94: cap_char = 7'd68;
                8'd95: cap_char = 7'd69;
                8'd96: cap_char = 7'd70;
                8'd97: cap_char = 7'd71;
                8'd98: cap_char = 7'd72;
                8'd99: cap_char = 7'd73;
                8'd100: cap_char = 7'd74;
                8'd101: cap_char = 7'd75;
                8'd102: cap_char = 7'd76;
                8'd103: cap_char = 7'd2;
                8'd104: cap_char = 7'd77;
                8'd105: cap_char = 7'd78;
                8'd106: cap_char = 7'd79;
                8'd107: cap_char = 7'd80;
                8'd108: cap_char = 7'd2;
                8'd109: cap_char = 7'd81;
                8'd110: cap_char = 7'd82;
                8'd111: cap_char = 7'd83;
                8'd112: cap_char = 7'd84;
                8'd113: cap_char = 7'd85;
                8'd114: cap_char = 7'd86;
                8'd115: cap_char = 7'd2;
                8'd116: cap_char = 7'd46;
                8'd117: cap_char = 7'd87;
                8'd118: cap_char = 7'd13;
                8'd119: cap_char = 7'd43;
                8'd120: cap_char = 7'd88;
                8'd121: cap_char = 7'd49;
                8'd122: cap_char = 7'd89;
                8'd123: cap_char = 7'd90;
                8'd124: cap_char = 7'd91;
                8'd125: cap_char = 7'd92;
                default: cap_char = 7'd0;
            endcase
        end
    endfunction

    // 字形序号 + 行号 -> 16 位点阵（16px 宋体二值化）
    function [15:0] zh_glyph_row;
        input [6:0] g;
        input [3:0] row;
        reg [255:0] bmp;
        begin
            case (g)
                7'd0  : bmp = 256'h0200fffc800404080400fff808000900110012002200444088201ff008100000; // 宏
                7'd1  : bmp = 256'h202020202020fbfc202060207020aa20a920212020202020202020a020400000; // 村
                7'd2  : bmp = 256'h0000000000000000000000000000000000000000600060002000400000000000; // ，
                7'd3  : bmp = 256'h2440244024402440fffc244024402440244027c02000200020003ff800000000; // 世
                7'd4  : bmp = 256'h3fe0222022203fe0222022203fe0050018c068b0888c08801080108020800000; // 界
                7'd5  : bmp = 256'h02000200fffc20202020104010400880050002000500088010406030800c0000; // 文
                7'd6  : bmp = 256'h110011082110212061406180a10023002500290021042104210420fc20000000; // 化
                7'd7  : bmp = 256'h47f0249027f000801ffce00027f02410249024902140222054108ffc00000000; // 遗
                7'd8  : bmp = 256'h0200fff800001040084008807ffc400040004000400040008000800000000000; // 产
                7'd9  : bmp = 256'h2040204022402258fa6822c827482248226822503a44c244820401fc00000000; // 地
                7'd10 : bmp = 256'h204020402080f89049084bfc4904480091f8510821085108890801f801080000; // 始
                7'd11 : bmp = 256'h0080f7f010902ffc209047f0f08017f0108090806ff82080588087fc00000000; // 建
                7'd12 : bmp = 256'h7ff00200020002000200fffc02000200020002000200020002000a0004000000; // 于
                7'd13 : bmp = 256'h0200fffc02000200fff8904888889fc882088208bfe882088208822880100000; // 南
                7'd14 : bmp = 256'h0200fffc8004020802000200fff807000a80124022204210820c020002000000; // 宋
                7'd15 : bmp = 256'h27f8410841089108f208222844108800f3f8820802083208c20883f802080000; // 绍
                7'd16 : bmp = 256'h041042102220102010400080fffc000008800840102010102010400880080000; // 兴
                7'd17 : bmp = 256'h20003ff84100410081003ff0210021002100fffc010001000100010001000000; // 年
                7'd18 : bmp = 256'h27f8200880088f888888888888888f888888888888888f888008802880100000; // 间
                7'd19 : bmp = 256'h20200020f3fc122422282a2073f8aa8822882250225022202450248829040000; // 被
                7'd20 : bmp = 256'h221022200040fffc104022205fd0800c3fe000003fe000003fe020203fe00000; // 誉
                7'd21 : bmp = 256'h4200220022000200fff00410041005100890089010102010401080a000400000; // 为
                7'd22 : bmp = 256'h0110022004400660066000000000000000000000000000000000000000000000; // “
                7'd23 : bmp = 256'hfffc000000009fc8924892489fc89248924892489fc880088008fff800080000; // 画
                7'd24 : bmp = 256'h7ff0421042107ff0421042107ff0020002007ff0020002000200fffc00000000; // 里
                7'd25 : bmp = 256'h04000840104020807f000210041008203fc00080010002000c003000c0000000; // 乡
                7'd26 : bmp = 256'h3300330011002200440000000000000000000000000000000000000000000000; // ”
                7'd27 : bmp = 256'h008001000208f2501fe0124022202fa0421042109fc8020402000a0004000000; // 承
                7'd28 : bmp = 256'h02000200fffc0200020002007ff00000020011109108902490240fe000000000; // 志
                7'd29 : bmp = 256'h22201240fffc80043fe8202020203fe0020002007ff002000200fffc00000000; // 堂
                7'd30 : bmp = 256'h352055209f40007c3f884848d1485e48445049507fa04450555064884d040000; // 徽
                7'd31 : bmp = 256'h40782f80280008388bc08a402a442a484a50ca204a204a105288530422000000; // 派
                7'd32 : bmp = 256'h020002000200fff807000a800a80124022204210820802040200020002000000; // 木
                7'd33 : bmp = 256'hfe48928092fcbb909290fefc8290ba90aafcaa90ba90829082fc8a8004800000; // 雕
                7'd34 : bmp = 256'h00007ff00410041004100410041004100810081010101010201040a080400000; // 刀
                7'd35 : bmp = 256'h0000fff80200020002000200020002000200020002000200fffc000000000000; // 工
                7'd36 : bmp = 256'h20402bfca840b1f82040fbfc600071f8a908a9f8210821f82108212821100000; // 精
                7'd37 : bmp = 256'h42102ffc221003f0821093f0121022102ffcc4a045104608440047f800000000; // 湛
                7'd38 : bmp = 256'h0000000000000000000000000000000000004000300018000800000000000000; // 、
                7'd39 : bmp = 256'h200043f84a488a48f2482248424883f8fa48824802483a48c24883f802080000; // 细
                7'd40 : bmp = 256'h1040fffc104010400000fff0041004100410041004a004400400040004000000; // 节
                7'd41 : bmp = 256'h7e40807c7c905550fe509420fe50088c11003e0004207ff002102a4044200000; // 繁
                7'd42 : bmp = 256'h20003ff84000bfe020203fe020203fe008001fe03040c880070038e0c01c0000; // 复
                7'd43 : bmp = 256'h7ff04010401040107ff0410041007ff841004080408048485028601840080000; // 民
                7'd44 : bmp = 256'h208020802100fdfc221025102110f91088a088a0884088a0f9108a0804040000; // 故
                7'd45 : bmp = 256'h0200fffc800400083fe0202020203fe000007ff04010401040107ff040100000; // 宫
                7'd46 : bmp = 256'h202020203fe0202020203fe00000fffc0200220023f0220052008a0007fc0000; // 是
                7'd47 : bmp = 256'h020002000200fff807000a800a801240222042109fc802040200020002000000; // 本
                7'd48 : bmp = 256'h1040fffc1040104000007fc001800600080010002000400840083ff800000000; // 艺
                7'd49 : bmp = 256'h20804080fcf88508850886088488fc488448840884088408fc08845000200000; // 的
                7'd50 : bmp = 256'h02000200fff807000a80124022204210820c0200000049104488848800080000; // 杰
                7'd51 : bmp = 256'h020042104210421042107ff00210020002008208820882088208fff800080000; // 出
                7'd52 : bmp = 256'h111011102100217c6f806100a080208020802040204420242014200c20040000; // 代
                7'd53 : bmp = 256'h0200fff8020002007ff002000200fffc0a00111030a050409230140c18000000; // 表
                7'd54 : bmp = 256'h7ffc40004100410041005ff84108410842084208440844088808905020200000; // 历
                7'd55 : bmp = 256'h020002007ff04210421042107ff042100200220012000c000b0030e0c01c0000; // 史
                7'd56 : bmp = 256'h04107fa004400480fffc02000400182031c05e009010101010100ff000000000; // 老
                7'd57 : bmp = 256'hfbf88888888888888928fa1089f8890889088908f9f800009110888808880000; // 照
                7'd58 : bmp = 256'h20802080208020803ff82000200020003fc02040204020404040404080400000; // 片
                7'd59 : bmp = 256'h3fe0202020202220222022202220222025202520090009001104610480fc0000; // 见
                7'd60 : bmp = 256'h400027fc204000400040e24022402278224022402a40324022400ffc00000000; // 证
                7'd61 : bmp = 256'h020002000200fffc0200020002003fe0202020202020202020203fe020200000; // 古
                7'd62 : bmp = 256'h1040fffc1040410021f02210052090c093302c0cc3f04210421043f042100000; // 落
                7'd63 : bmp = 256'hfffc0200040008007ff04010401040107ff040104010401040107ff040100000; // 百
                7'd64 : bmp = 256'h210821102000f7fc2040604073f8a840a04027fc204020402040204020400000; // 样
                7'd65 : bmp = 256'h608087f82a08920863f892082a084bf898a028a048a089240924521c24000000; // 貌
                7'd66 : bmp = 256'h0200fffc088028a04890888800007fe010400880050002000d803060c01c0000; // 变
                7'd67 : bmp = 256'h40f02780208000800080effc20802080208020802080208050008ffc00000000; // 迁
                7'd68 : bmp = 256'h20807efc91200a100000fbe022202220232022a03a24c4248424081c10000000; // 筑
                7'd69 : bmp = 256'hffc0004000402040204020403ff8000800080008ffc800080008005000200000; // 马
                7'd70 : bmp = 256'h0100110009004900210021000100fffc02000280044008201010600880080000; // 头
                7'd71 : bmp = 256'h40804ff840804490f2a04ffc400047f0441045d07550c5d0841007f004100000; // 墙
                7'd72 : bmp = 256'h200020003ff82000400040007ff0001000100010ff900010001000a000400000; // 与
                7'd73 : bmp = 256'h7ff00200020002000200fffc02000500050008800880104020204010800c0000; // 天
                7'd74 : bmp = 256'h104010401040fff81040104010401040fffc1040104020402040404080400000; // 井
                7'd75 : bmp = 256'h204040404ffc8840f04023f840008000fbf8820802083a08c20883f802080000; // 结
                7'd76 : bmp = 256'h2100210021f8fa08220864887088a908a948222823e820282008205020200000; // 构
                7'd77 : bmp = 256'h0200fff802007ff00200fffc00003fe020203fe020203fe0202020a020400000; // 青
                7'd78 : bmp = 256'h0040f84023f8204040807bfcc880c9004bf84808491078a04840402000200000; // 砖
                7'd79 : bmp = 256'h211060fcaf8020442034000c7ff052504a907ff00200fff80200fffc88880000; // 黛
                7'd80 : bmp = 256'hfffc0800080008000fc010401440124012401040204426443844203c00000000; // 瓦
                7'd81 : bmp = 256'hfbf888408840fa408a408bfcf8408040906088a094a0a524c124821c04000000; // 既
                7'd82 : bmp = 256'hf840884097fc9100a100910091f8890889088908d108a2088208845088200000; // 防
                7'd83 : bmp = 256'h02000200221022102220424042008500050008800880104020204010800c0000; // 火
                7'd84 : bmp = 256'h7fe02020202020401040104008800880050002000500088010406030800c0000; // 又
                7'd85 : bmp = 256'h44f87c0844507c204750fc88040001f0fe0012082310c6a00a403230c20c0000; // 聚
                7'd86 : bmp = 256'h20007ff840009fe000007fe00020002000200020002000140014000c00040000; // 气
                7'd87 : bmp = 256'h40002ff82080008080809080108020802080c080408040805ffc400000000000; // 江
                7'd88 : bmp = 256'h7ff0401040107ff0410041007ffc410041005ff05010901090101ff010100000; // 居
                7'd89 : bmp = 256'h088008807ff04890489048907ff0489048904890fffc08801040202040100000; // 典
                7'd90 : bmp = 256'hff08244824482448ff48244844084428821002007ff002000200fffc00000000; // 型
                7'd91 : bmp = 256'h2040a040a3f8f840a04027fc20103810e3fca010211020902010205020200000; // 特
                7'd92 : bmp = 256'h100027fc40409040104022406240a278224022402240224022402ffc20000000; // 征
                default: bmp = 256'h0;
            endcase
            zh_glyph_row = bmp[255 - {row, 4'b0000} -: 16];
        end
    endfunction

    // 英文字幕：每张图一行 32 字符的标题，居中补空格
    function [7:0] sub_en_glyph;
        input [1:0] c;
        input [4:0] idx;
        reg [255:0] str;
        begin
            case (c)
                2'd0: str = 256'h20202020202020484f4e4743554e204d4f4f4e20504f4e442020202020202020; // "HONGCUN MOON POND"
                2'd1: str = 256'h20202020204348454e475a48492048414c4c2043415256494e47202020202020; // "CHENGZHI HALL CARVING"
                2'd2: str = 256'h20202020202020484f4e4743554e204f4c442050484f544f5320202020202020; // "HONGCUN OLD PHOTOS"
                2'd3: str = 256'h20202020202048554920484f5253452d484541442057414c4c20202020202020; // "HUI HORSE-HEAD WALL"
                default: str = 256'h0;
            endcase
            sub_en_glyph = str[255 - {idx, 3'b000} -: 8];
        end
    endfunction
    // ==== 生成区结束 ====

    // Sidebar visibility follows the existing fixed-text enable bit.
    reg [1:0] text_mode_frame;
    reg vs_prev;
    wire frame_tick=vs_prev && !in_vs && !in_de;
    wire fixed_on=enable && text_mode_frame[0];
    always @(posedge clk or posedge rst)begin
      if(rst)begin text_mode_frame<=0;vs_prev<=0;end
      else begin vs_prev<=in_vs;if(frame_tick)text_mode_frame<=text_mode;end
    end

    // ---------------- 中英文双语字幕 ----------------
    // sub_mode: 0=关闭 1=只中文 2=只英文 3=双语上下叠加
    // Chinese: y=432..447; short captions centered, long captions pause then scroll.
    // English: y=456..471, static title, independent of photo colors.
    localparam [9:0] ZH_Y0 = 10'd432;
    localparam [9:0] EN_LEN = 10'd256;   // 32 字符 x 8 像素
    wire [9:0] en_x0 = 10'd16;
    wire [10:0] zh_view_x0 = 11'd16;
    wire [10:0] zh_view_width = 11'd608;

    wire sub_zh_on = enable && in_de && ((sub_mode == 2'd1) || (sub_mode == 2'd3));
    wire sub_en_on = enable && in_de && ((sub_mode == 2'd2) || (sub_mode == 2'd3));

    // ---------- 中文跑马灯 ----------
    wire [7:0]  zh_len   = cap_len(image_index);
    wire [10:0] zh_trip  = {3'd0, zh_len} << 4;         // 文字宽度 = 字数 x 16
    wire [10:0] zh_total = zh_trip + zh_view_width;

    reg [6:0] zh_pause;
    reg [10:0] zh_pos;        // 文字左边缘 + trip：0=完全在左侧外，total=完全在右侧外
    reg [1:0]  zh_cap_seen;
    reg        zh_compact_seen;
    reg        zh_vs_prev;
    wire zh_frame = zh_vs_prev && !in_vs && !in_de;
    wire [10:0] zh_step = (scroll_speed == 2'd0) ? 11'd1 :
                          (scroll_speed == 2'd1) ? 11'd2 : 11'd4;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            zh_pos <= 11'd0; zh_pause<=7'd60;
            zh_cap_seen <= 2'd3;
            zh_compact_seen <= 1'b0;
            zh_vs_prev  <= 1'b0;
        end else begin
            zh_vs_prev <= in_vs;
            if (image_index != zh_cap_seen || compact_layout != zh_compact_seen) begin
                // Start readable at the left edge, then allow a 60-frame reading pause.
                zh_cap_seen <= image_index;
                zh_compact_seen <= compact_layout;
                zh_pos <= zh_trip; zh_pause<=7'd60;
            end else if (zh_pos > zh_total) begin
                zh_pos <= zh_total;      // 字幕长度变化时收回有效范围
            end else if (zh_frame) begin
                if (zh_trip <= zh_view_width) begin
                    zh_pos <= zh_trip + ((zh_view_width-zh_trip) >> 1);
                end else if (zh_pause != 0) begin
                    zh_pause <= zh_pause-1'b1;
                end else if (scroll_dir) begin
                    if (zh_pos + zh_step >= zh_total) zh_pos <= 11'd0;
                    else                              zh_pos <= zh_pos + zh_step;
                end else begin
                    if (zh_pos < zh_step) zh_pos <= zh_total;
                    else                  zh_pos <= zh_pos - zh_step;
                end
            end
        end
    end

    wire [10:0] zh_local = {1'b0, in_x} - zh_view_x0 + zh_trip - zh_pos;
    wire        zh_req_valid = sub_zh_on && (in_y >= ZH_Y0) && (in_y < ZH_Y0 + 10'd16) &&
                               ({1'b0, in_x} >= zh_view_x0) &&
                               ({1'b0, in_x} < zh_view_x0 + zh_view_width) &&
                               (zh_local < zh_trip);
    wire [7:0]  zh_char_idx = cap_start(image_index) + {4'd0, zh_local[9:4]};
    wire [6:0]  zh_gid = cap_char(zh_char_idx);
    wire [3:0]  zh_gx  = zh_local[3:0];
    wire [3:0]  zh_gy  = in_y[3:0];      // 400 是 16 的整数倍

    // 中文 16x16 采用与 ASCII 字形通路相同的两级流水（整体 2 拍延迟）
    // Use the existing exact glyph table only at elaboration. A synchronous
    // block-ROM read replaces its large combinational mux without another
    // video stage. Unused glyph IDs retain the function's zero default.
    (* rom_style="bram", ram_style="bram" *) reg [15:0] zh_font_rom[0:2047];
    integer zh_font_init;
    initial begin
        for (zh_font_init=0; zh_font_init<2048; zh_font_init=zh_font_init+1)
            zh_font_rom[zh_font_init] = zh_glyph_row(zh_font_init[10:4], zh_font_init[3:0]);
    end
    reg [15:0] zh_row;
    reg        zh_v1, zh_v2, zh_pix;
    reg [3:0]  zh_gx_d1;
    // No asynchronous data reset: zh_v1/zh_v2 gate the ROM pipeline on reset.
    always @(posedge clk)
        zh_row <= zh_font_rom[{zh_gid, zh_gy}];
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            zh_v1    <= 1'b0;
            zh_v2    <= 1'b0;
            zh_pix   <= 1'b0;
            zh_gx_d1 <= 4'd0;
        end else begin
            zh_v1    <= zh_req_valid;
            zh_gx_d1 <= zh_req_valid ? zh_gx : 4'd0;
            zh_v2    <= zh_v1;
            zh_pix   <= zh_v1 ? zh_row[4'd15 - zh_gx_d1] : 1'b0;
        end
    end

    // ---------- 英文静态标题 ----------
    wire [9:0] en_local = in_x - en_x0;
    wire [8:0] en_y_ofs = in_y - 9'd456;
    wire sub_en_valid = sub_en_on && (in_x >= en_x0) && (in_x < en_x0 + EN_LEN) &&
                        (in_y >= 9'd456) && (in_y < 9'd472);
    wire [2:0] en_gx = en_local[2:0];
    wire [3:0] en_gy = en_y_ofs[3:0];

    wire [7:0] sub_en_char = sub_en_glyph(image_index, en_local[7:3]);

    assign text_valid=sub_en_valid;
    assign char_code=sub_en_char;
    assign glyph_x=en_gx;
    assign glyph_y=en_gy;
    // {DE, HS, VS, X[9:0], Y[8:0], RGB[23:0]}, 46 bits.
    reg [45:0] video_d1, video_d2;
    wire sidebar_valid,sidebar_pixel;wire [23:0] sidebar_color;
    ui_sidebar sidebar(.clk(clk),.rst(rst),.frame_tick(frame_tick),.enable(fixed_on),
      .x(in_x),.y(in_y),.de(in_de),.image_valid(image_valid),.auto_play(auto_play),
      .image_index(image_index),.scale_mode(scale_mode),.interpolation(interpolation),
      .transition_mode(transition_mode),.sw_code(sw_code),.brightness(brightness),
      .contrast(contrast),.setting_value(setting_value),.valid(sidebar_valid),
      .pixel(sidebar_pixel),.color(sidebar_color));
    wire [9:0] ui_x=video_d2[42:33];wire [8:0] ui_y=video_d2[32:24];
    reg [23:0] ui_bg;
    always @* begin
      ui_bg=video_d2[23:0];
      if(ui_x>=480 && ui_y<360)begin
        ui_bg=24'h091426;
        if((ui_y==104 || ui_y==152) && ui_x>=488 && ui_x<632)ui_bg=24'h303e50;
        if(((sw_code==7 || sw_code==8) && ui_y>=192 && ui_y<224) ||
           (sw_code==4 && ui_y>=224 && ui_y<256) ||
           (sw_code==10 && ui_y>=256 && ui_y<272) ||
           (sw_code==11 && ui_y>=272 && ui_y<288))begin
           if(ui_x>=486 && ui_x<634)ui_bg=24'h153e49;
           if(ui_x>=486 && ui_x<488)ui_bg=24'h32bdc9;end
      end
      if(ui_y>=360 && ui_y<416)ui_bg=24'h0b1729;
      if(ui_y>=416)ui_bg=24'h000000;
    end
    osd_glyph_pixel glyph (
        .clk(clk), .rst(rst), .in_valid(text_valid), .char_code(char_code),
        .glyph_x(glyph_x), .glyph_y(glyph_y),
        .out_valid(glyph_valid), .pixel_on(pixel_on)
    );
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            video_d1 <= 46'd0;
            video_d2 <= 46'd0;
            out_rgb <= 24'd0;
            out_de <= 1'b0;
            out_hs <= 1'b0;
            out_vs <= 1'b0;
            out_x <= 10'd0;
            out_y <= 9'd0;
        end else begin
            video_d1 <= {in_de, in_hs, in_vs, in_x, in_y, in_rgb};
            video_d2 <= video_d1;
            {out_de, out_hs, out_vs, out_x, out_y} <= video_d2[45:24];
            if (!video_d2[45])
                out_rgb <= 24'd0;
            else if(sidebar_valid && sidebar_pixel)out_rgb<=sidebar_color;
            else if (glyph_valid && pixel_on) out_rgb<=24'ha8b3c0;
            else if (zh_v2 && zh_pix) out_rgb<=24'hf2f4f6;
            else out_rgb<=ui_bg;
        end
    end
endmodule

// UI sidebar: same two font stages as caption ROM. 25MHz runtime clock.
module ui_sidebar #(parameter CLOCK_HZ=25000000)(
 input wire clk,rst,frame_tick,enable,
 input wire [9:0] x,input wire [8:0] y, input wire de,
 input wire image_valid,auto_play,input wire [1:0] image_index,scale_mode,
 input wire interpolation,input wire [2:0] transition_mode,
 input wire [3:0] sw_code,brightness,contrast,setting_value,
 output reg valid,pixel,output reg [23:0] color);
 reg [24:0] ticks; reg [3:0] s0,s1,m0,m1,h0,h1;
 reg [23:0] clock_frame;
 always @(posedge clk or posedge rst) begin
 if(rst) begin ticks<=0;s0<=0;s1<=0;m0<=0;m1<=0;h0<=0;h1<=0;clock_frame<=0;end
 else begin
 if(frame_tick) clock_frame<={h1,h0,m1,m0,s1,s0};
 if(ticks==CLOCK_HZ-1) begin ticks<=0;
 if(s0==9) begin s0<=0;if(s1==5) begin s1<=0;
 if(m0==9) begin m0<=0;if(m1==5) begin m1<=0;
 if(h1==2 && h0==3) begin h1<=0;h0<=0;end
 else if(h0==9) begin h0<=0;h1<=h1+1'b1;end else h0<=h0+1'b1;
 end else m1<=m1+1'b1;end else m0<=m0+1'b1;
 end else s1<=s1+1'b1;end else s0<=s0+1'b1;
 end else ticks<=ticks+1'b1;end end
 function [71:0] label; input [5:0] n;begin case(n)
6'd0:label=72'h010203040000000000;
6'd1:label=72'h050607080000000000;
6'd2:label=72'h090a07000000000000;
6'd3:label=72'h0b0c00000000000000;
6'd4:label=72'h0d0e00000000000000;
6'd5:label=72'h0f1000000000000000;
6'd6:label=72'h111200000000000000;
6'd7:label=72'h131415160000000000;
6'd8:label=72'h171800000000000000;
6'd9:label=72'h2b2c00000000000000;
6'd10:label=72'h494a00000000000000;
6'd11:label=72'h4b234a000000000000;
6'd12:label=72'h191a1b000000000000;
6'd13:label=72'h1c1d1e000000000000;
6'd14:label=72'h1f2021000000000000;
6'd15:label=72'h222324252600000000;
6'd16:label=72'h2728292a0000000000;
6'd17:label=72'h2d2e2f300000000000;
6'd18:label=72'h313231330000000000;
6'd19:label=72'h343536370000000000;
6'd20:label=72'h38393a2b0000000000;
6'd21:label=72'h3b2d3c3d0000000000;
6'd22:label=72'h3e3f40000000000000;
6'd23:label=72'h414243440000000000;
6'd24:label=72'h454647480000000000;
6'd25:label=72'h4c4d00000000000000;
6'd26:label=72'h4e374f4a0000000000;
6'd27:label=72'h4e3745500000000000;
6'd28:label=72'h2b2c07510000000000;
6'd29:label=72'h2b2c45500000000000;
6'd30:label=72'h4d5200000000000000;
6'd31:label=72'h535400000000000000;
6'd32:label=72'h555657000000000000;
6'd33:label=72'h6e6f70717273740000;
default:label=72'd0;endcase end endfunction
function [7:0] digit;input [3:0] n;begin case(n)
4'd0:digit=8'd96;
4'd1:digit=8'd97;
4'd2:digit=8'd98;
4'd3:digit=8'd99;
4'd4:digit=8'd100;
4'd5:digit=8'd101;
4'd6:digit=8'd102;
4'd7:digit=8'd103;
4'd8:digit=8'd104;
4'd9:digit=8'd105;
default:digit=0;endcase end endfunction
function [71:0] selected_value;input [3:0] sw,v;begin
 selected_value=0;case(sw)
1:case(v)
0:selected_value=72'h111200000000000000;
1:selected_value=72'h4c4d00000000000000;
2:selected_value=72'h4e3700000000000000;
3:selected_value=72'h4c4d4e370000000000;
default:selected_value=0;endcase
2:case(v)
0:selected_value=72'h580000000000000000;
1:selected_value=72'h590000000000000000;
2:selected_value=72'h5a0000000000000000;
default:selected_value=0;endcase
3:case(v)
0:selected_value=72'h505b00000000000000;
1:selected_value=72'h505c00000000000000;
default:selected_value=0;endcase
5:case(v)
0:selected_value=72'h5d0000000000000000;
1:selected_value=72'h590000000000000000;
2:selected_value=72'h510000000000000000;
default:selected_value=0;endcase
6:case(v)
0:selected_value=72'h505b00000000000000;
1:selected_value=72'h505c00000000000000;
default:selected_value=0;endcase
12:case(v)
0:selected_value=72'h111200000000000000;
1:selected_value=72'h594c00000000000000;
2:selected_value=72'h5e4c00000000000000;
3:selected_value=72'h195f00000000000000;
default:selected_value=0;endcase
default:selected_value=0;endcase end endfunction
function [15:0] font_init;input [10:0] a;begin case(a)
11'd16:font_init=16'h0100;
11'd17:font_init=16'h0180;
11'd18:font_init=16'h3ffc;
11'd19:font_init=16'h2004;
11'd20:font_init=16'h2304;
11'd21:font_init=16'h0200;
11'd22:font_init=16'h0600;
11'd23:font_init=16'h7ffe;
11'd24:font_init=16'h0c30;
11'd25:font_init=16'h0820;
11'd26:font_init=16'h07c0;
11'd27:font_init=16'h00e0;
11'd28:font_init=16'h071c;
11'd29:font_init=16'h3c06;
11'd30:font_init=16'h2000;
11'd32:font_init=16'h0060;
11'd33:font_init=16'h3e40;
11'd34:font_init=16'h26fc;
11'd35:font_init=16'h2688;
11'd36:font_init=16'h2748;
11'd37:font_init=16'h3e30;
11'd38:font_init=16'h0838;
11'd39:font_init=16'h29cf;
11'd40:font_init=16'h2ffe;
11'd41:font_init=16'h28fc;
11'd42:font_init=16'h2884;
11'd43:font_init=16'h2e84;
11'd44:font_init=16'h38fc;
11'd45:font_init=16'h4084;
11'd48:font_init=16'h0208;
11'd49:font_init=16'h3e08;
11'd50:font_init=16'h2848;
11'd51:font_init=16'h0868;
11'd52:font_init=16'h0828;
11'd53:font_init=16'h7e88;
11'd54:font_init=16'h1cc8;
11'd55:font_init=16'h1e68;
11'd56:font_init=16'h1b4a;
11'd57:font_init=16'h287e;
11'd58:font_init=16'h6988;
11'd59:font_init=16'h4808;
11'd60:font_init=16'h0808;
11'd61:font_init=16'h0808;
11'd62:font_init=16'h0808;
11'd64:font_init=16'h1020;
11'd65:font_init=16'h1020;
11'd66:font_init=16'h1020;
11'd67:font_init=16'h7dfe;
11'd68:font_init=16'h1020;
11'd69:font_init=16'h1020;
11'd70:font_init=16'h15fc;
11'd71:font_init=16'h1884;
11'd72:font_init=16'h7088;
11'd73:font_init=16'h10c8;
11'd74:font_init=16'h1050;
11'd75:font_init=16'h1030;
11'd76:font_init=16'h10d8;
11'd77:font_init=16'h378e;
11'd78:font_init=16'h0002;
11'd81:font_init=16'h33fc;
11'd82:font_init=16'h1000;
11'd85:font_init=16'h7ffe;
11'd86:font_init=16'h7880;
11'd87:font_init=16'h1890;
11'd88:font_init=16'h1908;
11'd89:font_init=16'h191c;
11'd90:font_init=16'h1be4;
11'd91:font_init=16'h1800;
11'd92:font_init=16'h3c00;
11'd93:font_init=16'h43fe;
11'd96:font_init=16'h1800;
11'd97:font_init=16'h11fc;
11'd98:font_init=16'h3000;
11'd99:font_init=16'h6000;
11'd100:font_init=16'h4c00;
11'd101:font_init=16'h1bfe;
11'd102:font_init=16'h1010;
11'd103:font_init=16'h3010;
11'd104:font_init=16'h7010;
11'd105:font_init=16'h5010;
11'd106:font_init=16'h1010;
11'd107:font_init=16'h1010;
11'd108:font_init=16'h1010;
11'd109:font_init=16'h1070;
11'd110:font_init=16'h1020;
11'd112:font_init=16'h0008;
11'd113:font_init=16'h0008;
11'd114:font_init=16'h7c08;
11'd115:font_init=16'h65fe;
11'd116:font_init=16'h65fe;
11'd117:font_init=16'h6408;
11'd118:font_init=16'h7c88;
11'd119:font_init=16'h64c8;
11'd120:font_init=16'h6448;
11'd121:font_init=16'h6408;
11'd122:font_init=16'h7c08;
11'd123:font_init=16'h6408;
11'd124:font_init=16'h6008;
11'd125:font_init=16'h0038;
11'd128:font_init=16'h1000;
11'd129:font_init=16'h19fc;
11'd130:font_init=16'h0804;
11'd131:font_init=16'h6004;
11'd132:font_init=16'h67e4;
11'd133:font_init=16'h6424;
11'd134:font_init=16'h6424;
11'd135:font_init=16'h67e4;
11'd136:font_init=16'h6424;
11'd137:font_init=16'h6424;
11'd138:font_init=16'h67e4;
11'd139:font_init=16'h6004;
11'd140:font_init=16'h6004;
11'd141:font_init=16'h600c;
11'd144:font_init=16'h0100;
11'd145:font_init=16'h0100;
11'd146:font_init=16'h0100;
11'd147:font_init=16'h3ff8;
11'd148:font_init=16'h0100;
11'd149:font_init=16'h0100;
11'd150:font_init=16'h7ffe;
11'd151:font_init=16'h0380;
11'd152:font_init=16'h0740;
11'd153:font_init=16'h0d60;
11'd154:font_init=16'h1930;
11'd155:font_init=16'h311c;
11'd156:font_init=16'h6106;
11'd157:font_init=16'h0100;
11'd160:font_init=16'h1020;
11'd161:font_init=16'h1030;
11'd162:font_init=16'h13fe;
11'd163:font_init=16'h7c00;
11'd164:font_init=16'h1088;
11'd165:font_init=16'h108c;
11'd166:font_init=16'h3106;
11'd167:font_init=16'h3f08;
11'd168:font_init=16'h7488;
11'd169:font_init=16'h50d8;
11'd170:font_init=16'h5070;
11'd171:font_init=16'h1020;
11'd172:font_init=16'h10d8;
11'd173:font_init=16'h178e;
11'd174:font_init=16'h0202;
11'd177:font_init=16'h3ffc;
11'd178:font_init=16'h2304;
11'd179:font_init=16'h23e4;
11'd180:font_init=16'h2664;
11'd181:font_init=16'h2f44;
11'd182:font_init=16'h2184;
11'd183:font_init=16'h2674;
11'd184:font_init=16'h399c;
11'd185:font_init=16'h20c4;
11'd186:font_init=16'h2304;
11'd187:font_init=16'h20c4;
11'd188:font_init=16'h2004;
11'd189:font_init=16'h3ffc;
11'd190:font_init=16'h2006;
11'd192:font_init=16'h1820;
11'd193:font_init=16'h1820;
11'd194:font_init=16'h1820;
11'd195:font_init=16'h1820;
11'd196:font_init=16'h1ffe;
11'd197:font_init=16'h1800;
11'd198:font_init=16'h1800;
11'd199:font_init=16'h1800;
11'd200:font_init=16'h1ff0;
11'd201:font_init=16'h1010;
11'd202:font_init=16'h1010;
11'd203:font_init=16'h3010;
11'd204:font_init=16'h2010;
11'd205:font_init=16'h6010;
11'd206:font_init=16'h0010;
11'd208:font_init=16'h1820;
11'd209:font_init=16'h1060;
11'd210:font_init=16'h7e50;
11'd211:font_init=16'h10d8;
11'd212:font_init=16'h218c;
11'd213:font_init=16'h2f06;
11'd214:font_init=16'h4880;
11'd215:font_init=16'h7e8c;
11'd216:font_init=16'h08b8;
11'd217:font_init=16'h08e0;
11'd218:font_init=16'h7e80;
11'd219:font_init=16'h6884;
11'd220:font_init=16'h0886;
11'd221:font_init=16'h08fc;
11'd222:font_init=16'h0800;
11'd224:font_init=16'h100c;
11'd225:font_init=16'h13fc;
11'd226:font_init=16'h112c;
11'd227:font_init=16'h7928;
11'd228:font_init=16'h13fe;
11'd229:font_init=16'h10b0;
11'd230:font_init=16'h11a8;
11'd231:font_init=16'h3b26;
11'd232:font_init=16'h77fe;
11'd233:font_init=16'h1324;
11'd234:font_init=16'h13fc;
11'd235:font_init=16'h1324;
11'd236:font_init=16'h1324;
11'd237:font_init=16'h73fc;
11'd238:font_init=16'h0304;
11'd241:font_init=16'h3ffc;
11'd242:font_init=16'h0620;
11'd243:font_init=16'h0620;
11'd244:font_init=16'h0620;
11'd245:font_init=16'h0620;
11'd246:font_init=16'h7ffe;
11'd247:font_init=16'h7ffe;
11'd248:font_init=16'h0620;
11'd249:font_init=16'h0420;
11'd250:font_init=16'h0420;
11'd251:font_init=16'h0c20;
11'd252:font_init=16'h1820;
11'd253:font_init=16'h7020;
11'd256:font_init=16'h0180;
11'd257:font_init=16'h0080;
11'd258:font_init=16'h1ffc;
11'd259:font_init=16'h100c;
11'd260:font_init=16'h100c;
11'd261:font_init=16'h1ffc;
11'd262:font_init=16'h1ffc;
11'd263:font_init=16'h1000;
11'd264:font_init=16'h17fc;
11'd265:font_init=16'h140c;
11'd266:font_init=16'h340c;
11'd267:font_init=16'h240c;
11'd268:font_init=16'h67fc;
11'd269:font_init=16'h440c;
11'd270:font_init=16'h040c;
11'd272:font_init=16'h0420;
11'd273:font_init=16'h0420;
11'd274:font_init=16'h0660;
11'd275:font_init=16'h3ffc;
11'd276:font_init=16'h3ffc;
11'd277:font_init=16'h0180;
11'd278:font_init=16'h0180;
11'd279:font_init=16'h0180;
11'd280:font_init=16'h7ffe;
11'd281:font_init=16'h0180;
11'd282:font_init=16'h0340;
11'd283:font_init=16'h0670;
11'd284:font_init=16'h0c1c;
11'd285:font_init=16'h700c;
11'd288:font_init=16'h1000;
11'd289:font_init=16'h19fe;
11'd290:font_init=16'h0806;
11'd291:font_init=16'h6046;
11'd292:font_init=16'h6046;
11'd293:font_init=16'h6ff6;
11'd294:font_init=16'h60c6;
11'd295:font_init=16'h6146;
11'd296:font_init=16'h6346;
11'd297:font_init=16'h6646;
11'd298:font_init=16'h6c46;
11'd299:font_init=16'h7846;
11'd300:font_init=16'h61c6;
11'd301:font_init=16'h610c;
11'd304:font_init=16'h0180;
11'd305:font_init=16'h1184;
11'd306:font_init=16'h198c;
11'd307:font_init=16'h0998;
11'd308:font_init=16'h0990;
11'd309:font_init=16'h0180;
11'd310:font_init=16'h3ffc;
11'd311:font_init=16'h0004;
11'd312:font_init=16'h0004;
11'd313:font_init=16'h3ffc;
11'd314:font_init=16'h0004;
11'd315:font_init=16'h0004;
11'd316:font_init=16'h3ffc;
11'd317:font_init=16'h0004;
11'd318:font_init=16'h0004;
11'd320:font_init=16'h0c10;
11'd321:font_init=16'h0620;
11'd322:font_init=16'h7ffe;
11'd324:font_init=16'h0004;
11'd325:font_init=16'h3f64;
11'd326:font_init=16'h2164;
11'd327:font_init=16'h3f64;
11'd328:font_init=16'h2164;
11'd329:font_init=16'h2164;
11'd330:font_init=16'h3f64;
11'd331:font_init=16'h2164;
11'd332:font_init=16'h2104;
11'd333:font_init=16'h271c;
11'd334:font_init=16'h2010;
11'd336:font_init=16'h11f8;
11'd337:font_init=16'h1108;
11'd338:font_init=16'h1108;
11'd339:font_init=16'h7df8;
11'd340:font_init=16'h1000;
11'd341:font_init=16'h13de;
11'd342:font_init=16'h1652;
11'd343:font_init=16'h1bde;
11'd344:font_init=16'h7020;
11'd345:font_init=16'h17fe;
11'd346:font_init=16'h10f0;
11'd347:font_init=16'h10b8;
11'd348:font_init=16'h132c;
11'd349:font_init=16'h3622;
11'd350:font_init=16'h0020;
11'd352:font_init=16'h0cc0;
11'd353:font_init=16'h0880;
11'd354:font_init=16'h1980;
11'd355:font_init=16'h11fe;
11'd356:font_init=16'h3340;
11'd357:font_init=16'h3640;
11'd358:font_init=16'h507c;
11'd359:font_init=16'h5040;
11'd360:font_init=16'h1040;
11'd361:font_init=16'h1040;
11'd362:font_init=16'h107e;
11'd363:font_init=16'h1040;
11'd364:font_init=16'h1040;
11'd365:font_init=16'h1040;
11'd366:font_init=16'h1040;
11'd368:font_init=16'h1020;
11'd369:font_init=16'h1020;
11'd370:font_init=16'h23fe;
11'd371:font_init=16'h2282;
11'd372:font_init=16'h4cfe;
11'd373:font_init=16'h7918;
11'd374:font_init=16'h1310;
11'd375:font_init=16'h273e;
11'd376:font_init=16'h2126;
11'd377:font_init=16'h7926;
11'd378:font_init=16'h013e;
11'd379:font_init=16'h0126;
11'd380:font_init=16'h7d26;
11'd381:font_init=16'h413e;
11'd382:font_init=16'h0126;
11'd384:font_init=16'h1020;
11'd385:font_init=16'h1820;
11'd386:font_init=16'h0840;
11'd387:font_init=16'h7f7e;
11'd388:font_init=16'h104c;
11'd389:font_init=16'h10cc;
11'd390:font_init=16'h1fc8;
11'd391:font_init=16'h1248;
11'd392:font_init=16'h1228;
11'd393:font_init=16'h1228;
11'd394:font_init=16'h3230;
11'd395:font_init=16'h2230;
11'd396:font_init=16'h6268;
11'd397:font_init=16'h4fc6;
11'd398:font_init=16'h0002;
11'd401:font_init=16'h7efc;
11'd402:font_init=16'h0284;
11'd403:font_init=16'h02c4;
11'd404:font_init=16'h22cc;
11'd405:font_init=16'h3648;
11'd406:font_init=16'h1c48;
11'd407:font_init=16'h0c48;
11'd408:font_init=16'h0c78;
11'd409:font_init=16'h0a30;
11'd410:font_init=16'h1b30;
11'd411:font_init=16'h3078;
11'd412:font_init=16'h20cc;
11'd413:font_init=16'h0306;
11'd414:font_init=16'h0200;
11'd416:font_init=16'h10c0;
11'd417:font_init=16'h1058;
11'd418:font_init=16'h3048;
11'd419:font_init=16'h2644;
11'd420:font_init=16'h4df8;
11'd421:font_init=16'h7b40;
11'd422:font_init=16'h105e;
11'd423:font_init=16'h13f0;
11'd424:font_init=16'h224c;
11'd425:font_init=16'h7c68;
11'd426:font_init=16'h0030;
11'd427:font_init=16'h1c70;
11'd428:font_init=16'h70da;
11'd429:font_init=16'h030e;
11'd432:font_init=16'h1020;
11'd433:font_init=16'h1120;
11'd434:font_init=16'h1120;
11'd435:font_init=16'h1d20;
11'd436:font_init=16'h55fe;
11'd437:font_init=16'h5720;
11'd438:font_init=16'h5220;
11'd439:font_init=16'h5020;
11'd440:font_init=16'h11fc;
11'd441:font_init=16'h1020;
11'd442:font_init=16'h1020;
11'd443:font_init=16'h1020;
11'd444:font_init=16'h1020;
11'd445:font_init=16'h13fe;
11'd446:font_init=16'h1000;
11'd449:font_init=16'h1ff8;
11'd450:font_init=16'h1ff8;
11'd451:font_init=16'h1018;
11'd452:font_init=16'h1ff8;
11'd454:font_init=16'h7ffe;
11'd455:font_init=16'h1100;
11'd456:font_init=16'h1ff8;
11'd457:font_init=16'h1148;
11'd458:font_init=16'h1f48;
11'd459:font_init=16'h11b0;
11'd460:font_init=16'h7f38;
11'd461:font_init=16'h01ce;
11'd464:font_init=16'h0004;
11'd465:font_init=16'h31fc;
11'd466:font_init=16'h1900;
11'd467:font_init=16'h0900;
11'd468:font_init=16'h0100;
11'd469:font_init=16'h01fe;
11'd470:font_init=16'h7110;
11'd471:font_init=16'h1110;
11'd472:font_init=16'h1110;
11'd473:font_init=16'h1310;
11'd474:font_init=16'h1210;
11'd475:font_init=16'h1210;
11'd476:font_init=16'h3c00;
11'd477:font_init=16'h63fe;
11'd480:font_init=16'h0c00;
11'd481:font_init=16'h0c3e;
11'd482:font_init=16'h1a24;
11'd483:font_init=16'h31a4;
11'd484:font_init=16'h28a4;
11'd485:font_init=16'h4c2c;
11'd486:font_init=16'h042c;
11'd487:font_init=16'h3f24;
11'd488:font_init=16'h0122;
11'd489:font_init=16'h0222;
11'd490:font_init=16'h1622;
11'd491:font_init=16'h1c2e;
11'd492:font_init=16'h0c28;
11'd493:font_init=16'h0620;
11'd494:font_init=16'h0020;
11'd497:font_init=16'h1ffe;
11'd498:font_init=16'h10c0;
11'd499:font_init=16'h1080;
11'd500:font_init=16'h17fc;
11'd501:font_init=16'h160c;
11'd502:font_init=16'h17fc;
11'd503:font_init=16'h160c;
11'd504:font_init=16'h37fc;
11'd505:font_init=16'h3040;
11'd506:font_init=16'h2240;
11'd507:font_init=16'h2248;
11'd508:font_init=16'h6444;
11'd509:font_init=16'h49c0;
11'd513:font_init=16'h1ffc;
11'd514:font_init=16'h180c;
11'd515:font_init=16'h180c;
11'd516:font_init=16'h180c;
11'd517:font_init=16'h1ffc;
11'd518:font_init=16'h108c;
11'd519:font_init=16'h1080;
11'd520:font_init=16'h10c0;
11'd521:font_init=16'h1040;
11'd522:font_init=16'h3060;
11'd523:font_init=16'h3030;
11'd524:font_init=16'h201c;
11'd525:font_init=16'h600e;
11'd526:font_init=16'h4000;
11'd528:font_init=16'h0020;
11'd529:font_init=16'h0020;
11'd530:font_init=16'h0020;
11'd531:font_init=16'h0020;
11'd532:font_init=16'h7ffe;
11'd533:font_init=16'h0020;
11'd534:font_init=16'h0020;
11'd535:font_init=16'h1820;
11'd536:font_init=16'h0820;
11'd537:font_init=16'h0c20;
11'd538:font_init=16'h0420;
11'd539:font_init=16'h0020;
11'd540:font_init=16'h0020;
11'd541:font_init=16'h00e0;
11'd544:font_init=16'h1020;
11'd545:font_init=16'h3f7e;
11'd546:font_init=16'h64c8;
11'd547:font_init=16'h458c;
11'd548:font_init=16'h1ff8;
11'd549:font_init=16'h0180;
11'd550:font_init=16'h0180;
11'd551:font_init=16'hfffe;
11'd552:font_init=16'h0030;
11'd553:font_init=16'h0030;
11'd554:font_init=16'h3ffc;
11'd555:font_init=16'h0830;
11'd556:font_init=16'h0430;
11'd557:font_init=16'h0070;
11'd560:font_init=16'h0080;
11'd561:font_init=16'h2080;
11'd562:font_init=16'h2080;
11'd563:font_init=16'h2084;
11'd564:font_init=16'h209c;
11'd565:font_init=16'h3ef0;
11'd566:font_init=16'h20c0;
11'd567:font_init=16'h2080;
11'd568:font_init=16'h2080;
11'd569:font_init=16'h2080;
11'd570:font_init=16'h2280;
11'd571:font_init=16'h2e86;
11'd572:font_init=16'h78c6;
11'd573:font_init=16'h207c;
11'd576:font_init=16'h0802;
11'd577:font_init=16'h1fc2;
11'd578:font_init=16'h1112;
11'd579:font_init=16'h3112;
11'd580:font_init=16'h3312;
11'd581:font_init=16'h73d2;
11'd582:font_init=16'h5252;
11'd583:font_init=16'h1652;
11'd584:font_init=16'h1fd2;
11'd585:font_init=16'h1092;
11'd586:font_init=16'h1092;
11'd587:font_init=16'h1182;
11'd588:font_init=16'h1302;
11'd589:font_init=16'h160e;
11'd590:font_init=16'h1000;
11'd592:font_init=16'h0600;
11'd593:font_init=16'h3cfe;
11'd594:font_init=16'h2426;
11'd595:font_init=16'h2626;
11'd596:font_init=16'h2664;
11'd597:font_init=16'h3bdc;
11'd598:font_init=16'h2090;
11'd599:font_init=16'h3ffc;
11'd600:font_init=16'h3084;
11'd601:font_init=16'h3084;
11'd602:font_init=16'h3ffc;
11'd603:font_init=16'h3084;
11'd604:font_init=16'h3ffc;
11'd605:font_init=16'h3004;
11'd606:font_init=16'h3004;
11'd608:font_init=16'h2040;
11'd609:font_init=16'h2040;
11'd610:font_init=16'h3040;
11'd611:font_init=16'h13fc;
11'd612:font_init=16'h0044;
11'd613:font_init=16'h00c4;
11'd614:font_init=16'h7084;
11'd615:font_init=16'h1084;
11'd616:font_init=16'h1184;
11'd617:font_init=16'h1104;
11'd618:font_init=16'h133c;
11'd619:font_init=16'h1218;
11'd620:font_init=16'h2c00;
11'd621:font_init=16'h43fe;
11'd624:font_init=16'h1828;
11'd625:font_init=16'h1024;
11'd626:font_init=16'h3dfe;
11'd627:font_init=16'h6020;
11'd628:font_init=16'hc020;
11'd629:font_init=16'h3dfc;
11'd630:font_init=16'h1124;
11'd631:font_init=16'h11fc;
11'd632:font_init=16'h7d24;
11'd633:font_init=16'h1124;
11'd634:font_init=16'h11fc;
11'd635:font_init=16'h1524;
11'd636:font_init=16'h1924;
11'd637:font_init=16'h112c;
11'd640:font_init=16'h0190;
11'd641:font_init=16'h6190;
11'd642:font_init=16'h17fe;
11'd643:font_init=16'h0190;
11'd644:font_init=16'h47fe;
11'd645:font_init=16'h67fe;
11'd646:font_init=16'h2090;
11'd647:font_init=16'h07fe;
11'd648:font_init=16'h1492;
11'd649:font_init=16'h34b2;
11'd650:font_init=16'h257a;
11'd651:font_init=16'h672a;
11'd652:font_init=16'h4442;
11'd653:font_init=16'h040e;
11'd654:font_init=16'h0408;
11'd656:font_init=16'h0468;
11'd657:font_init=16'h046c;
11'd658:font_init=16'h3f66;
11'd659:font_init=16'h0460;
11'd660:font_init=16'h7ffe;
11'd661:font_init=16'h0420;
11'd662:font_init=16'h0424;
11'd663:font_init=16'h7fa4;
11'd664:font_init=16'h0928;
11'd665:font_init=16'h1fb8;
11'd666:font_init=16'h3910;
11'd667:font_init=16'h69b0;
11'd668:font_init=16'h0f6a;
11'd669:font_init=16'h18ce;
11'd670:font_init=16'h0084;
11'd672:font_init=16'h0c30;
11'd673:font_init=16'h0420;
11'd674:font_init=16'h7ffe;
11'd675:font_init=16'h000c;
11'd676:font_init=16'h3f2c;
11'd677:font_init=16'h3f2c;
11'd678:font_init=16'h212c;
11'd679:font_init=16'h3f2c;
11'd680:font_init=16'h231c;
11'd682:font_init=16'h3ff8;
11'd683:font_init=16'h0208;
11'd684:font_init=16'h0608;
11'd685:font_init=16'h3838;
11'd686:font_init=16'h2000;
11'd688:font_init=16'h1820;
11'd689:font_init=16'h1020;
11'd690:font_init=16'h7ffe;
11'd691:font_init=16'h3060;
11'd692:font_init=16'h2040;
11'd693:font_init=16'h29fe;
11'd694:font_init=16'h4840;
11'd695:font_init=16'h7ec0;
11'd696:font_init=16'h08fc;
11'd697:font_init=16'h080c;
11'd698:font_init=16'h7e18;
11'd699:font_init=16'h08f0;
11'd700:font_init=16'h0860;
11'd701:font_init=16'h0818;
11'd702:font_init=16'h0008;
11'd704:font_init=16'h11fc;
11'd705:font_init=16'h11fc;
11'd706:font_init=16'h1010;
11'd707:font_init=16'h1020;
11'd708:font_init=16'h7c40;
11'd709:font_init=16'h11fe;
11'd710:font_init=16'h1152;
11'd711:font_init=16'h10d2;
11'd712:font_init=16'h1092;
11'd713:font_init=16'h15b2;
11'd714:font_init=16'h1f22;
11'd715:font_init=16'h6266;
11'd716:font_init=16'h00c6;
11'd717:font_init=16'h018c;
11'd718:font_init=16'h0100;
11'd720:font_init=16'h0180;
11'd721:font_init=16'h0180;
11'd722:font_init=16'h7ffc;
11'd723:font_init=16'h0100;
11'd724:font_init=16'h1ff8;
11'd725:font_init=16'h1818;
11'd726:font_init=16'h1ff8;
11'd727:font_init=16'h1818;
11'd728:font_init=16'h1ff8;
11'd729:font_init=16'h1818;
11'd730:font_init=16'h1818;
11'd731:font_init=16'h1ff8;
11'd732:font_init=16'h1818;
11'd733:font_init=16'h7ffe;
11'd736:font_init=16'h1020;
11'd737:font_init=16'h1020;
11'd738:font_init=16'h13fe;
11'd739:font_init=16'h7c88;
11'd740:font_init=16'h1088;
11'd741:font_init=16'h1110;
11'd742:font_init=16'h17fe;
11'd743:font_init=16'h1c40;
11'd744:font_init=16'h73fe;
11'd745:font_init=16'h1088;
11'd746:font_init=16'h1198;
11'd747:font_init=16'h10f0;
11'd748:font_init=16'h1078;
11'd749:font_init=16'h73c6;
11'd750:font_init=16'h0200;
11'd752:font_init=16'h1000;
11'd753:font_init=16'h1000;
11'd754:font_init=16'h11fe;
11'd755:font_init=16'h1066;
11'd756:font_init=16'h1266;
11'd757:font_init=16'h7e66;
11'd758:font_init=16'h1046;
11'd759:font_init=16'h1044;
11'd760:font_init=16'h1044;
11'd761:font_init=16'h16c4;
11'd762:font_init=16'h1c84;
11'd763:font_init=16'h3184;
11'd764:font_init=16'h0304;
11'd765:font_init=16'h061c;
11'd768:font_init=16'h10c0;
11'd769:font_init=16'h1080;
11'd770:font_init=16'h11f8;
11'd771:font_init=16'h7d10;
11'd772:font_init=16'h1230;
11'd773:font_init=16'h11fc;
11'd774:font_init=16'h1524;
11'd775:font_init=16'h1d24;
11'd776:font_init=16'h7124;
11'd777:font_init=16'h57fe;
11'd778:font_init=16'h1070;
11'd779:font_init=16'h10d0;
11'd780:font_init=16'h118c;
11'd781:font_init=16'h7706;
11'd784:font_init=16'h0040;
11'd785:font_init=16'h334c;
11'd786:font_init=16'h1248;
11'd787:font_init=16'h02e0;
11'd788:font_init=16'h00b8;
11'd789:font_init=16'h630c;
11'd790:font_init=16'h3660;
11'd791:font_init=16'h0040;
11'd792:font_init=16'h1344;
11'd793:font_init=16'h1268;
11'd794:font_init=16'h3260;
11'd795:font_init=16'h2090;
11'd796:font_init=16'h6198;
11'd797:font_init=16'h4706;
11'd800:font_init=16'h0180;
11'd801:font_init=16'h0180;
11'd802:font_init=16'h3188;
11'd803:font_init=16'h3188;
11'd804:font_init=16'h3188;
11'd805:font_init=16'h3188;
11'd806:font_init=16'h3ff8;
11'd807:font_init=16'h0180;
11'd808:font_init=16'h2184;
11'd809:font_init=16'h2184;
11'd810:font_init=16'h2184;
11'd811:font_init=16'h2184;
11'd812:font_init=16'h3ffc;
11'd813:font_init=16'h3ffc;
11'd814:font_init=16'h0004;
11'd816:font_init=16'h0400;
11'd817:font_init=16'h0600;
11'd818:font_init=16'h0300;
11'd819:font_init=16'h0180;
11'd820:font_init=16'h0180;
11'd821:font_init=16'h01c0;
11'd822:font_init=16'h0340;
11'd823:font_init=16'h0260;
11'd824:font_init=16'h0620;
11'd825:font_init=16'h0c30;
11'd826:font_init=16'h0818;
11'd827:font_init=16'h181c;
11'd828:font_init=16'h700e;
11'd829:font_init=16'h6000;
11'd832:font_init=16'h0180;
11'd833:font_init=16'h0180;
11'd834:font_init=16'h0180;
11'd835:font_init=16'h0184;
11'd836:font_init=16'h7d8c;
11'd837:font_init=16'h0590;
11'd838:font_init=16'h05e0;
11'd839:font_init=16'h09e0;
11'd840:font_init=16'h09a0;
11'd841:font_init=16'h1190;
11'd842:font_init=16'h3198;
11'd843:font_init=16'h618e;
11'd844:font_init=16'h0180;
11'd845:font_init=16'h0380;
11'd846:font_init=16'h0200;
11'd849:font_init=16'h3ffc;
11'd850:font_init=16'h0180;
11'd851:font_init=16'h1188;
11'd852:font_init=16'h1998;
11'd853:font_init=16'h0d90;
11'd854:font_init=16'h05a0;
11'd855:font_init=16'h0180;
11'd856:font_init=16'h7ffe;
11'd857:font_init=16'h0180;
11'd858:font_init=16'h0180;
11'd859:font_init=16'h0180;
11'd860:font_init=16'h0180;
11'd861:font_init=16'h0180;
11'd862:font_init=16'h0180;
11'd864:font_init=16'h23f8;
11'd865:font_init=16'h3208;
11'd866:font_init=16'h13e8;
11'd867:font_init=16'h0228;
11'd868:font_init=16'h4228;
11'd869:font_init=16'h3ffe;
11'd870:font_init=16'h0802;
11'd871:font_init=16'h03f8;
11'd872:font_init=16'h1308;
11'd873:font_init=16'h33f8;
11'd874:font_init=16'h2308;
11'd875:font_init=16'h63f8;
11'd876:font_init=16'h4308;
11'd877:font_init=16'h0318;
11'd878:font_init=16'h0300;
11'd880:font_init=16'h0030;
11'd881:font_init=16'h0030;
11'd882:font_init=16'h3e30;
11'd883:font_init=16'h0030;
11'd884:font_init=16'h00fe;
11'd885:font_init=16'h7f32;
11'd886:font_init=16'h7f22;
11'd887:font_init=16'h1022;
11'd888:font_init=16'h1622;
11'd889:font_init=16'h2222;
11'd890:font_init=16'h2362;
11'd891:font_init=16'h7d46;
11'd892:font_init=16'h00c6;
11'd893:font_init=16'h019c;
11'd897:font_init=16'h1ff8;
11'd898:font_init=16'h1008;
11'd899:font_init=16'h1048;
11'd900:font_init=16'h1448;
11'd901:font_init=16'h1248;
11'd902:font_init=16'h1388;
11'd903:font_init=16'h1188;
11'd904:font_init=16'h3188;
11'd905:font_init=16'h23c8;
11'd906:font_init=16'h2648;
11'd907:font_init=16'h2c6a;
11'd908:font_init=16'h600e;
11'd909:font_init=16'h4006;
11'd910:font_init=16'h4000;
11'd912:font_init=16'h0100;
11'd913:font_init=16'h0300;
11'd914:font_init=16'h3ffc;
11'd915:font_init=16'h0600;
11'd916:font_init=16'h0480;
11'd917:font_init=16'h0880;
11'd918:font_init=16'h1080;
11'd919:font_init=16'h1ffc;
11'd920:font_init=16'h0080;
11'd921:font_init=16'h0080;
11'd922:font_init=16'h7ffe;
11'd923:font_init=16'h0080;
11'd924:font_init=16'h0080;
11'd925:font_init=16'h0080;
11'd926:font_init=16'h0080;
11'd928:font_init=16'h0840;
11'd929:font_init=16'h08c0;
11'd930:font_init=16'h00fe;
11'd931:font_init=16'h7e80;
11'd932:font_init=16'h11fe;
11'd933:font_init=16'h11fe;
11'd934:font_init=16'h1c16;
11'd935:font_init=16'h3490;
11'd936:font_init=16'h349e;
11'd937:font_init=16'h2490;
11'd938:font_init=16'h2490;
11'd939:font_init=16'h65d0;
11'd940:font_init=16'h5d70;
11'd941:font_init=16'h423e;
11'd942:font_init=16'h0200;
11'd944:font_init=16'h0008;
11'd945:font_init=16'h3ff8;
11'd946:font_init=16'h0180;
11'd947:font_init=16'h0180;
11'd948:font_init=16'h3ffc;
11'd949:font_init=16'h0990;
11'd950:font_init=16'h0990;
11'd951:font_init=16'h7ffe;
11'd952:font_init=16'h0990;
11'd953:font_init=16'h0990;
11'd954:font_init=16'h3ffc;
11'd955:font_init=16'h0180;
11'd956:font_init=16'h0180;
11'd957:font_init=16'h1ffc;
11'd960:font_init=16'h1060;
11'd961:font_init=16'h13fe;
11'd962:font_init=16'h1202;
11'd963:font_init=16'h7ba0;
11'd964:font_init=16'h11dc;
11'd965:font_init=16'h1354;
11'd966:font_init=16'h1cdc;
11'd967:font_init=16'h3b8c;
11'd968:font_init=16'h5376;
11'd969:font_init=16'h1600;
11'd970:font_init=16'h11fc;
11'd971:font_init=16'h1128;
11'd972:font_init=16'h132c;
11'd973:font_init=16'h7262;
11'd976:font_init=16'h0060;
11'd977:font_init=16'h7c60;
11'd978:font_init=16'h64d0;
11'd979:font_init=16'h6898;
11'd980:font_init=16'h690e;
11'd981:font_init=16'h7efa;
11'd982:font_init=16'h6820;
11'd983:font_init=16'h6c20;
11'd984:font_init=16'h67fc;
11'd985:font_init=16'h6420;
11'd986:font_init=16'h79a8;
11'd987:font_init=16'h612c;
11'd988:font_init=16'h6226;
11'd989:font_init=16'h60e0;
11'd990:font_init=16'h6000;
11'd993:font_init=16'h7ffe;
11'd994:font_init=16'h0100;
11'd995:font_init=16'h0100;
11'd996:font_init=16'h1ff8;
11'd997:font_init=16'h1008;
11'd998:font_init=16'h1008;
11'd999:font_init=16'h1008;
11'd1000:font_init=16'h1ff8;
11'd1001:font_init=16'h1008;
11'd1002:font_init=16'h1008;
11'd1003:font_init=16'h1008;
11'd1004:font_init=16'h1ff8;
11'd1005:font_init=16'h1008;
11'd1006:font_init=16'h1000;
11'd1008:font_init=16'h0030;
11'd1009:font_init=16'h7c30;
11'd1010:font_init=16'h7c30;
11'd1011:font_init=16'h4430;
11'd1012:font_init=16'h4430;
11'd1013:font_init=16'h47fe;
11'd1014:font_init=16'h4430;
11'd1015:font_init=16'h4430;
11'd1016:font_init=16'h4430;
11'd1017:font_init=16'h7c30;
11'd1018:font_init=16'h4430;
11'd1019:font_init=16'h4430;
11'd1020:font_init=16'h4030;
11'd1021:font_init=16'h0030;
11'd1024:font_init=16'h0100;
11'd1025:font_init=16'h0180;
11'd1026:font_init=16'h7ffe;
11'd1027:font_init=16'h6472;
11'd1028:font_init=16'h3b1c;
11'd1029:font_init=16'h2204;
11'd1030:font_init=16'h1ffc;
11'd1031:font_init=16'h120c;
11'd1032:font_init=16'h17fc;
11'd1033:font_init=16'h1e6c;
11'd1034:font_init=16'h11cc;
11'd1035:font_init=16'h17cc;
11'd1036:font_init=16'h108c;
11'd1037:font_init=16'h1ffc;
11'd1038:font_init=16'h300c;
11'd1041:font_init=16'h3ffc;
11'd1042:font_init=16'h27e4;
11'd1043:font_init=16'h2424;
11'd1044:font_init=16'h27e4;
11'd1045:font_init=16'h2004;
11'd1046:font_init=16'h27e4;
11'd1047:font_init=16'h2424;
11'd1048:font_init=16'h25a4;
11'd1049:font_init=16'h2524;
11'd1050:font_init=16'h2144;
11'd1051:font_init=16'h2eb4;
11'd1052:font_init=16'h2814;
11'd1053:font_init=16'h3ffc;
11'd1054:font_init=16'h2004;
11'd1057:font_init=16'h7f8c;
11'd1058:font_init=16'h1218;
11'd1059:font_init=16'h1230;
11'd1060:font_init=16'h1260;
11'd1061:font_init=16'h1206;
11'd1062:font_init=16'h7f8c;
11'd1063:font_init=16'h1218;
11'd1064:font_init=16'h1230;
11'd1065:font_init=16'h1262;
11'd1066:font_init=16'h1204;
11'd1067:font_init=16'h2218;
11'd1068:font_init=16'h2230;
11'd1069:font_init=16'h6260;
11'd1072:font_init=16'h0180;
11'd1073:font_init=16'h0180;
11'd1074:font_init=16'h118c;
11'd1075:font_init=16'h1998;
11'd1076:font_init=16'h0db0;
11'd1077:font_init=16'h1180;
11'd1078:font_init=16'h7ffe;
11'd1079:font_init=16'h0240;
11'd1080:font_init=16'h0240;
11'd1081:font_init=16'h0640;
11'd1082:font_init=16'h0440;
11'd1083:font_init=16'h0c42;
11'd1084:font_init=16'h1846;
11'd1085:font_init=16'h707c;
11'd1088:font_init=16'h7ffe;
11'd1089:font_init=16'h2006;
11'd1090:font_init=16'h2526;
11'd1091:font_init=16'h2546;
11'd1092:font_init=16'h2ff6;
11'd1093:font_init=16'h2106;
11'd1094:font_init=16'h3ff6;
11'd1095:font_init=16'h2466;
11'd1096:font_init=16'h3ffe;
11'd1097:font_init=16'h26c6;
11'd1098:font_init=16'h2716;
11'd1099:font_init=16'h23f6;
11'd1100:font_init=16'h2006;
11'd1101:font_init=16'h3ffe;
11'd1102:font_init=16'h2006;
11'd1104:font_init=16'h0300;
11'd1105:font_init=16'h0180;
11'd1106:font_init=16'h0100;
11'd1107:font_init=16'h7ffe;
11'd1108:font_init=16'h0400;
11'd1109:font_init=16'h0400;
11'd1110:font_init=16'h0400;
11'd1111:font_init=16'h07f8;
11'd1112:font_init=16'h0408;
11'd1113:font_init=16'h0408;
11'd1114:font_init=16'h0c08;
11'd1115:font_init=16'h1818;
11'd1116:font_init=16'h1018;
11'd1117:font_init=16'h2070;
11'd1120:font_init=16'h1040;
11'd1121:font_init=16'h1040;
11'd1122:font_init=16'h1040;
11'd1123:font_init=16'h13fc;
11'd1124:font_init=16'h7c4c;
11'd1125:font_init=16'h104c;
11'd1126:font_init=16'h104c;
11'd1127:font_init=16'h17fe;
11'd1128:font_init=16'h1860;
11'd1129:font_init=16'h1460;
11'd1130:font_init=16'h38b0;
11'd1131:font_init=16'h6198;
11'd1132:font_init=16'h030c;
11'd1133:font_init=16'h0606;
11'd1134:font_init=16'h0402;
11'd1136:font_init=16'h0040;
11'd1137:font_init=16'h6040;
11'd1138:font_init=16'h17fe;
11'd1139:font_init=16'h0506;
11'd1140:font_init=16'h4518;
11'd1141:font_init=16'h736c;
11'd1142:font_init=16'h06e4;
11'd1143:font_init=16'h01b0;
11'd1144:font_init=16'h2318;
11'd1145:font_init=16'h3ffe;
11'd1146:font_init=16'h2208;
11'd1147:font_init=16'h2208;
11'd1148:font_init=16'h6208;
11'd1149:font_init=16'h43f8;
11'd1150:font_init=16'h0208;
11'd1152:font_init=16'h1800;
11'd1153:font_init=16'h10fe;
11'd1154:font_init=16'h3e22;
11'd1155:font_init=16'h6426;
11'd1156:font_init=16'h7f4c;
11'd1157:font_init=16'h2dc8;
11'd1158:font_init=16'h3f58;
11'd1159:font_init=16'h2d78;
11'd1160:font_init=16'h2d7e;
11'd1161:font_init=16'h3f98;
11'd1162:font_init=16'h2dfe;
11'd1163:font_init=16'h2d18;
11'd1164:font_init=16'h6d18;
11'd1165:font_init=16'h4318;
11'd1166:font_init=16'h0018;
11'd1168:font_init=16'h0100;
11'd1169:font_init=16'h7ffe;
11'd1171:font_init=16'h0ff0;
11'd1172:font_init=16'h0810;
11'd1173:font_init=16'h0ff0;
11'd1175:font_init=16'h7ffe;
11'd1176:font_init=16'h7ffe;
11'd1177:font_init=16'h4002;
11'd1178:font_init=16'h07e0;
11'd1179:font_init=16'h0460;
11'd1180:font_init=16'h0c62;
11'd1181:font_init=16'h387e;
11'd1182:font_init=16'h2000;
11'd1184:font_init=16'h0080;
11'd1185:font_init=16'h0080;
11'd1186:font_init=16'h3ffc;
11'd1187:font_init=16'h2210;
11'd1188:font_init=16'h2210;
11'd1189:font_init=16'h2ffc;
11'd1190:font_init=16'h2210;
11'd1191:font_init=16'h23f0;
11'd1192:font_init=16'h2000;
11'd1193:font_init=16'h2ff8;
11'd1194:font_init=16'h2310;
11'd1195:font_init=16'h21a0;
11'd1196:font_init=16'h60c0;
11'd1197:font_init=16'h473e;
11'd1198:font_init=16'h0802;
11'd1200:font_init=16'h0008;
11'd1201:font_init=16'h0008;
11'd1202:font_init=16'h7e08;
11'd1203:font_init=16'h0208;
11'd1204:font_init=16'h03fe;
11'd1205:font_init=16'h2408;
11'd1206:font_init=16'h3488;
11'd1207:font_init=16'h1c88;
11'd1208:font_init=16'h0c48;
11'd1209:font_init=16'h0c48;
11'd1210:font_init=16'h1608;
11'd1211:font_init=16'h3208;
11'd1212:font_init=16'h6008;
11'd1213:font_init=16'h4038;
11'd1216:font_init=16'h0300;
11'd1217:font_init=16'h0100;
11'd1218:font_init=16'h0180;
11'd1219:font_init=16'h7ffe;
11'd1220:font_init=16'h0830;
11'd1221:font_init=16'h0820;
11'd1222:font_init=16'h0c20;
11'd1223:font_init=16'h0460;
11'd1224:font_init=16'h0640;
11'd1225:font_init=16'h02c0;
11'd1226:font_init=16'h0180;
11'd1227:font_init=16'h03c0;
11'd1228:font_init=16'h0e70;
11'd1229:font_init=16'h781e;
11'd1232:font_init=16'h0100;
11'd1233:font_init=16'h0180;
11'd1234:font_init=16'h3ffe;
11'd1235:font_init=16'h2006;
11'd1236:font_init=16'h2006;
11'd1237:font_init=16'h0ff0;
11'd1238:font_init=16'h0060;
11'd1239:font_init=16'h00c0;
11'd1240:font_init=16'h0080;
11'd1241:font_init=16'h7ffe;
11'd1242:font_init=16'h0080;
11'd1243:font_init=16'h0080;
11'd1244:font_init=16'h0080;
11'd1245:font_init=16'h0380;
11'd1246:font_init=16'h0200;
11'd1248:font_init=16'h0040;
11'd1249:font_init=16'h2060;
11'd1250:font_init=16'h1ffe;
11'd1251:font_init=16'h0118;
11'd1252:font_init=16'h4246;
11'd1253:font_init=16'h6492;
11'd1254:font_init=16'h3118;
11'd1255:font_init=16'h03fc;
11'd1256:font_init=16'h00e8;
11'd1257:font_init=16'h11a4;
11'd1258:font_init=16'h3398;
11'd1259:font_init=16'h2d98;
11'd1260:font_init=16'h61cc;
11'd1261:font_init=16'h4186;
11'd1262:font_init=16'h0100;
11'd1264:font_init=16'h0040;
11'd1265:font_init=16'h27fe;
11'd1266:font_init=16'h37fe;
11'd1267:font_init=16'h1040;
11'd1268:font_init=16'h03fc;
11'd1269:font_init=16'h0244;
11'd1270:font_init=16'h7244;
11'd1271:font_init=16'h37fc;
11'd1272:font_init=16'h30d0;
11'd1273:font_init=16'h3158;
11'd1274:font_init=16'h3246;
11'd1275:font_init=16'h3440;
11'd1276:font_init=16'h3800;
11'd1277:font_init=16'hc7fe;
11'd1278:font_init=16'h4000;
11'd1280:font_init=16'h0200;
11'd1281:font_init=16'h0600;
11'd1282:font_init=16'h0400;
11'd1283:font_init=16'h3ffe;
11'd1284:font_init=16'h2006;
11'd1285:font_init=16'h2006;
11'd1286:font_init=16'h27e6;
11'd1287:font_init=16'h2426;
11'd1288:font_init=16'h2426;
11'd1289:font_init=16'h2426;
11'd1290:font_init=16'h27e6;
11'd1291:font_init=16'h2006;
11'd1292:font_init=16'h2006;
11'd1293:font_init=16'h201c;
11'd1296:font_init=16'h0c00;
11'd1297:font_init=16'h0c30;
11'd1298:font_init=16'h0c60;
11'd1299:font_init=16'h0cc0;
11'd1300:font_init=16'h0d80;
11'd1301:font_init=16'h0d00;
11'd1302:font_init=16'h7ffe;
11'd1303:font_init=16'h0c80;
11'd1304:font_init=16'h0cc0;
11'd1305:font_init=16'h0c40;
11'd1306:font_init=16'h0c20;
11'd1307:font_init=16'h0db8;
11'd1308:font_init=16'h0e1e;
11'd1309:font_init=16'h0c04;
11'd1312:font_init=16'h0460;
11'd1313:font_init=16'h7ffc;
11'd1314:font_init=16'h0460;
11'd1315:font_init=16'h1ff8;
11'd1316:font_init=16'h1018;
11'd1317:font_init=16'h1ff8;
11'd1318:font_init=16'h1ff8;
11'd1319:font_init=16'h0200;
11'd1320:font_init=16'h7ffe;
11'd1321:font_init=16'h0db0;
11'd1322:font_init=16'hfffe;
11'd1323:font_init=16'h0990;
11'd1324:font_init=16'h0990;
11'd1325:font_init=16'h09b0;
11'd1326:font_init=16'h0180;
11'd1328:font_init=16'h0100;
11'd1329:font_init=16'h0180;
11'd1330:font_init=16'h3ffc;
11'd1331:font_init=16'h0c30;
11'd1332:font_init=16'h0420;
11'd1333:font_init=16'h0460;
11'd1334:font_init=16'h7ffe;
11'd1336:font_init=16'h1ff8;
11'd1337:font_init=16'h1818;
11'd1338:font_init=16'h1ff8;
11'd1339:font_init=16'h1818;
11'd1340:font_init=16'h1818;
11'd1341:font_init=16'h1ff8;
11'd1342:font_init=16'h1818;
11'd1344:font_init=16'h0800;
11'd1345:font_init=16'h28fe;
11'd1346:font_init=16'h2f10;
11'd1347:font_init=16'h2820;
11'd1348:font_init=16'h287e;
11'd1349:font_init=16'h7f46;
11'd1350:font_init=16'h0856;
11'd1351:font_init=16'h2856;
11'd1352:font_init=16'h2b56;
11'd1353:font_init=16'h6a56;
11'd1354:font_init=16'h0e56;
11'd1355:font_init=16'h0c28;
11'd1356:font_init=16'h186c;
11'd1357:font_init=16'h61c6;
11'd1361:font_init=16'h1ff8;
11'd1362:font_init=16'h0100;
11'd1363:font_init=16'h0100;
11'd1364:font_init=16'h0100;
11'd1365:font_init=16'h0100;
11'd1366:font_init=16'h7ffe;
11'd1367:font_init=16'h0340;
11'd1368:font_init=16'h0240;
11'd1369:font_init=16'h0240;
11'd1370:font_init=16'h0640;
11'd1371:font_init=16'h0c42;
11'd1372:font_init=16'h1846;
11'd1373:font_init=16'h707c;
11'd1376:font_init=16'h2000;
11'd1377:font_init=16'h31f0;
11'd1378:font_init=16'h1910;
11'd1379:font_init=16'h0110;
11'd1380:font_init=16'h0310;
11'd1381:font_init=16'h761e;
11'd1382:font_init=16'h1400;
11'd1383:font_init=16'h13f8;
11'd1384:font_init=16'h1108;
11'd1385:font_init=16'h1190;
11'd1386:font_init=16'h14b0;
11'd1387:font_init=16'h1c60;
11'd1388:font_init=16'h18f0;
11'd1389:font_init=16'h131e;
11'd1390:font_init=16'h0c02;
11'd1393:font_init=16'h3ffc;
11'd1394:font_init=16'h3244;
11'd1395:font_init=16'h3ffc;
11'd1396:font_init=16'h0180;
11'd1397:font_init=16'h3ffc;
11'd1398:font_init=16'h0ff8;
11'd1399:font_init=16'h0810;
11'd1400:font_init=16'h0ff0;
11'd1401:font_init=16'h0810;
11'd1402:font_init=16'h0ff0;
11'd1403:font_init=16'h0ff0;
11'd1404:font_init=16'h0810;
11'd1405:font_init=16'h7ffe;
11'd1408:font_init=16'h11fc;
11'd1409:font_init=16'h1104;
11'd1410:font_init=16'h11fc;
11'd1411:font_init=16'h5d04;
11'd1412:font_init=16'h75fc;
11'd1413:font_init=16'h53fe;
11'd1414:font_init=16'h5292;
11'd1415:font_init=16'h1292;
11'd1416:font_init=16'h116c;
11'd1417:font_init=16'h13fc;
11'd1418:font_init=16'h1088;
11'd1419:font_init=16'h10d0;
11'd1420:font_init=16'h1070;
11'd1421:font_init=16'h178e;
11'd1422:font_init=16'h1000;
11'd1424:font_init=16'h0180;
11'd1425:font_init=16'h0180;
11'd1426:font_init=16'h0180;
11'd1427:font_init=16'h3ffc;
11'd1428:font_init=16'h2184;
11'd1429:font_init=16'h2184;
11'd1430:font_init=16'h2184;
11'd1431:font_init=16'h2184;
11'd1432:font_init=16'h3ffc;
11'd1433:font_init=16'h2184;
11'd1434:font_init=16'h0180;
11'd1435:font_init=16'h0180;
11'd1436:font_init=16'h0180;
11'd1437:font_init=16'h0180;
11'd1438:font_init=16'h0180;
11'd1440:font_init=16'h1040;
11'd1441:font_init=16'h1040;
11'd1442:font_init=16'h1040;
11'd1443:font_init=16'h1bf8;
11'd1444:font_init=16'h7448;
11'd1445:font_init=16'h5448;
11'd1446:font_init=16'h5048;
11'd1447:font_init=16'h53fe;
11'd1448:font_init=16'h1060;
11'd1449:font_init=16'h10e0;
11'd1450:font_init=16'h1090;
11'd1451:font_init=16'h1198;
11'd1452:font_init=16'h130c;
11'd1453:font_init=16'h1606;
11'd1454:font_init=16'h1000;
11'd1456:font_init=16'h0300;
11'd1457:font_init=16'h0300;
11'd1458:font_init=16'h0200;
11'd1459:font_init=16'h3ffe;
11'd1460:font_init=16'h0200;
11'd1461:font_init=16'h0600;
11'd1462:font_init=16'h0400;
11'd1463:font_init=16'h0ffc;
11'd1464:font_init=16'h08c0;
11'd1465:font_init=16'h18c0;
11'd1466:font_init=16'h30c0;
11'd1467:font_init=16'h60c0;
11'd1468:font_init=16'h40c0;
11'd1469:font_init=16'h1ffe;
11'd1472:font_init=16'h0180;
11'd1473:font_init=16'h0100;
11'd1474:font_init=16'h0300;
11'd1475:font_init=16'h7ffe;
11'd1476:font_init=16'h0200;
11'd1477:font_init=16'h0600;
11'd1478:font_init=16'h0400;
11'd1479:font_init=16'h0ff8;
11'd1480:font_init=16'h1c08;
11'd1481:font_init=16'h3c08;
11'd1482:font_init=16'h6c08;
11'd1483:font_init=16'h4c08;
11'd1484:font_init=16'h0ff8;
11'd1485:font_init=16'h0ff8;
11'd1486:font_init=16'h0c08;
11'd1488:font_init=16'h2000;
11'd1489:font_init=16'h21fe;
11'd1490:font_init=16'h6200;
11'd1491:font_init=16'h7e00;
11'd1492:font_init=16'h48fc;
11'd1493:font_init=16'h0884;
11'd1494:font_init=16'h0884;
11'd1495:font_init=16'h7e84;
11'd1496:font_init=16'h18fc;
11'd1497:font_init=16'h188c;
11'd1498:font_init=16'h1ccc;
11'd1499:font_init=16'h3648;
11'd1500:font_init=16'h2098;
11'd1501:font_init=16'h41fe;
11'd1504:font_init=16'h0420;
11'd1505:font_init=16'h0420;
11'd1506:font_init=16'h7ffe;
11'd1507:font_init=16'h0420;
11'd1508:font_init=16'h0180;
11'd1509:font_init=16'h1ff8;
11'd1510:font_init=16'h1998;
11'd1511:font_init=16'h1998;
11'd1512:font_init=16'h1998;
11'd1513:font_init=16'h7ffe;
11'd1514:font_init=16'h01c0;
11'd1515:font_init=16'h0260;
11'd1516:font_init=16'h0c38;
11'd1517:font_init=16'h780e;
11'd1520:font_init=16'h23fe;
11'd1521:font_init=16'h3040;
11'd1522:font_init=16'h1040;
11'd1523:font_init=16'h03fc;
11'd1524:font_init=16'h00cc;
11'd1525:font_init=16'h708c;
11'd1526:font_init=16'h17fe;
11'd1527:font_init=16'h1000;
11'd1528:font_init=16'h1000;
11'd1529:font_init=16'h11fc;
11'd1530:font_init=16'h1d04;
11'd1531:font_init=16'h1904;
11'd1532:font_init=16'h1104;
11'd1533:font_init=16'h11fc;
11'd1534:font_init=16'h0104;
11'd1538:font_init=16'h3c00;
11'd1539:font_init=16'h6400;
11'd1540:font_init=16'h4200;
11'd1541:font_init=16'h4200;
11'd1542:font_init=16'h4200;
11'd1543:font_init=16'h4200;
11'd1544:font_init=16'h4200;
11'd1545:font_init=16'h4200;
11'd1546:font_init=16'h4600;
11'd1547:font_init=16'h2c00;
11'd1548:font_init=16'h1800;
11'd1554:font_init=16'h0800;
11'd1555:font_init=16'h1800;
11'd1556:font_init=16'h7800;
11'd1557:font_init=16'h5800;
11'd1558:font_init=16'h1800;
11'd1559:font_init=16'h1800;
11'd1560:font_init=16'h1800;
11'd1561:font_init=16'h1800;
11'd1562:font_init=16'h1800;
11'd1563:font_init=16'h1800;
11'd1564:font_init=16'h1800;
11'd1570:font_init=16'h3c00;
11'd1571:font_init=16'h6600;
11'd1572:font_init=16'h4200;
11'd1573:font_init=16'h0600;
11'd1574:font_init=16'h0400;
11'd1575:font_init=16'h0c00;
11'd1576:font_init=16'h0800;
11'd1577:font_init=16'h1000;
11'd1578:font_init=16'h2000;
11'd1579:font_init=16'h7e00;
11'd1580:font_init=16'h7e00;
11'd1586:font_init=16'h3c00;
11'd1587:font_init=16'h6600;
11'd1588:font_init=16'h4200;
11'd1589:font_init=16'h0600;
11'd1590:font_init=16'h0c00;
11'd1591:font_init=16'h0c00;
11'd1592:font_init=16'h0600;
11'd1593:font_init=16'h0200;
11'd1594:font_init=16'h4200;
11'd1595:font_init=16'h6400;
11'd1596:font_init=16'h1800;
11'd1602:font_init=16'h0400;
11'd1603:font_init=16'h0c00;
11'd1604:font_init=16'h1c00;
11'd1605:font_init=16'h1400;
11'd1606:font_init=16'h2400;
11'd1607:font_init=16'h6400;
11'd1608:font_init=16'h4400;
11'd1609:font_init=16'hff00;
11'd1610:font_init=16'h0400;
11'd1611:font_init=16'h0400;
11'd1612:font_init=16'h0400;
11'd1618:font_init=16'h3e00;
11'd1619:font_init=16'h6000;
11'd1620:font_init=16'h4000;
11'd1621:font_init=16'h5000;
11'd1622:font_init=16'h7c00;
11'd1623:font_init=16'h4600;
11'd1624:font_init=16'h0200;
11'd1625:font_init=16'h0200;
11'd1626:font_init=16'hc600;
11'd1627:font_init=16'h6c00;
11'd1628:font_init=16'h3800;
11'd1634:font_init=16'h0800;
11'd1635:font_init=16'h1800;
11'd1636:font_init=16'h1000;
11'd1637:font_init=16'h3000;
11'd1638:font_init=16'h7c00;
11'd1639:font_init=16'h6200;
11'd1640:font_init=16'h4300;
11'd1641:font_init=16'h4300;
11'd1642:font_init=16'h4200;
11'd1643:font_init=16'h6600;
11'd1644:font_init=16'h3c00;
11'd1650:font_init=16'h7e00;
11'd1651:font_init=16'h0200;
11'd1652:font_init=16'h0600;
11'd1653:font_init=16'h0400;
11'd1654:font_init=16'h0c00;
11'd1655:font_init=16'h0800;
11'd1656:font_init=16'h1800;
11'd1657:font_init=16'h1000;
11'd1658:font_init=16'h1000;
11'd1659:font_init=16'h3000;
11'd1660:font_init=16'h3000;
11'd1666:font_init=16'h3c00;
11'd1667:font_init=16'h4600;
11'd1668:font_init=16'h4200;
11'd1669:font_init=16'h4600;
11'd1670:font_init=16'h7c00;
11'd1671:font_init=16'h7c00;
11'd1672:font_init=16'h4200;
11'd1673:font_init=16'hc200;
11'd1674:font_init=16'h4200;
11'd1675:font_init=16'h6600;
11'd1676:font_init=16'h3c00;
11'd1682:font_init=16'h3c00;
11'd1683:font_init=16'h4600;
11'd1684:font_init=16'hc200;
11'd1685:font_init=16'hc200;
11'd1686:font_init=16'hc600;
11'd1687:font_init=16'h6c00;
11'd1688:font_init=16'h3c00;
11'd1689:font_init=16'h0800;
11'd1690:font_init=16'h1800;
11'd1691:font_init=16'h1000;
11'd1692:font_init=16'h3000;
11'd1702:font_init=16'h1800;
11'd1707:font_init=16'h1800;
11'd1708:font_init=16'h1800;
11'd1714:font_init=16'h0200;
11'd1715:font_init=16'h0400;
11'd1716:font_init=16'h0400;
11'd1717:font_init=16'h0800;
11'd1718:font_init=16'h0800;
11'd1719:font_init=16'h1000;
11'd1720:font_init=16'h1000;
11'd1721:font_init=16'h2000;
11'd1722:font_init=16'h2000;
11'd1723:font_init=16'h4000;
11'd1724:font_init=16'h8000;
11'd1739:font_init=16'h6000;
11'd1740:font_init=16'h6000;
11'd1751:font_init=16'hfe00;
11'd1762:font_init=16'h1800;
11'd1763:font_init=16'h1800;
11'd1764:font_init=16'h1800;
11'd1765:font_init=16'h3c00;
11'd1766:font_init=16'h2400;
11'd1767:font_init=16'h2400;
11'd1768:font_init=16'h7c00;
11'd1769:font_init=16'h6600;
11'd1770:font_init=16'h4200;
11'd1771:font_init=16'h4200;
11'd1772:font_init=16'hc300;
11'd1778:font_init=16'h4200;
11'd1779:font_init=16'h6200;
11'd1780:font_init=16'h6200;
11'd1781:font_init=16'h7200;
11'd1782:font_init=16'h5200;
11'd1783:font_init=16'h5a00;
11'd1784:font_init=16'h4a00;
11'd1785:font_init=16'h4e00;
11'd1786:font_init=16'h4600;
11'd1787:font_init=16'h4600;
11'd1788:font_init=16'h4600;
11'd1794:font_init=16'h4000;
11'd1795:font_init=16'h4000;
11'd1796:font_init=16'h4000;
11'd1797:font_init=16'h4000;
11'd1798:font_init=16'h4000;
11'd1799:font_init=16'h4000;
11'd1800:font_init=16'h4000;
11'd1801:font_init=16'h4000;
11'd1802:font_init=16'h4000;
11'd1803:font_init=16'h7e00;
11'd1804:font_init=16'h7e00;
11'd1810:font_init=16'h3c00;
11'd1811:font_init=16'h6600;
11'd1812:font_init=16'h4200;
11'd1813:font_init=16'h4200;
11'd1814:font_init=16'hc200;
11'd1815:font_init=16'hc200;
11'd1816:font_init=16'hc200;
11'd1817:font_init=16'h4200;
11'd1818:font_init=16'h4600;
11'd1819:font_init=16'h6400;
11'd1820:font_init=16'h1800;
11'd1826:font_init=16'h3c00;
11'd1827:font_init=16'h6600;
11'd1828:font_init=16'h4200;
11'd1829:font_init=16'h4200;
11'd1830:font_init=16'h4000;
11'd1831:font_init=16'h4e00;
11'd1832:font_init=16'h4e00;
11'd1833:font_init=16'h4200;
11'd1834:font_init=16'h6200;
11'd1835:font_init=16'h3600;
11'd1836:font_init=16'h1a00;
11'd1842:font_init=16'h1800;
11'd1843:font_init=16'h1800;
11'd1844:font_init=16'h1800;
11'd1845:font_init=16'h1800;
11'd1846:font_init=16'h1800;
11'd1847:font_init=16'h1800;
11'd1848:font_init=16'h1800;
11'd1849:font_init=16'h1800;
11'd1850:font_init=16'h1800;
11'd1851:font_init=16'h1800;
11'd1852:font_init=16'h1800;
11'd1858:font_init=16'h3c00;
11'd1859:font_init=16'h6600;
11'd1860:font_init=16'h4200;
11'd1861:font_init=16'h4200;
11'd1862:font_init=16'h4000;
11'd1863:font_init=16'h4000;
11'd1864:font_init=16'h4200;
11'd1865:font_init=16'h4200;
11'd1866:font_init=16'h6200;
11'd1867:font_init=16'h3600;
11'd1868:font_init=16'h1c00;
11'd1874:font_init=16'h7e00;
11'd1875:font_init=16'h4000;
11'd1876:font_init=16'h4000;
11'd1877:font_init=16'h4000;
11'd1878:font_init=16'h4000;
11'd1879:font_init=16'h7c00;
11'd1880:font_init=16'h4000;
11'd1881:font_init=16'h4000;
11'd1882:font_init=16'h4000;
11'd1883:font_init=16'h4000;
11'd1884:font_init=16'h4000;
11'd1890:font_init=16'h7c00;
11'd1891:font_init=16'h4600;
11'd1892:font_init=16'h4200;
11'd1893:font_init=16'h4200;
11'd1894:font_init=16'h4200;
11'd1895:font_init=16'h7e00;
11'd1896:font_init=16'h7000;
11'd1897:font_init=16'h4000;
11'd1898:font_init=16'h4000;
11'd1899:font_init=16'h4000;
11'd1900:font_init=16'h4000;
default:font_init=0;endcase end endfunction
 (* rom_style="bram",ram_style="bram" *) reg [15:0] font[0:2047];
 integer i;initial for(i=0;i<2048;i=i+1)font[i]=font_init(i);
 reg [71:0] line;reg active;reg [3:0] gx,gy;reg [23:0] ink;reg [5:0] operation;
 wire [9:0] dx=x-10'd488;
 reg [7:0] gid;
 always @* begin
 operation=6'd32;
 case(sw_code)
 1:operation=25;2:operation=26;3:operation=27;4:operation=9;5:operation=28;6:operation=29;7,8:operation=8;9:operation=31;10:operation=10;11:operation=11;12:operation=30;default:;endcase
 line=0;active=0;gx=dx[3:0];gy=y[3:0];ink=24'hdce5ee;
 if(enable && de && x>=488 && x<632) begin
 active=1;case(y[8:4])
 0:begin line=label(33);ink=24'h39b9c8;end
 1:line=label(0);
 2:begin active=0;end
 3:begin line=label(1);ink=24'h8b9aa9;end
 4:line={digit(clock_frame[23:20]),digit(clock_frame[19:16]),8'd106,digit(clock_frame[15:12]),digit(clock_frame[11:8]),8'd106,digit(clock_frame[7:4]),digit(clock_frame[3:0]),8'd0};
 5:begin line=label(2);ink=24'h8b9aa9;end
 6:active=0;
 7:line={32'h0b0c0000,8'd0,digit(image_valid ? {2'd0,image_index}+4'd1:4'd0),8'd107,digit(4),8'd0};
 8:begin line={32'h0d0e0000,8'd0,auto_play ? 32'h0f100000:32'h11120000};end
 9:active=0;
 10:begin line=label(7);ink=24'h8b9aa9;end
 11:begin line=label(operation);ink=24'h39b9c8;end
 12:line=label(interpolation ? 12:13);
 13:line=label(scale_mode==1 ? 15:scale_mode==2 ? 16:14);
 14:line={32'h2b2c0000,40'd0};
 15:line=label(6'd17+{3'd0,transition_mode});
 16:line={32'h494a0000,8'd0,digit(brightness==10 ? 1:0),digit(brightness==10 ? 0:brightness),16'd0};
 17:line={48'h4b234a000000,digit(contrast==10 ? 1:0),digit(contrast==10 ? 0:contrast),8'd0};
 18:begin line=selected_value(sw_code,setting_value-4'd1);ink=24'ha8b3c0;end
 default:active=0;endcase end
 gid=(line >> ((8-dx[7:4])*8));
 end
 reg [15:0] bits;reg v1;reg [3:0] gx1;reg [23:0] c1;
 always @(posedge clk) bits<=font[{gid[6:0],gy}];
 always @(posedge clk or posedge rst)begin
 if(rst)begin v1<=0;gx1<=0;valid<=0;pixel<=0;c1<=0;color<=0;end
 else begin v1<=active;gx1<=gx;c1<=ink;valid<=v1;pixel<=v1 && bits[15-gx1];color<=c1;end end
 endmodule
