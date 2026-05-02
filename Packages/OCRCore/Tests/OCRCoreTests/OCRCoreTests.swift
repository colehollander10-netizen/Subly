import Testing
import OCRCore

#if os(iOS) && canImport(UIKit) && canImport(Vision)
import UIKit
#endif

struct OCRCoreTests {
    @Test
    func publicErrorCasesAreAvailable() {
        let invalidImage: TrialOCRError = .invalidImage

        #expect(String(describing: invalidImage) == "invalidImage")
    }

    #if os(iOS) && canImport(UIKit) && canImport(Vision)
    @Test
    func iOSRecognitionAPISurfaceIsAvailable() {
        let recognize: (UIImage) async throws -> String = TrialOCRService.recognize(from:)

        #expect(MemoryLayout.size(ofValue: recognize) > 0)
    }
    #endif
}
