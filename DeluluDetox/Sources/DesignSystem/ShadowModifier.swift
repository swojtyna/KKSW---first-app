import SwiftUI

struct ShadowModifier: ViewModifier {
    let shadow: Theme.Shadow

    init(_ shadow: Theme.Shadow) {
        self.shadow = shadow
    }

    func body(content: Content) -> some View {
        content.shadow(
            color: shadow.color,
            radius: shadow.radius,
            x: shadow.x,
            y: shadow.y
        )
    }
}

extension View {
    func dduShadow(_ shadow: Theme.Shadow) -> some View {
        modifier(ShadowModifier(shadow))
    }
}
