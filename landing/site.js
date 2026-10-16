const storyCopy = {
  sleep: {
    signal: 'Señal · Registros de sueño disponibles en Apple Health; la cobertura depende de tu dispositivo y permisos.',
    context: 'Contexto · Puedes añadir horario, viaje o una nota personal. La app distingue esa nota de una medición.',
    reflection: 'Reflexión · Observar cambios puede ayudar a formular preguntas; no demuestra por qué ocurrieron.'
  },
  move: {
    signal: 'Señal · Actividad registrada por las fuentes conectadas a Apple Health, si existen.',
    context: 'Contexto · La rutina y los eventos que anotas acompañan la señal, pero no la convierten en una explicación.',
    reflection: 'Reflexión · Comparar periodos describe variaciones; no juzga tu valor ni establece una causa.'
  },
  context: {
    signal: 'Señal · El punto de partida es una medición identificable o reconocer que no hay dato.',
    context: 'Contexto · Tú eliges registrar hábitos, eventos y cómo te sentiste.',
    reflection: 'Reflexión · BioPulse pone ambas fuentes en perspectiva y deja las conclusiones en tus manos.'
  }
};

const signalField = document.querySelector('.signal-field');
const signalStory = document.querySelector('.signal-story');
const caption = document.querySelector('#story-caption');
const signalButtons = [...document.querySelectorAll('[data-signal]')];
const sequenceButtons = [...document.querySelectorAll('[data-sequence]')];
let activeSignal = 'sleep';
let activeStage = 'signal';

function updateStory() {
  signalField.dataset.active = activeSignal;
  signalButtons.forEach((button) => {
    const selected = button.dataset.signal === activeSignal;
    button.classList.toggle('is-selected', selected);
    button.setAttribute('aria-pressed', String(selected));
  });
  sequenceButtons.forEach((button) => {
    const selected = button.dataset.sequence === activeStage;
    button.classList.toggle('is-current', selected);
    button.setAttribute('aria-pressed', String(selected));
  });
  caption.textContent = storyCopy[activeSignal][activeStage];
}

signalButtons.forEach((button) => {
  button.addEventListener('click', () => {
    activeSignal = button.dataset.signal;
    updateStory();
  });
});

sequenceButtons.forEach((button) => {
  button.setAttribute('aria-pressed', String(button.dataset.sequence === activeStage));
  button.addEventListener('click', () => {
    activeStage = button.dataset.sequence;
    updateStory();
  });
});

if ('IntersectionObserver' in window) {
  const storyObserver = new IntersectionObserver(([entry]) => {
    signalStory.classList.toggle('is-in-view', entry.isIntersecting);
  }, { threshold: 0.12 });
  storyObserver.observe(signalStory);
} else {
  signalStory.classList.add('is-in-view');
}

const menuToggle = document.querySelector('.menu-toggle');
const mobileNav = document.querySelector('#mobile-nav');

menuToggle.addEventListener('click', () => {
  const expanded = menuToggle.getAttribute('aria-expanded') === 'true';
  menuToggle.setAttribute('aria-expanded', String(!expanded));
  menuToggle.setAttribute('aria-label', expanded ? 'Abrir menú' : 'Cerrar menú');
  mobileNav.hidden = expanded;
});

mobileNav.querySelectorAll('a').forEach((link) => {
  link.addEventListener('click', () => {
    mobileNav.hidden = true;
    menuToggle.setAttribute('aria-expanded', 'false');
    menuToggle.setAttribute('aria-label', 'Abrir menú');
  });
});

document.querySelector('#year').textContent = new Date().getFullYear();
