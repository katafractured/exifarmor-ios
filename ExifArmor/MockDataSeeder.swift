import Foundation

/// Mock data seeder for screenshot mode (--screenshots launch argument).
/// Provides sample photos with EXIF metadata for UI testing.
struct MockDataSeeder {
    static func seedDataIfNeeded() {
        guard CommandLine.arguments.contains("--screenshots") else { return }
        
        // TODO: Tek wires this to real model.
        // Minimal fixture: seed sample photo URLs or mock PHAsset references.
        // Current: placeholder print.
        print("MockDataSeeder: TODO — wire to real ExifArmor photo model")
    }
}
