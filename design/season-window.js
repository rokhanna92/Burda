// <season-window season="snow|leaves|petals|sun|stars|embers|dust"> — small canvas of drifting seasonal particles.
// Colors read from the host's CSS vars (--accent, --ink) so they follow the edition.
(() => {
if (customElements.get('season-window')) return;
const rnd = (a, b) => a + Math.random() * (b - a);

const SEASONS = {
  snow:   { n: 26, spawn: 'top',    vy: [8, 18],   vx: [-4, 4],   size: [1.2, 3],   shape: 'dot',     alpha: [.55, .95], tone: 'white' },
  leaves: { n: 14, spawn: 'top',    vy: [9, 20],   vx: [-10, 6],  size: [2.5, 7],   shape: 'leaf',    alpha: [.7, 1],    tone: 'leaf' },
  petals: { n: 16, spawn: 'top',    vy: [6, 14],   vx: [-8, 8],   size: [2.5, 4.5], shape: 'petal',   alpha: [.6, .95],  tone: 'accent' },
  sun:    { n: 18, spawn: 'any',    vy: [-6, -2],  vx: [-3, 3],   size: [.8, 2],    shape: 'sparkle', alpha: [.3, .9],   tone: 'accent' },
  stars:  { n: 34, spawn: 'any',    vy: [-1, 1],   vx: [-1, 1],   size: [.5, 1.6],  shape: 'star',    alpha: [.2, 1],    tone: 'white' },
  embers: { n: 16, spawn: 'bottom', vy: [-16, -6], vx: [-4, 4],   size: [.8, 2.2],  shape: 'dot',     alpha: [.4, 1],    tone: 'accent' },
  dust:   { n: 30, spawn: 'any',    vy: [-3, 3],   vx: [-3, 3],   size: [.5, 1.4],  shape: 'star',    alpha: [.2, .9],   tone: 'accent' },
};

class SeasonWindow extends HTMLElement {
  static get observedAttributes() { return ['season']; }
  connectedCallback() {
    this.style.display = this.style.display || 'block';
    this.canvas = document.createElement('canvas');
    this.canvas.style.cssText = 'width:100%;height:100%;display:block;pointer-events:none';
    this.appendChild(this.canvas);
    this.ctx = this.canvas.getContext('2d');
    this.ro = new ResizeObserver(() => this.resize()); this.ro.observe(this);
    this.visible = true;
    this.io = new IntersectionObserver(e => { this.visible = e[0].isIntersecting; }); this.io.observe(this);
    this.resize(); this.reset();
    this.last = performance.now();
    this.tick = this.tick.bind(this);
    this.raf = requestAnimationFrame(this.tick);
  }
  attributeChangedCallback() { if (this.ctx) this.reset(); }
  disconnectedCallback() { cancelAnimationFrame(this.raf); this.ro.disconnect(); this.io.disconnect(); }
  resize() {
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    this.w = this.clientWidth || 60; this.h = this.clientHeight || 60;
    this.canvas.width = this.w * dpr; this.canvas.height = this.h * dpr;
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }
  cfg() { return SEASONS[this.getAttribute('season')] || SEASONS.petals; }
  spawn(p, fresh) {
    const c = this.cfg();
    p.size = rnd(...c.size); p.vx = rnd(...c.vx); p.vy = rnd(...c.vy);
    p.alpha = rnd(...c.alpha); p.rot = rnd(0, Math.PI * 2); p.spin = rnd(-1.5, 1.5); p.phase = rnd(0, Math.PI * 2);
    p.kind = Math.floor(rnd(0, 5));
    p.hue = ['#B8541E', '#D98A2B', '#8A3A1B', '#C9A227', '#A0522D', '#7B2D26'][Math.floor(rnd(0, 6))];
    p.x = rnd(0, this.w);
    if (fresh || c.spawn === 'any') p.y = rnd(0, this.h);
    else p.y = c.spawn === 'top' ? -p.size * 2 : this.h + p.size * 2;
    p.life = 0;
  }
  reset() {
    const c = this.cfg();
    this.parts = Array.from({ length: c.n }, () => { const p = {}; this.spawn(p, true); return p; });
  }
  colors() {
    const cs = getComputedStyle(this);
    return { accent: cs.getPropertyValue('--accent').trim() || '#c2445f', ink: cs.getPropertyValue('--ink').trim() || '#2a1d1e' };
  }
  tick(now) {
    this.raf = requestAnimationFrame(this.tick);
    const dt = Math.min(0.05, (now - this.last) / 1000); this.last = now;
    if (!this.visible) return;
    const c = this.cfg(), col = this.colors(), ctx = this.ctx, t = now / 1000;
    ctx.clearRect(0, 0, this.w, this.h);
    const baseFill = c.tone === 'white' ? '#ffffff' : col.accent;
    for (const p of this.parts) {
      const fill = c.tone === 'leaf' ? p.hue : baseFill;
      p.life += dt;
      p.x += (p.vx + Math.sin(t * 1.3 + p.phase) * 4) * dt;
      p.y += p.vy * dt;
      p.rot += p.spin * dt;
      const off = p.x < -8 || p.x > this.w + 8 || p.y < -10 || p.y > this.h + 10;
      if (off) this.spawn(p, false);
      let a = p.alpha;
      if (c.shape === 'star' || c.shape === 'sparkle') a *= 0.35 + 0.65 * (0.5 + 0.5 * Math.sin(t * 2.2 + p.phase * 3));
      ctx.globalAlpha = a; ctx.fillStyle = fill;
      ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.rot);
      const s = p.size;
      if (c.shape === 'dot' || c.shape === 'star') { ctx.beginPath(); ctx.arc(0, 0, s, 0, Math.PI * 2); ctx.fill(); }
      else if (c.shape === 'petal') { ctx.beginPath(); ctx.ellipse(0, 0, s, s * 0.55, 0, 0, Math.PI * 2); ctx.fill(); }
      else if (c.shape === 'leaf') {
        // wobble so leaves tumble, not just rotate
        ctx.rotate(Math.sin(t * 1.7 + p.phase) * 0.35);
        ctx.scale(1, 0.75 + 0.25 * Math.sin(t * 2.1 + p.phase));
        ctx.beginPath();
        if (p.kind === 0) { // simple oval leaf (beech)
          ctx.moveTo(-s, 0); ctx.quadraticCurveTo(0, -s * 0.8, s, 0); ctx.quadraticCurveTo(0, s * 0.8, -s, 0);
        } else if (p.kind === 1) { // pointed lance (willow)
          ctx.moveTo(-s * 1.3, 0); ctx.quadraticCurveTo(0, -s * 0.45, s * 1.3, 0); ctx.quadraticCurveTo(0, s * 0.45, -s * 1.3, 0);
        } else if (p.kind === 2) { // maple: 5 lobes
          for (let i = 0; i < 5; i++) { const ang = -Math.PI / 2 + (i - 2) * 0.62; const r = i === 2 ? s * 1.15 : i === 1 || i === 3 ? s : s * 0.72; const px = Math.cos(ang) * r, py = Math.sin(ang) * r + s * 0.25; if (i === 0) ctx.moveTo(px, py); else { const mid = ang - 0.31, rm = s * 0.38; ctx.lineTo(Math.cos(mid) * rm, Math.sin(mid) * rm + s * 0.25); ctx.lineTo(px, py); } }
          ctx.lineTo(s * 0.35, s * 0.5); ctx.lineTo(0, s * 0.9); ctx.lineTo(-s * 0.35, s * 0.5); ctx.closePath();
        } else if (p.kind === 3) { // oak: wavy lobes
          ctx.moveTo(0, -s); for (let i = 0; i < 4; i++) { const y = -s + (i + 0.5) * s * 0.5; ctx.quadraticCurveTo(s * 0.9, y - s * 0.1, s * 0.3, y + s * 0.25); } ctx.lineTo(0, s);
          for (let i = 3; i >= 0; i--) { const y = -s + (i + 0.5) * s * 0.5; ctx.quadraticCurveTo(-s * 0.9, y + s * 0.15, -s * 0.3, y - s * 0.25); } ctx.closePath();
        } else { // heart (linden / birch)
          ctx.moveTo(0, s); ctx.quadraticCurveTo(-s * 1.1, 0, -s * 0.55, -s * 0.7); ctx.quadraticCurveTo(0, -s * 1.05, 0, -s * 0.5); ctx.quadraticCurveTo(0, -s * 1.05, s * 0.55, -s * 0.7); ctx.quadraticCurveTo(s * 1.1, 0, 0, s);
        }
        ctx.fill();
        ctx.globalAlpha = a * 0.45; ctx.strokeStyle = '#3a1a0a'; ctx.lineWidth = 0.5;
        ctx.beginPath(); if (p.kind <= 1) { ctx.moveTo(-s, 0); ctx.lineTo(s, 0); } else { ctx.moveTo(0, s); ctx.lineTo(0, -s * 0.7); } ctx.stroke();
      }
      else if (c.shape === 'sparkle') { ctx.fillRect(-s * 2, -s * 0.3, s * 4, s * 0.6); ctx.fillRect(-s * 0.3, -s * 2, s * 0.6, s * 4); }
      ctx.restore();
    }
    ctx.globalAlpha = 1;
  }
}
customElements.define('season-window', SeasonWindow);
})();
