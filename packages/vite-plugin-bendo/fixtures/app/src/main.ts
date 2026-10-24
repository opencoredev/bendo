/// <reference types="vite/client" />
// The page checks a handle with Bend code imported straight from a .bend file.
// Editing shared/handle.bend or shared/rules.bend swaps in the new functions
// without a reload, so the typed text and the swap count survive.
import "./style.css";
import { check, headline, min_length } from "../shared/handle.bend";

let live = { check, headline, min_length };
let swaps = 0;

function element(id: string): HTMLElement {
  const found = document.getElementById(id);
  if (found === null) throw new Error(`missing #${id}`);
  return found;
}

function handleInput(): HTMLInputElement {
  const found = element("handle");
  if (!(found instanceof HTMLInputElement)) throw new Error("#handle is not an input");
  return found;
}

const input = handleInput();

function render(): void {
  element("headline").textContent = live.headline();
  const min = live.min_length();
  element("rule").textContent = `At least ${min} characters.`;
  const verdict = element("verdict");
  const value = input.value;
  const ok = live.check(value);
  verdict.dataset.state = value === "" ? "empty" : ok ? "ok" : "short";
  verdict.textContent =
    value === "" ? "Type a handle." : ok ? `“${value}” works.` : `“${value}” is too short.`;
  element("swaps").textContent =
    swaps === 0
      ? "Bend module loaded once."
      : `Bend module hot-swapped ${swaps}×; your text stayed.`;
}

input.addEventListener("input", render);
render();

if (import.meta.hot)
  import.meta.hot.accept("../shared/handle.bend", (next) => {
    if (next === undefined) return;
    live = { check: next.check, headline: next.headline, min_length: next.min_length };
    swaps++;
    render();
  });
