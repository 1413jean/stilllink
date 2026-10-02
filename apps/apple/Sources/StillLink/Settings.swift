import SwiftUI

/// 命盤設定（參考文墨天機的設定項，只放真的會生效的）
struct ZSettings: Codable, Equatable {
    // 排盤
    enum Algorithm: String, Codable, CaseIterable { case standard = "default", zhongzhou }
    enum YearDivide: String, Codable, CaseIterable { case normal, exact }       // 正月初一／立春
    enum DayDivide: String, Codable, CaseIterable { case forward, current }     // 晚子時：視為次日／當日
    var algorithm: Algorithm = .standard
    var yearDivide: YearDivide = .normal
    var dayDivide: DayDivide = .forward
    var leapSplit = true                                                       // 閏月：月中分界／視為本月

    // 四化版本（各干只有庚辛壬癸常見分歧）
    var geng = "陽武陰同"
    var xin = "巨陽曲昌"
    var ren = "梁紫輔武"
    var gui = "破巨陰貪"

    // 盤面顯示
    var showAdj = true          // 雜曜
    var showGods = true         // 博士／將前／歲前
    var showAges = true         // 流年／小限歲數
    var showMinor = true        // 小限疊盤（選流年時一起顯示）
    var showMinorMutagen = true // 小限四化方塊（小限疊盤開著時才有作用）
    var showOuterBelowMonth = false // 選到流月／流日／流時時，仍顯示生年與大限四化（預設不顯示，盤面比較乾淨）
    var openWithDecade = false  // 打開命盤時預設停在大限（關閉＝本命）
    var showBody = true         // 身宮
    var showLaiyin = true       // 來因宮
    var showSanfang = true      // 三方四正連線
    var showSelf = true         // 自化箭頭
    var showTransfer = true     // 轉宮宮名（點選宮位當太極，顯示 X之Y）
    var showCompass = true      // 方位
    var showComposer = false    // 命盤下方的 AI 對話框（AI 還沒推出，預設隱藏）

    // 音效與動畫
    var motion = true
    var sound = true
    var haptics = true
    var cues: [String: String] = [:]     // Sound.Event → 音效 id
    var soundStyle = "minimal"
    var volume = 0.6

    // MARK: 四化表

    static let gengOptions: [String: [String]] = [
        "陽武陰同": ["太陽", "武曲", "太陰", "天同"], "陽武同陰": ["太陽", "武曲", "天同", "太陰"],
        "陽武府同": ["太陽", "武曲", "天府", "天同"], "陽武府相": ["太陽", "武曲", "天府", "天相"],
        "陽武同相": ["太陽", "武曲", "天同", "天相"],
    ]
    static let xinOptions: [String: [String]] = [
        "巨陽曲昌": ["巨門", "太陽", "文曲", "文昌"], "巨陽武昌": ["巨門", "太陽", "武曲", "文昌"],
    ]
    static let renOptions: [String: [String]] = [
        "梁紫輔武": ["天梁", "紫微", "左輔", "武曲"], "梁紫府武": ["天梁", "紫微", "天府", "武曲"],
        "梁紫相武": ["天梁", "紫微", "天相", "武曲"],
    ]
    static let guiOptions: [String: [String]] = [
        "破巨陰貪": ["破軍", "巨門", "太陰", "貪狼"], "破巨陽貪": ["破軍", "巨門", "太陽", "貪狼"],
    ]

    /// 依設定組出的十干四化表
    var stemMutagen: [String: [String]] {
        var t = ZW.defaultStemMutagen
        t["庚"] = Self.gengOptions[geng] ?? t["庚"]
        t["辛"] = Self.xinOptions[xin] ?? t["辛"]
        t["壬"] = Self.renOptions[ren] ?? t["壬"]
        t["癸"] = Self.guiOptions[gui] ?? t["癸"]
        return t
    }

    /// 影響計算結果的設定（變了就要重算命盤）
    var calcKey: String { "\(algorithm.rawValue)|\(yearDivide.rawValue)|\(dayDivide.rawValue)|\(leapSplit)|\(geng)|\(xin)|\(ren)|\(gui)" }

    /// 傳給 iztro 的設定（iztro 的四化表要用簡體星名）
    var iztroConfig: [String: Any] {
        let cn: [String: String] = [
            "太陽": "太阳", "太陰": "太阴", "巨門": "巨门", "左輔": "左辅", "破軍": "破军", "貪狼": "贪狼",
            "廉貞": "廉贞", "天機": "天机",
        ]
        var m: [String: [String]] = [:]
        for (stem, stars) in stemMutagen { m[stem] = stars.map { cn[$0] ?? $0 } }
        return ["mutagens": m, "algorithm": algorithm.rawValue, "yearDivide": yearDivide.rawValue,
                "dayDivide": dayDivide.rawValue]
    }
}

extension ZSettings {
    /// 從偏好設定讀出目前的設定（給還拿不到 environment 的地方用，例如 View 的 init）
    static func stored() -> ZSettings {
        guard let d = UserDefaults.standard.data(forKey: "settings") else { return ZSettings() }
        if let s = try? JSONDecoder().decode(ZSettings.self, from: d) { return s }
        // 新增設定欄位後舊資料會缺 key：把存的值疊在預設值上再解，其他設定才不會整組被重置
        guard let saved = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
              let defData = try? JSONEncoder().encode(ZSettings()),
              var merged = (try? JSONSerialization.jsonObject(with: defData)) as? [String: Any] else { return ZSettings() }
        merged.merge(saved) { _, new in new }
        guard let md = try? JSONSerialization.data(withJSONObject: merged),
              let s = try? JSONDecoder().decode(ZSettings.self, from: md) else { return ZSettings() }
        return s
    }

    /// 打開命盤時的預設運限層級
    var openLevel: Int { openWithDecade ? 1 : 0 }
}

private struct SettingsKey: EnvironmentKey { static let defaultValue = ZSettings() }
extension EnvironmentValues {
    var zSettings: ZSettings {
        get { self[SettingsKey.self] }
        set { self[SettingsKey.self] = newValue }
    }
}
