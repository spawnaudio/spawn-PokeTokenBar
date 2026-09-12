import SwiftUI

/// 이번 달 일별 추이 — 주/월 스칼라 두 개로는 답할 수 없는 "지난 며칠 어땠나"를 채운다.
///
/// 데이터는 이미 메모리에 있다(`ProviderEnrichment.monthDaily` — enrichment 스캔이 월 전체를
/// 읽고 있었고, 지금까지 합계만 남기고 버렸다). 새 창을 만들지 않고 기존 헤더 결을 따라 캡션 한 줄
/// + 막대 한 줄로 접는다.
///
/// 표시 게이트는 **의미값**이다(`peak > 0`). `series.isEmpty` 나 `!= nil` 로 게이트하면 안 된다 —
/// 생산자가 사용 없는 날도 0 으로 채우므로 이번 달을 한 번도 안 쓴 사용자에게도 배열은 non-empty 라
/// #56 계열(옵셔널 tautology)의 "안 썼는데 왜 뜨지"가 재현된다.
@MainActor
struct MonthDailyTrend: View {
    let series: [DailyUsage]
    let showsCost: Bool
    /// 오늘의 `localDay` 키 — 강조할 막대를 뷰가 시계를 다시 읽어 고르지 않게 주입한다.
    let today: String
    let l: L

    /// 마우스가 올라간 막대. 캡션의 리드아웃이 이걸 따라가고, 벗어나면 오늘로 돌아온다.
    /// 툴팁(`.help`)과 달리 **지연이 없고, 안 올려도 오늘 값이 항상 보인다** — 날짜를 알려면
    /// 반드시 호버해야 했던 게 첫 버전의 불만이었다.
    @State private var hovered: String?

    var body: some View {
        let peak = series.map(\.totalTokens).max() ?? 0
        if peak > 0 {
            VStack(alignment: .leading, spacing: 3) {
                captionRow(peak: peak)
                barRow(peak: peak)
                weekendTickRow
                axisRow
            }
            .padding(.top, 4)
        }
    }

    /// 캡션 + 리드아웃(호버 중인 날, 없으면 오늘) + 최댓값.
    /// 최댓값을 남기는 이유: 막대 높이가 상대값이라 어딘가 한 곳은 절대 스케일을 적어야 한다.
    private func captionRow(peak: Int) -> some View {
        HStack(spacing: 5) {
            Text(l.dailyTrend)
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(readout)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Spacer()
            Text(l.peakDay)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(TokenFormatter.compact(peak))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func barRow(peak: Int) -> some View {
        HStack(alignment: .bottom, spacing: DailyTrendMetrics.spacing) {
            ForEach(series, id: \.date) { day in
                let isToday = day.date == today
                // 사용 0 인 날은 바닥 눈금만 남으므로, 아주 조금 쓴 날과 높이로는 구분되지
                // 않는다 — 색을 한 단계 흐리게 해 "안 쓴 날"과 "조금 쓴 날"을 갈라준다.
                let isEmptyDay = day.totalTokens == 0
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(isToday ? Color.accentColor
                                  : Color.secondary.opacity(isEmptyDay ? 0.18 : 0.45))
                    .frame(height: DailyTrendMetrics.barHeight(tokens: day.totalTokens, peak: peak))
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())   // 낮은 막대도 칼럼 전체가 호버 대상이 되게
                    .onHover { inside in hovered = inside ? day.date : nil }
            }
        }
        .frame(height: DailyTrendMetrics.track, alignment: .bottom)
    }

    /// 주말 칼럼에 짧은 밑줄. **전체 높이 음영으로 하면 안 된다** — 다크 배경에서 그 음영이
    /// 막대로 읽혀 주말이 큰 사용량인 것처럼 보인다(후보 B 를 렌더해서 확인하고 버렸다).
    private var weekendTickRow: some View {
        HStack(spacing: DailyTrendMetrics.spacing) {
            ForEach(series, id: \.date) { day in
                Rectangle()
                    .fill(DailyTrendMetrics.isWeekend(day.date)
                          ? Color.secondary.opacity(0.5) : Color.clear)
                    .frame(height: DailyTrendMetrics.tickHeight)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// 날짜 축. 막대 폭이 한 달 기준 약 9pt 라 두 자리 숫자가 다 안 들어가므로 **전부 붙이면
    /// 서로 겹친다** — 1일·7일 간격·오늘에만 붙이고 나머지 칼럼은 빈 자리로 폭을 맞춘다
    /// (빈 자리를 빼면 라벨이 막대와 어긋난다).
    private var axisRow: some View {
        HStack(spacing: DailyTrendMetrics.spacing) {
            ForEach(series, id: \.date) { day in
                Group {
                    if let label = DailyTrendMetrics.axisLabel(for: day.date, today: today) {
                        Text(label)
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(day.date == today ? Color.accentColor : Color.secondary)
                            .fixedSize(horizontal: true, vertical: false)
                    } else {
                        Color.clear.frame(height: 1)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// 호버 중인 날(없으면 오늘)의 "8/24 (월) 5.2M". 시리즈에 없는 날짜면 빈 문자열 —
    /// 프로덕션에선 시리즈가 항상 오늘로 끝나므로 조회 실패는 일어나지 않는다(배열 조회가
    /// 옵셔널이라 생기는 분기일 뿐, 테스트할 분기가 아니다).
    private var readout: String {
        let target = hovered ?? today
        guard let day = series.first(where: { $0.date == target }) else { return "" }
        let stamp = DailyTrendMetrics.dayStamp(day.date, language: l.lang)
        let tokens = TokenFormatter.compact(day.totalTokens)
        guard showsCost else { return "\(stamp) \(tokens)" }
        return "\(stamp) \(tokens) \(day.usageCost.text(l))"
    }
}

/// 추이 막대의 기하 — 뷰 밖의 순수 함수로 둔다. SwiftUI 안에 두면 헤드리스로 검증할 수 없고,
/// 이 계산은 0 과 최댓값 경계에서 조용히 틀리기 쉽다(0 을 0pt 로 그리면 "그날이 없는" 것처럼 보인다).
enum DailyTrendMetrics {
    /// 막대 트랙 높이. 헤더가 이미 촘촘하므로 스파크라인 수준으로 낮게 잡는다.
    static let track: CGFloat = 26
    static let spacing: CGFloat = 1.5
    /// 사용 없는 날에 남기는 바닥 눈금. 0pt 로 그리면 그 날짜 칸이 사라진 것처럼 보이고, 축이
    /// 밀리지 않았다는 사실(=0 을 명시적으로 채웠다)이 화면에서 안 읽힌다.
    static let baseline: CGFloat = 1.5
    /// 주말 표시 밑줄 두께.
    static let tickHeight: CGFloat = 1.5

    /// `tokens` 를 `peak` 대비 비율로 트랙 안에 눕힌다.
    /// - `peak <= 0`: 스케일이 없다 → 전부 바닥 눈금 (호출부가 이미 게이트하지만 0 나눗셈은 막는다).
    /// - `tokens <= 0`: 바닥 눈금.
    /// - 그 외: 최소 `baseline` 을 보장해 아주 작은 날도 사라지지 않는다.
    static func barHeight(tokens: Int, peak: Int) -> CGFloat {
        guard peak > 0, tokens > 0 else { return baseline }
        let ratio = min(1, Double(tokens) / Double(peak))
        return max(baseline, CGFloat(ratio) * track)
    }

    /// 축에 숫자를 붙일 날인가 — 1일, 7일 간격, 그리고 오늘.
    ///
    /// 오늘을 항상 붙이는 이유: 오늘 사용량이 적으면 막대가 바닥 눈금 한 줄이라 강조색만으로는
    /// 위치를 못 찾는다(31일 렌더에서 실제로 안 보였다). 축의 숫자가 그때 유일한 단서다.
    ///
    /// **오늘 옆의 정기 라벨은 지운다.** 한 달이 다 찬 축은 칼럼이 약 9pt 인데 두 자리 숫자는
    /// 약 11pt 라, 오늘이 7의 배수 바로 옆이면(22일·29일 등) `21 22` 가 간격 없이 붙어 한 숫자로
    /// 읽힌다(8월 실데이터로 렌더해서 확인했다). 오늘은 절대 지우지 않으므로 라벨이 0개가 되는
    /// 상태는 없고, 인접한 정기 라벨 하나를 잃는 대가는 없다 — 오늘 위치를 알면 그 옆도 안다.
    static func axisLabel(for date: String, today: String, labelInterval: Int = 7,
                          minimumSeparation: Int = 3) -> String?
    {
        // `Int(...)` 옵셔널 해제는 API 강제다 — 시리즈의 날짜는 항상 "yyyy-MM-dd" 라 실패하지
        // 않는다(테스트할 분기가 아니다).
        guard let dayOfMonth = Int(date.suffix(2)) else { return nil }
        if date == today { return "\(dayOfMonth)" }

        let isRegular = dayOfMonth == 1 || (labelInterval > 0 && dayOfMonth % labelInterval == 0)
        guard isRegular else { return nil }
        if let todayOfMonth = Int(today.suffix(2)),
           abs(dayOfMonth - todayOfMonth) < minimumSeparation { return nil }
        return "\(dayOfMonth)"
    }

    /// `calendar` 는 테스트 주입 구멍 — 주말이 어느 요일인지는 로케일이 정한다(금·토인 지역도
    /// 있다). 프로덕션은 사용자 달력을 그대로 따라야 하므로 기본값을 쓴다.
    static func isWeekend(_ date: String, calendar: Calendar = .current) -> Bool {
        guard let parsed = LocalUsageReader.localDayFormatter().date(from: date) else { return false }
        return calendar.isDateInWeekend(parsed)
    }

    /// 월·일 + 요일을 **그 언어가 쓰는 순서로** — ko "8. 24. (월)", en "Mon, 8/24", fr "lun. 24/08".
    ///
    /// 두 가지를 로케일 템플릿(`MdE`)에 맡긴다.
    /// ① **요일 이름**: 6개 언어 × 7요일을 `Localization.swift` 에 손으로 적으면 OS 가 이미 가진 것을
    ///    다시 적는 셈이다.
    /// ② **월·일 순서**: `"\(month)/\(day)"` 로 조립하면 프랑스어·스페인어·포르투갈어에서도 미국식
    ///    순서(8/24)가 강제된다 — 그 언어들은 24/08 이 맞다.
    ///
    /// 로케일은 반드시 `AppLanguage` 에서 온다. `DateFormatter` 를 기본값으로 만들면 시스템 로케일을
    /// 따라, 앱 언어를 바꾼 사용자에게 한 화면 두 언어가 된다(defect-log §표시·UI 의 `.relative` 부류).
    static func dayStamp(_ date: String, language: AppLanguage) -> String {
        guard let parsed = LocalUsageReader.localDayFormatter().date(from: date) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = language.displayLocale
        formatter.setLocalizedDateFormatFromTemplate("MdE")
        return formatter.string(from: parsed)
    }
}
