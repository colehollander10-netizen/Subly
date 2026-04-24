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

    @Test("only nervous + hunting have emotional beat loops")
    func onlyExpectedStatesHaveBeats() {
        for state in FoxState.allCases {
            switch state {
            case .nervous, .hunting:
                #expect(state.hasEmotionalBeat == true)
            default:
                #expect(state.hasEmotionalBeat == false)
            }
        }
    }

    @Test("FoxState raw values remain stable (no silent renames)")
    func rawValuesStable() {
        #expect(FoxState.sleeping.rawValue == "sleeping")
        #expect(FoxState.sitting.rawValue == "sitting")
        #expect(FoxState.watching.rawValue == "watching")
        #expect(FoxState.nervous.rawValue == "nervous")
        #expect(FoxState.hunting.rawValue == "hunting")
        #expect(FoxState.celebrating.rawValue == "celebrating")
        #expect(FoxState.proud.rawValue == "proud")
    }
}
