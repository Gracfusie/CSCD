package tb_pkg;

  // 24-bit wrap helper (two's complement wrap, not saturating)
  function automatic int signed wrap24i (int signed x);
    int unsigned y;
    y = int'(x) & 32'h00FF_FFFF;                 // keep low 24
    return ( (y & 32'h0080_0000) ? int'(y | 32'hFF00_0000) : int'(y) );
  endfunction

  // Sign-extend a 16-bit value to 32-bit int
  function automatic int signed sext16i (int signed x16);
    int unsigned y;
    y = int'(x16) & 32'h0000_FFFF;
    return ( (y & 32'h0000_8000) ? int'(y | 32'hFFFF_0000) : int'(y) );
  endfunction

  // Golden model step for one MAC: acc := wrap24( acc + sext16(a*u8 * b*s8) )
  function automatic int signed golden_mac_step (
      input int signed acc_24,
      input byte unsigned a_u8,
      input byte signed   b_s8
  );
    int signed prod = int'(a_u8) * int'(b_s8);   // full-precision multiply
    golden_mac_step = wrap24i( acc_24 + sext16i(prod) );
  endfunction

  // Golden model output selection
  function automatic int signed golden_out (
      input int signed acc_24,
      input bit        mode_sel         // 0: raw, 1: ReLU
  );
    if (mode_sel) golden_out = (acc_24 < 0) ? 0 : acc_24;
    else          golden_out = acc_24;
  endfunction

endpackage
