import { Astrolabe, LUNAR_DAYS, LUNAR_MONTHS, ZHI_HOURS } from '../lib/chart';
import { Level } from './ChartBoard';

const GAN = '甲乙丙丁戊己庚辛壬癸';
const ZHI = '子丑寅卯辰巳午未申酉戌亥';
const yearGz = (y: number) => GAN[(y - 4) % 10] + ZHI[(y - 4) % 12];

export type Pick = { level: Level; year: number; lm: number; ld: number; hour: number };

type Props = { chart: Astrolabe; birthYear: number; pick: Pick; onPick: (p: Partial<Pick>) => void };

/** 文墨天機下方的運限表：大限／流年小限／流月／流日／流時 */
export function Periods({ chart, birthYear, pick, onPick }: Props) {
  const decades = chart.palaces
    .map((p) => ({ range: p.decadal.range, gz: p.heavenlyStem + p.earthlyBranch }))
    .sort((a, b) => a.range[0] - b.range[0]);
  const age = pick.year - birthYear + 1;
  const cur = decades.find((d) => age >= d.range[0] && age <= d.range[1]);
  const start = cur ? birthYear + cur.range[0] - 1 : birthYear;
  const years = Array.from({ length: 10 }, (_, k) => start + k);
  const on = (lv: Level, hit: boolean) => (hit && pick.level >= lv ? 'on' : '');

  return (
    <div className="pt">
      <div className="pt-row">
        <div className="pt-head">大限</div>
        <div className="pt-cells">
          <button className={`pt-cell ${!cur && pick.level >= 1 ? 'on' : ''}`}
            onClick={() => onPick({ level: 2, year: birthYear })}>
            起限前<small>(童限)</small>
          </button>
          {decades.map((d) => (
            <button key={d.range[0]} className={`pt-cell ${on(1, cur === d)}`}
              onClick={() => cur === d && pick.level === 1
                ? onPick({ level: 0 })
                : onPick({ level: 1, year: birthYear + d.range[0] - 1 })}>
              {d.range[0]}~{d.range[1]}<small>{d.gz}限</small>
            </button>
          ))}
        </div>
      </div>
      <div className="pt-row">
        <div className="pt-head">流年<br />小限</div>
        <div className="pt-cells">
          {years.map((y) => (
            <button key={y} className={`pt-cell ${on(2, y === pick.year)}`}
              onClick={() => onPick({ level: y === pick.year && pick.level === 2 ? 1 : 2, year: y })}>
              {y}年<small>{yearGz(y)}{y - birthYear + 1}歲</small>
            </button>
          ))}
        </div>
      </div>
      <div className="pt-row">
        <div className="pt-head">流月</div>
        <div className="pt-cells">
          {LUNAR_MONTHS.map((m, k) => (
            <button key={m} className={`pt-cell one ${on(3, k + 1 === pick.lm)}`}
              onClick={() => onPick({ level: k + 1 === pick.lm && pick.level === 3 ? 2 : 3, lm: k + 1 })}>
              {m}
            </button>
          ))}
        </div>
      </div>
      <div className="pt-row">
        <div className="pt-head">流日</div>
        <div className="pt-cells days">
          {LUNAR_DAYS.map((d, k) => (
            <button key={d} className={`pt-cell one ${on(4, k + 1 === pick.ld)}`}
              onClick={() => onPick({ level: k + 1 === pick.ld && pick.level === 4 ? 3 : 4, ld: k + 1 })}>
              {d}
            </button>
          ))}
        </div>
      </div>
      <div className="pt-row">
        <div className="pt-head">流時</div>
        <div className="pt-cells">
          {ZHI_HOURS.map((h, k) => (
            <button key={h} className={`pt-cell one ${on(5, k === pick.hour)}`}
              onClick={() => onPick({ level: k === pick.hour && pick.level === 5 ? 4 : 5, hour: k })}>
              {h}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
