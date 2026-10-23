// Trusted host effect. Nat values here also fit the native 48-bit range.
// Construct Result directly: .mjs libraries do not include executable IO helpers.
function bendo_clock_failure(code, message) {
  return { $: CID(Fail), error: { $: CID(Tuple), fst: code, snd: message } };
}

function bendo_wall_millis() {
  try {
    const millis = Date.now();
    if (!Number.isSafeInteger(millis) || millis < 0 || millis > 253402300799999) {
      return bendo_clock_failure(34, "wall clock outside years 1970..9999");
    }
    return { $: CID(Done), value: millis };
  } catch {
    return bendo_clock_failure(5, "wall clock unavailable");
  }
}

io_eff(CID(wall_millis), bendo_wall_millis);
