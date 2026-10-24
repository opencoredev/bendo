// Trusted host effect. A JS program runs one thread in one process, so it
// serves with one worker: a count of 1 answers index 0, and any other count
// fails with ENOSYS (38). As in the native effect, a worker's variables are
// read into private state at load and removed from the environment, so a
// process the app starts never inherits them. Values are built directly, so
// .mjs libraries load it.
const bendo_worker_index = (() => {
  const env = typeof process === "object" && process.env ? process.env : {};
  const text = env.BENDO_WORKER_INDEX;
  delete env.BENDO_WORKER_INDEX;
  delete env.BENDO_WORKER_READY;
  delete env.BENDO_WORKER_NAME;
  const n = typeof text === "string" && /^[1-9][0-9]*$/.test(text) ? Number(text) : 0;
  return n < 256 ? n : 0;
})();

function bendo_start_workers(count) {
  if (bendo_worker_index !== 0) {
    return { $: CID(Done), value: bendo_worker_index };
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
