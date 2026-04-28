import XCTest

@MainActor
class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--screenshots"]
        setupSnapshot(app)
        app.launch()
    }

    /// Home: gallery grid with sample photos
    func testHomeGallery() throws {
        let app = XCUIApplication()
        snapshot("01-home-gallery")
    }

    /// Photo detail: original EXIF visible
    func testPhotoDetail() throws {
        let app = XCUIApplication()
        snapshot("02-photo-detail")
    }

    /// EXIF stripping in progress
    func testStrippingProgress() throws {
        let app = XCUIApplication()
        snapshot("03-stripping-progress")
    }

    /// Stripped result: clean metadata, before/after toggle
    func testStrippedResult() throws {
        let app = XCUIApplication()
        snapshot("04-stripped-result")
    }

    /// Settings: privacy options
    func testSettings() throws {
        let app = XCUIApplication()
        snapshot("05-settings")
    }
}
