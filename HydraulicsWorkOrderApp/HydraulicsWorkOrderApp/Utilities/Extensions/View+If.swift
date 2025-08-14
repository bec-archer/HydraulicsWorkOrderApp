//
//  View+If.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/14/25.
//


//
//  View+If.swift
//  HydraulicsWorkOrderApp
//
//  Created by Bec Archer on 8/14/25.
//

import SwiftUI

// ───── Conditionally apply a modifier when iOS 17+ is available ─────
public extension View {
    @ViewBuilder
    func ifIOS17<T: View>(_ transform: (Self) -> T) -> some View {
        if #available(iOS 17.0, *) {
            transform(self)
        } else {
            self
        }
    }
}
// ───── END ─────

#Preview {
    Text("ifIOS17 helper")
        .ifIOS17 { $0.toolbar(removing: .sidebarToggle) } // no-op on < iOS 17
}
