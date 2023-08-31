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
                entity.transform.translation = [0, 1, -2]
                entity.components.set(InputTargetComponent(allowedInputTypes: .all))
                entity.generateCollisionShapes(recursive: false)
                entity.components.set(DynamicMeshComponent())
                content.add(entity)
            }
            .gesture(TapGesture()
                .targetedToEntity(where: .has(DynamicMeshComponent.self))
                .onEnded { value in
                    switch DynamicMeshSystem.mode {
                    case .vertexDataOnly:
                        DynamicMeshSystem.mode = .generateOnly
                    case .generateOnly:
                        DynamicMeshSystem.mode = .generateAndReplace
                    case .generateAndReplace:
                        DynamicMeshSystem.mode = .generateAndReplaceAsync
                    case .generateAndReplaceAsync:
                        DynamicMeshSystem.mode = .vertexDataOnly
                    }
                    
                    print("DynamicMeshSystemMode \(DynamicMeshSystem.mode)")
                })
        }
    }
}

class DynamicMeshComponent: Component {}

class DynamicMeshSystem: System {
    enum Mode {
        case vertexDataOnly, generateOnly, generateAndReplace, generateAndReplaceAsync
    }
    
    static let query = EntityQuery(where: .has(DynamicMeshComponent.self))
    
    // Modify to increase mesh complexity
    static let divisions = 50
    static var mode: Mode = .vertexDataOnly
    
    var descriptor = MeshDescriptor()
    var positions: [SIMD3<Float>]
    var normals: [SIMD3<Float>]
    var indices: [UInt32]
    var mesh: MeshResource?

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
            
            // Rather than constructing new MeshBuffers every frame and generating a new MeshResource
            // it would be nice to mutate an existing MeshBuffer as you would with a lower level
            // graphics API
            descriptor.positions = MeshBuffer(positions)
            descriptor.normals = MeshBuffer(normals)
            descriptor.primitives = .triangles(indices)
            
            switch Self.mode {
            case .vertexDataOnly:
                return
            case .generateOnly:
                // Just generate a new mesh without replacing the current mesh
                // This narrows down the overhead of dynamic meshes to the .generate function
                mesh = try! MeshResource.generate(from: [descriptor])
            case .generateAndReplace:
                // Generate and replace the current mesh
                let mesh = try! MeshResource.generate(from: [descriptor])
                try! model.mesh.replace(with: mesh.contents)
            case .generateAndReplaceAsync:
                Task {
                    // Generate and replace the current mesh
                    let mesh = try! await MeshResource(from: [descriptor])
                    try! await model.mesh.replace(with: mesh.contents)
                }
            }
        }
    }
}
