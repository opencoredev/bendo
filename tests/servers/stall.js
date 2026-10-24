// Test-only host effect: a JS build runs one worker, so nothing to hold back.
function bendo_test_stall() {
  return { $: CID(Unit) };
}

io_eff(CID(stall), bendo_test_stall);
