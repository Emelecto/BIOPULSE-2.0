export const MAX_MESSAGE_COUNT = 16;
export const MAX_MESSAGE_CHARS = 4_000;
export const MAX_CONTEXT_BYTES = 24_000;

export type ChatMessage = { role: "user" | "assistant"; content: string };
export type CoachContext = {
  metrics?: Array<Record<string, unknown>>;
  trends?: Array<Record<string, unknown>>;
  journal?: Array<Record<string, unknown>>;
};

function allowedObject(value: unknown, keys: string[]): value is Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) return false;
  return Object.keys(value).every((key) => keys.includes(key));
}

export function validContext(value: unknown): value is CoachContext {
  if (!allowedObject(value, ["metrics", "trends", "journal"])) return false;
  const groups: Array<[unknown, number, string[]]> = [
    [value.metrics ?? [], 80, ["name", "value", "unit", "observedAt", "quality", "provenance", "period"]],
    [value.trends ?? [], 40, ["name", "direction", "period", "summary", "baseline", "unit", "quality"]],
    [value.journal ?? [], 30, ["category", "title", "notes", "occurredAt", "timezone"]],
  ];
  for (const [group, maxCount, keys] of groups) {
    if (!Array.isArray(group) || group.length > maxCount) return false;
    for (const item of group) {
      if (!allowedObject(item, keys)) return false;
      for (const [key, field] of Object.entries(item)) {
        if (field === null || typeof field === "number" && Number.isFinite(field) || typeof field === "boolean") continue;
        if (typeof field !== "string" || field.length > (key === "notes" || key === "summary" ? 1_000 : 180)) return false;
      }
    }
  }
  return new TextEncoder().encode(JSON.stringify(value)).length <= MAX_CONTEXT_BYTES;
}

export function validMessages(value: unknown): value is ChatMessage[] {
  if (!Array.isArray(value) || value.length < 1 || value.length > MAX_MESSAGE_COUNT) return false;
  if (!value.every((item) =>
    allowedObject(item, ["role", "content"]) &&
    (item.role === "user" || item.role === "assistant") &&
    typeof item.content === "string" && item.content.trim().length > 0 &&
    item.content.length <= MAX_MESSAGE_CHARS
  )) return false;
  return value.at(-1)?.role === "user";
}

export function urgentSafetyResponse(text: string): string | null {
  const urgentPattern = /\b(dolor.{0,24}pecho|opresi[oó]n.{0,16}pecho|dificultad.{0,20}respirar|falta de aire intensa|desmayo|p[eé]rdida del conocimiento|debilidad.{0,24}(lado|brazo|pierna)|cara.{0,20}ca[ií]da|habla.{0,18}(extra[nñ]a|dificultad)|sangrado abundante|reacci[oó]n al[eé]rgica grave|anafilaxia|convulsi[oó]n|ideas? suicidas|hacerme da[nñ]o|quitarme la vida)\b/i;
  if (!urgentPattern.test(text)) return null;
  return "Lo que describes podría requerir atención urgente. No puedo evaluarlo ni diagnosticarlo por chat. Contacta ahora con los servicios de emergencia de tu zona o acude a un servicio médico; si puedes, avisa a alguien de confianza para que te acompañe.";
}

export function safeSummary(value: unknown): string {
  if (typeof value !== "string") return "";
  return value.trim().slice(0, 1_500);
}
