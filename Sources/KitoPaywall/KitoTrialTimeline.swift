//
//  KitoTrialTimeline.swift
//  KitoPaywall
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// The dates of a free trial: access today, a reminder before it ends, and the first charge.
/// A 7-day trial with the default reminder reads Today → Day 5 → Day 7.
public struct KitoTrialTimeline: Equatable, Sendable {
    public struct Step: Identifiable, Equatable, Sendable {
        public enum Kind: Hashable, Sendable { case start, reminder, charge }

        public let kind: Kind
        public let date: Date
        /// Days after the start: 0 today, 7 for the charge on a 7-day trial.
        public let day: Int

        public var id: Kind { kind }

        /// "Today", "Day 5", "Day 7".
        public var title: String { day == 0 ? "Today" : "Day \(day)" }
    }

    public let steps: [Step]

    /// Starts `trial` at `start`, with a reminder `reminderDaysBefore` days before the charge.
    /// The reminder is left out when it would fall on the first day.
    public init(start: Date = .now, trial: KitoBillingPeriod, reminderDaysBefore: Int = 2, calendar: Calendar = .current) {
        let charge = calendar.date(byAdding: trial.unit.calendarComponent, value: trial.value, to: start)
            ?? start.addingTimeInterval(TimeInterval(trial.approximateDays) * 86_400)
        let day0 = calendar.startOfDay(for: start)
        func dayNumber(_ date: Date) -> Int {
            calendar.dateComponents([.day], from: day0, to: calendar.startOfDay(for: date)).day ?? 0
        }
        var steps = [Step(kind: .start, date: start, day: 0)]
        if reminderDaysBefore > 0, let reminder = calendar.date(byAdding: .day, value: -reminderDaysBefore, to: charge), dayNumber(reminder) > 0 {
            steps.append(Step(kind: .reminder, date: reminder, day: dayNumber(reminder)))
        }
        steps.append(Step(kind: .charge, date: charge, day: dayNumber(charge)))
        self.steps = steps
    }

    /// When the first payment is taken.
    public var chargeDate: Date { steps.last?.date ?? .now }

    public var reminder: Step? { steps.first { $0.kind == .reminder } }
}
