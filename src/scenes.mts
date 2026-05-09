export const SCENE = {
    INTRO: 0,
    MENU: 1,
    CREDITS: 2,
    OPTIONS: 3,
    NEW: 4,
    LOAD: 5,
    EXIT: 6,
    BATTLE_PLAIN_WOLVES: 7,
    BATTLE_RIVER_WOLVES: 8,
    BATTLE_PLAIN_GOBLINS: 9,
} as const;

export type SceneId = typeof SCENE[keyof typeof SCENE];