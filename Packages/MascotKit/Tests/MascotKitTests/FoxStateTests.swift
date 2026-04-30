import Testing
@testable import MascotKit

@Suite("FoxState")
struct FoxStateTests {
    @Test("every state exposes a non-empty asset name")
    func everyStateHasAssetName() {
        for state in FoxState.allCases {
            #expect(!state.assetName.isEmpty)
        }
    }

    @Test("every state exposes a non-empty accessibility label")
    func everyStateHasAccessibilityLabel() {
        for state in FoxState.allCases {
            #expect(!state.accessibilityLabel.isEmpty)
        }
    }

    @Test("v1 moods do not have emotional beat loops")
    func v1MoodsAreStatic() {
        for state in FoxState.allCases {
            #expect(state.hasEmotionalBeat == false)
        }
    }

    @Test("FoxState raw values remain stable (no silent renames)")
    func rawValuesStable() {
        #expect(FoxState.sleeping.rawValue == "sleeping")
        #expect(FoxState.neutral.rawValue == "neutral")
        #expect(FoxState.concerned.rawValue == "concerned")
    }
}
