const screens = [...document.querySelectorAll(".screen")];
const tabs = [...document.querySelectorAll(".tab")];
const dialog = document.querySelector("#detail-dialog");
const dialogTitle = document.querySelector("#dialog-title");
const dialogBody = document.querySelector("#dialog-body");
const dialogKicker = document.querySelector("#dialog-kicker");
const toast = document.querySelector("#toast");
let toastTimer;

const detailCopy = {
  score: {
    kicker: "BIOSCORE",
    title: "Cálculo pendiente",
    body: "El anillo estará listo para mostrar tu bienestar general cuando la fórmula y sus entradas estén validadas. Mientras tanto conserva su lugar visible sin inventar una cifra.",
    source: "Estado actual · sin puntuación calculada"
  },
  hrv: {
    kicker: "SEÑAL REAL",
    title: "Variabilidad cardiaca",
    body: "Aquí aparecerá una muestra de HRV cuando Apple Salud la comparta. BioPulse podrá compararla con tu referencia personal cuando exista suficiente historial.",
    source: "Fuente esperada · Apple Salud / Apple Watch"
  },
  sleep: {
    kicker: "SEÑAL REAL",
    title: "Sueño",
    body: "Aquí aparecerá el tiempo calculado a partir de las etapas de sueño registradas. No se rellenará con una estimación si no hay muestras.",
    source: "Fuente esperada · Apple Salud / Apple Watch"
  },
  activity: {
    kicker: "SEÑAL REAL",
    title: "Actividad",
    body: "La actividad podrá incluir pasos, ejercicio y energía acumulada cuando haya registros del día. Cada valor mostrará su unidad y procedencia.",
    source: "Fuente esperada · Apple Salud / Apple Watch"
  },
  resting: {
    kicker: "SEÑAL REAL",
    title: "Frecuencia en reposo",
    body: "Se mostrará la última muestra disponible de Apple Salud. La ausencia de una muestra permanecerá visible como ausencia.",
    source: "Fuente esperada · Apple Salud / Apple Watch"
  },
  respiration: {
    kicker: "SEÑAL REAL",
    title: "Frecuencia respiratoria",
    body: "La disponibilidad depende del dispositivo, la región, el permiso y las muestras registradas en Apple Salud.",
    source: "Fuente esperada · Apple Salud / Apple Watch"
  },
  oxygen: {
    kicker: "SEÑAL REAL",
    title: "Oxígeno en sangre",
    body: "Solo aparecerá si existe una medición compatible y autorizada. BioPulse no convierte la ausencia en una lectura aproximada.",
    source: "Fuente esperada · Apple Salud / Apple Watch"
  },
  energy: {
    kicker: "CONTEXTO DEL DÍA",
    title: "Mapa de energía",
    body: "Se construirá con sueño, actividad, señales observadas y contexto del diario. La app no dibujará una curva fisiológica hasta contar con datos y una metodología documentada.",
    source: "Estado actual · entradas y cobertura pendientes"
  },
  breathing: {
    kicker: "PAUSA GUIADA",
    title: "Respiración",
    body: "La sesión inicial usa un ritmo visual de cuatro segundos para inhalar y cuatro para exhalar. No interpreta biometría ni sustituye indicaciones clínicas.",
    source: "Herramienta local · sin envío de datos",
    visual: "breathing"
  },
  weekly: {
    kicker: "RESUMEN SEMANAL",
    title: "Contexto antes que conclusiones",
    body: "El resumen reunirá cambios, cobertura, datos ausentes y registros del diario cuando exista una semana real suficiente.",
    source: "Estado actual · historial insuficiente"
  },
  technical: {
    kicker: "CIENCIA DE DATOS",
    title: "Vista técnica",
    body: "Mostrará datasets, variables, procesamiento, separación de evaluación, baselines, métricas reproducibles y limitaciones. No reutilizará cifras hardcodeadas como evidencia.",
    source: "Estado actual · arquitectura definida, resultados pendientes"
  },
  sleepScore: {
    kicker: "SLEEP SCORE",
    title: "Puntuación pendiente",
    body: "El Sleep Score estará visible desde el MVP, pero permanecerá sin cifra hasta validar fórmula, cobertura y entradas con datos reales.",
    source: "Estado actual · sin puntuación calculada"
  },
  account: {
    kicker: "CUENTA REQUERIDA",
    title: "Inicia sesión para continuar",
    body: "BioPulse requiere una cuenta para entrar. Podrás registrarte con Apple, correo y contraseña, o Google. Iniciar sesión no activa la sincronización: cada categoría cloud se habilitará con tu consentimiento.",
    source: "Diseño confirmado · proveedor aún no conectado"
  },
  privacy: {
    kicker: "PRIVACIDAD",
    title: "Datos bajo tu control",
    body: "Los datos biométricos originales de HealthKit permanecerán locales por defecto. Perfil, diario, ajustes y métricas derivadas solo podrán sincronizarse con consentimiento explícito.",
    source: "Política de arquitectura confirmada"
  },
  coach: {
    kicker: "COACH BIOPULSE",
    title: "Pilar futuro",
    body: "El Coach podrá analizar métricas, tendencias y diario solo con autorización. Se limitará al contexto de BioPulse, sin diagnóstico, con controles de entrada, salida, herramientas y pruebas contra prompt injection.",
    source: "Estado actual · IA remota no conectada"
  }
};

function showToast(message) {
  clearTimeout(toastTimer);
  toast.textContent = message;
  toast.classList.add("show");
  toastTimer = setTimeout(() => toast.classList.remove("show"), 3200);
}

function showDetail(key) {
  const copy = detailCopy[key] || detailCopy.score;
  dialogKicker.textContent = copy.kicker;
  dialogTitle.textContent = copy.title;
  const visual = copy.visual === "breathing" ? '<div class="breathing-preview" aria-label="Vista previa animada de respiración"></div>' : "";
  dialogBody.innerHTML = `${visual}<p class="dialog-copy">${copy.body}</p><p class="dialog-source">${copy.source}<br />Preview visual · sin datos personales</p>`;
  if (typeof dialog.showModal === "function") dialog.showModal();
  else dialog.setAttribute("open", "");
}

function navigate(tabName) {
  tabs.forEach(tab => {
    const active = tab.dataset.tab === tabName;
    tab.classList.toggle("active", active);
    tab.setAttribute("aria-current", active ? "page" : "false");
  });
  screens.forEach(screen => {
    const active = screen.dataset.screen === tabName;
    screen.hidden = !active;
    screen.classList.toggle("active", active);
  });
}

document.querySelector("#today-date").textContent = new Intl.DateTimeFormat("es-CO", { weekday: "long", day: "numeric", month: "long" }).format(new Date());
tabs.forEach(tab => tab.addEventListener("click", () => navigate(tab.dataset.tab)));
document.querySelector("#score-trigger").addEventListener("click", () => showDetail("score"));
document.querySelectorAll("[data-detail]").forEach(button => button.addEventListener("click", () => showDetail(button.dataset.detail)));
document.querySelector("#dialog-close").addEventListener("click", () => dialog.close());
dialog.addEventListener("click", event => { if (event.target === dialog) dialog.close(); });
document.querySelector("#coach-button").addEventListener("click", () => showDetail("coach"));

function markPreviewConnected() {
  const panel = document.querySelector("#connection-panel");
  const button = document.querySelector("#connect-button");
  panel.classList.add("connected");
  button.classList.add("connected");
  button.textContent = "Conectado en preview";
  document.querySelector("#source-label").textContent = "Apple Salud · preview";
  document.querySelector(".source-state .state-dot").style.background = "var(--mint)";
  document.querySelector("#insight-title").textContent = "Tus señales, listas para explorar";
  document.querySelector("#insight-description").textContent = "Este estado representa la interfaz conectada. No contiene mediciones biométricas reales.";
  showToast("Estado conectado solo para revisar la interfaz.");
}

document.querySelector("#connect-button").addEventListener("click", markPreviewConnected);
document.querySelector("#profile-connect").addEventListener("click", markPreviewConnected);
document.querySelector("#refresh-button").addEventListener("click", () => showToast("En la app real, esta acción consultará Apple Salud."));
document.querySelector("#csv-input").addEventListener("change", event => {
  const file = event.target.files?.[0];
  if (!file) return;
  showToast(`Archivo seleccionado: ${file.name}. La preview no lo guarda ni lo importa.`);
});

const journalForm = document.querySelector("#journal-form");
const journalList = document.querySelector("#journal-list");
const journalEmpty = document.querySelector("#journal-empty");

journalForm.addEventListener("submit", event => {
  event.preventDefault();
  const category = document.querySelector("#journal-category").value;
  const titleInput = document.querySelector("#journal-title-input");
  const notesInput = document.querySelector("#journal-notes");
  const title = titleInput.value.trim();
  const notes = notesInput.value.trim();
  if (!title) return;

  const entry = document.createElement("article");
  entry.className = "journal-entry";
  const icon = document.createElement("span");
  icon.setAttribute("aria-hidden", "true");
  icon.textContent = category === "Síntoma" ? "+" : category === "Evento" ? "□" : "⌁";

  const content = document.createElement("div");
  const header = document.createElement("header");
  const categoryLabel = document.createElement("small");
  categoryLabel.textContent = category.toUpperCase();
  const time = document.createElement("time");
  time.textContent = new Intl.DateTimeFormat("es-CO", { hour: "numeric", minute: "2-digit" }).format(new Date());
  header.append(categoryLabel, time);

  const heading = document.createElement("strong");
  heading.textContent = title;
  content.append(header, heading);
  if (notes) {
    const paragraph = document.createElement("p");
    paragraph.textContent = notes;
    content.append(paragraph);
  }
  entry.append(icon, content);
  journalList.prepend(entry);
  journalEmpty.hidden = true;
  journalForm.reset();
  showToast("Registro añadido solo a esta sesión de preview.");
});
