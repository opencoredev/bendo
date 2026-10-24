// Trusted host effect. A JS program runs one thread in one process, so it
// serves with one worker: a count of 1 answers index 0, and any other count
// fails with ENOSYS (38). A process started by the native effect keeps its
// BENDO_WORKER_INDEX. Values are built directly, so .mjs libraries load it.
function bendo_start_workers(count) {
  const env = typeof process === "object" && process.env ? process.env : {};
  const mine = env.BENDO_WORKER_INDEX;
  if (mine !== undefined) {
    return { $: CID(Done), value: Number.parseInt(mine, 10) >>> 0 };
  }
  if (Number(count) === 1) {
    return { $: CID(Done), value: 0 };
  }
  return {
    $: CID(Fail),
    error: { $: CID(Tuple), fst: 38, snd: "bendo: workers > 1 needs the native build" },
  };
}

io_eff(CID(start_workers), bendo_start_workers);
