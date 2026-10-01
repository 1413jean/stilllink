import { useEffect, useRef } from 'react';

// 4×4 Bayer 矩陣：用來把連續明暗抖成點陣
const BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5].map((v) => (v + 0.5) / 16);

function rand(seed: number) {
  let s = seed >>> 0 || 1;
  return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 2 ** 32);
}

/** 抖色點陣球：參考圖那種像素星體 */
export function DotSphere({ size = 160, cell = 4, seed = 7 }: { size?: number; cell?: number; seed?: number }) {
  const ref = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const c = ref.current!;
    const dpr = window.devicePixelRatio || 1;
    c.width = size * dpr;
    c.height = size * dpr;
    const g = c.getContext('2d')!;
    g.scale(dpr, dpr);
    const color = getComputedStyle(c).color;
    g.fillStyle = color;
    const r = rand(seed);
    const n = Math.floor(size / cell);
    const R = n * 0.42;
    for (let y = 0; y < n; y++)
      for (let x = 0; x < n; x++) {
        const dx = (x - n / 2) / R, dy = (y - n / 2) / R;
        const wobble = 1 + 0.12 * Math.sin(Math.atan2(dy, dx) * 5 + seed);
        const d2 = dx * dx + dy * dy;
        if (d2 > wobble * wobble) {
          if (d2 < 1.9 && r() < 0.06) g.fillRect(x * cell, y * cell, cell - 1, cell - 1);
          continue;
        }
        const z = Math.sqrt(Math.max(0, 1 - d2));
        const light = Math.max(0, -0.5 * dx - 0.6 * dy + 0.62 * z) * 1.1 + r() * 0.15;
        if (light > BAYER[(y % 4) * 4 + (x % 4)]) g.fillRect(x * cell, y * cell, cell - 1, cell - 1);
      }
  }, [size, cell, seed]);
  return <canvas ref={ref} className="dot-art" style={{ width: size, height: size }} aria-hidden />;
}

/** 背景散點：稀疏的方點，靠近中央一帶比較密 */
export function DotField({ seed = 3 }: { seed?: number }) {
  const ref = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const c = ref.current!;
    const draw = () => {
      const { width: w, height: h } = c.getBoundingClientRect();
      const dpr = window.devicePixelRatio || 1;
      c.width = w * dpr;
      c.height = h * dpr;
      const g = c.getContext('2d')!;
      g.scale(dpr, dpr);
      g.fillStyle = getComputedStyle(c).color;
      const r = rand(seed);
      const cell = 6;
      for (let y = 0; y < h; y += cell)
        for (let x = 0; x < w; x += cell) {
          const band = Math.exp(-(((y / h - 0.55 - 0.15 * Math.sin((x / w) * 3.4)) / 0.16) ** 2));
          if (r() < 0.004 + band * 0.22 * (0.5 + 0.5 * Math.sin(x * 0.013 + y * 0.02)))
            g.fillRect(x, y, 3, 3);
        }
    };
    draw();
    const ro = new ResizeObserver(draw);
    ro.observe(c);
    return () => ro.disconnect();
  }, [seed]);
  return <canvas ref={ref} className="dot-field" aria-hidden />;
}
