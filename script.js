/* ═══════════════════════════════════════════════
   NEON SNAKE — Full Game Engine
   ═══════════════════════════════════════════════ */

(() => {
  'use strict';

  // ── DOM refs ──────────────────────────────────
  const bgCanvas      = document.getElementById('bgCanvas');
  const bgCtx         = bgCanvas.getContext('2d');
  const canvas        = document.getElementById('gameCanvas');
  const ctx           = canvas.getContext('2d');
  const scoreEl       = document.getElementById('score');
  const highScoreEl   = document.getElementById('high-score');
  const levelEl       = document.getElementById('level');
  const levelBadge    = document.getElementById('level-badge');
  const overlay       = document.getElementById('overlay');
  const overlayText   = document.getElementById('overlay-text');
  const logo          = document.getElementById('logo');
  const startBtn      = document.getElementById('start-btn');
  const btnText       = document.getElementById('btn-text');
  const statsPanel    = document.getElementById('stats');
  const statScore     = document.getElementById('stat-score');
  const statFood      = document.getElementById('stat-food');
  const statLevel     = document.getElementById('stat-level');
  const statTime      = document.getElementById('stat-time');
  const gameBoard     = document.getElementById('game-board');

  // ── Constants ─────────────────────────────────
  const GRID       = 20;      // cells per axis
  const BASE_SPEED = 140;     // ms per tick at level 1
  const SPEED_STEP = 6;       // ms faster per level
  const MIN_SPEED  = 55;

  // ── Neon palette ──────────────────────────────
  const COLORS = {
    headFill:    '#00ff87',
    headGlow:    'rgba(0,255,135,0.6)',
    bodyStart:   [0, 240, 255],
    bodyEnd:     [177, 77, 255],
    foodFill:    '#ff2d75',
    foodGlow:    'rgba(255,45,117,0.8)',
    gridDot:     'rgba(255,255,255,0.04)',
    bgCell:      'rgba(0,0,0,0.35)',
  };

  // ── State ─────────────────────────────────────
  let snake       = [];
  let food        = { x: 0, y: 0 };
  let dir         = { x: 0, y: 0 };
  let nextDir     = { x: 0, y: 0 };
  let score       = 0;
  let highScore   = parseInt(localStorage.getItem('neonSnakeHigh') || '0', 10);
  let level       = 1;
  let foodEaten   = 0;
  let startTime   = 0;
  let gameInterval = null;
  let playing     = false;
  let gameOver    = false;
  let cellPx      = 0;

  // Particles
  let particles   = [];

  highScoreEl.textContent = highScore;

  // ── Resize logic ──────────────────────────────
  function resize() {
    const rect = gameBoard.getBoundingClientRect();
    const size = Math.floor(rect.width);
    canvas.width  = size;
    canvas.height = size;
    cellPx = size / GRID;

    bgCanvas.width  = window.innerWidth;
    bgCanvas.height = window.innerHeight;
  }
  window.addEventListener('resize', resize);
  resize();

  // ══════════════════════════════════════════════
  //  Background Floating Particles
  // ══════════════════════════════════════════════
  const bgParticles = [];
  const BG_COUNT = 50;

  function initBgParticles() {
    bgParticles.length = 0;
    for (let i = 0; i < BG_COUNT; i++) {
      bgParticles.push({
        x: Math.random() * bgCanvas.width,
        y: Math.random() * bgCanvas.height,
        r: Math.random() * 1.8 + 0.4,
        dx: (Math.random() - 0.5) * 0.3,
        dy: (Math.random() - 0.5) * 0.3,
        alpha: Math.random() * 0.25 + 0.05,
      });
    }
  }
  initBgParticles();

  function drawBg() {
    bgCtx.clearRect(0, 0, bgCanvas.width, bgCanvas.height);
    for (const p of bgParticles) {
      p.x += p.dx;
      p.y += p.dy;
      if (p.x < 0) p.x = bgCanvas.width;
      if (p.x > bgCanvas.width) p.x = 0;
      if (p.y < 0) p.y = bgCanvas.height;
      if (p.y > bgCanvas.height) p.y = 0;
      bgCtx.beginPath();
      bgCtx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
      bgCtx.fillStyle = `rgba(0,240,255,${p.alpha})`;
      bgCtx.fill();
    }
    requestAnimationFrame(drawBg);
  }
  drawBg();

  // ══════════════════════════════════════════════
  //  Eat Particles
  // ══════════════════════════════════════════════
  function spawnParticles(cx, cy) {
    const count = 14;
    for (let i = 0; i < count; i++) {
      const angle = (Math.PI * 2 / count) * i + Math.random() * 0.3;
      const speed = 1.5 + Math.random() * 3;
      particles.push({
        x: cx,
        y: cy,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        life: 1,
        decay: 0.025 + Math.random() * 0.015,
        r: 2 + Math.random() * 3,
        color: Math.random() > 0.5 ? COLORS.foodFill : COLORS.headFill,
      });
    }
  }

  function updateParticles() {
    for (let i = particles.length - 1; i >= 0; i--) {
      const p = particles[i];
      p.x += p.vx;
      p.y += p.vy;
      p.vx *= 0.96;
      p.vy *= 0.96;
      p.life -= p.decay;
      if (p.life <= 0) {
        particles.splice(i, 1);
      }
    }
  }

  function drawParticles() {
    for (const p of particles) {
      ctx.save();
      ctx.globalAlpha = p.life;
      ctx.shadowBlur = 8;
      ctx.shadowColor = p.color;
      ctx.fillStyle = p.color;
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.r * p.life, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
    }
  }

  // ══════════════════════════════════════════════
  //  Game Logic
  // ══════════════════════════════════════════════
  function startGame() {
    snake = [];
    const mid = Math.floor(GRID / 2);
    for (let i = 0; i < 3; i++) snake.push({ x: mid, y: mid + i });
    dir     = { x: 0, y: -1 };
    nextDir = { x: 0, y: -1 };
    score     = 0;
    level     = 1;
    foodEaten = 0;
    particles = [];
    startTime = Date.now();
    playing   = true;
    gameOver  = false;

    scoreEl.textContent     = 0;
    levelEl.textContent     = 1;
    overlay.classList.add('hidden');
    statsPanel.classList.add('hidden');

    placeFood();
    clearInterval(gameInterval);
    gameInterval = setInterval(tick, BASE_SPEED);
  }

  function placeFood() {
    let ok = false;
    while (!ok) {
      food.x = Math.floor(Math.random() * GRID);
      food.y = Math.floor(Math.random() * GRID);
      ok = !snake.some(s => s.x === food.x && s.y === food.y);
    }
  }

  function tick() {
    if (!playing) return;

    dir = { ...nextDir };
    const head = {
      x: (snake[0].x + dir.x + GRID) % GRID,
      y: (snake[0].y + dir.y + GRID) % GRID,
    };

    // Self collision
    if (snake.some(s => s.x === head.x && s.y === head.y)) {
      endGame();
      return;
    }

    snake.unshift(head);

    if (head.x === food.x && head.y === food.y) {
      // Score
      foodEaten++;
      score += 10 * level;
      scoreEl.textContent = score;
      scoreEl.classList.remove('score-pop');
      void scoreEl.offsetWidth;           // reflow trigger
      scoreEl.classList.add('score-pop');

      // Level up every 5 foods
      const newLevel = Math.floor(foodEaten / 5) + 1;
      if (newLevel !== level) {
        level = newLevel;
        levelEl.textContent = level;
        levelBadge.classList.remove('pop');
        void levelBadge.offsetWidth;
        levelBadge.classList.add('pop');
        setTimeout(() => levelBadge.classList.remove('pop'), 350);

        // Speed up
        const newSpeed = Math.max(MIN_SPEED, BASE_SPEED - (level - 1) * SPEED_STEP);
        clearInterval(gameInterval);
        gameInterval = setInterval(tick, newSpeed);
      }

      // High score
      if (score > highScore) {
        highScore = score;
        highScoreEl.textContent = highScore;
        localStorage.setItem('neonSnakeHigh', highScore);
      }

      // Particles 🎉
      spawnParticles(
        head.x * cellPx + cellPx / 2,
        head.y * cellPx + cellPx / 2
      );

      placeFood();
    } else {
      snake.pop();
    }

    draw();
  }

  function endGame() {
    playing  = false;
    gameOver = true;
    clearInterval(gameInterval);

    // Screen shake
    gameBoard.classList.add('shake');
    setTimeout(() => gameBoard.classList.remove('shake'), 400);

    // Time calc
    const elapsed = Math.floor((Date.now() - startTime) / 1000);
    const mins = Math.floor(elapsed / 60);
    const secs = String(elapsed % 60).padStart(2, '0');

    // Show overlay
    logo.querySelector('.logo-sub').textContent = 'GAME OVER';
    overlayText.textContent = 'Вы столкнулись с самим собой!';
    btnText.textContent = 'ЗАНОВО';
    statsPanel.classList.remove('hidden');
    statScore.textContent = score;
    statFood.textContent  = foodEaten;
    statLevel.textContent = level;
    statTime.textContent  = `${mins}:${secs}`;
    overlay.classList.remove('hidden');
  }

  // ══════════════════════════════════════════════
  //  Drawing
  // ══════════════════════════════════════════════
  function draw() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    // Background fill
    ctx.fillStyle = COLORS.bgCell;
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    // Grid dots
    ctx.fillStyle = COLORS.gridDot;
    for (let x = 0; x < GRID; x++) {
      for (let y = 0; y < GRID; y++) {
        ctx.beginPath();
        ctx.arc(x * cellPx + cellPx / 2, y * cellPx + cellPx / 2, 1, 0, Math.PI * 2);
        ctx.fill();
      }
    }

    // ── Food ────────────────────────────────────
    const foodCx = food.x * cellPx + cellPx / 2;
    const foodCy = food.y * cellPx + cellPx / 2;
    const pulse  = 0.85 + 0.15 * Math.sin(Date.now() / 200);

    ctx.save();
    ctx.shadowBlur  = 18;
    ctx.shadowColor = COLORS.foodGlow;
    ctx.fillStyle   = COLORS.foodFill;
    ctx.beginPath();
    ctx.arc(foodCx, foodCy, (cellPx / 2 - 2) * pulse, 0, Math.PI * 2);
    ctx.fill();
    // inner bright dot
    ctx.shadowBlur = 0;
    ctx.fillStyle  = 'rgba(255,255,255,0.65)';
    ctx.beginPath();
    ctx.arc(foodCx - 2, foodCy - 2, 2.5, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();

    // ── Snake ───────────────────────────────────
    const len = snake.length;
    for (let i = len - 1; i >= 0; i--) {
      const seg = snake[i];
      const px  = seg.x * cellPx;
      const py  = seg.y * cellPx;
      const t   = len > 1 ? i / (len - 1) : 0;

      if (i === 0) {
        // Head
        ctx.save();
        ctx.shadowBlur  = 14;
        ctx.shadowColor = COLORS.headGlow;
        ctx.fillStyle   = COLORS.headFill;
        roundRect(ctx, px + 1, py + 1, cellPx - 2, cellPx - 2, 5);
        ctx.fill();

        // Eyes
        ctx.shadowBlur = 0;
        const eyeOff = cellPx * 0.22;
        const eyeR   = cellPx * 0.1;
        let ex1, ey1, ex2, ey2;

        if (dir.x === 1)       { ex1 = px+cellPx-eyeOff; ey1 = py+eyeOff;          ex2 = px+cellPx-eyeOff; ey2 = py+cellPx-eyeOff; }
        else if (dir.x === -1) { ex1 = px+eyeOff;        ey1 = py+eyeOff;          ex2 = px+eyeOff;        ey2 = py+cellPx-eyeOff; }
        else if (dir.y === -1) { ex1 = px+eyeOff;        ey1 = py+eyeOff;          ex2 = px+cellPx-eyeOff; ey2 = py+eyeOff; }
        else                   { ex1 = px+eyeOff;        ey1 = py+cellPx-eyeOff;   ex2 = px+cellPx-eyeOff; ey2 = py+cellPx-eyeOff; }

        ctx.fillStyle = '#0a0a0a';
        ctx.beginPath(); ctx.arc(ex1, ey1, eyeR, 0, Math.PI * 2); ctx.fill();
        ctx.beginPath(); ctx.arc(ex2, ey2, eyeR, 0, Math.PI * 2); ctx.fill();
        ctx.restore();
      } else {
        // Body segment — gradient from cyan → purple
        const r = lerp(COLORS.bodyStart[0], COLORS.bodyEnd[0], t);
        const g = lerp(COLORS.bodyStart[1], COLORS.bodyEnd[1], t);
        const b = lerp(COLORS.bodyStart[2], COLORS.bodyEnd[2], t);
        const shrink = Math.min(3, t * 4);
        const off = 1 + shrink / 2;
        const sz  = cellPx - 2 - shrink;

        ctx.save();
        ctx.shadowBlur  = 4;
        ctx.shadowColor = `rgba(${r|0},${g|0},${b|0},0.45)`;
        ctx.fillStyle   = `rgb(${r|0},${g|0},${b|0})`;
        roundRect(ctx, px + off, py + off, sz, sz, 4);
        ctx.fill();
        ctx.restore();
      }
    }

    // Particles on top
    updateParticles();
    drawParticles();
  }

  // ── Helpers ───────────────────────────────────
  function lerp(a, b, t) { return a + (b - a) * t; }

  function roundRect(c, x, y, w, h, r) {
    c.beginPath();
    c.moveTo(x + r, y);
    c.lineTo(x + w - r, y);
    c.quadraticCurveTo(x + w, y, x + w, y + r);
    c.lineTo(x + w, y + h - r);
    c.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
    c.lineTo(x + r, y + h);
    c.quadraticCurveTo(x, y + h, x, y + h - r);
    c.lineTo(x, y + r);
    c.quadraticCurveTo(x, y, x + r, y);
    c.closePath();
  }

  // ══════════════════════════════════════════════
  //  Input: Keyboard
  // ══════════════════════════════════════════════
  const KEY_MAP = {
    ArrowUp:    { x:  0, y: -1 },
    ArrowDown:  { x:  0, y:  1 },
    ArrowLeft:  { x: -1, y:  0 },
    ArrowRight: { x:  1, y:  0 },
    w: { x:  0, y: -1 }, W: { x:  0, y: -1 },
    s: { x:  0, y:  1 }, S: { x:  0, y:  1 },
    a: { x: -1, y:  0 }, A: { x: -1, y:  0 },
    d: { x:  1, y:  0 }, D: { x:  1, y:  0 },
  };

  document.addEventListener('keydown', (e) => {
    if (['ArrowUp','ArrowDown','ArrowLeft','ArrowRight',' '].includes(e.key)) e.preventDefault();
    const mapped = KEY_MAP[e.key];
    if (!mapped || !playing) return;
    // Prevent 180° turn
    if (mapped.x === -dir.x && mapped.y === -dir.y) return;
    nextDir = { ...mapped };
  });

  // ══════════════════════════════════════════════
  //  Input: D-Pad (mobile)
  // ══════════════════════════════════════════════
  const dpadDirs = {
    'dpad-up':    { x:  0, y: -1 },
    'dpad-down':  { x:  0, y:  1 },
    'dpad-left':  { x: -1, y:  0 },
    'dpad-right': { x:  1, y:  0 },
  };

  for (const [id, d] of Object.entries(dpadDirs)) {
    const el = document.getElementById(id);
    el.addEventListener('pointerdown', (e) => {
      e.preventDefault();
      if (!playing) return;
      if (d.x === -dir.x && d.y === -dir.y) return;
      nextDir = { ...d };
    });
  }

  // ══════════════════════════════════════════════
  //  Input: Swipe (mobile)
  // ══════════════════════════════════════════════
  let touchStart = null;
  canvas.addEventListener('touchstart', (e) => {
    const t = e.touches[0];
    touchStart = { x: t.clientX, y: t.clientY };
  }, { passive: true });

  canvas.addEventListener('touchend', (e) => {
    if (!touchStart || !playing) return;
    const t = e.changedTouches[0];
    const dx = t.clientX - touchStart.x;
    const dy = t.clientY - touchStart.y;
    const absDx = Math.abs(dx);
    const absDy = Math.abs(dy);
    if (Math.max(absDx, absDy) < 20) return;

    let swipe;
    if (absDx > absDy) {
      swipe = dx > 0 ? { x: 1, y: 0 } : { x: -1, y: 0 };
    } else {
      swipe = dy > 0 ? { x: 0, y: 1 } : { x: 0, y: -1 };
    }
    if (swipe.x === -dir.x && swipe.y === -dir.y) return;
    nextDir = { ...swipe };
    touchStart = null;
  });

  // ══════════════════════════════════════════════
  //  Start button
  // ══════════════════════════════════════════════
  startBtn.addEventListener('click', () => {
    logo.querySelector('.logo-sub').textContent = 'SNAKE';
    startGame();
  });

  // ── Initial render ────────────────────────────
  draw();

})();
