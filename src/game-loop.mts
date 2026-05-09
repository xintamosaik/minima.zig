export type GameLoop = {
    start: () => void;
    stop: () => void;
    restart: () => void;
};

export function createGameLoop(config: {
    tickRate: number;
    maxCatchUpSteps: number;
    writeInput: () => void;
    tick: () => void;
    render: () => void;
    present: () => void;
}): GameLoop {
    const fixedStepMs = 1000 / config.tickRate;

    let accumulatorMs = 0;
    let lastFrameTimeMs = 0;
    let animationFrameId: number | null = null;
    let running = false;

    function loop(nowMs: number): void {
        if (!running) {
            return;
        }

        if (lastFrameTimeMs === 0) {
            lastFrameTimeMs = nowMs;
        }

        let frameDeltaMs = nowMs - lastFrameTimeMs;
        lastFrameTimeMs = nowMs;

        if (frameDeltaMs > 250) {
            frameDeltaMs = 250;
        }

        accumulatorMs += frameDeltaMs;

        config.writeInput();

        let steps = 0;

        while (accumulatorMs >= fixedStepMs && steps < config.maxCatchUpSteps) {
            config.tick();
            accumulatorMs -= fixedStepMs;
            steps += 1;
        }

        if (steps === config.maxCatchUpSteps && accumulatorMs > fixedStepMs) {
            accumulatorMs = fixedStepMs;
        }

        config.render();
        config.present();

        animationFrameId = requestAnimationFrame(loop);
    }

    function start(): void {
        if (running) {
            return;
        }

        running = true;
        lastFrameTimeMs = 0;
        animationFrameId = requestAnimationFrame(loop);
    }

    function stop(): void {
        running = false;

        if (animationFrameId !== null) {
            cancelAnimationFrame(animationFrameId);
            animationFrameId = null;
        }
    }

    function restart(): void {
        stop();

        accumulatorMs = 0;
        lastFrameTimeMs = 0;

        start();
    }

    return { start, stop, restart };
}