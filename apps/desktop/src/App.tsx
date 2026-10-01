import { useEffect, useMemo, useState } from 'react';
import { HOURS, Person, SAMPLE_PEOPLE, buildChart } from './lib/chart';
import { ChartBoard, Level } from './components/ChartBoard';
import { Periods, Pick } from './components/Periods';
import { lunar2solar, solar2lunar } from 'lunar-lite';
import { DotField, DotSphere } from './components/DotArt';

type Theme = 'light' | 'dark' | 'system';
type Msg = { role: 'me' | 'note'; text: string; at: number };

const LEVELS = ['本命', '大限', '流年', '流月', '流日', '流時'];

function todayPick(): Pick {
  const now = new Date();
  const l = solar2lunar(`${now.getFullYear()}-${now.getMonth() + 1}-${now.getDate()}`);
  return { level: 2, year: l.lunarYear, lm: l.lunarMonth, ld: l.lunarDay, hour: Math.floor(((now.getHours() + 1) % 24) / 2) };
}

/** 讓彈出層有退場動畫：關閉後再留 --glass-dur 的時間才卸載 */
function usePresence(open: boolean, ms = 220) {
  const [mounted, setMounted] = useState(open);
  useEffect(() => {
    if (open) { setMounted(true); return; }
    const t = setTimeout(() => setMounted(false), ms);
    return () => clearTimeout(t);
  }, [open, ms]);
  return { mounted: open || mounted, state: open ? 'open' : 'closing' };
}

function useTheme(): [Theme, (t: Theme) => void, 'light' | 'dark'] {
  const [theme, setTheme] = useState<Theme>(() => {
    try { return (localStorage.getItem('ziwei:theme') as Theme) || 'system'; } catch { return 'system'; }
  });
  const [sysDark, setSysDark] = useState(() => matchMedia('(prefers-color-scheme: dark)').matches);
  useEffect(() => {
    const mq = matchMedia('(prefers-color-scheme: dark)');
    const fn = () => setSysDark(mq.matches);
    mq.addEventListener('change', fn);
    return () => mq.removeEventListener('change', fn);
  }, []);
  useEffect(() => {
    if (theme === 'system') document.documentElement.removeAttribute('data-theme');
    else document.documentElement.setAttribute('data-theme', theme);
    try { localStorage.setItem('ziwei:theme', theme); } catch { /* 無痕模式 */ }
  }, [theme]);
  return [theme, setTheme, theme === 'system' ? (sysDark ? 'dark' : 'light') : theme];
}

export default function App() {
  const [theme, setTheme, resolved] = useTheme();
  const [people, setPeople] = useState<Person[]>(SAMPLE_PEOPLE);
  const [activeId, setActiveId] = useState(SAMPLE_PEOPLE[0].id);
  const [query, setQuery] = useState('');
  const [pick, setPick] = useState<Pick>(todayPick);
  const [chatOpen, setChatOpen] = useState(() => window.innerWidth > 1180);
  const [drawer, setDrawer] = useState(false);
  const [settings, setSettings] = useState(false);
  const [creating, setCreating] = useState(false);
  const [msgs, setMsgs] = useState<Record<string, Msg[]>>({});

  const settingsP = usePresence(settings);
  const createP = usePresence(creating);

  const person = people.find((p) => p.id === activeId)!;
  const chart = useMemo(() => buildChart(person), [person]);
  const birthYear = Number(person.solar.slice(0, 4));
  const horo = useMemo(() => {
    const d = lunar2solar(`${pick.year}-${pick.lm}-${Math.min(pick.ld, 29)}`, false);
    return chart.horoscope(`${d.solarYear}-${d.solarMonth}-${d.solarDay}`, pick.hour);
  }, [chart, pick]);
  const onPick = (p: Partial<Pick>) => setPick((o) => ({ ...o, ...p }));

  const groups = useMemo(() => {
    const q = query.trim();
    const list = people.filter((p) => !q || p.name.includes(q));
    const m = new Map<string, Person[]>();
    list.filter((p) => p.pinned).forEach((p) => m.set('釘選', [...(m.get('釘選') ?? []), p]));
    list.filter((p) => !p.pinned).forEach((p) => m.set(p.group, [...(m.get(p.group) ?? []), p]));
    return [...m.entries()];
  }, [people, query]);

  const choose = (id: string) => { setActiveId(id); setDrawer(false); };

  return (
    <div className={`app ${chatOpen ? 'chat-on' : ''} ${drawer ? 'drawer-on' : ''}`}>
      {/* ── 側欄 ── */}
      <aside className="sidebar">
        <div className="titlebar-space" data-tauri-drag-region />
        <button className="new-btn" onClick={() => setCreating(true)}>
          <span className="plus">＋</span> 新增命盤 <kbd>⌘N</kbd>
        </button>
        <label className="search">
          <svg viewBox="0 0 16 16" width="14" height="14"><circle cx="7" cy="7" r="4.5" fill="none" stroke="currentColor" /><path d="M10.5 10.5 14 14" stroke="currentColor" /></svg>
          <input placeholder="搜尋姓名" value={query} onChange={(e) => setQuery(e.target.value)} />
        </label>

        <nav className="people">
          {groups.map(([g, list]) => (
            <div key={g} className="group">
              <div className="label group-label">{g} <span>{String(list.length).padStart(2, '0')}</span></div>
              {list.map((p) => {
                const c = buildChart(p);
                const soul = c.palaces.find((x) => x.name === '命宮')!;
                return (
                  <button key={p.id} className={`person ${p.id === activeId ? 'on' : ''}`} onClick={() => choose(p.id)}>
                    <span className="dot" />
                    <span className="pn">{p.name}</span>
                    <span className="pm">{soul.majorStars.map((s) => s.name).join('') || '空宮'}</span>
                  </button>
                );
              })}
            </div>
          ))}
        </nav>

        <div className="account">
          <button className="me" onClick={() => setSettings((s) => !s)}>
            <span className="avatar">J</span>
            <span className="who"><b>Jean</b><small className="label">LOCAL · 未登入</small></span>
            <svg viewBox="0 0 16 16" width="14" height="14"><path d="M4 6l4 4 4-4" fill="none" stroke="currentColor" /></svg>
          </button>
          {settingsP.mounted && (
            <div className="popover glass" data-state={settingsP.state}>
              <div className="label">APPEARANCE / 外觀</div>
              <div className="seg">
                {(['light', 'dark', 'system'] as Theme[]).map((t) => (
                  <button key={t} className={theme === t ? 'on' : ''} onClick={() => setTheme(t)}>
                    {{ light: '淺色', dark: '深色', system: '系統' }[t]}
                  </button>
                ))}
              </div>
              <div className="label">ACCOUNT / 帳號同步</div>
              <button className="btn-line wide"><span className="logo"></span> 使用 Apple 登入</button>
              <button className="btn-line wide"><span className="logo g">G</span> 使用 Google 登入</button>
              <div className="pop-sep" />
              <button className="menu-item">命盤設定 <span className="label">四化流派 · 顯示</span></button>
              <button className="menu-item">匯出／匯入</button>
            </div>
          )}
        </div>
      </aside>
      <div className="scrim" onClick={() => setDrawer(false)} />
      {settingsP.mounted && <div className="glass-scrim" data-state={settingsP.state} onClick={() => setSettings(false)} />}

      {/* ── 主區 ── */}
      <main className="main">
        <DotField key={resolved} />
        <header className="topbar" data-tauri-drag-region>
          <button className="icon-btn only-narrow" onClick={() => setDrawer(true)} aria-label="開啟命盤列表">
            <svg viewBox="0 0 16 16" width="16" height="16"><path d="M2 4h12M2 8h12M2 12h12" stroke="currentColor" /></svg>
          </button>
          <div className="crumb">
            <span className="label">{person.group.toUpperCase()} /</span>
            <b>{person.name}</b>
            <span className="muted">{person.gender} · {person.solar} {HOURS[person.t]}時 · {chart.fiveElementsClass}</span>
          </div>
          <div className="seg layers">
            {LEVELS.map((l, k) => (
              <button key={l} className={pick.level === k ? 'on' : ''} onClick={() => onPick({ level: k as Level })}>{l}</button>
            ))}
          </div>
          <button className={`icon-btn ${chatOpen ? 'on' : ''}`} onClick={() => setChatOpen((v) => !v)} aria-label="對話框">
            <svg viewBox="0 0 16 16" width="16" height="16"><rect x="1.5" y="2.5" width="13" height="11" fill="none" stroke="currentColor" /><path d="M10 2.5v11" stroke="currentColor" /></svg>
          </button>
        </header>

        <div className="workspace">
          <div className="chart-col">
            <ChartBoard key={person.id} person={person} chart={chart} horo={horo} level={pick.level} />
            <Periods chart={chart} birthYear={birthYear} pick={pick} onPick={onPick} />
          </div>

          {/* ── 對話框 ── */}
          <ChatPanel
            key={person.id}
            name={person.name}
            msgs={msgs[person.id] ?? []}
            onClose={() => setChatOpen(false)}
            onSend={(text) =>
              setMsgs((all) => ({
                ...all,
                [person.id]: [...(all[person.id] ?? []), { role: 'me', text, at: Date.now() }],
              }))
            }
          />
        </div>
      </main>

      {createP.mounted && (
        <NewChartModal
          state={createP.state}
          onClose={() => setCreating(false)}
          onCreate={(p) => { setPeople((ps) => [p, ...ps]); setActiveId(p.id); setCreating(false); }}
        />
      )}
    </div>
  );
}

function ChatPanel({ name, msgs, onSend, onClose }: { name: string; msgs: Msg[]; onSend: (t: string) => void; onClose: () => void }) {
  const [text, setText] = useState('');
  const send = () => { const t = text.trim(); if (t) { onSend(t); setText(''); } };
  return (
    <aside className="chat">
      <header className="chat-head">
        <div className="label">SESSION / {name}</div>
        <button className="icon-btn only-narrow-chat" onClick={onClose} aria-label="關閉">✕</button>
      </header>
      <div className="chat-body">
        {msgs.length === 0 ? (
          <div className="chat-empty">
            <DotSphere size={88} cell={3} seed={11} />
            <h3>這張盤，想看什麼？</h3>
            <p>先把客人的問題和你的觀察記在這裡。AI 解盤之後會接上，直接讀這張盤回答。</p>
            <div className="suggest">
              {['今年感情', '事業轉換時機', '大限走勢'].map((s) => (
                <button key={s} className="btn-line" onClick={() => setText(s)}>{s}</button>
              ))}
            </div>
          </div>
        ) : (
          msgs.map((m) => (
            <div key={m.at} className={`msg ${m.role}`}>
              <div className="label">{new Date(m.at).toLocaleTimeString('zh-TW', { hour: '2-digit', minute: '2-digit' })} · 筆記</div>
              <p>{m.text}</p>
            </div>
          ))
        )}
      </div>
      <div className="composer">
        <textarea
          rows={2}
          placeholder="記下問題或觀察…"
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter' && !e.shiftKey && !e.nativeEvent.isComposing) { e.preventDefault(); send(); } }}
        />
        <div className="composer-bar">
          <span className="seg tiny"><button className="on">筆記</button><button disabled title="即將推出">AI 解盤</button></span>
          <button className="btn-solid" onClick={send} disabled={!text.trim()}>送出</button>
        </div>
      </div>
    </aside>
  );
}

function NewChartModal({ state, onClose, onCreate }: { state: string; onClose: () => void; onCreate: (p: Person) => void }) {
  const [name, setName] = useState('');
  const [gender, setGender] = useState<'男' | '女'>('女');
  const [solar, setSolar] = useState('1995-01-01');
  const [t, setT] = useState(6);
  const [group, setGroup] = useState('客人');
  const ok = name.trim() && /^\d{4}-\d{2}-\d{2}$/.test(solar);
  return (
    <div className="modal-back glass-scrim" data-state={state} onClick={onClose}>
      <div className="modal glass" data-state={state} onClick={(e) => e.stopPropagation()}>
        <div className="modal-art"><DotSphere size={150} cell={4} seed={23} /></div>
        <div className="modal-body">
          <div className="label">NEW / 新增命盤</div>
          <h3>輸入生辰，立刻排盤</h3>
          <div className="form">
            <label><span className="label">姓名</span><input autoFocus value={name} onChange={(e) => setName(e.target.value)} placeholder="例如：林小姐" /></label>
            <label><span className="label">性別</span>
              <span className="seg">{(['女', '男'] as const).map((g) => <button key={g} type="button" className={gender === g ? 'on' : ''} onClick={() => setGender(g)}>{g}</button>)}</span>
            </label>
            <label><span className="label">國曆生日</span><input type="date" value={solar} onChange={(e) => setSolar(e.target.value)} /></label>
            <label><span className="label">時辰</span>
              <select value={t} onChange={(e) => setT(Number(e.target.value))}>
                {HOURS.map((h, k) => <option key={k} value={k}>{h}時</option>)}
              </select>
            </label>
            <label><span className="label">分組</span><input value={group} onChange={(e) => setGroup(e.target.value)} /></label>
          </div>
          <div className="modal-actions">
            <button className="btn-line" onClick={onClose}>‹ 取消</button>
            <button className="btn-solid" disabled={!ok}
              onClick={() => onCreate({ id: crypto.randomUUID(), name: name.trim(), gender, solar, t, group: group.trim() || '客人' })}>
              排盤
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
