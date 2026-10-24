import "react";

declare module "react" {
  interface CSSProperties {
    /** The hue of a person's mark and name, from hue() in Transcript.tsx. */
    "--hue"?: number;
  }
}
