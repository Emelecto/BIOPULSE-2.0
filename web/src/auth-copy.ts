export type AuthAction = "login" | "signup" | "recovery" | "update" | "resend";

export function authErrorMessage(error: { code?: string; message?: string } | null, action: AuthAction): string {
  const code = error?.code ?? "";
  const message = (error?.message ?? "").toLowerCase();
  if (code === "invalid_credentials" || message.includes("invalid login credentials"))
    return "No pudimos iniciar sesión con ese correo y contraseña. Revísalos e inténtalo de nuevo.";
  if (code === "email_not_confirmed" || message.includes("email not confirmed"))
    return "Tu correo aún no está confirmado. Revisa el mensaje de BioPulse o solicita uno nuevo.";
  if (code === "user_already_exists" || message.includes("already registered"))
    return "Ya existe una cuenta con ese correo. Inicia sesión o recupera tu contraseña.";
  if (code === "weak_password" || message.includes("password should be"))
    return "Esa contraseña no cumple los requisitos de seguridad. Prueba una más larga y única.";
  if (code === "over_email_send_rate_limit" || code === "over_request_rate_limit" || message.includes("rate limit"))
    return "Se enviaron demasiadas solicitudes. Espera unos minutos antes de intentar de nuevo.";
  if (code === "same_password") return "La nueva contraseña debe ser diferente de la actual.";
  if (code === "email_address_invalid" || message.includes("invalid email"))
    return "Escribe una dirección de correo válida.";
  if (code === "otp_expired" || code === "otp_disabled" || message.includes("expired"))
    return "Este enlace ya no es válido. Solicita uno nuevo.";
  if (action === "recovery" || action === "resend")
    return "No pudimos enviar el correo ahora. Revisa tu conexión e inténtalo más tarde.";
  return "No pudimos completar esta acción. Inténtalo de nuevo en unos momentos.";
}

export function passwordValidation(password: string, confirmation: string): string | null {
  if (password.length < 8) return "Usa al menos 8 caracteres.";
  if (password !== confirmation) return "Las contraseñas no coinciden.";
  return null;
}

export function authRedirect(kind: "confirm" | "reset" | "email-change"): string {
  return `${window.location.origin}/app/${kind}`;
}
