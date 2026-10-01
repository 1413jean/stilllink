import Foundation

/// 出生地資料（離線）：台灣、中國、港澳手動整理；其他國家讀 tz 資料庫的 zone.tab（每個時區代表城市的經緯度）
struct PlaceCity: Hashable, Identifiable {
    let name: String
    let lat: Double
    let lon: Double
    let tz: String
    var id: String { name + tz }
}

struct PlaceRegion: Hashable, Identifiable {
    let name: String
    let cities: [PlaceCity]
    var id: String { name }
}

enum Places {
    static let all: [PlaceRegion] = build()

    private static func c(_ n: String, _ lat: Double, _ lon: Double, _ tz: String) -> PlaceCity { PlaceCity(name: n, lat: lat, lon: lon, tz: tz) }

    static let taiwan = PlaceRegion(name: "台灣", cities: [
        c("台北市", 25.0330, 121.5654, "Asia/Taipei"), c("新北市", 25.0120, 121.4657, "Asia/Taipei"),
        c("基隆市", 25.1283, 121.7419, "Asia/Taipei"), c("桃園市", 24.9936, 121.3010, "Asia/Taipei"),
        c("新竹市", 24.8138, 120.9675, "Asia/Taipei"), c("新竹縣", 24.8387, 121.0177, "Asia/Taipei"),
        c("苗栗縣", 24.5602, 120.8214, "Asia/Taipei"), c("台中市", 24.1477, 120.6736, "Asia/Taipei"),
        c("彰化縣", 24.0518, 120.5161, "Asia/Taipei"), c("南投縣", 23.9609, 120.9719, "Asia/Taipei"),
        c("雲林縣", 23.7092, 120.4313, "Asia/Taipei"), c("嘉義市", 23.4801, 120.4491, "Asia/Taipei"),
        c("嘉義縣", 23.4518, 120.2555, "Asia/Taipei"), c("台南市", 22.9999, 120.2270, "Asia/Taipei"),
        c("高雄市", 22.6273, 120.3014, "Asia/Taipei"), c("屏東縣", 22.5519, 120.5487, "Asia/Taipei"),
        c("宜蘭縣", 24.7021, 121.7378, "Asia/Taipei"), c("花蓮縣", 23.9872, 121.6015, "Asia/Taipei"),
        c("台東縣", 22.7583, 121.1444, "Asia/Taipei"), c("澎湖縣", 23.5711, 119.5793, "Asia/Taipei"),
        c("金門縣", 24.4493, 118.3767, "Asia/Taipei"), c("連江縣", 26.1602, 119.9517, "Asia/Taipei"),
    ])

    static let china = PlaceRegion(name: "中國", cities: [
        c("北京", 39.9042, 116.4074, "Asia/Shanghai"), c("上海", 31.2304, 121.4737, "Asia/Shanghai"),
        c("天津", 39.3434, 117.3616, "Asia/Shanghai"), c("重慶", 29.5630, 106.5516, "Asia/Shanghai"),
        c("廣州", 23.1291, 113.2644, "Asia/Shanghai"), c("深圳", 22.5431, 114.0579, "Asia/Shanghai"),
        c("杭州", 30.2741, 120.1551, "Asia/Shanghai"), c("南京", 32.0603, 118.7969, "Asia/Shanghai"),
        c("蘇州", 31.2990, 120.5853, "Asia/Shanghai"), c("福州", 26.0745, 119.2965, "Asia/Shanghai"),
        c("廈門", 24.4798, 118.0894, "Asia/Shanghai"), c("成都", 30.5728, 104.0668, "Asia/Shanghai"),
        c("武漢", 30.5928, 114.3055, "Asia/Shanghai"), c("長沙", 28.2282, 112.9388, "Asia/Shanghai"),
        c("西安", 34.3416, 108.9398, "Asia/Shanghai"), c("鄭州", 34.7466, 113.6254, "Asia/Shanghai"),
        c("濟南", 36.6512, 117.1201, "Asia/Shanghai"), c("青島", 36.0671, 120.3826, "Asia/Shanghai"),
        c("瀋陽", 41.8057, 123.4315, "Asia/Shanghai"), c("大連", 38.9140, 121.6147, "Asia/Shanghai"),
        c("長春", 43.8171, 125.3235, "Asia/Shanghai"), c("哈爾濱", 45.8038, 126.5349, "Asia/Shanghai"),
        c("石家莊", 38.0428, 114.5149, "Asia/Shanghai"), c("太原", 37.8706, 112.5489, "Asia/Shanghai"),
        c("呼和浩特", 40.8424, 111.7490, "Asia/Shanghai"), c("合肥", 31.8206, 117.2272, "Asia/Shanghai"),
        c("南昌", 28.6820, 115.8579, "Asia/Shanghai"), c("南寧", 22.8170, 108.3665, "Asia/Shanghai"),
        c("海口", 20.0440, 110.1999, "Asia/Shanghai"), c("貴陽", 26.6470, 106.6302, "Asia/Shanghai"),
        c("昆明", 25.0389, 102.7183, "Asia/Shanghai"), c("拉薩", 29.6520, 91.1721, "Asia/Shanghai"),
        c("蘭州", 36.0611, 103.8343, "Asia/Shanghai"), c("西寧", 36.6171, 101.7782, "Asia/Shanghai"),
        c("銀川", 38.4872, 106.2309, "Asia/Shanghai"), c("烏魯木齊", 43.8256, 87.6168, "Asia/Shanghai"),
    ])

    static let hkmo = [
        PlaceRegion(name: "香港", cities: [c("香港", 22.3193, 114.1694, "Asia/Hong_Kong")]),
        PlaceRegion(name: "澳門", cities: [c("澳門", 22.1987, 113.5439, "Asia/Macau")]),
    ]

    /// 常見城市的中文名（其餘用英文）
    private static let zhCity: [String: String] = [
        "Tokyo": "東京", "Seoul": "首爾", "Singapore": "新加坡", "Kuala Lumpur": "吉隆坡", "Kuching": "古晉",
        "Bangkok": "曼谷", "Manila": "馬尼拉", "Jakarta": "雅加達", "Ho Chi Minh": "胡志明市", "Yangon": "仰光",
        "New York": "紐約", "Los Angeles": "洛杉磯", "Chicago": "芝加哥", "Denver": "丹佛", "Phoenix": "鳳凰城",
        "Anchorage": "安克拉治", "Honolulu": "檀香山", "Toronto": "多倫多", "Vancouver": "溫哥華", "Edmonton": "艾德蒙頓",
        "Halifax": "哈利法克斯", "Winnipeg": "溫尼伯", "London": "倫敦", "Paris": "巴黎", "Berlin": "柏林",
        "Madrid": "馬德里", "Rome": "羅馬", "Amsterdam": "阿姆斯特丹", "Zurich": "蘇黎世", "Vienna": "維也納",
        "Moscow": "莫斯科", "Dubai": "杜拜", "Sydney": "雪梨", "Melbourne": "墨爾本", "Brisbane": "布里斯本",
        "Perth": "伯斯", "Adelaide": "阿德雷德", "Auckland": "奧克蘭", "Sao Paulo": "聖保羅", "Mexico City": "墨西哥城",
        "Kolkata": "加爾各答", "Karachi": "喀拉蚩", "Istanbul": "伊斯坦堡", "Cairo": "開羅", "Johannesburg": "約翰尼斯堡",
    ]

    private static func build() -> [PlaceRegion] {
        let skip: Set<String> = ["TW", "CN", "HK", "MO"]
        var byCountry: [String: [PlaceCity]] = [:]
        if let url = Engine.resource("zone", "tab"), let text = try? String(contentsOf: url, encoding: .utf8) {
            for line in text.split(separator: "\n") where !line.hasPrefix("#") {
                let f = line.split(separator: "\t").map(String.init)
                guard f.count >= 3, !skip.contains(f[0]), let (lat, lon) = parse(f[1]) else { continue }
                let raw = f[2].split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? f[2]
                byCountry[f[0], default: []].append(c(zhCity[raw] ?? raw, lat, lon, f[2]))
            }
        }
        let zh = Locale(identifier: "zh_TW")
        let others = byCountry.map { code, cities in
            PlaceRegion(name: zh.localizedString(forRegionCode: code) ?? code, cities: cities.sorted { $0.name < $1.name })
        }
        .sorted { $0.name.compare($1.name, locale: zh) == .orderedAscending }
        return [taiwan, china] + hkmo + others
    }

    /// zone.tab 座標：±DDMM±DDDMM 或 ±DDMMSS±DDDMMSS
    private static func parse(_ s: String) -> (Double, Double)? {
        guard let i = s.dropFirst().firstIndex(where: { $0 == "+" || $0 == "-" }) else { return nil }
        func dms(_ t: Substring, degDigits: Int) -> Double? {
            let sign: Double = t.first == "-" ? -1 : 1
            let d = Array(t.dropFirst())
            guard d.count >= degDigits + 2 else { return nil }
            let deg = Double(String(d[0..<degDigits])) ?? 0
            let min = Double(String(d[degDigits..<degDigits + 2])) ?? 0
            let sec = d.count >= degDigits + 4 ? Double(String(d[degDigits + 2..<degDigits + 4])) ?? 0 : 0
            return sign * (deg + min / 60 + sec / 3600)
        }
        guard let lat = dms(s[..<i], degDigits: 2), let lon = dms(s[i...], degDigits: 3) else { return nil }
        return (lat, lon)
    }
}
