import CoreGraphics
import Foundation
import RealityKit
import simd

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Builds the framed painting as a real 3D object. (code.md §2, "How to build it in code")
///
/// The hierarchy:
/// ```
/// root
///  ├ backdrop          white wall, receives the shadow, does not tilt
///  ├ keyLight          upper left, casts the shadow
///  ├ fillLight         weak, front right, keeps the shadow side readable
///  ├ camera
///  └ frame             everything below here tilts with the gyroscope
///     ├ moulding ×4
///     ├ rebate         dark plate; its edge is the lip around the canvas
///     ├ canvas         the painting
///     └ glass          low-alpha specular sheen
/// ```
@MainActor
enum FramedArtworkScene {

    /// The subtree that tilts. Everything else in the scene stays put.
    static let frameName = "frame"

    static func makeRoot(for artwork: Artwork) async -> Entity {
        let geometry = artwork.geometry
        let root = Entity()

        let frame = Entity()
        frame.name = frameName
        for bar in makeMoulding(geometry, finish: artwork.finish) {
            frame.addChild(bar)
        }
        frame.addChild(makeRebate(geometry))
        frame.addChild(await makeCanvas(geometry, image: artwork.image))
        frame.addChild(makeGlass(geometry))

        // The frame's own origin is at the back face; shift it so it rotates about
        // its centre of volume, which is how a hanging object behaves.
        frame.position = [0, 0, -geometry.depth / 2]

        root.addChild(frame)
        root.addChild(makeBackdrop(geometry))
        root.addChild(makeKeyLight(geometry))
        root.addChild(makeFillLight())
        root.addChild(makeCamera(geometry))
        return root
    }

    // MARK: - Moulding

    /// Four bars, butt-jointed: top and bottom run the full outer width, the stiles
    /// fill between them. code.md offers mitred corners as the nicer option, but a
    /// true mitre needs a custom mesh — butt joints are a real frame joint and the
    /// seam is invisible at any sane viewing distance.
    private static func makeMoulding(
        _ geometry: FrameGeometry,
        finish: FrameFinish
    ) -> [ModelEntity] {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: finish.sceneTint)
        material.roughness = .init(floatLiteral: finish.roughness)
        material.metallic = .init(floatLiteral: 0)

        let railMesh = MeshResource.generateBox(
            width: geometry.outer.x,
            height: geometry.border,
            depth: geometry.depth
        )
        let stileMesh = MeshResource.generateBox(
            width: geometry.border,
            height: geometry.outer.y - 2 * geometry.border,
            depth: geometry.depth
        )

        let railOffset = (geometry.outer.y - geometry.border) / 2
        let stileOffset = (geometry.outer.x - geometry.border) / 2
        let z = geometry.mouldingZ

        let placements: [(MeshResource, SIMD3<Float>)] = [
            (railMesh, [0, railOffset, z]),
            (railMesh, [0, -railOffset, z]),
            (stileMesh, [-stileOffset, 0, z]),
            (stileMesh, [stileOffset, 0, z])
        ]

        return placements.map { mesh, position in
            let bar = ModelEntity(mesh: mesh, materials: [material])
            bar.position = position
            bar.components.set(GroundingShadowComponent(castsShadow: true))
            return bar
        }
    }

    // MARK: - Rebate lip

    /// code.md §2 puts a black plate at 0.42 opacity behind the canvas. Here it is
    /// opaque and simply unlit by the key light — the recess does the darkening,
    /// which is what the flat design was imitating.
    private static func makeRebate(_ geometry: FrameGeometry) -> ModelEntity {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: PlatformColor(white: 0.05, alpha: 1))
        material.roughness = .init(floatLiteral: 0.95)
        material.metallic = .init(floatLiteral: 0)

        let mesh = MeshResource.generateBox(
            width: geometry.rebate.x,
            height: geometry.rebate.y,
            depth: geometry.slabDepth
        )
        let plate = ModelEntity(mesh: mesh, materials: [material])
        plate.position = [0, 0, geometry.rebateZ]
        return plate
    }

    // MARK: - Canvas

    private static func makeCanvas(
        _ geometry: FrameGeometry,
        image: CGImage?
    ) async -> ModelEntity {
        var material = PhysicallyBasedMaterial()
        // Paint on canvas is matte and not remotely metallic. Getting this wrong is
        // the fastest way to make a painting look like a photograph of a screen.
        material.roughness = .init(floatLiteral: 0.85)
        material.metallic = .init(floatLiteral: 0)

        if let image,
           let texture = try? await TextureResource(
               image: image,
               options: .init(semantic: .color)
           ) {
            material.baseColor = .init(texture: .init(texture))
        } else {
            material.baseColor = .init(tint: PlatformColor(white: 0.92, alpha: 1))
        }

        let mesh = MeshResource.generateBox(
            width: geometry.artwork.x,
            height: geometry.artwork.y,
            depth: geometry.slabDepth
        )
        let canvas = ModelEntity(mesh: mesh, materials: [material])
        canvas.position = [0, 0, geometry.canvasZ]
        return canvas
    }

    // MARK: - Glass

    /// Barely there. The point is the highlight that sweeps across it as the frame
    /// tilts — at any opacity you can actually notice, it fights the painting.
    private static func makeGlass(_ geometry: FrameGeometry) -> ModelEntity {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: PlatformColor(white: 1, alpha: 1))
        material.roughness = .init(floatLiteral: 0.05)
        material.metallic = .init(floatLiteral: 0)
        material.blending = .transparent(opacity: .init(floatLiteral: 0.06))
        material.faceCulling = .back

        let mesh = MeshResource.generateBox(
            width: geometry.rebate.x,
            height: geometry.rebate.y,
            depth: geometry.slabDepth / 2
        )
        let glass = ModelEntity(mesh: mesh, materials: [material])
        glass.position = [0, 0, geometry.glassZ]
        return glass
    }

    // MARK: - Stage

    /// The wall. code.md §3 is emphatic that gallery white is not a flat fill, but a
    /// radial gradient that reads as lit — here the falloff comes from the lights
    /// rather than a painted gradient.
    private static func makeBackdrop(_ geometry: FrameGeometry) -> ModelEntity {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: PlatformColor(white: 0.97, alpha: 1))
        material.roughness = .init(floatLiteral: 0.9)
        material.metallic = .init(floatLiteral: 0)

        let span = max(geometry.outer.x, geometry.outer.y) * 6
        let mesh = MeshResource.generateBox(width: span, height: span, depth: 0.01)
        let wall = ModelEntity(mesh: mesh, materials: [material])
        // Far enough back that the cast shadow has room to spread and soften.
        wall.position = [0, 0, -geometry.depth * 4]
        return wall
    }

    /// Key light from the upper left, matching the 8, 14 offset of the design's key
    /// shadow. (code.md §2, "Wall shadow")
    private static func makeKeyLight(_ geometry: FrameGeometry) -> Entity {
        let light = Entity()
        light.components.set(DirectionalLightComponent(color: .white, intensity: 3_200))
        light.components.set(DirectionalLightComponent.Shadow())
        light.look(
            at: .zero,
            from: [-geometry.outer.x, geometry.outer.y * 1.2, geometry.outer.x * 1.6],
            relativeTo: nil
        )
        return light
    }

    /// Fill from the opposite side, no shadow. Without it the ambient layer of the
    /// design's three-shadow stack has no equivalent and the dark side goes flat.
    private static func makeFillLight() -> Entity {
        let light = Entity()
        light.components.set(DirectionalLightComponent(color: .white, intensity: 900))
        light.look(at: .zero, from: [1, -0.4, 1.4], relativeTo: nil)
        return light
    }

    private static func makeCamera(_ geometry: FrameGeometry) -> Entity {
        let camera = Entity()
        var component = PerspectiveCameraComponent()
        // Long-ish lens. A wide one splays the frame's thickness faces and makes a
        // 60 cm painting look like furniture.
        component.fieldOfViewInDegrees = 32
        camera.components.set(component)
        camera.look(at: .zero, from: [0, 0, geometry.cameraDistance], relativeTo: nil)
        return camera
    }
}
