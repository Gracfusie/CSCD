module cv32e40p_wrapper (
	inout 	logic	clk_i_pad,
	inout 	logic	rst_ni_pad,
	inout 	logic	tck_i_pad,
	inout 	logic	tms_i_pad,
	inout 	logic	td_i_pad,
	inout 	logic	td_o_pad,
	inout 	logic	clk_led_pad,
	inout 	logic	tck_led_pad
);
	logic 	clk_i;
	logic	rst_ni;
	logic 	tck_i;
	logic 	tms_i;
	logic 	td_i;
	logic 	td_o;
	logic 	clk_led;
	logic 	tck_led;
	
	PDUW0204CDG i_CLK_I (
		.I		(1'b0		),
		.DS		(1'b1		),
		.OEN	(1'b1		),
		.PAD	(clk_i_pad	),
		.C		(clk_i		),
		.PE		(1'b1		),
		.IE		(1'b1		)
	);

	PDUW0204CDG i_RST_NI (
		.I		(1'b0		),
		.DS		(1'b1		),
		.OEN	(1'b1		),
		.PAD	(rst_ni_pad	),
		.C		(rst_ni		),
		.PE		(1'b1		),
		.IE		(1'b1		)
	);

	PDUW0204CDG i_TCK_I (
		.I		(1'b0		),
		.DS		(1'b1		),
		.OEN	(1'b1		),
		.PAD	(tck_i_pad	),
		.C		(tck_i		),
		.PE		(1'b1		),
		.IE		(1'b1		)
	);

	PDUW0204CDG i_TMS_I (
		.I		(1'b0		),
		.DS		(1'b1		),
		.OEN	(1'b1		),
		.PAD	(tms_i_pad	),
		.C		(tms_i		),
		.PE		(1'b1		),
		.IE		(1'b1		)
	);

	PDUW0204CDG i_TD_I (
		.I		(1'b0		),
		.DS		(1'b1		),
		.OEN	(1'b1		),
		.PAD	(td_i_pad	),
		.C		(td_i		),
		.PE		(1'b1		),
		.IE		(1'b1		)
	);

	PDUW0204CDG i_TD_O (
		.I		(td_o		),
		.DS		(1'b1		),
		.OEN	(1'b0		),
		.PAD	(td_o_pad	),
		.C		(			),
		.PE		(1'b1		),
		.IE		(1'b0		)
	);

	PDUW0204CDG i_CLK_LED (
		.I		(clk_led		),
		.DS		(1'b1			),
		.OEN	(1'b0			),
		.PAD	(clk_led_pad	),
		.C		(				),
		.PE		(1'b1			),
		.IE		(1'b0			)
	);

	PDUW0204CDG i_TCK_LED (
		.I		(tck_led		),
		.DS		(1'b1			),
		.OEN	(1'b0			),
		.PAD	(tck_led_pad	),
		.C		(				),
		.PE		(1'b1			),
		.IE		(1'b0			)
	);


	cv32e40p_xilinx i_cv32e40p_xilinx(
		.clk_i		(clk_i		),
		.rst_ni		(rst_ni		),
		.tck_i		(tck_i		),
		.tms_i		(tms_i		),
		.td_i		(td_i		),
		.td_o		(td_o		),
		.clk_led	(clk_led	),
		.tck_led	(tck_led	)
	);
endmodule
