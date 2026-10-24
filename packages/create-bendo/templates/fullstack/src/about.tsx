const files: ReadonlyArray<{ path: string; role: string }> = [
  {
    path: "main.bend",
    role: "The API: routes, schemas and handlers, compiled to one native binary.",
  },
  {
    path: "shared/notes.bend",
    role: "Note rules. The server's schema and this page's counter both call it.",
  },
  { path: ".bendo/", role: "Route types and response schemas written by bendo gen." },
  { path: "src/api.ts", role: "The typed client. Its calls are checked against .bendo/routes.ts." },
  { path: "src/router.tsx", role: "TanStack Router routes for this page and the notes page." },
  { path: "bendo/", role: "The Bendo framework source that main.bend imports." },
];

export function About() {
  return (
    <section>
      <h1>How this app fits together</h1>
      <p className="lede">
        One Bend file serves the API. <code>bun run build</code> compiles it, regenerates the
        client's types and builds this page, and <code>bun run start</code> serves both from{" "}
        <code>dist/</code>.
      </p>
      <dl className="files">
        {files.map((file) => (
          <div key={file.path} className="file">
            <dt>
              <code>{file.path}</code>
            </dt>
            <dd>{file.role}</dd>
          </div>
        ))}
      </dl>
    </section>
  );
}
