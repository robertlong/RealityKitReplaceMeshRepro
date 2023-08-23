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

    required init(scene: RealityKit.Scene) {}
    
    func update(context: SceneUpdateContext) {
        for entity in context.scene.performQuery(Self.query) {
            guard let model = entity.components[ModelComponent.self] else { continue }
            
            let time = CACurrentMediaTime()
            
            let radius = Float((sin(time) + 1.0) / 2.0)
            let divisions = 10 // Modify to increase mesh complexity
            
            var descriptor = MeshDescriptor()
            
            var positions: [SIMD3<Float>] = []
            var normals: [SIMD3<Float>] = []
            var indices: [UInt32] = []
            
            for i in 0...divisions {
                let latitude = Float(i) * Float.pi / Float(divisions)
                let y = radius * cos(latitude)
                let r = radius * sin(latitude)
                
                for j in 0...divisions {
                    let longitude = Float(j) * 2 * Float.pi / Float(divisions)
                    let x = r * sin(longitude)
                    let z = r * cos(longitude)
                    
                    let position = SIMD3<Float>(x, y, z)
                    positions.append(position)
                    
                    let normal = normalize(position)
                    normals.append(normal)
                }
            }
            
            for i in 0..<divisions {
                for j in 0..<divisions {
                    let first = i * (divisions + 1) + j
                    let second = first + divisions + 1
                    
                    indices.append(UInt32(first))
                    indices.append(UInt32(second))
                    indices.append(UInt32(first + 1))
                    
                    indices.append(UInt32(second))
                    indices.append(UInt32(second + 1))
                    indices.append(UInt32(first + 1))
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
