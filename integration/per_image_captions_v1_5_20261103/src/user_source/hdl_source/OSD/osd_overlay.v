`timescale 1ns/1ps
// Black fixed/status text plus optional bottom scrolling banner; three stages.
// enable must be stable for an active frame; frame-boundary control is upstream.
//
// text_mode  : 0=文字关闭 1=只显示固定状态 OSD 2=只显示滚动字幕 3=两者同时
// scroll_speed: 0=慢(1 像素/帧) 1=中(2 像素/帧) 2=快(4 像素/帧)
// scroll_dir : 0=向左 1=向右
//
// 滚动位置只在每帧消隐边界（VS 起始沿）更新一次，一帧有效区内保持不变。
// 方向改变时保留当前位置，下一帧起反向移动；字幕完全移出后从另一侧进入。
// SW=1010/1011 时底部改为居中显示 BRIGHTNESS:nn / CONTRAST:nn 调节提示。
// sub_mode 控制中英双语字幕层：0=关闭 1=只中文 2=只英文 3=双语上下叠加。
module osd_overlay #(parameter STATUS_MODE=0, parameter SCROLL_ENABLE=1) (
    input wire clk,
    input wire rst,
    input wire enable,
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
    wire layout_valid;
    wire [7:0] layout_char;
    wire [2:0] layout_x;
    wire [3:0] layout_y;
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

    // ---------------- 底部滚动字幕 ----------------
    // 20 个字符，8x16 字形，共 160 像素宽，显示在第 448~463 行。
    // text_pos 是“字形串左边缘 + 160”的偏置值：
    //   text_pos = 0    左边缘在 x=-160（完全移出左侧）
    //   text_pos = 800  左边缘在 x=+640（完全移出右侧）
    // 行内有效条件为 0 <= in_x - (text_pos-160) < 160，改写为下面的模 1024 运算。
    localparam [9:0] TEXT_W       = 10'd160;
    localparam [9:0] TEXT_POS_MAX = 10'd800;   // TEXT_W + 640

    reg [9:0] text_pos;         // 偏置后的字幕左边缘
    reg [1:0] text_mode_frame;  // 在帧边界锁存的显示模式
    reg vs_prev;

    wire frame_tick = vs_prev && !in_vs && !in_de;

    // 每帧步进 1/2/4 像素
    wire [9:0] scroll_step = (scroll_speed == 2'd0) ? 10'd1 :
                             (scroll_speed == 2'd1) ? 10'd2 : 10'd4;

    // 调节提示字幕的使能与选项必须先声明，供滚动字幕互斥使用。
    wire msg_bright = (sw_code == 4'b1010);
    wire msg_contra = (sw_code == 4'b1011);
    wire msg_on     = enable && (msg_bright || msg_contra);

    wire scroll_on    = SCROLL_ENABLE && enable && text_mode_frame[1] && !msg_on;
    wire fixed_on     = enable && text_mode_frame[0];
    wire [9:0] scroll_local = in_x + TEXT_W - text_pos;
    wire scroll_valid = scroll_on && in_de && (in_x < 10'd640) &&
                        (in_y >= 9'd448) && (in_y < 9'd464) &&
                        (scroll_local < TEXT_W);

    reg [7:0] scroll_char;
    always @* begin
        scroll_char = " ";
        case (scroll_local[9:3])
            0: scroll_char="W";
            1: scroll_char="E";
            2: scroll_char="L";
            3: scroll_char="C";
            4: scroll_char="O";
            5: scroll_char="M";
            6: scroll_char="E";
            7: scroll_char=" ";
            8: scroll_char="T";
            9: scroll_char="O";
            10: scroll_char=" ";
            11: scroll_char="A";
            12: scroll_char="N";
            13: scroll_char="L";
            14: scroll_char="U";
            15: scroll_char=" ";
            16: scroll_char="F";
            17: scroll_char="P";
            18: scroll_char="G";
            19: scroll_char="A";
            default: scroll_char=" ";
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            text_pos        <= TEXT_POS_MAX;   // 复位后完全移出右侧，向左进场
            text_mode_frame <= 2'd0;
            vs_prev         <= 1'b0;
        end else begin
            vs_prev <= in_vs;
            if (frame_tick) begin
                text_mode_frame <= text_mode;
                if (scroll_dir) begin
                    // 向右：左边缘 x 递增，移出右侧后改从左侧进入
                    if (({1'b0, text_pos} + {1'b0, scroll_step}) > {1'b0, TEXT_POS_MAX})
                        text_pos <= 10'd0;
                    else
                        text_pos <= text_pos + scroll_step;
                end else begin
                    // 向左：左边缘 x 递减，移出左侧后改从右侧进入
                    if (text_pos < scroll_step)
                        text_pos <= TEXT_POS_MAX;
                    else
                        text_pos <= text_pos - scroll_step;
                end
            end
        end
    end

    // ---------------- 调节提示字幕 ----------------
    // SW=1010 显示 BRIGHTNESS:nn，SW=1011 显示 CONTRAST:nn，居中放在底部同一行。
    // 提示字幕不受文字显示模式影响，拨到该设置项就显示，便于看清档位。
    // msg_bright / msg_contra / msg_on 已在滚动字幕之前声明。
    wire [3:0] msg_level = msg_contra ? contrast : brightness;
    wire [9:0] msg_x0  = msg_contra ? 10'd276 : 10'd268;
    wire [9:0] msg_len = msg_contra ? 10'd88  : 10'd104;  // 11/13 字符，单位像素
    wire [9:0] msg_local = in_x - msg_x0;
    wire msg_valid = msg_on && in_de && (in_x >= msg_x0) &&
                     (in_x < msg_x0 + msg_len) &&
                     (in_y >= 9'd448) && (in_y < 9'd464) && (msg_local < msg_len);

    wire [3:0] msg_units = (msg_level >= 4'd10) ? (msg_level - 4'd10) : msg_level;
    wire [7:0] msg_ones  = 8'h30 + {4'd0, msg_units};
    wire [7:0] msg_tens  = (msg_level >= 4'd10) ? "1" : " ";

    reg [7:0] msg_char;
    always @* begin
        msg_char = " ";
        case (msg_local[9:3])
            0: msg_char = msg_contra ? "C" : "B";
            1: msg_char = msg_contra ? "O" : "R";
            2: msg_char = msg_contra ? "N" : "I";
            3: msg_char = msg_contra ? "T" : "G";
            4: msg_char = msg_contra ? "R" : "H";
            5: msg_char = msg_contra ? "A" : "T";
            6: msg_char = msg_contra ? "S" : "N";
            7: msg_char = msg_contra ? "T" : "E";
            8: msg_char = msg_contra ? ":" : "S";
            9: msg_char = msg_contra ? msg_tens : "S";
            10: msg_char = msg_contra ? msg_ones : ":";
            11: msg_char = msg_tens;
            12: msg_char = msg_ones;
            default: msg_char = " ";
        endcase
    end

    // ---------------- 中英文双语字幕 ----------------
    // sub_mode: 0=关闭 1=只中文 2=只英文 3=双语上下叠加
    // 中文：16x16 点阵，第 400~415 行，跟随当前图片切换，跑马灯横向滚动
    // 英文：8x16 字形，第 424~439 行，跟随当前图片切换，居中静态显示
    localparam [9:0] ZH_Y0  = 10'd400;
    localparam [9:0] EN_X0  = 10'd160;
    localparam [9:0] EN_LEN = 10'd256;   // 32 字符 x 8 像素

    wire sub_zh_on = enable && in_de && ((sub_mode == 2'd1) || (sub_mode == 2'd3));
    wire sub_en_on = enable && in_de && ((sub_mode == 2'd2) || (sub_mode == 2'd3));

    // ---------- 中文跑马灯 ----------
    wire [7:0]  zh_len   = cap_len(image_index);
    wire [10:0] zh_trip  = {3'd0, zh_len} << 4;         // 文字宽度 = 字数 x 16
    wire [10:0] zh_total = zh_trip + 11'd640;

    reg [10:0] zh_pos;        // 文字左边缘 + trip：0=完全在左侧外，total=完全在右侧外
    reg [1:0]  zh_cap_seen;
    reg        zh_vs_prev;
    wire zh_frame = zh_vs_prev && !in_vs && !in_de;
    wire [10:0] zh_step = (scroll_speed == 2'd0) ? 11'd1 :
                          (scroll_speed == 2'd1) ? 11'd2 : 11'd4;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            zh_pos      <= 11'd0;
            zh_cap_seen <= 2'd3;
            zh_vs_prev  <= 1'b0;
        end else begin
            zh_vs_prev <= in_vs;
            if (image_index != zh_cap_seen) begin
                // 换图重新从右侧进场
                zh_cap_seen <= image_index;
                zh_pos      <= zh_total;
            end else if (zh_pos > zh_total) begin
                zh_pos <= zh_total;      // 字幕长度变化时收回有效范围
            end else if (zh_frame) begin
                if (scroll_dir) begin
                    if (zh_pos + zh_step >= zh_total) zh_pos <= 11'd0;
                    else                              zh_pos <= zh_pos + zh_step;
                end else begin
                    if (zh_pos < zh_step) zh_pos <= zh_total;
                    else                  zh_pos <= zh_pos - zh_step;
                end
            end
        end
    end

    wire [10:0] zh_local = {1'b0, in_x} + zh_trip - zh_pos;
    wire        zh_req_valid = sub_zh_on && (in_y >= ZH_Y0) && (in_y < ZH_Y0 + 10'd16) &&
                               (zh_local < zh_trip);
    wire [7:0]  zh_char_idx = cap_start(image_index) + {4'd0, zh_local[9:4]};
    wire [6:0]  zh_gid = cap_char(zh_char_idx);
    wire [3:0]  zh_gx  = zh_local[3:0];
    wire [3:0]  zh_gy  = in_y[3:0];      // 400 是 16 的整数倍

    // 中文 16x16 采用与 ASCII 字形通路相同的两级流水（整体 2 拍延迟）
    reg [15:0] zh_row;
    reg        zh_v1, zh_v2, zh_pix;
    reg [3:0]  zh_gx_d1;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            zh_row   <= 16'd0;
            zh_v1    <= 1'b0;
            zh_v2    <= 1'b0;
            zh_pix   <= 1'b0;
            zh_gx_d1 <= 4'd0;
        end else begin
            zh_row   <= zh_req_valid ? zh_glyph_row(zh_gid, zh_gy) : 16'd0;
            zh_v1    <= zh_req_valid;
            zh_gx_d1 <= zh_req_valid ? zh_gx : 4'd0;
            zh_v2    <= zh_v1;
            zh_pix   <= zh_v1 ? zh_row[4'd15 - zh_gx_d1] : 1'b0;
        end
    end

    // ---------- 英文静态标题 ----------
    wire [9:0] en_local = in_x - EN_X0;
    wire [8:0] en_y_ofs = in_y - 9'd424;
    wire sub_en_valid = sub_en_on && (in_x >= EN_X0) && (in_x < EN_X0 + EN_LEN) &&
                        (in_y >= 9'd424) && (in_y < 9'd440);
    wire [2:0] en_gx = en_local[2:0];
    wire [3:0] en_gy = en_y_ofs[3:0];

    wire [7:0] sub_en_char = sub_en_glyph(image_index, en_local[7:3]);

    assign text_valid = layout_valid || scroll_valid || msg_valid || sub_en_valid;
    assign char_code = msg_valid ? msg_char :
                       sub_en_valid ? sub_en_char :
                       scroll_valid ? scroll_char : layout_char;
    assign glyph_x = msg_valid ? msg_local[2:0] :
                     sub_en_valid ? en_gx :
                     scroll_valid ? scroll_local[2:0] : layout_x;
    assign glyph_y = msg_valid ? (in_y - 9'd448) :
                     sub_en_valid ? en_gy :
                     scroll_valid ? (in_y - 9'd448) : layout_y;
    // {DE, HS, VS, X[9:0], Y[8:0], RGB[23:0]}, 46 bits.
    reg [45:0] video_d1, video_d2;
    generate if (STATUS_MODE) begin : status_mode
    osd_status_layout layout (
        .enable(fixed_on), .in_de(in_de), .in_x(in_x), .in_y(in_y),
        .image_valid(image_valid), .image_index(image_index), .auto_play(auto_play),
        .sw_code(sw_code), .setting_value(setting_value),
        .text_valid(layout_valid), .char_code(layout_char),
        .glyph_x(layout_x), .glyph_y(layout_y)
    );
    end else begin : fixed_mode
    osd_fixed_layout layout (
        .enable(fixed_on), .in_de(in_de), .in_x(in_x), .in_y(in_y),
        .text_valid(layout_valid), .char_code(layout_char),
        .glyph_x(layout_x), .glyph_y(layout_y)
    );
    end endgenerate
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
            else if (glyph_valid && pixel_on)
                out_rgb <= 24'h000000;
            else if (zh_v2 && zh_pix)
                out_rgb <= 24'h000000;
            else
                out_rgb <= video_d2[23:0];
        end
    end
endmodule
