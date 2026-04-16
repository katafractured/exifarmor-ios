import XCTest
import ImageIO
@testable import ExifArmor

/// Tests for StripService — metadata removal from image data.
final class StripServiceTests: XCTestCase {

    // MARK: - Helpers

    /// Create test image data with full metadata.
    private func makeFullMetadataImage() -> Data {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.green.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }

        guard let baseData = image.jpegData(compressionQuality: 0.9),
              let source = CGImageSourceCreateWithData(baseData as CFData, nil),
              let uti = CGImageSourceGetType(source)
        else { return Data() }

        let properties: [String: Any] = [
            kCGImagePropertyGPSDictionary as String: [
                kCGImagePropertyGPSLatitude as String: 37.7749,
                kCGImagePropertyGPSLatitudeRef as String: "N",
                kCGImagePropertyGPSLongitude as String: 122.4194,
                kCGImagePropertyGPSLongitudeRef as String: "W",
                kCGImagePropertyGPSAltitude as String: 15.0,
            ],
            kCGImagePropertyTIFFDictionary as String: [
                kCGImagePropertyTIFFMake as String: "Apple",
                kCGImagePropertyTIFFModel as String: "iPhone 15 Pro",
                kCGImagePropertyTIFFSoftware as String: "17.4.1",
                kCGImagePropertyTIFFOrientation as String: 1,
            ],
            kCGImagePropertyExifDictionary as String: [
                kCGImagePropertyExifDateTimeOriginal as String: "2024:06:15 10:30:00",
                kCGImagePropertyExifDateTimeDigitized as String: "2024:06:15 10:30:00",
                kCGImagePropertyExifFocalLength as String: 6.765,
                kCGImagePropertyExifFNumber as String: 1.78,
                kCGImagePropertyExifExposureTime as String: 0.004,
                kCGImagePropertyExifISOSpeedRatings as String: [50],
                kCGImagePropertyExifLensModel as String: "iPhone 15 Pro back camera",
            ],
        ]

        let destData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(destData as CFMutableData, uti, 1, nil) else {
            return Data()
        }
        CGImageDestinationAddImageFromSource(dest, source, 0, properties as CFDictionary)
        CGImageDestinationFinalize(dest)
        return destData as Data
    }

    /// Read back metadata properties from image data.
    private func readProperties(from data: Data) -> [String: Any]? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
    }

    // MARK: - Strip All Tests

    func testStripAllRemovesGPS() {
        let original = makeFullMetadataImage()
        guard let stripped = StripService.stripMetadata(from: original, options: .all) else {
            XCTFail("Strip returned nil")
            return
        }

        let props = readProperties(from: stripped)
        XCTAssertNil(props?[kCGImagePropertyGPSDictionary as String],
                     "GPS dictionary should be completely removed")
    }

    func testStripAllRemovesEXIF() {
        let original = makeFullMetadataImage()
        guard let stripped = StripService.stripMetadata(from: original, options: .all) else {
            XCTFail("Strip returned nil")
            return
        }

        let props = readProperties(from: stripped)
        XCTAssertNil(props?[kCGImagePropertyExifDictionary as String],
                     "EXIF dictionary should be completely removed")
    }

    func testStripAllRemovesDeviceFromTIFF() {
        let original = makeFullMetadataImage()
        guard let stripped = StripService.stripMetadata(from: original, options: .all) else {
            XCTFail("Strip returned nil")
            return
        }

        let props = readProperties(from: stripped)
        if let tiff = props?[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            XCTAssertNil(tiff[kCGImagePropertyTIFFMake as String], "Make should be removed")
            XCTAssertNil(tiff[kCGImagePropertyTIFFModel as String], "Model should be removed")
            XCTAssertNil(tiff[kCGImagePropertyTIFFSoftware as String], "Software should be removed")
        }
    }

    func testStripAllPreservesOrientation() {
        let original = makeFullMetadataImage()
        guard let stripped = StripService.stripMetadata(from: original, options: .all) else {
            XCTFail("Strip returned nil")
            return
        }

        let props = readProperties(from: stripped)
        if let tiff = props?[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            XCTAssertNotNil(tiff[kCGImagePropertyTIFFOrientation as String],
                           "Orientation should be preserved even in strip-all mode")
        }
    }

    func testStripAllProducesValidImage() {
        let original = makeFullMetadataImage()
        guard let stripped = StripService.stripMetadata(from: original, options: .all) else {
            XCTFail("Strip returned nil")
            return
        }

        // Verify it's still a valid image
        let image = UIImage(data: stripped)
        XCTAssertNotNil(image, "Stripped data should produce a valid UIImage")
        XCTAssertEqual(image?.size.width, CGFloat(100), accuracy: 1.0)
        XCTAssertEqual(image?.size.height, CGFloat(100), accuracy: 1.0)
    }

    func testStripAllDoesNotIncreaseFileSize() {
        let original = makeFullMetadataImage()
        guard let stripped = StripService.stripMetadata(from: original, options: .all) else {
            XCTFail("Strip returned nil")
            return
        }

        // Stripped should be smaller or roughly equal (less metadata)
        XCTAssertLessThanOrEqual(stripped.count, original.count + 100,
                                 "Stripped file should not be significantly larger")
    }

    // MARK: - Location Only Tests

    func testStripLocationOnlyRemovesGPS() {
        let original = makeFullMetadataImage()
        guard let stripped = StripService.stripMetadata(from: original, options: .locationOnly) else {
            XCTFail("Strip returned nil")
            return
        }

        let props = readProperties(from: stripped)
        XCTAssertNil(props?[kCGImagePropertyGPSDictionary as String],
                     "GPS should be removed in location-only mode")
    }

    func testStripLocationOnlyKeepsEXIF() {
        let original = makeFullMetadataImage()
        guard let stripped = StripService.stripMetadata(from: original, options: .locationOnly) else {
            XCTFail("Strip returned nil")
            return
        }

        let props = readProperties(from: stripped)
        let exif = props?[kCGImagePropertyExifDictionary as String] as? [String: Any]
        XCTAssertNotNil(exif, "EXIF should still exist in location-only mode")
        XCTAssertNotNil(exif?[kCGImagePropertyExifFocalLength as String],
                       "Camera settings should be preserved")
    }

    func testStripLocationOnlyKeepsDeviceInfo() {
        let original = makeFullMetadataImage()
        guard let stripped = StripService.stripMetadata(from: original, options: .locationOnly) else {
            XCTFail("Strip returned nil")
            return
        }

        let props = readProperties(from: stripped)
        let tiff = props?[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        XCTAssertNotNil(tiff?[kCGImagePropertyTIFFMake as String],
                       "Device make should be preserved in location-only mode")
    }

    // MARK: - Privacy Focused Tests

    func testStripPrivacyFocusedRemovesLocationAndDevice() {
        let original = makeFullMetadataImage()
        guard let stripped = StripService.stripMetadata(from: original, options: .privacyFocused) else {
            XCTFail("Strip returned nil")
            return
        }

        let props = readProperties(from: stripped)

        // GPS removed
        XCTAssertNil(props?[kCGImagePropertyGPSDictionary as String])

        // Device info removed from TIFF
        if let tiff = props?[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            XCTAssertNil(tiff[kCGImagePropertyTIFFMake as String])
            XCTAssertNil(tiff[kCGImagePropertyTIFFModel as String])
            XCTAssertNil(tiff[kCGImagePropertyTIFFSoftware as String])
        }

        // DateTime removed from EXIF
        if let exif = props?[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            XCTAssertNil(exif[kCGImagePropertyExifDateTimeOriginal as String])

            // Camera settings should still exist
            XCTAssertNotNil(exif[kCGImagePropertyExifFocalLength as String],
                           "Camera settings should be preserved in privacy-focused mode")
        }
    }

    // MARK: - Custom Options Tests

    func testCustomStripDateTimeOnly() {
        let options = StripOptions(
            removeLocation: false,
            removeDateTime: true,
            removeDeviceInfo: false,
            removeCameraSettings: false,
            removeAll: false
        )

        let original = makeFullMetadataImage()
        guard let stripped = StripService.stripMetadata(from: original, options: options) else {
            XCTFail("Strip returned nil")
            return
        }

        let props = readProperties(from: stripped)

        // GPS should still exist
        XCTAssertNotNil(props?[kCGImagePropertyGPSDictionary as String],
                       "GPS should be preserved when not selected for removal")

        // DateTime should be removed
        if let exif = props?[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            XCTAssertNil(exif[kCGImagePropertyExifDateTimeOriginal as String],
                        "DateTime should be removed")
            XCTAssertNil(exif[kCGImagePropertyExifDateTimeDigitized as String],
                        "DateTimeDigitized should be removed")
        }
    }

    func testCustomStripCameraSettingsOnly() {
        let options = StripOptions(
            removeLocation: false,
            removeDateTime: false,
            removeDeviceInfo: false,
            removeCameraSettings: true,
            removeAll: false
        )

        let original = makeFullMetadataImage()
        guard let stripped = StripService.stripMetadata(from: original, options: options) else {
            XCTFail("Strip returned nil")
            return
        }

        let props = readProperties(from: stripped)

        if let exif = props?[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            XCTAssertNil(exif[kCGImagePropertyExifFocalLength as String])
            XCTAssertNil(exif[kCGImagePropertyExifFNumber as String])
            XCTAssertNil(exif[kCGImagePropertyExifExposureTime as String])
            XCTAssertNil(exif[kCGImagePropertyExifISOSpeedRatings as String])
            XCTAssertNil(exif[kCGImagePropertyExifLensModel as String])

            // DateTime should still exist
            XCTAssertNotNil(exif[kCGImagePropertyExifDateTimeOriginal as String],
                           "DateTime should be preserved when camera-only strip")
        }
    }

    // MARK: - Field Count Tests

    func testCountFieldsToRemoveAll() {
        let data = makeFullMetadataImage()
        let image = UIImage(data: data)!
        let meta = MetadataService.extractMetadata(from: data, image: image)

        let count = StripService.countFieldsToRemove(from: meta, options: .all)
        XCTAssertEqual(count, meta.exposedFieldCount,
                      "Strip-all should count all exposed fields")
    }

    func testCountFieldsToRemoveLocationOnly() {
        let data = makeFullMetadataImage()
        let image = UIImage(data: data)!
        let meta = MetadataService.extractMetadata(from: data, image: image)

        let count = StripService.countFieldsToRemove(from: meta, options: .locationOnly)
        // GPS coordinate (1) + altitude (1) = 2
        XCTAssertEqual(count, 2, "Location-only should count GPS + altitude")
    }

    // MARK: - Edge Cases

    func testStripFromPNGData() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 50, height: 50))
        let image = renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 50, height: 50))
        }
        let pngData = image.pngData()!

        let stripped = StripService.stripMetadata(from: pngData, options: .all)
        XCTAssertNotNil(stripped, "Should handle PNG data without crashing")

        if let stripped {
            let resultImage = UIImage(data: stripped)
            XCTAssertNotNil(resultImage, "Stripped PNG should still be valid")
        }
    }

    func testStripFromEmptyDataReturnsNil() {
        let result = StripService.stripMetadata(from: Data(), options: .all)
        XCTAssertNil(result, "Empty data should return nil, not crash")
    }

    func testStripFromGarbageDataReturnsNil() {
        let garbage = Data(repeating: 0xFF, count: 100)
        let result = StripService.stripMetadata(from: garbage, options: .all)
        XCTAssertNil(result, "Garbage data should return nil, not crash")
    }

    func testStripIsIdempotent() {
        let original = makeFullMetadataImage()

        guard let firstStrip = StripService.stripMetadata(from: original, options: .all),
              let secondStrip = StripService.stripMetadata(from: firstStrip, options: .all)
        else {
            XCTFail("Strip returned nil")
            return
        }

        // Second strip should produce valid image with same (no) metadata
        let image = UIImage(data: secondStrip)
        XCTAssertNotNil(image, "Double-stripped data should still be valid")

        let props = readProperties(from: secondStrip)
        XCTAssertNil(props?[kCGImagePropertyGPSDictionary as String])
        XCTAssertNil(props?[kCGImagePropertyExifDictionary as String])
    }

    func testOriginalDataIsNotMutated() {
        let original = makeFullMetadataImage()
        let originalCopy = Data(original) // Copy before strip

        _ = StripService.stripMetadata(from: original, options: .all)

        // Original data should be unchanged
        XCTAssertEqual(original, originalCopy,
                      "Strip must not mutate the input data")
    }
}
