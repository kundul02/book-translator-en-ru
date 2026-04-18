const canvas = document.getElementById('gameCanvas');
const ctx = canvas.getContext('2d');
const scoreElement = document.getElementById('score');
const highScoreElement = document.getElementById('high-score');
const startBtn = document.getElementById('start-btn');
const overlay = document.getElementById('overlay');
const overlayTitle = document.getElementById('overlay-title');
const overlayText = document.getElementById('overlay-text');

// Game variables
const gridSize = 20;
const tileCount = canvas.width / gridSize;
let snake = [];
let food = {};
let dx = 0;
let dy = 0;
let score = 0;
let highScore = localStorage.getItem('snakeHighScore') || 0;
let gameLoop;
let isGameOver = false;
let gameSpeed = 120;

highScoreElement.textContent = highScore;

// Colors
const colors = {
    head: '#00ff87',
    body: '#60efff',
    food1: '#ff0844',
    food2: '#ffb199',
    grid: 'rgba(255, 255, 255, 0.03)'
};

function initGame() {
    snake = [
        { x: 10, y: 10 },
        { x: 10, y: 11 },
        { x: 10, y: 12 }
    ];
    
    dx = 0;
    dy = -1; // Start moving up
    score = 0;
    gameSpeed = 130;
    scoreElement.textContent = score;
    isGameOver = false;
    overlay.classList.add('hidden');
    
    spawnFood();

    if (gameLoop) clearInterval(gameLoop);
    gameLoop = setInterval(update, gameSpeed);
}

function spawnFood() {
    let valid = false;
    while (!valid) {
        food = {
            x: Math.floor(Math.random() * tileCount),
            y: Math.floor(Math.random() * tileCount)
        };
        valid = true;
        for (let segment of snake) {
            if (segment.x === food.x && segment.y === food.y) {
                valid = false;
                break;
            }
        }
    }
}

function update() {
    if (isGameOver) return;

    const head = { x: snake[0].x + dx, y: snake[0].y + dy };

    // Wall collision (wrap around logic for modern feel)
    if (head.x < 0) head.x = tileCount - 1;
    if (head.x >= tileCount) head.x = 0;
    if (head.y < 0) head.y = tileCount - 1;
    if (head.y >= tileCount) head.y = 0;

    // Self collision
    for (let i = 0; i < snake.length; i++) {
        if (head.x === snake[i].x && head.y === snake[i].y) {
            gameOver();
            return;
        }
    }

    snake.unshift(head);

    // Food collision
    if (head.x === food.x && head.y === food.y) {
        score += 10;
        scoreElement.textContent = score;
        
        // Add a slight scale animation to score
        scoreElement.style.transform = 'scale(1.2)';
        setTimeout(() => scoreElement.style.transform = 'scale(1)', 150);

        if (score > highScore) {
            highScore = score;
            highScoreElement.textContent = highScore;
            localStorage.setItem('snakeHighScore', highScore);
        }
        spawnFood();
        
        // Progressive difficulty
        if (gameSpeed > 60) {
            clearInterval(gameLoop);
            gameSpeed -= 3;
            gameLoop = setInterval(update, gameSpeed);
        }
    } else {
        snake.pop();
    }

    draw();
}

function draw() {
    // Clear canvas
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    // Draw grid lines
    ctx.strokeStyle = colors.grid;
    ctx.lineWidth = 1;
    for (let i = 0; i < tileCount; i++) {
        ctx.beginPath();
        ctx.moveTo(i * gridSize, 0);
        ctx.lineTo(i * gridSize, canvas.height);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(0, i * gridSize);
        ctx.lineTo(canvas.width, i * gridSize);
        ctx.stroke();
    }

    // Draw Food with glow
    ctx.shadowBlur = 20;
    ctx.shadowColor = colors.food1;
    
    const foodGradient = ctx.createLinearGradient(
        food.x * gridSize, food.y * gridSize, 
        (food.x + 1) * gridSize, (food.y + 1) * gridSize
    );
    foodGradient.addColorStop(0, colors.food1);
    foodGradient.addColorStop(1, colors.food2);
    
    ctx.fillStyle = foodGradient;
    ctx.beginPath();
    ctx.arc(food.x * gridSize + gridSize/2, food.y * gridSize + gridSize/2, gridSize/2 - 2, 0, Math.PI * 2);
    ctx.fill();

    // Draw Snake
    for (let i = 0; i < snake.length; i++) {
        if (i === 0) {
            ctx.shadowBlur = 15;
            ctx.shadowColor = colors.head;
            ctx.fillStyle = colors.head;
        } else {
            ctx.shadowBlur = 5;
            ctx.shadowColor = colors.body;
            ctx.fillStyle = colors.body;
        }
        
        // Calculate size based on position to make tail slightly smaller
        const sizeMod = i === 0 ? 0 : Math.min(4, i * 0.2);
        const size = gridSize - 2 - sizeMod;
        const offset = 1 + sizeMod/2;
        
        // Rounded rectangles for snake
        ctx.beginPath();
        ctx.roundRect(
            snake[i].x * gridSize + offset, 
            snake[i].y * gridSize + offset, 
            size, 
            size,
            4 // border radius
        );
        ctx.fill();
    }
    
    ctx.shadowBlur = 0;
}

function gameOver() {
    isGameOver = true;
    clearInterval(gameLoop);
    overlayTitle.textContent = 'ИГРА ОКОНЧЕНА';
    overlayTitle.style.background = 'linear-gradient(to right, #ff0844, #ffb199)';
    overlayTitle.style.webkitBackgroundClip = 'text';
    overlayText.textContent = `Итоговый счет: ${score}`;
    startBtn.textContent = 'ИГРАТЬ СНОВА';
    overlay.classList.remove('hidden');
}

// Input handling
let lastInputDirection = { x: 0, y: -1 };

document.addEventListener('keydown', (e) => {
    // Prevent default scrolling
    if(["ArrowUp","ArrowDown","ArrowLeft","ArrowRight", " "].indexOf(e.key) > -1) {
        e.preventDefault();
    }
    
    if (isGameOver) return;
    
    // Prevent reverse gear self-collision
    if ((e.key === 'ArrowUp' || e.key === 'w' || e.key === 'W') && lastInputDirection.y !== 1) {
        dx = 0; dy = -1;
    } else if ((e.key === 'ArrowDown' || e.key === 's' || e.key === 'S') && lastInputDirection.y !== -1) {
        dx = 0; dy = 1;
    } else if ((e.key === 'ArrowLeft' || e.key === 'a' || e.key === 'A') && lastInputDirection.x !== 1) {
        dx = -1; dy = 0;
    } else if ((e.key === 'ArrowRight' || e.key === 'd' || e.key === 'D') && lastInputDirection.x !== -1) {
        dx = 1; dy = 0;
    }
    
    lastInputDirection = { x: dx, y: dy };
});

startBtn.addEventListener('click', initGame);

// Initial empty state drawing
draw();
