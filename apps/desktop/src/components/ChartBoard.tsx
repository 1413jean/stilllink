import { useState } from 'react';
import {
  ANCHOR, Astrolabe, COMPASS, HOURS, Horoscope, Mutagen, Person, gridPos, sanFangSiZheng,
  selfTransforms, flyingFrom, scopeMutagen, starTone, wuxing, yearlyAges,
} from '../lib/chart';

/** 0 本命、1 大限、2 流年、3 流月、4 流日、5 流時 */
export type Level = 0 | 1 | 2 | 3 | 4 | 5;

const SCOPES = [
  { key: 'decadal', tag: '大', cls: 'dec' },
  { key: 'yearly', tag: '年', cls: 'year' },
  { key: 'monthly', tag: '月', cls: 'month' },
  { key: 'daily', tag: '日', cls: 'day' },
  { key: 'hourly', tag: '時', cls: 'hour' },
] as const;

const MUT_CLASS: Record<Mutagen, string> = { 祿: 'm-lu', 權: 'm-quan', 科: 'm-ke', 忌: 'm-ji' };

type Props = { person: Person; chart: Astrolabe; horo: Horoscope; level: Level };

export function ChartBoard({ person, chart, horo, level }: Props) {
  const soul = chart.palaces.findIndex((p) => p.name === '命宮');
  const [sel, setSel] = useState(soul);
  const sf = sanFangSiZheng(sel);
  const active = SCOPES.slice(0, level);
  const flies = flyingFrom(chart, sel);
  const flyTo = new Map<number, Mutagen[]>();
  flies.forEach((f) => f.to >= 0 && flyTo.set(f.to, [...(flyTo.get(f.to) ?? []), f.m]));

  const stems = chart.chineseDate.split(' ');
  const yinYang = ['甲', '丙', '戊', '庚', '壬'].includes(stems[0][0]) ? '陽' : '陰';
  const [a, b, c, d] = sf.map((i) => ANCHOR[i]);

  return (
    <div className="wm">
      {chart.palaces.map((_, i) => {
        const [r, col] = gridPos(i);
        const side = r === 0 ? 'top' : r === 3 ? 'bottom' : col === 0 ? 'left' : 'right';
        if ((side === 'top' || side === 'bottom') && (col === 0 || col === 3)) return null;
        return (
          <div key={'c' + i} className={`compass c-${side}`}
            style={side === 'top' || side === 'bottom'
              ? { gridRow: side === 'top' ? 1 : 6, gridColumn: col + 2 }
              : { gridRow: r + 2, gridColumn: side === 'left' ? 1 : 6 }}>
            {COMPASS[i]}
          </div>
        );
      })}

      {chart.palaces.map((p, i) => {
        const [r, col] = gridPos(i);
        const selfs = selfTransforms(chart, i);
        const outSelf = new Map(selfs.filter((s) => s.dir === 'out').map((s) => [s.star, s.m]));
        const inSelf = new Map(selfs.filter((s) => s.dir === 'in').map((s) => [s.star, s.m]));
        const stars = [...p.majorStars, ...p.minorStars];
        const curDecade = level >= 1 && horo.decadal.index === i;
        return (
          <section key={i}
            className={`wp ${sel === i ? 'is-sel' : ''} ${sf.includes(i) && sel !== i ? 'is-sf' : ''}`}
            style={{ gridRow: r + 2, gridColumn: col + 2 }}
            onClick={() => setSel(i)}>
            <div className="wp-stars">
              {stars.map((s) => {
                const om = outSelf.get(s.name);
                const im = inSelf.get(s.name);
                return (
                  <div key={s.name} className={`ws tone-${starTone(s.type)} ${s.type === 'major' ? 'major' : ''}`}>
                    <span className={`ws-name ${om ? 'self ' + MUT_CLASS[om] : ''} ${im ? 'inself ' + MUT_CLASS[im] : ''}`}
                      title={om ? `離心自化${om}` : im ? `向心自化${im}` : undefined}>
                      {s.name}
                    </span>
                    <span className="ws-bright">{s.brightness || '　'}</span>
                    {s.mutagen && <span className="ws-mut birth">{s.mutagen}</span>}
                    {active.map((sc) => {
                      const m = scopeMutagen(horo[sc.key].mutagen, s.name);
                      return m && <span key={sc.key} className={`ws-mut sc-${sc.cls}`}>{m}</span>;
                    })}
                  </div>
                );
              })}
              {p.adjectiveStars.map((s) => (
                <div key={s.name} className="ws tone-blue adj"><span className="ws-name">{s.name}</span></div>
              ))}
            </div>

            <div className="wp-ages">
              <div>流年: {yearlyAges(chart, i).join(',')}</div>
              <div>小限: {p.ages.slice(0, 5).join(',')}</div>
            </div>

            {flyTo.has(i) && (
              <div className="wp-fly">
                {flyTo.get(i)!.map((m) => <span key={m} className={`fly ${MUT_CLASS[m]}`}>→{m}</span>)}
              </div>
            )}

            <div className="wp-foot">
              <div className="wp-gods">
                <span className="g-boshi">{p.boshi12}</span>
                <span>{p.jiangqian12}</span>
                <span>{p.suiqian12}</span>
              </div>
              <div className="wp-mid">
                <div className={`wp-range ${curDecade ? 'cur' : ''}`}>{p.decadal.range[0]}~{p.decadal.range[1]}</div>
                <div className="wp-names">
                  {active.map((sc) => (
                    <span key={sc.key} className={`wp-tag t-${sc.cls}`}>{sc.tag}{horo[sc.key].palaceNames[i].slice(0, 1)}</span>
                  ))}
                  <span className="wp-pname">{p.name}</span>
                </div>
              </div>
              <div className="wp-gz">
                <span className="wp-cs">{p.changsheng12}</span>
                <span className="wp-stem">{p.heavenlyStem}</span>
                <span className="wp-branch">{p.earthlyBranch}</span>
              </div>
            </div>
            {p.isBodyPalace && <span className="wp-body">身宮</span>}
          </section>
        );
      })}

      <div className="wc" style={{ gridRow: '3 / 5', gridColumn: '3 / 5' }}>
        <svg className="wc-lines" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden>
          <polygon points={`${a} ${b} ${c}`} />
          <line x1={a[0]} y1={a[1]} x2={d[0]} y2={d[1]} />
        </svg>
        <div className="wc-body">
          <div className="wc-title">紫微斗數</div>
          <dl className="wc-facts">
            <div><dt>姓名</dt><dd>{person.name}</dd><dd className="wc-ju">{yinYang}{person.gender}　{chart.fiveElementsClass}</dd></div>
            <div><dt>國曆</dt><dd>{person.solar.replace(/-/g, '-')} {HOURS[person.t]}時（{chart.timeRange}）</dd></div>
            <div><dt>農曆</dt><dd>{chart.lunarDate} {chart.time}</dd></div>
            <div><dt>命主</dt><dd>{chart.soul}　身主: {chart.body}　生肖: {chart.zodiac}</dd></div>
          </dl>
          <div className="wc-pillars">
            {stems.map((gz, k) => (
              <div key={k} className="pillar">
                <span className={`wx-${wuxing(gz[0])}`}>{gz[0]}</span>
                <span className={`wx-${wuxing(gz[1])}`}>{gz[1]}</span>
                <small>{'年月日時'[k]}</small>
              </div>
            ))}
          </div>
          <div className="wc-flies">
            <span className="wc-sel">{chart.palaces[sel].name}（{chart.palaces[sel].heavenlyStem}）飛化：</span>
            {flies.map((f) => (
              <span key={f.m} className={`fly ${MUT_CLASS[f.m]}`}>
                {f.star}{f.m}→{f.to >= 0 ? chart.palaces[f.to].name : '—'}
              </span>
            ))}
          </div>
          <div className="wc-legend">
            自化圖示: <span className="self m-lu">祿</span><span className="self m-quan">權</span>
            <span className="self m-ke">科</span><span className="self m-ji">忌</span>
            <span className="wc-legend-note">實底＝離心　框線＝向心</span>
          </div>
        </div>
      </div>
    </div>
  );
}
