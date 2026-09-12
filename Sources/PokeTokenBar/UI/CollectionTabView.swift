import SwiftUI

/// Collection root: Bag | Dex | Shop. Dex is the default segment.
@MainActor
struct CollectionTabView: View {
    let store: CompanionStore
    let navigation: PopoverNavigation

    private var l: L { store.l }

    var body: some View {
        @Bindable var nav = navigation
        VStack(alignment: .leading, spacing: 8) {
            Picker("", selection: $nav.collectionSegment) {
                Text(l.bag).tag(CollectionSegment.bag)
                Text(l.dexSegment).tag(CollectionSegment.dex)
                Text(l.shop).tag(CollectionSegment.shop)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Group {
                switch nav.collectionSegment {
                case .bag:
                    BagView(store: store, nav: navigation)
                case .dex:
                    CollectionView(store: store, navigation: navigation)
                case .shop:
                    ShopView(store: store, nav: navigation)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 520, alignment: .top)
        }
    }
}
