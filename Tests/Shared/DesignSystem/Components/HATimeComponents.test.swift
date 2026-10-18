@testable import HADesignSystem
import Testing

/// `ha-duration-input`'s `_durationChanged` carries overflow between the boxes, and does it
/// unevenly — the asymmetries below are the frontend's, not oversights, so each one is pinned.
struct HATimeComponentsTests {
    @Test func millisecondsCarryIntoSeconds() {
        let result = HATimeComponents(milliseconds: 1500).normalized(enableSecond: true)
        #expect(result.seconds == 1)
        #expect(result.milliseconds == 500)
    }

    /// The millisecond carry is the one that is unconditional: the frontend only skips it when the
    /// box is hidden *and* the value is already zero, so a hidden box still carries. Note the
    /// seconds it produces stay put here, because the second carry is guarded and off.
    @Test func millisecondsCarryEvenWithOtherCarriesOff() {
        let result = HATimeComponents(milliseconds: 2500).normalized(enableSecond: false)
        #expect(result.seconds == 2)
        #expect(result.milliseconds == 500)
    }

    @Test func secondsCarryIntoMinutesWhenShown() {
        let result = HATimeComponents(seconds: 90).normalized(enableSecond: true)
        #expect(result.minutes == 1)
        #expect(result.seconds == 30)
    }

    /// Unlike milliseconds, the second carry is guarded on the box being shown. With it hidden the
    /// value is left exactly as typed.
    @Test func secondsDoNotCarryWhenTheBoxIsHidden() {
        let result = HATimeComponents(seconds: 90).normalized(enableSecond: false)
        #expect(result.minutes == 0)
        #expect(result.seconds == 90)
    }

    @Test func minutesAlwaysCarryIntoHours() {
        let result = HATimeComponents(minutes: 130).normalized()
        #expect(result.hours == 2)
        #expect(result.minutes == 10)
    }

    @Test func hoursCarryIntoDaysWhenShown() {
        let result = HATimeComponents(hours: 25).normalized(enableDay: true)
        #expect(result.days == 1)
        #expect(result.hours == 1)
    }

    /// The frontend's guard is `hours > 24`, not `>= 24`, so a flat day's worth stays spelled as
    /// 24 hours rather than collapsing to "1d 0h".
    @Test func exactlyTwentyFourHoursDoesNotCarry() {
        let result = HATimeComponents(hours: 24).normalized(enableDay: true)
        #expect(result.days == 0)
        #expect(result.hours == 24)
    }

    @Test func hoursDoNotCarryWhenTheDayBoxIsHidden() {
        let result = HATimeComponents(hours: 40).normalized(enableDay: false)
        #expect(result.days == 0)
        #expect(result.hours == 40)
    }

    /// Carries run smallest unit first, so one edit ripples the whole way up: the 2000ms becomes
    /// 2s, which tips 59s past the minute, which tips 59m past the hour, which tips 24h past a day.
    /// Starting an hour lower would stop at 24h, since the day carry needs to *exceed* 24.
    @Test func carriesCascadeFromMillisecondsToDays() {
        let result = HATimeComponents(days: 0, hours: 24, minutes: 59, seconds: 59, milliseconds: 2000)
            .normalized(enableDay: true, enableSecond: true)
        #expect(result.days == 1)
        #expect(result.hours == 1)
        #expect(result.minutes == 0)
        #expect(result.seconds == 1)
        #expect(result.milliseconds == 0)
    }

    @Test func negativeAppliesToEverySegment() {
        let result = HATimeComponents(hours: 1, minutes: 30).normalized(negative: true)
        #expect(result.hours == -1)
        #expect(result.minutes == -30)
        #expect(result.seconds == 0)
    }

    /// The boxes always hold magnitudes; the sign lives on the toggle. Feeding a negative value
    /// back in has to land on the same magnitudes rather than double-negating.
    @Test func magnitudesAreTakenBeforeCarrying() {
        let result = HATimeComponents(hours: -1, minutes: -90).normalized()
        #expect(result.hours == 2)
        #expect(result.minutes == 30)
    }
}
