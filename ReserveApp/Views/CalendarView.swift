import SwiftUI
import FirebaseFirestore

// MARK: - Calendar helpers

enum CalendarMath {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "fr_FR")
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .current
        calendar.firstWeekday = 2
        return calendar
    }()

    static let weekdaySymbols = ["L", "M", "M", "J", "V", "S", "D"]

    static func isoKey(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

    static func days(in interval: DateInterval) -> [Date] {
        var days: [Date] = []
        var day = interval.start
        while day < interval.end {
            days.append(day)
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? interval.end
        }
        return days
    }

    static func monthGrid(for date: Date) -> [Date] {
        guard let month = calendar.dateInterval(of: .month, for: date),
              let firstWeek = calendar.dateInterval(of: .weekOfYear, for: month.start),
              let lastWeek = calendar.dateInterval(of: .weekOfYear, for: month.end.addingTimeInterval(-1)) else { return [] }
        return days(in: DateInterval(start: firstWeek.start, end: lastWeek.end))
    }
}

// MARK: - Restaurant capacity / closures (live)

final class CalendarRestaurantConfig: ObservableObject {
    @Published private var data: [String: Any] = [:]
    private var listener: ListenerRegistration?

    private static let dayNames = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]

    func start() {
        guard listener == nil,
              let restaurantId = UserDefaults.standard.string(forKey: "restaurantDocumentId"), !restaurantId.isEmpty else { return }
        listener = Firestore.firestore().collection("restaurants").document(restaurantId)
            .addSnapshotListener { [weak self] snapshot, _ in
                DispatchQueue.main.async { self?.data = snapshot?.data() ?? [:] }
            }
    }

    deinit { listener?.remove() }

    private func dayHours(_ date: Date) -> [String: Any]? {
        let weekday = CalendarMath.calendar.component(.weekday, from: date)
        return (data["openingHours"] as? [String: Any])?[Self.dayNames[weekday - 1]] as? [String: Any]
    }

    private func closedDateEntry(_ iso: String) -> [String: Any]? {
        (data["closedDates"] as? [Any])?.compactMap { entry -> [String: Any]? in
            if let dict = entry as? [String: Any], dict["date"] as? String == iso { return dict }
            if let string = entry as? String, string == iso { return [:] }
            return nil
        }.first
    }

    func closureReason(_ date: Date) -> String? {
        let iso = CalendarMath.isoKey(date)
        if let entry = closedDateEntry(iso), (entry["closedServices"] as? [String])?.isEmpty ?? true {
            return entry["reason"] as? String ?? "Fermé"
        }
        if dayHours(date)?["closed"] as? Bool == true { return "Fermé" }
        return nil
    }

    private func slots(for date: Date, service: ServiceType) -> [String] {
        guard let configured = data["timeSlots"] as? [String], !configured.isEmpty else { return [] }
        let hours = dayHours(date)
        let open = hours?["open"] as? String ?? "00:00"
        let close = hours?["close"] as? String ?? "23:59"
        return configured.filter { $0 >= open && $0 <= close && ServiceType.from(timeSlot: $0) == service }
    }

    func isServiceClosed(_ date: Date, _ service: ServiceType) -> Bool {
        if closureReason(date) != nil { return true }
        let iso = CalendarMath.isoKey(date)
        if let perService = (data["closedServices"] as? [String: Any])?[iso] as? [String: Any],
           let status = perService[service.rawValue] as? [String: Any],
           status["isClosed"] as? Bool == true { return true }
        if let services = closedDateEntry(iso)?["closedServices"] as? [String], services.contains(service.rawValue) { return true }
        return data["timeSlots"] != nil && data["openingHours"] != nil && slots(for: date, service: service).isEmpty
    }

    /// Estimated covers a service can hold: slots × 30 min / table duration "turns" × max guests per slot.
    func capacity(_ date: Date, _ service: ServiceType) -> Int? {
        guard let perSlot = data["maxGuestsPerSlot"] as? Int, perSlot > 0 else { return nil }
        let slotCount = slots(for: date, service: service).count
        guard slotCount > 0 else { return nil }
        let duration = max(30, data["serviceDuration"] as? Int ?? 90)
        let turns = max(1.0, Double(slotCount * 30) / Double(duration))
        return Int((Double(perSlot) * turns).rounded())
    }
}

// MARK: - Day summary

struct CalendarDaySummary {
    let reservations: [Reservation]

    var active: [Reservation] { reservations.filter { $0.status != .cancelled && $0.status != .noShow } }
    var covers: Int { active.reduce(0) { $0 + $1.numberOfPeople } }

    func covers(_ service: ServiceType) -> Int {
        active.filter { $0.service == service }.reduce(0) { $0 + $1.numberOfPeople }
    }
}

enum FillLevel {
    static func ratio(covers: Int, capacity: Int?, fallbackMax: Int) -> Double {
        let denominator = Double(capacity ?? max(fallbackMax, 1))
        return min(1, Double(covers) / denominator)
    }

    static func color(_ ratio: Double) -> Color {
        switch ratio {
        case ..<0.6: return AppTheme.gold
        case ..<0.9: return .orange
        default: return .red
        }
    }
}

// MARK: - Calendar View

struct CalendarView: View {
    @ObservedObject var viewModel: ReservationViewModel
    var onDateSelected: ((Date) -> Void)?

    @StateObject private var config = CalendarRestaurantConfig()
    @State private var mode: Mode = .month
    @State private var anchorDate = Date()
    @State private var selectedDate = Date()
    @State private var selectedReservation: Reservation?

    enum Mode: String, CaseIterable {
        case week = "Semaine"
        case month = "Mois"
    }

    private var cal: Calendar { CalendarMath.calendar }

    private var reservationsByDay: [String: [Reservation]] {
        Dictionary(grouping: viewModel.reservations) { CalendarMath.isoKey($0.date) }
    }

    private func summary(_ date: Date) -> CalendarDaySummary {
        CalendarDaySummary(reservations: reservationsByDay[CalendarMath.isoKey(date)] ?? [])
    }

    private var periodInterval: DateInterval {
        cal.dateInterval(of: mode == .month ? .month : .weekOfYear, for: anchorDate) ?? DateInterval(start: anchorDate, duration: 86_400)
    }

    private var periodDays: [Date] { CalendarMath.days(in: periodInterval) }

    private var fallbackMax: Int {
        periodDays.flatMap { day in ServiceType.allCases.map { summary(day).covers($0) } }.max() ?? 1
    }

    private var headerTitle: String {
        if mode == .month { return CalendarMath.format(anchorDate, "LLLL yyyy").capitalized }
        let last = periodInterval.end.addingTimeInterval(-1)
        return "\(CalendarMath.format(periodInterval.start, "d MMM")) – \(CalendarMath.format(last, "d MMM yyyy"))"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    Group {
                        if mode == .month { monthGrid } else { weekGrid }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 30).onEnded { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            navigate(value.translation.width < 0 ? 1 : -1)
                        }
                    )
                    legend
                    dayPanel
                }
                .padding(.vertical)
            }
            .background(AppTheme.anthracite)
            .navigationTitle("Calendrier")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { config.start() }
        .sheet(item: $selectedReservation) { reservation in
            ReservationDetailView(reservation: reservation, viewModel: viewModel)
        }
    }

    // MARK: Header

    private var header: some View {
        let periodSummary = CalendarDaySummary(reservations: periodDays.flatMap { summary($0).reservations })
        return VStack(spacing: 12) {
            Picker("Vue", selection: $mode.animation()) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(SegmentedPickerStyle())

            HStack {
                navButton("chevron.left") { navigate(-1) }
                Spacer()
                VStack(spacing: 4) {
                    Text(headerTitle)
                        .font(.custom("Didot", size: 20))
                        .foregroundColor(AppTheme.gold)
                    Text("\(periodSummary.active.count) rés. · \(periodSummary.covers) couverts")
                        .font(.caption)
                        .foregroundColor(AppTheme.cream.opacity(0.7))
                }
                Spacer()
                navButton("chevron.right") { navigate(1) }
            }

            if !cal.isDate(anchorDate, equalTo: Date(), toGranularity: mode == .month ? .month : .weekOfYear)
                || !cal.isDateInToday(selectedDate) {
                Button("Aujourd'hui") {
                    withAnimation {
                        anchorDate = Date()
                        selectedDate = Date()
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundColor(AppTheme.anthracite)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(AppTheme.gold))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 15).fill(AppTheme.darkGray))
        .padding(.horizontal)
    }

    private func navButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.gold)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.anthracite.opacity(0.4)))
        }
    }

    private func navigate(_ direction: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            anchorDate = cal.date(byAdding: mode == .month ? .month : .weekOfYear, value: direction, to: anchorDate) ?? anchorDate
            if !periodInterval.contains(selectedDate) { selectedDate = periodInterval.start }
        }
    }

    private func select(_ date: Date) {
        withAnimation(.easeInOut(duration: 0.15)) { selectedDate = date }
    }

    // MARK: Month grid

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(Array(CalendarMath.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppTheme.cream.opacity(0.6))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        VStack(spacing: 6) {
            weekdayHeader
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(CalendarMath.monthGrid(for: anchorDate), id: \.self) { date in
                    MonthDayCell(
                        date: date,
                        summary: summary(date),
                        inMonth: cal.isDate(date, equalTo: anchorDate, toGranularity: .month),
                        isSelected: cal.isDate(date, inSameDayAs: selectedDate),
                        isToday: cal.isDateInToday(date),
                        config: config,
                        fallbackMax: fallbackMax
                    )
                    .onTapGesture { select(date) }
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: Week grid

    private var weekGrid: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Color.clear.frame(width: 38)
                ForEach(periodDays, id: \.self) { date in
                    let isSelected = cal.isDate(date, inSameDayAs: selectedDate)
                    let isToday = cal.isDateInToday(date)
                    VStack(spacing: 2) {
                        Text(CalendarMath.format(date, "EEEEE").uppercased())
                            .font(.caption2.weight(.semibold))
                        Text(CalendarMath.format(date, "d"))
                            .font(.system(size: 15, weight: isToday ? .bold : .medium))
                    }
                    .foregroundColor(isToday ? AppTheme.gold : AppTheme.cream)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? AppTheme.gold.opacity(0.25) : Color.clear))
                    .onTapGesture { select(date) }
                }
            }
            ForEach(ServiceType.allCases, id: \.self) { service in
                HStack(spacing: 4) {
                    Text(service == .lunch ? "Midi" : "Soir")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppTheme.cream.opacity(0.7))
                        .frame(width: 38, alignment: .leading)
                    ForEach(periodDays, id: \.self) { date in
                        WeekServiceCell(
                            covers: summary(date).covers(service),
                            capacity: config.capacity(date, service),
                            closed: config.isServiceClosed(date, service),
                            isSelected: cal.isDate(date, inSameDayAs: selectedDate),
                            fallbackMax: fallbackMax
                        )
                        .onTapGesture { select(date) }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(AppTheme.gold, "Disponible")
            legendItem(.orange, "Presque complet")
            legendItem(.red, "Complet")
            HStack(spacing: 4) {
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundColor(AppTheme.cream.opacity(0.5))
                Text("Fermé")
            }
        }
        .font(.caption2)
        .foregroundColor(AppTheme.cream.opacity(0.6))
    }

    private func legendItem(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 4)
            Text(label)
        }
    }

    // MARK: Selected day panel

    private var dayPanel: some View {
        let reservations = summary(selectedDate).reservations.sorted(by: Reservation.byServiceTime)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(CalendarMath.format(selectedDate, "EEEE d MMMM").capitalized)
                    .font(.custom("Didot", size: 18))
                    .foregroundColor(AppTheme.gold)
                Spacer()
                if let reason = config.closureReason(selectedDate) {
                    Text(reason)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.red)
                }
            }

            ForEach(ServiceType.allCases, id: \.self) { service in
                servicePanel(service, reservations: reservations.filter { $0.service == service })
            }

            Button {
                onDateSelected?(selectedDate)
            } label: {
                HStack {
                    Image(systemName: "list.bullet")
                    Text("Ouvrir dans Réservations")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppTheme.anthracite)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.gold))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 15).fill(AppTheme.darkGray))
        .padding(.horizontal)
    }

    private func servicePanel(_ service: ServiceType, reservations: [Reservation]) -> some View {
        let active = reservations.filter { $0.status != .cancelled && $0.status != .noShow }
        let covers = active.reduce(0) { $0 + $1.numberOfPeople }
        let capacity = config.capacity(selectedDate, service)
        let closed = config.isServiceClosed(selectedDate, service)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(service == .lunch ? "MIDI" : "SOIR")
                    .font(.caption.weight(.bold))
                    .tracking(1.5)
                    .foregroundColor(AppTheme.gold)
                if closed {
                    Text("Fermé").font(.caption2.weight(.semibold)).foregroundColor(.red)
                }
                Spacer()
                Text("\(active.count) rés. · \(covers)\(capacity.map { "/\($0)" } ?? "") couv.")
                    .font(.caption)
                    .foregroundColor(AppTheme.cream.opacity(0.7))
            }
            if let capacity, !closed {
                let ratio = FillLevel.ratio(covers: covers, capacity: capacity, fallbackMax: 1)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppTheme.anthracite.opacity(0.6))
                        Capsule().fill(FillLevel.color(ratio)).frame(width: geo.size.width * ratio)
                    }
                }
                .frame(height: 4)
            }
            if reservations.isEmpty {
                Text("Aucune réservation")
                    .font(.caption)
                    .italic()
                    .foregroundColor(AppTheme.cream.opacity(0.5))
            } else {
                ForEach(reservations) { reservation in
                    CalendarReservationRow(reservation: reservation)
                        .onTapGesture { selectedReservation = reservation }
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.anthracite.opacity(0.5)))
    }
}

// MARK: - Month day cell

private struct MonthDayCell: View {
    let date: Date
    let summary: CalendarDaySummary
    let inMonth: Bool
    let isSelected: Bool
    let isToday: Bool
    @ObservedObject var config: CalendarRestaurantConfig
    let fallbackMax: Int

    var body: some View {
        let dayClosed = config.closureReason(date) != nil
        VStack(spacing: 4) {
            Text(CalendarMath.format(date, "d"))
                .font(.system(size: 14, weight: isToday ? .bold : .medium))
                .foregroundColor(isToday ? AppTheme.anthracite : AppTheme.cream)
                .frame(width: 24, height: 24)
                .background(Circle().fill(isToday ? AppTheme.gold : Color.clear))

            if dayClosed && summary.reservations.isEmpty {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppTheme.cream.opacity(0.4))
                    .frame(height: 10)
            } else {
                VStack(spacing: 2) {
                    ForEach(ServiceType.allCases, id: \.self) { service in
                        serviceBar(service)
                    }
                }
                .frame(height: 10)
            }

            Text(summary.covers > 0 ? "\(summary.covers)" : " ")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AppTheme.cream.opacity(0.8))
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? AppTheme.gold.opacity(0.22) : AppTheme.darkGray.opacity(dayClosed ? 0.25 : 0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? AppTheme.gold : Color.clear, lineWidth: 1.5)
        )
        .opacity(inMonth ? 1 : 0.35)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func serviceBar(_ service: ServiceType) -> some View {
        let covers = summary.covers(service)
        if config.isServiceClosed(date, service) && covers == 0 {
            Capsule().fill(AppTheme.cream.opacity(0.08)).frame(height: 3)
        } else {
            let ratio = FillLevel.ratio(covers: covers, capacity: config.capacity(date, service), fallbackMax: fallbackMax)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppTheme.cream.opacity(0.12))
                    Capsule().fill(FillLevel.color(ratio)).frame(width: geo.size.width * ratio)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 6)
        }
    }
}

// MARK: - Week service cell

private struct WeekServiceCell: View {
    let covers: Int
    let capacity: Int?
    let closed: Bool
    let isSelected: Bool
    let fallbackMax: Int

    var body: some View {
        let ratio = FillLevel.ratio(covers: covers, capacity: capacity, fallbackMax: fallbackMax)
        VStack(spacing: 4) {
            if closed && covers == 0 {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.cream.opacity(0.35))
            } else {
                Text("\(covers)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(covers > 0 ? AppTheme.cream : AppTheme.cream.opacity(0.4))
                if let capacity {
                    Text("/\(capacity)")
                        .font(.system(size: 9))
                        .foregroundColor(AppTheme.cream.opacity(0.5))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .background(
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 8).fill(AppTheme.darkGray.opacity(closed ? 0.25 : 0.7))
                if !(closed && covers == 0) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(FillLevel.color(ratio).opacity(0.35))
                        .frame(height: 64 * ratio)
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? AppTheme.gold : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Compact reservation row

private struct CalendarReservationRow: View {
    let reservation: Reservation

    var body: some View {
        let inactive = reservation.status == .cancelled || reservation.status == .noShow
        HStack(spacing: 10) {
            Text(reservation.time)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(inactive ? AppTheme.cream.opacity(0.4) : AppTheme.gold)
            Text(reservation.name.capitalized)
                .font(.subheadline)
                .foregroundColor(inactive ? AppTheme.cream.opacity(0.5) : AppTheme.cream)
                .strikethrough(reservation.status == .cancelled, color: .red)
                .lineLimit(1)
            Spacer()
            Text("\(reservation.numberOfPeople)p")
                .font(.caption.weight(.semibold))
                .foregroundColor(AppTheme.cream.opacity(inactive ? 0.4 : 0.8))
            Text(reservation.status.displayName)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(StatusBadgeView.statusColor(for: reservation.status)))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#Preview {
    CalendarView(viewModel: ReservationViewModel())
        .withCasanovaTheme()
}
