# JSONTestSuite parsing fixtures

Source: https://github.com/nst/JSONTestSuite
Revision: `1ef36fa01286573e846ac449e8683f8833c5b26a`
Author: Nicolas Seriot and JSONTestSuite contributors.
License: MIT; the upstream LICENSE is included unchanged.

`test_parsing/` is copied byte for byte, including malformed JSON and invalid
Unicode. Do not format or normalize these files. Bendo's formatter ignores this
folder. `y_` means required acceptance, `n_` required rejection, and `i_`
implementation-defined behavior. See `docs/data/json.md` for Bendo's policy.
