import SwiftUI

struct CircularProgressView: View {
    let progress: Double
    var trackColor: Color = Color(uiColor: .systemGray4)
    var progressColor: Color = .blue
    var lineWidth: CGFloat = 3
    var size: CGFloat? = 32
    var lineCap: CGLineCap = .round
    var animation: Animation? = .easeOut

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    trackColor,
                    lineWidth: lineWidth
                )
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0.0), 1.0)))
                .stroke(
                    progressColor,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: lineCap
                    )
                )
                .rotationEffect(Angle(degrees: -90))
                .animation(animation, value: progress)
        }
        .frame(width: size, height: size)
    }
}
