import { parseHealthCSV } from "./csv";

const worker = self as unknown as {
  onmessage: ((event: MessageEvent<{ file: File; timeZone: string }>) => void) | null;
  postMessage: (message: unknown) => void;
};

worker.onmessage = async ({ data }) => {
  try {
    const bytes = await data.file.arrayBuffer();
    const text = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
    worker.postMessage({ result: parseHealthCSV(text, data.timeZone) });
  } catch (error) {
    worker.postMessage({ error: error instanceof Error ? error.message : "No se pudo leer el CSV." });
  }
};
