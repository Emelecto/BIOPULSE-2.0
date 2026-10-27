import { useEffect, useRef, useState } from "react";

/** Decorative loops run only on a visible surface in an active document. */
export function useMotionVisibility<T extends HTMLElement>() {
  const ref = useRef<T>(null);
  const [active, setActive] = useState(false);
  useEffect(() => {
    let inView = false;
    const media = matchMedia("(prefers-reduced-motion: reduce)");
    const update = () => setActive(inView && !document.hidden && !media.matches);
    const observer = new IntersectionObserver(([entry]) => { inView = entry.isIntersecting; update(); }, { threshold: .05 });
    if (ref.current) observer.observe(ref.current);
    document.addEventListener("visibilitychange", update);
    media.addEventListener("change", update);
    return () => { observer.disconnect(); document.removeEventListener("visibilitychange", update); media.removeEventListener("change", update); };
  }, []);
  return { ref, active };
}
