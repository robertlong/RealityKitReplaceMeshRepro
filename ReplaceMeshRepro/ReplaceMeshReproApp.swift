import SwiftUI
import RealityKit

@main
struct ReplaceMeshReproApp: App {
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissWindow) var dismissWindow
    
    init() {
        DynamicMeshComponent.registerComponent()
        DynamicMeshSystem.registerSystem()
    }

    var body: some SwiftUI.Scene {
        WindowGroup(id: "Window") {
            VStack {
                Button("Show ImmersiveSpace") {
                    Task {
                        await openImmersiveSpace(id: "ImmersiveSpace")
                        dismissWindow(id: "Window")
                    }
                }
            }
        }

        ImmersiveSpace(id: "ImmersiveSpace") {
            RealityView { content in
                let entity = ModelEntity(mesh: .generateBox(size: 1.0), materials: [PhysicallyBasedMaterial()])
                entity.components.set(DynamicMeshComponent())
                entity.transform.translation = [0, 1, -2]
                content.add(entity)
            }
        }
    }
}

class DynamicMeshComponent: Component {}

class DynamicMeshSystem: System {
    
    static let query = EntityQuery(where: .has(DynamicMeshComponent.self))
    
    // Modify to increase mesh complexity
    static let divisions = 50
    
    var descriptor = MeshDescriptor()
    var positions: [SIMD3<Float>]
    var normals: [SIMD3<Float>]
    var indices: [UInt32]

    required init(scene: RealityKit.Scene) {
        positions = Array(repeating: SIMD3<Float>(), count: (Self.divisions + 1) * (Self.divisions + 1))
        normals = Array(repeating: SIMD3<Float>(), count: (Self.divisions + 1) * (Self.divisions + 1))
        indices = Array(repeating: 0, count: Self.divisions * Self.divisions * 6)
    }
    
    func update(context: SceneUpdateContext) {
        for entity in context.scene.performQuery(Self.query) {
            guard let model = entity.components[ModelComponent.self] else { continue }
            
            let time = CACurrentMediaTime()
            
            let radius = Float((sin(time) + 1.0) / 2.0)
            
            for i in 0...Self.divisions {
                let latitude = Float(i) * Float.pi / Float(Self.divisions)
                let y = radius * cos(latitude)
                let r = radius * sin(latitude)
                
                for j in 0...Self.divisions {
                    let longitude = Float(j) * 2 * Float.pi / Float(Self.divisions)
                    let x = r * sin(longitude)
                    let z = r * cos(longitude)
                    let position = SIMD3<Float>(x, y, z)
                    
                    let index = i * (Self.divisions + 1) + j
                    positions[index] = position
                    normals[index] = normalize(position)
                }
            }
            
            for i in 0..<Self.divisions {
                for j in 0..<Self.divisions {
                    let indexOffset = i * Self.divisions * 6 + j * 6
                    let first = i * (Self.divisions + 1) + j
                    let second = first + Self.divisions + 1
                    
                    indices[indexOffset] = UInt32(first)
                    indices[indexOffset + 1] = UInt32(second)
                    indices[indexOffset + 2] = UInt32(first + 1)
                    
                    indices[indexOffset + 3] = UInt32(second)
                    indices[indexOffset + 4] = UInt32(second + 1)
                    indices[indexOffset + 5] = UInt32(first + 1)
                }
            }
            
            descriptor.positions = MeshBuffer(positions)
            descriptor.normals = MeshBuffer(normals)
            descriptor.primitives = .triangles(indices)
            
            let mesh = try! MeshResource.generate(from: [descriptor])
            
            try! model.mesh.replace(with: mesh.contents)
        }
    }
}
