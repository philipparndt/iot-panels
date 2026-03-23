import WidgetKit

enum WidgetHelper {
    static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
