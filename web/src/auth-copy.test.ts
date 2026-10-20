import { describe, expect, it } from "vitest";
import { authErrorMessage, passwordValidation } from "./auth-copy";

describe("mensajes de acceso", () => {
  it("traduce errores frecuentes sin mostrar detalles del proveedor", () => {
    expect(authErrorMessage({ code: "invalid_credentials" }, "login")).toContain("correo y contraseña");
    expect(authErrorMessage({ code: "email_not_confirmed" }, "login")).toContain("confirmado");
    expect(authErrorMessage({ message: "Database internal failure" }, "signup")).not.toContain("Database");
  });

  it("mantiene neutral la recuperación y valida la confirmación", () => {
    expect(authErrorMessage({ message: "Internal failure" }, "recovery")).not.toContain("cuenta");
    expect(passwordValidation("corta", "corta")).toContain("8 caracteres");
    expect(passwordValidation("contraseña-segura", "otra contraseña")).toContain("no coinciden");
    expect(passwordValidation("contraseña-segura", "contraseña-segura")).toBeNull();
  });
});
