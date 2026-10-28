import SwiftUI

public struct SleepingMacIconView: View {
    public var size: CGFloat = 34

    public init(size: CGFloat = 34) {
        self.size = size
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.indigo, Color(red: 0.14, green: 0.16, blue: 0.36)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: .indigo.opacity(0.35), radius: 4, y: 2)

            VStack(spacing: size * 0.04) {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.08)
                        .stroke(Color.cyan.opacity(0.9), lineWidth: max(1.5, size * 0.055))
                        .frame(width: size * 0.56, height: size * 0.38)

                    // Closed sleeping eyes (-  -)
                    HStack(spacing: size * 0.10) {
                        Capsule()
                            .fill(Color.cyan)
                            .frame(width: size * 0.11, height: max(1.5, size * 0.045))
                        Capsule()
                            .fill(Color.cyan)
                            .frame(width: size * 0.11, height: max(1.5, size * 0.045))
                    }
                }
                // MacBook base lip
                Capsule()
                    .fill(Color.cyan.opacity(0.95))
                    .frame(width: size * 0.68, height: max(2.0, size * 0.065))
            }
            .frame(width: size, height: size)
            .offset(y: size * 0.06)

            // Floating "Zzz" badge
            Text("Zzz")
                .font(.system(size: size * 0.25, weight: .heavy, design: .rounded))
                .foregroundStyle(.yellow)
                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                .offset(x: -size * 0.06, y: size * 0.04)
        }
    }
}

