// Swift ↔ iztro 的橋。只負責計算，回傳 JSON 字串給 Swift 解碼。
var __cache = {};
var __fixLeap = true;

// 套用設定（四化表、派別、年分界、晚子時），並清掉快取
function zwConfig(json) {
  var c = JSON.parse(json);
  __fixLeap = c.fixLeap !== false;
  delete c.fixLeap;
  iztro.astro.config(c);
  __cache = {};
}

function __astro(solar, t, gender) {
  var key = solar + '|' + t + '|' + gender;
  if (!__cache[key]) __cache[key] = iztro.astro.bySolar(solar, t, gender, __fixLeap, 'zh-TW');
  return __cache[key];
}

// 宮名用語：僕役宮一律叫交友宮
function __pn(n) { return n === '僕役' ? '交友' : n; }

function __star(s) {
  return { name: s.name, type: s.type, brightness: s.brightness || '', mutagen: s.mutagen || '' };
}

function zwChart(solar, t, gender) {
  var a = __astro(solar, t, gender);
  return JSON.stringify({
    solarDate: a.solarDate, lunarDate: a.lunarDate, chineseDate: a.chineseDate,
    time: a.time, timeRange: a.timeRange, sign: a.sign, zodiac: a.zodiac,
    soul: a.soul, body: a.body, fiveElementsClass: a.fiveElementsClass,
    yearBranch: a.rawDates.chineseDate.yearly[1],
    lunarYear: a.rawDates.lunarDate.lunarYear, lunarMonth: a.rawDates.lunarDate.lunarMonth,
    palaces: a.palaces.map(function (p) {
      return {
        name: __pn(p.name), stem: p.heavenlyStem, branch: p.earthlyBranch, isBody: p.isBodyPalace,
        major: p.majorStars.map(__star), minor: p.minorStars.map(__star), adj: p.adjectiveStars.map(__star),
        changsheng: p.changsheng12, boshi: p.boshi12, jiangqian: p.jiangqian12, suiqian: p.suiqian12,
        range: p.decadal.range, ages: p.ages,
      };
    }),
  });
}

function zwHoro(solar, t, gender, date, hour) {
  var h = __astro(solar, t, gender).horoscope(date, hour);
  // 流曜（運祿、流鸞…）改成文墨天機的叫法：大X、年X
  function fs(x) { return (x.stars || []).map(function (arr) { return arr.map(function (s) { return s.name.replace(/^運/, '大').replace(/^流/, '年'); }); }); }
  function sc(x) { return { index: x.index, stem: x.heavenlyStem, branch: x.earthlyBranch, palaceNames: x.palaceNames.map(__pn), mutagen: x.mutagen, stars: fs(x) }; }
  return JSON.stringify({ decadal: sc(h.decadal), age: sc(h.age), yearly: sc(h.yearly), monthly: sc(h.monthly), daily: sc(h.daily), hourly: sc(h.hourly) });
}

function zwLunarToSolar(y, m, d, leap) {
  return iztro.astro.byLunar(y + '-' + m + '-' + d, 0, '女', !!leap, true, 'zh-TW').solarDate;
}

function zwSolarToLunar(solar) {
  var l = iztro.astro.bySolar(solar, 0, '女', true, 'zh-TW').rawDates.lunarDate;
  return JSON.stringify({ year: l.lunarYear, month: l.lunarMonth, day: l.lunarDay });
}
