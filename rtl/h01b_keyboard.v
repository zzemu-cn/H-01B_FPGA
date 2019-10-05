// keyboard

/*****************************************************************************
* Convert PS/2 keyboard to ASCII keyboard
******************************************************************************/


/*
`ifdef SIMULATE
initial
	begin
		LAST_KEY = 72'b0;
	end
`endif
*/

// 键盘检测的方法，就是循环地问每一行线发送低电平信号，也就是用该地址线为“0”的地址去读取数据。
// 例如，检测第一行时，使A0为0，其余为1；加上选通IC4的高五位地址01101，成为01101***11111110B（A8~A10不起作用，
// 可为任意值，故68FEH，69FEH，6AFEH，6BFEH，6CFEH，6DFEH，6EFEH，6FFEH均可）。
// 读 6800H 判断是否有按键按下。

// 键盘选通，整个竖列有一个选通的位置被按下，对应值为0。


module H01B_KEYBOARD
(
	input				KB_CLK,		// 1.5625 MHz
	input				DLY_CLK,	// 0.15625 MHz
	input				RESET_N,

	input				PS2_KBCLK,
	input				PS2_KBDAT,

	input	[10:0]		KEY_ADDR,
	output				KEY_PRESSED,
	output	[6:0]		KEY_DATA,

	output				RESET_KEY_N
);


// keyboard

wire	[7:0]		SCAN;
wire				PRESS;
wire				PRESS_N;
wire				EXTENDED;

reg		[63:0]		KEY;
reg		[9:0]		KEY_EX;
reg		[11:0]		KEY_Fxx;
//wire	[6:0]		KEY_DATA;
//reg	[63:0]		LAST_KEY;
//reg				CAPS_CLK;
//reg				CAPS;
//wire				KEY_PRESSED;


reg		KEY_RESET;
reg		[11:0]		RESET_KEY_COUNT;



wire	[63:0]	KEY_C		=	KEY;
wire	[9:0]	KEY_EX_C	=	KEY_EX;

//wire KEY_CTRL_ULRD = (KEY_EX[7:4]==4'b1111);
wire KEY_CTRL_ULRD_BRK = (KEY_EX[8:3]==6'b111111);



/*
NF-500A

   KD7 KD6 KD5 KD4 KD3 KD2 KD1 KD0  扫描用地址
A0      R   E   5 CTRL? 6   T   W    BFFEH
A1      3   2   Y  E/C  U   4   1    BFFDH
A2      9   :   8   -   7   0   下   BFFBH
A3      D   S   G  ESC  H   F   Q    BFF7H
A4      X   A   V   Z       C  BRK   BFEFH
A5      L BS 左 K  空格 J   ;   右   BFDFH
A6      M   .   N       B   ,   /    BFBFH
A7      P  RETN O SHIFT I   [        BF7FH

按键 3 56 34 51 功能未验证，暂时放在 ] TAB \ ' 位置。

E/C E汉 = ~  对应 ascii 20
ESC 对应 ascii 31
BS 对应 ascii 8
61 对应 ascii 13 回车键
16 对应 ascii 10 下
56 对应 ascii 16
27 3 34 51  无反应

测试按键 ASCII 码的程序
10 A$=INKEY$
20 IF LEN(A$)>0 THEN PRINT ASC(A$)
30 GOTO 10

TRS-80
左8 右9 上91 下10
Clear 31
@ 64
退格 8

*/


/*
H-01B
   KD7 KD6 KD5 KD4 KD3 KD2 KD1 KD0  扫描用地址
A0             空格 Z   A   Q   1    BFFEH
A1             BRK  X   S   W   2    BFFDH
A2             (16) C   D   E   3    BFFBH
A3             E/C  V   F   R   4    BFF7H
A4              -   B   G   T   5    BFEFH
A5             右   N   H   Y   6    BFDFH
A6            RETN  M   J   U   7    BFBFH
A7              [   ,   K   I   8    BF7FH
A8            BS 左 .   L   O   9    BEFFH
A9              :   /   ;   P   0    BDFFH
A10           SHIFT            下    BBFFH

需要确定的键
Ctrl ESC
*/


wire KEY_DATA_BIT6 =	1'b1;
wire KEY_DATA_BIT5 =	1'b1;

wire KEY_DATA_BIT4 = (KEY_ADDR[10:0]|{KEY_EX[8]&KEY_EX[9],KEY_C[19],KEY_C[45]&KEY_EX[5],KEY_C[57],KEY_C[61],KEY_EX[6],KEY_C[21],KEY_C[11],KEY_EX[3],~KEY_Fxx[0],KEY_C[43]})==11'h7ff;
wire KEY_DATA_BIT3 = (KEY_ADDR[10:0]|{~KEY_Fxx[3],	KEY_C[48],	KEY_C[53],	KEY_C[49],	KEY_C[54],	KEY_C[52],	KEY_C[50],	KEY_C[36],	KEY_C[33],	KEY_C[38],	KEY_C[35]})==11'h7ff;
wire KEY_DATA_BIT2 = (KEY_ADDR[10:0]|{~KEY_Fxx[2],	KEY_C[41],	KEY_C[46],	KEY_C[44],	KEY_C[42],	KEY_C[26],	KEY_C[28],	KEY_C[25],	KEY_C[30],	KEY_C[29],	KEY_C[37]})==11'h7ff;
wire KEY_DATA_BIT1 = (KEY_ADDR[10:0]|{~KEY_Fxx[1],	KEY_C[62],	KEY_C[60],	KEY_C[58],	KEY_C[10],	KEY_C[12],	KEY_C[ 1],	KEY_C[ 6],	KEY_C[ 5],	KEY_C[ 0],	KEY_C[24]})==11'h7ff;
wire KEY_DATA_BIT0 = (KEY_ADDR[10:0]|{KEY_EX[7],	KEY_C[17],	KEY_C[22],	KEY_C[20],	KEY_C[18],	KEY_C[ 2],	KEY_C[ 4],	KEY_C[ 9],	KEY_C[14],	KEY_C[13],	KEY_C[ 8]})==11'h7ff;


assign KEY_DATA = { KEY_DATA_BIT6, KEY_DATA_BIT5, KEY_DATA_BIT4, KEY_DATA_BIT3, KEY_DATA_BIT2, KEY_DATA_BIT1, KEY_DATA_BIT0 };

/*
assign KEY_DATA = 	(KEY_ADDR[0]==1'b0) ? KEY[ 7: 0] :
					(KEY_ADDR[1]==1'b0) ? KEY[15: 8] :
					(KEY_ADDR[2]==1'b0) ? KEY[23:16] :
2					(KEY_ADDR[3]==1'b0) ? KEY[31:24] :
					(KEY_ADDR[4]==1'b0) ? KEY[39:32] :
					(KEY_ADDR[5]==1'b0) ? KEY[47:40] :
					(KEY_ADDR[6]==1'b0) ? KEY[55:48] :
					(KEY_ADDR[7]==1'b0) ? KEY[63:56] :
					8'hff;

assign KEY_DATA =
					(KEY_ADDR[7]==1'b0) ? KEY[63:56] :
					(KEY_ADDR[6]==1'b0) ? KEY[55:48] :
					(KEY_ADDR[5]==1'b0) ? KEY[47:40] :
					(KEY_ADDR[4]==1'b0) ? KEY[39:32] :
					(KEY_ADDR[3]==1'b0) ? KEY[31:24] :
					(KEY_ADDR[2]==1'b0) ? KEY[23:16] :
					(KEY_ADDR[1]==1'b0) ? KEY[15: 8] :
					(KEY_ADDR[0]==1'b0) ? KEY[ 7: 0] :
					8'hff;
*/


assign	KEY_PRESSED = (KEY[63:0] == 64'hFFFFFFFFFFFFFFFF) ? 1'b0:1'b1;


always @(posedge DLY_CLK or negedge RESET_N)
begin
	if(~RESET_N)
	begin
		RESET_KEY_COUNT		<=	12'hFFF;
	end
	else
	begin
		if(KEY_RESET)
		begin
			RESET_KEY_COUNT		<=	12'h000;
		end
		else
		begin
			if(RESET_KEY_COUNT[11]==1'b0)
			begin
				RESET_KEY_COUNT	<=	RESET_KEY_COUNT+1;
			end
		end
	end
end

always @(posedge KB_CLK or negedge RESET_N)
begin
	if(~RESET_N)
	begin
		KEY					<=	64'hFFFFFFFFFFFFFFFF;
		KEY_EX				<=	10'h3FF;
		KEY_Fxx				<=	12'h000;
//		CAPS_CLK			<=	1'b0;
		KEY_RESET			<=	1'b0;
	end
	else
	begin
		//KEY[?] <= CAPS;

		case(SCAN)
		8'h07:
		begin
				KEY_Fxx[11]	<= PRESS;	// F12 RESET
				if(PRESS && (KEY_EX[0]==PRESS_N))
				begin
					KEY_RESET			<=	1'b1;
				end
				else
				begin
					KEY_RESET			<=	1'b0;
				end
		end
		8'h78:	KEY_Fxx[10] <= PRESS;	// F11
		8'h09:	KEY_Fxx[ 9] <= PRESS;	// F10
		8'h01:	KEY_Fxx[ 8] <= PRESS;	// F9
		8'h0A:	KEY_Fxx[ 7] <= PRESS;	// F8
		8'h83:	KEY_Fxx[ 6] <= PRESS;	// F7
		8'h0B:	KEY_Fxx[ 5] <= PRESS;	// F6
		8'h03:	KEY_Fxx[ 4] <= PRESS;	// F5
		8'h0C:	KEY_Fxx[ 3] <= PRESS;	// F4
		8'h04:	KEY_Fxx[ 2] <= PRESS;	// F3
		8'h06:	KEY_Fxx[ 1] <= PRESS;	// F2
		8'h05:	KEY_Fxx[ 0] <= PRESS;	// F1

		8'h16:	KEY[ 8] <= PRESS_N;	// 1 !
		8'h1E:	KEY[13] <= PRESS_N;	// 2 @
		8'h26:	KEY[14] <= PRESS_N;	// 3 #
		8'h25:	KEY[ 9] <= PRESS_N;	// 4 $
		8'h2E:	KEY[ 4] <= PRESS_N;	// 5 %

		8'h36:	KEY[ 2] <= PRESS_N;	// 6 ^
		8'h3D:	KEY[18] <= PRESS_N;	// 7 &
		8'h3E:	KEY[20] <= PRESS_N;	// 8 *
		8'h46:	KEY[22] <= PRESS_N;	// 9 (
		8'h45:	KEY[17] <= PRESS_N;	// 0 )


		8'h0D:	KEY[56] <= PRESS_N;	// TAB
		8'h4E:	KEY[19] <= PRESS_N;	// - _
		8'h55:	KEY[21] <= PRESS_N;	// = +
		8'h66:	KEY[45] <= PRESS_N;	// backspace
		8'h0E:	KEY[11] <= PRESS_N;	// ` ~
		8'h5D:	KEY[34] <= PRESS_N;	// \ |
		8'h49:	KEY[53] <= PRESS_N;	// . >
//		8'h11	KEY[] <= PRESS_N; // line feed (really right ALT (Extended) see below
		8'h5A:	KEY[61] <= PRESS_N;	// CR
		8'h54:	KEY[57] <= PRESS_N;	// [ {
		8'h5B:	KEY[ 3] <= PRESS_N;	// ] }
		8'h52:	KEY[51] <= PRESS_N;	// ' "
		8'h41:	KEY[49] <= PRESS_N;	// , <

		8'h1C:	KEY[37] <= PRESS_N;	// A
		8'h32:	KEY[50] <= PRESS_N;	// B
		8'h21:	KEY[33] <= PRESS_N;	// C
		8'h23:	KEY[30] <= PRESS_N;	// D
		8'h24:	KEY[ 5] <= PRESS_N;	// E
		8'h2B:	KEY[25] <= PRESS_N;	// F
		8'h34:	KEY[28] <= PRESS_N;	// G

		8'h33:	KEY[26] <= PRESS_N;	// H
		8'h43:	KEY[58] <= PRESS_N;	// I
		8'h3B:	KEY[42] <= PRESS_N;	// J
		8'h42:	KEY[44] <= PRESS_N;	// K
		8'h4b:	KEY[46] <= PRESS_N;	// L
		8'h3a:	KEY[54] <= PRESS_N;	// M
		8'h31:	KEY[52] <= PRESS_N;	// N

		8'h44:	KEY[60] <= PRESS_N;	// O
		8'h4D:	KEY[62] <= PRESS_N;	// P
		8'h2D:	KEY[ 6] <= PRESS_N;	// R
		8'h15:	KEY[24] <= PRESS_N;	// Q
		8'h1B:	KEY[29] <= PRESS_N;	// S
		8'h2C:	KEY[ 1] <= PRESS_N;	// T

		8'h3C:	KEY[10] <= PRESS_N;	// U
		8'h2a:	KEY[36] <= PRESS_N;	// V
		8'h1D:	KEY[ 0] <= PRESS_N;	// W
		8'h22:	KEY[38] <= PRESS_N;	// X
		8'h35:	KEY[12] <= PRESS_N;	// Y
		8'h1A:	KEY[35] <= PRESS_N;	// Z

		8'h29:	KEY[43] <= PRESS_N;	// Space
		8'h4A:	KEY[48] <= PRESS_N;	// / ?
		8'h4C:	KEY[41] <= PRESS_N;	// ; :
		8'h14:	KEY_EX[0] <= PRESS_N;	// Ctrl either left or right
		8'h12:	KEY_EX[8] <= PRESS_N;	// L-Shift
		8'h59:	KEY_EX[9] <= PRESS_N;	// R-Shift
		8'h11:
		begin
			if(~EXTENDED)
					KEY_EX[1] <= PRESS_N;	// Repeat really left ALT
			else
					KEY_EX[2] <= PRESS_N;	// LF really right ALT
		end
		8'h76:	KEY_EX[3] <= PRESS_N;	// Esc
		8'h75:	KEY_EX[4] <= PRESS_N;	// up
		8'h6B:	KEY_EX[5] <= PRESS_N;	// left
		8'h74:	KEY_EX[6] <= PRESS_N;	// right
		8'h72:	KEY_EX[7] <= PRESS_N;	// down
		endcase
	end
end


ps2_keyboard KEYBOARD(
		.RESET_N(RESET_N),
		.CLK(KB_CLK),
		.PS2_CLK(PS2_KBCLK),
		.PS2_DATA(PS2_KBDAT),
		.RX_SCAN(SCAN),
		.RX_PRESSED(PRESS),
		.RX_EXTENDED(EXTENDED)
);

assign PRESS_N = ~PRESS;

// 键盘 ctrl + f12 系统复位
assign RESET_KEY_N = RESET_KEY_COUNT[11];

endmodule 
