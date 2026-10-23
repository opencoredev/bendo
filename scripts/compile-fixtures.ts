import { compile } from "../tests/harness.ts";

// Multipart's typechecking peaks above 6 GiB. Warm it before the test workers
// start so several compilers cannot force it into swap on a cold CI runner.
// Both calls are cheap cache lookups on subsequent runs.
compile("tests/servers/multipart.bend", "native");
compile("tests/fixtures/multipart/consumer.bend", "mjs");
