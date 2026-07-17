import SwiftUI
import UIKit

// 1. The UIKit View
class ConfettiUIView: UIView {
    private let emitter = CAEmitterLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupEmitter()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupEmitter()
    }
    
    private func setupEmitter() {
        backgroundColor = .clear
        isUserInteractionEnabled = false
        
        // Ensure the emitter is running as soon as it's created
        emitter.birthRate = 1.0
        
        let colors: [UIColor] = [
            .systemRed, .systemBlue, .systemGreen, .systemYellow,
            .systemOrange, .systemPurple, .systemPink, .systemTeal
        ]
        
        var cells: [CAEmitterCell] = []
        for color in colors {
            let cell = CAEmitterCell()
            
            // Increased birth rate for a denser, more explosive burst
            cell.birthRate = 15.0
            
            cell.lifetime = 10.0
            
            // Much higher velocity to shoot outwards initially
            cell.velocity = CGFloat.random(in: 400...700)
            cell.velocityRange = 200
            
            // Gravity remains the same, it will pull the particles down after they shoot out
            cell.yAcceleration = 300 
            
            // 360-degree burst spread
            cell.emissionRange = .pi * 2
            
            cell.spin = CGFloat.random(in: 3...6)
            cell.spinRange = 3
            cell.scale = 1.0
            cell.scaleRange = 0.3
            cell.color = color.cgColor
            
            let size = CGSize(width: 10, height: 6)
            let image = UIGraphicsImageRenderer(size: size).image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
            }
            cell.contents = image.cgImage
            
            cells.append(cell)
        }
        
        emitter.emitterCells = cells
        layer.addSublayer(emitter)
        
        // Stop emitting new particles after a very short time to create a sharp burst
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(0.2))
            self?.emitter.birthRate = 0
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // 1. Position the emitter in the exact center of the view
        emitter.emitterPosition = CGPoint(x: bounds.width / 2, y: bounds.height / 6)
        
        // 2. Change shape to point so it originates from a single central spot
        emitter.emitterShape = .point
        emitter.frame = bounds
    }
}

// 2. The SwiftUI Wrapper
struct ConfettiView: UIViewRepresentable {
    var onCompletion: @MainActor @Sendable () -> Void

    func makeUIView(context: Context) -> ConfettiUIView {
        let view = ConfettiUIView()
        
        // Trigger completion callback after 5.0 seconds when particles have finished falling
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5.0))
            onCompletion()
        }
        
        return view
    }
    
    func updateUIView(_ uiView: ConfettiUIView, context: Context) {
        // No updates needed, it runs itself on creation
    }
}