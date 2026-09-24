import SwiftUI

struct BatteryDetail: View {
    var instance: WidgetInstance
    var context: WidgetContext

    var body: some View {
        Text("BatteryDetail")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
    }
}
