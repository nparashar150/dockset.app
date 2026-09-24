import SwiftUI

/// Routes a widget to its own detail content.
///
/// One switch rather than a protocol with two dozen conformances: the bodies
/// have nothing in common beyond being a view, and the chrome around them is
/// already shared by `WidgetDetailChrome`.
struct WidgetDetailBody: View {
    var instance: WidgetInstance
    var context: WidgetContext

    var body: some View {
        switch instance.kind {
        case .music:
            MusicDetail(instance: instance, context: context)
        case .timer:
            FocusTimerDetail(instance: instance, context: context)
        case .calendar:
            CalendarDetail(instance: instance, context: context)
        case .battery:
            BatteryDetail(instance: instance, context: context)
        case .system:
            SystemActivityDetail(instance: instance, context: context)
        case .notes:
            StickyNoteDetail(instance: instance, context: context)
        case .stripe, .paddle, .shopify:
            RevenueDetail(instance: instance, context: context)
        case .stock, .watchlist:
            StocksDetail(instance: instance, context: context)
        default:
            // A widget with nothing more to say than its tile already shows.
            // Better an honest line than a panel padded out with filler.
            Text("No further detail for this widget.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
