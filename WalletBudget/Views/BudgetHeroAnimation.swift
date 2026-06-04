import SwiftUI

/// The welcome screen's animated hero: a living "budget orrery" drawn in white line art.
///
/// Three concentric orbit rings each carry a budget-gauge arc (rounded caps) whose sweep slowly
/// breathes, like categories filling toward their limits, with a coin dot leading each arc. They
/// orbit a gently pulsing dollar coin, inside a faint 12-tick dial (the months of the year).
/// Everything draws itself in over the first ~1.4 seconds.
///
/// Rendered with `TimelineView(.animation)` + `Canvas`, so it animates continuously at the
/// display's refresh rate with no third-party dependencies.
struct BudgetHeroAnimation: View {
    /// Reference time for the entrance (draw-in) phase.
    @State private var start = Date()

    /// Per-orbit configuration: radius as a fraction of the canvas, rotation speed in
    /// degrees/second (sign = direction), base arc sweep in degrees, breath depth in degrees,
    /// and breath speed in radians/second.
    private struct Orbit {
        let radiusFraction: CGFloat
        let rotationSpeed: Double
        let baseSweep: Double
        let breathDepth: Double
        let breathSpeed: Double
    }

    private static let orbits: [Orbit] = [
        Orbit(radiusFraction: 0.42, rotationSpeed: 9, baseSweep: 150, breathDepth: 40, breathSpeed: 0.45),
        Orbit(radiusFraction: 0.62, rotationSpeed: -6, baseSweep: 105, breathDepth: 30, breathSpeed: 0.33),
        Orbit(radiusFraction: 0.82, rotationSpeed: 4, baseSweep: 200, breathDepth: 55, breathSpeed: 0.24),
    ]

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                // Entrance progress, eased out: arcs sweep open and rings fade in.
                let entrance = easeOut(min(1, timeline.date.timeIntervalSince(start) / 1.4))
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let unit = min(size.width, size.height) / 2

                drawMonthTicks(context, center: center, radius: unit * 0.95, time: t, entrance: entrance)
                for orbit in Self.orbits {
                    drawOrbit(orbit, context, center: center, unit: unit, time: t, entrance: entrance)
                }
                drawDollarCoin(context, center: center, unit: unit, time: t, entrance: entrance)
            }
        }
        .onAppear { start = Date() }
        .accessibilityHidden(true)
    }

    /// Cubic ease-out for the entrance phase.
    private func easeOut(_ p: Double) -> Double { 1 - pow(1 - p, 3) }

    /// The faint outer dial: 12 tick marks (months) rotating almost imperceptibly.
    private func drawMonthTicks(_ context: GraphicsContext, center: CGPoint, radius: CGFloat,
                                time: Double, entrance: Double) {
        let rotation = Angle.degrees(time * 1.2).radians
        for tick in 0..<12 {
            let angle = Double(tick) / 12 * 2 * .pi + rotation
            let inner = point(center, radius - 5, angle)
            let outer = point(center, radius + 5, angle)
            var path = Path()
            path.move(to: inner)
            path.addLine(to: outer)
            context.stroke(path, with: .color(.white.opacity(0.22 * entrance)),
                           style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
    }

    /// One orbit: its faint guide ring, the bright breathing gauge arc, and the leading coin dot.
    private func drawOrbit(_ orbit: Orbit, _ context: GraphicsContext, center: CGPoint,
                           unit: CGFloat, time: Double, entrance: Double) {
        let radius = unit * orbit.radiusFraction

        let ring = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                          width: radius * 2, height: radius * 2))
        context.stroke(ring, with: .color(.white.opacity(0.22 * entrance)), lineWidth: 1)

        let startAngle = Angle.degrees(time * orbit.rotationSpeed)
        let sweep = (orbit.baseSweep + sin(time * orbit.breathSpeed) * orbit.breathDepth) * entrance
        let endAngle = startAngle + .degrees(sweep)
        var arc = Path()
        arc.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle,
                   clockwise: false)
        context.stroke(arc, with: .color(.white.opacity(0.95)),
                       style: StrokeStyle(lineWidth: 4.5, lineCap: .round))

        // Leading coin: a soft halo under a solid dot at the arc's head.
        let head = point(center, radius, endAngle.radians)
        let halo = Path(ellipseIn: CGRect(x: head.x - 9, y: head.y - 9, width: 18, height: 18))
        context.fill(halo, with: .color(.white.opacity(0.3 * entrance)))
        let dot = Path(ellipseIn: CGRect(x: head.x - 4.5, y: head.y - 4.5, width: 9, height: 9))
        context.fill(dot, with: .color(.white.opacity(entrance)))
    }

    /// The pulsing dollar coin at the center of the orrery.
    private func drawDollarCoin(_ context: GraphicsContext, center: CGPoint, unit: CGFloat,
                                time: Double, entrance: Double) {
        let pulse = 1 + 0.05 * sin(time * 1.6)
        let radius = unit * 0.2 * pulse * entrance
        let coin = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                          width: radius * 2, height: radius * 2))
        context.stroke(coin, with: .color(.white.opacity(0.95)), lineWidth: 2)
        context.draw(
            Text("$").font(.system(size: unit * 0.22 * pulse, weight: .semibold))
                .foregroundStyle(.white.opacity(entrance)),
            at: center
        )
    }

    /// Point on a circle of `radius` around `center` at `angle` radians.
    private func point(_ center: CGPoint, _ radius: CGFloat, _ angle: Double) -> CGPoint {
        CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
    }
}

#Preview {
    ZStack {
        Color.brandBlue.ignoresSafeArea()
        BudgetHeroAnimation()
            .frame(width: 320, height: 320)
    }
}
