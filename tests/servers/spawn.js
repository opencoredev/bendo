// Test-only host effect: a JS build does not start copies, so it answers 0.
function bendo_test_spawn_copy() {
  return 0;
}

io_eff(CID(spawn_copy), bendo_test_spawn_copy);
