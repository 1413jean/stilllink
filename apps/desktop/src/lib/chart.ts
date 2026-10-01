import { astro } from 'iztro';

export type Person = {
  id: string;
  name: string;
  gender: '男' | '女';
  solar: string; // YYYY-MM-DD
  t: number; // 時辰 index 0–12（iztro 規則：0 早子、12 晚子）
  group: string;
  pinned?: boolean;
};

export type Astrolabe = ReturnType<typeof astro.bySolar>;
export type Horoscope = ReturnType<Astrolabe['horoscope']>;

export const HOURS = ['早子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥', '晚子'];
export const MUTAGENS = ['祿', '權', '科', '忌'] as const;
export type Mutagen = (typeof MUTAGENS)[number];

// 宮干四化（祿、權、科、忌），庚干採「陽武陰同」
export const STEM_MUTAGEN: Record<string, string[]> = {
  甲: ['廉貞', '破軍', '武曲', '太陽'],
  乙: ['天機', '天梁', '紫微', '太陰'],
  丙: ['天同', '天機', '文昌', '廉貞'],
  丁: ['太陰', '天同', '天機', '巨門'],
  戊: ['貪狼', '太陰', '右弼', '天機'],
  己: ['武曲', '貪狼', '天梁', '文曲'],
  庚: ['太陽', '武曲', '太陰', '天同'],
  辛: ['巨門', '太陽', '文曲', '文昌'],
  壬: ['天梁', '紫微', '左輔', '武曲'],
  癸: ['破軍', '巨門', '太陰', '貪狼'],
};

// palaces[i] 的 i：0 寅、1 卯 … 11 丑。盤面 4×4，回傳 [row, col]
const GRID: Record<number, [number, number]> = {
  3: [0, 0], 4: [0, 1], 5: [0, 2], 6: [0, 3],
  2: [1, 0], 7: [1, 3],
  1: [2, 0], 8: [2, 3],
  0: [3, 0], 11: [3, 1], 10: [3, 2], 9: [3, 3],
};
export const gridPos = (i: number) => GRID[i];

export const sanFangSiZheng = (i: number) => [i, (i + 4) % 12, (i + 8) % 12, (i + 6) % 12];

export function buildChart(p: Person) {
  return astro.bySolar(p.solar, p.t, p.gender, true, 'zh-TW');
}

function starsIn(a: Astrolabe, i: number): string[] {
  const pal = a.palaces[i];
  return [...pal.majorStars, ...pal.minorStars].map((s) => s.name);
}

/** 自化：本宮宮干化出本宮的星（離心）；對宮宮干化入本宮（向心） */
export function selfTransforms(a: Astrolabe, i: number) {
  const names: string[] = starsIn(a, i);
  const out: { star: string; m: Mutagen; dir: 'out' | 'in' }[] = [];
  const own = STEM_MUTAGEN[a.palaces[i].heavenlyStem] ?? [];
  const opp = STEM_MUTAGEN[a.palaces[(i + 6) % 12].heavenlyStem] ?? [];
  own.forEach((s, k) => names.includes(s) && out.push({ star: s, m: MUTAGENS[k], dir: 'out' }));
  opp.forEach((s, k) => names.includes(s) && out.push({ star: s, m: MUTAGENS[k], dir: 'in' }));
  return out;
}

/** 宮干飛化：本宮宮干四化分別飛入哪一宮 */
export function flyingFrom(a: Astrolabe, i: number) {
  return (STEM_MUTAGEN[a.palaces[i].heavenlyStem] ?? []).map((star, k) => ({
    star,
    m: MUTAGENS[k],
    to: a.palaces.findIndex((_, j) => starsIn(a, j).includes(star)),
  }));
}

/** 某顆星在運限（大限／流年／流月）的四化 */
export function scopeMutagen(list: string[] | undefined, star: string): Mutagen | null {
  if (!list) return null;
  const k = list.indexOf(star);
  return k >= 0 ? MUTAGENS[k] : null;
}

// ── 文墨天機式顯示用 ──
/** 星曜顏色類別：主星與吉星紅、煞星黑、雜曜藍 */
export function starTone(type: string): 'red' | 'black' | 'blue' {
  if (type === 'major' || type === 'soft' || type === 'lucun' || type === 'tianma') return 'red';
  if (type === 'tough') return 'black';
  return 'blue';
}

const BRANCHES = ['子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥'];
export const ZHI_HOURS = BRANCHES.map((b) => b + '時');
export const LUNAR_MONTHS = ['正月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '冬月', '臘月'];
export const LUNAR_DAYS = Array.from({ length: 30 }, (_, k) => {
  const d = k + 1;
  const n = ['', '一', '二', '三', '四', '五', '六', '七', '八', '九', '十'];
  if (d <= 10) return '初' + n[d];
  if (d < 20) return '十' + n[d - 10];
  if (d === 20) return '二十';
  if (d < 30) return '廿' + n[d - 20];
  return '三十';
});

/** 方位（依地支，palaces 的 i：0 寅） */
export const COMPASS = ['東偏北', '正東方', '東偏南', '南偏東', '正南方', '南偏西', '西偏南', '正西方', '西偏北', '北偏西', '正北方', '北偏東'];

/** 中宮四邊的錨點（0–100），畫三方四正連線用 */
export const ANCHOR: [number, number][] = [
  [0, 100], [0, 75], [0, 25], [0, 0], [25, 0], [75, 0], [100, 0], [100, 25], [100, 75], [100, 100], [75, 100], [25, 100],
];

/** 流年落在這一宮的虛歲（前 5 次） */
export function yearlyAges(a: Astrolabe, i: number) {
  const birthBranch = BRANCHES.indexOf(a.rawDates.chineseDate.yearly[1]);
  const first = (((i + 2) % 12) - birthBranch + 12) % 12 + 1;
  return Array.from({ length: 5 }, (_, k) => first + k * 12);
}

const WUXING: Record<string, string> = {
  甲: 'wood', 乙: 'wood', 丙: 'fire', 丁: 'fire', 戊: 'earth', 己: 'earth', 庚: 'metal', 辛: 'metal', 壬: 'water', 癸: 'water',
  寅: 'wood', 卯: 'wood', 巳: 'fire', 午: 'fire', 辰: 'earth', 戌: 'earth', 丑: 'earth', 未: 'earth', 申: 'metal', 酉: 'metal', 亥: 'water', 子: 'water',
};
export const wuxing = (ch: string) => WUXING[ch] ?? 'water';

export const SAMPLE_PEOPLE: Person[] = [
  { id: 'p1', name: 'Jean', gender: '女', solar: '1990-06-15', t: 6, group: '自己', pinned: true },
  { id: 'p2', name: '林小姐', gender: '女', solar: '1988-11-02', t: 3, group: '客人' },
  { id: 'p3', name: '陳先生', gender: '男', solar: '1979-03-21', t: 9, group: '客人' },
  { id: 'p4', name: '王小美', gender: '女', solar: '1996-08-08', t: 11, group: '客人' },
  { id: 'p5', name: '張大哥', gender: '男', solar: '1984-01-30', t: 1, group: '客人' },
  { id: 'p6', name: '媽媽', gender: '女', solar: '1962-09-12', t: 5, group: '家人' },
  { id: 'p7', name: '爸爸', gender: '男', solar: '1958-04-05', t: 7, group: '家人' },
];
