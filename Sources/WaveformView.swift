import AppKit

class WaveformView: NSView {
    private let barCount = 18 // More bars for a smoother look
    private var barLayers: [CALayer] = []
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupBars()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupBars() {
        self.wantsLayer = true
        let spacing: CGFloat = 2.5
        let width: CGFloat = 2.5
        let totalWidth = CGFloat(barCount) * width + CGFloat(barCount - 1) * spacing
        let startX = (self.bounds.width - totalWidth) / 2
        
        for i in 0..<barCount {
            let layer = CALayer()
            // Professional Look: Slight transparency and white color
            layer.backgroundColor = NSColor.white.withAlphaComponent(0.9).cgColor
            layer.cornerRadius = width / 2
            
            // Fading edges for a professional aesthetic
            let distanceFromCenter = abs(CGFloat(i) - CGFloat(barCount-1)/2.0)
            let normalizedDistance = distanceFromCenter / (CGFloat(barCount)/2.0)
            layer.opacity = Float(1.0 - (normalizedDistance * 0.6))
            
            let x = startX + CGFloat(i) * (width + spacing)
            layer.frame = CGRect(x: x, y: self.bounds.height / 2, width: width, height: 2)
            self.layer?.addSublayer(layer)
            barLayers.append(layer)
        }
    }
    
    func update(level: Float) {
        let timestamp = CACurrentMediaTime()
        for (index, layer) in barLayers.enumerated() {
            // Level is 0.0 to 1.0
            // Apply a sine wave based on index and time for a "fluid" feel
            let waveOffset = sin(timestamp * 10 + Double(index) * 0.5) * 0.1
            let reactiveLevel = max(0, level + Float(waveOffset))
            
            // Focus intensity in the center
            let distanceFromCenter = abs(CGFloat(index) - CGFloat(barCount-1)/2.0)
            let normalizedDistance = distanceFromCenter / (CGFloat(barCount)/2.0)
            let indexScale = 1.0 - pow(normalizedDistance, 1.5)
            
            let height = CGFloat(max(3, reactiveLevel * 30 * Float(indexScale)))
            
            let currentFrame = layer.frame
            let newY = (self.bounds.height - height) / 2
            
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.08) // Faster, snappier response
            layer.frame = CGRect(x: currentFrame.origin.x, y: newY, width: currentFrame.width, height: height)
            CATransaction.commit()
        }
    }
    
    func reset() {
        for layer in barLayers {
            let currentFrame = layer.frame
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.3)
            layer.frame = CGRect(x: currentFrame.origin.x, y: self.bounds.height / 2, width: currentFrame.width, height: 2)
            CATransaction.commit()
        }
    }
    
    override func layout() {
        super.layout()
        // Reposition bars if view size changes
        let spacing: CGFloat = 2.5
        let width: CGFloat = 2.5
        let totalWidth = CGFloat(barCount) * width + CGFloat(barCount - 1) * spacing
        let startX = (self.bounds.width - totalWidth) / 2
        
        for (i, layer) in barLayers.enumerated() {
            let x = startX + CGFloat(i) * (width + spacing)
            layer.frame = CGRect(x: x, y: layer.frame.origin.y, width: width, height: layer.frame.height)
        }
    }
}
