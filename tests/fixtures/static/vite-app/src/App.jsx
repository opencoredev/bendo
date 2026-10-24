import { useEffect, useState } from "react";

export default function App() {
  const [count, setCount] = useState(0);
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);
  return (
    <main>
      <h1>Served by Bendo</h1>
      <p data-testid="status">{mounted ? "React is running" : "Loading"}</p>
      <button type="button" onClick={() => setCount((n) => n + 1)}>
        Clicked {count} times
      </button>
    </main>
  );
}
