import AppKit
import ScreenSaver

@objc(FlyingToastersView)
final class FlyingToastersView: ScreenSaverView {
    private struct Flyer {
        enum Kind { case toaster, toast }

        var kind: Kind
        var position: CGPoint
        var speed: CGFloat
        var phase: Int
        var size: CGSize
    }

    private let moduleIdentifier = "com.example.FlyingToasters"
    private var flyers: [Flyer] = []
    private var toasterFrames: [NSImage] = []
    private var toastImage: NSImage?
    private var tick = 0

    private var configurationWindow: NSWindow?
    private var densitySlider: NSSlider?
    private var speedSlider: NSSlider?
    private var toastCheckbox: NSButton?

    private var defaults: ScreenSaverDefaults? {
        ScreenSaverDefaults(forModuleWithName: moduleIdentifier)
    }

    private var density: Int {
        max(4, defaults?.integer(forKey: "density") ?? 18)
    }

    private var speedMultiplier: CGFloat {
        let value = defaults?.double(forKey: "speed") ?? 1.0
        return CGFloat(max(0.35, min(value, 2.5)))
    }

    private var includesToast: Bool {
        if defaults?.object(forKey: "includesToast") == nil { return true }
        return defaults?.bool(forKey: "includesToast") ?? true
    }

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)

        animationTimeInterval = 1.0 / 30.0
        loadImages()

        defaults?.register(defaults: [
            "density": 18,
            "speed": 1.0,
            "includesToast": true
        ])

        rebuildFlyers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        animationTimeInterval = 1.0 / 30.0
        loadImages()

        defaults?.register(defaults: [
            "density": 18,
            "speed": 1.0,
            "includesToast": true
        ])

        rebuildFlyers()
    }

    override func startAnimation() {
        rebuildFlyers()
        super.startAnimation()
    }

    override func animateOneFrame() {
        guard bounds.width > 0, bounds.height > 0 else { return }

        tick += 1
        let velocityScale = speedMultiplier

        for index in flyers.indices {
            let base = flyers[index].speed * velocityScale

            flyers[index].position.x -= base
            flyers[index].position.y -= base * 0.72

            if flyers[index].position.x < -flyers[index].size.width ||
               flyers[index].position.y < -flyers[index].size.height {
                respawn(index: index)
            }

            if tick % 5 == 0 {
                flyers[index].phase = (flyers[index].phase + 1) % 2
            }
        }

        needsDisplay = true
    }

    override func draw(_ rect: NSRect) {
        NSColor.black.setFill()
        bounds.fill()

        NSGraphicsContext.current?.imageInterpolation = .none

        for flyer in flyers {
            let image: NSImage?

            switch flyer.kind {
            case .toaster:
                image = toasterFrames.isEmpty ? nil : toasterFrames[flyer.phase % toasterFrames.count]
            case .toast:
                image = toastImage
            }

            guard let image else { continue }

            let drawRect = NSRect(
                origin: flyer.position,
                size: flyer.size
            )

            image.draw(
                in: drawRect,
                from: .zero,
                operation: .sourceOver,
                fraction: 1.0,
                respectFlipped: true,
                hints: [.interpolation: NSImageInterpolation.none]
            )
        }
    }

    override var hasConfigureSheet: Bool {
        true
    }

    override var configureSheet: NSWindow? {
        if configurationWindow == nil {
            configurationWindow = makeConfigurationWindow()
        }

        densitySlider?.integerValue = density
        speedSlider?.doubleValue = Double(speedMultiplier)
        toastCheckbox?.state = includesToast ? .on : .off

        return configurationWindow
    }

    private func loadImages() {
        toasterFrames = [
            loadImage(named: "toaster_wing_up"),
            loadImage(named: "toaster_wing_down")
        ].compactMap { $0 }

        toastImage = loadImage(named: "toast")
    }

    private func loadImage(named name: String) -> NSImage? {
        guard let url = Bundle(for: Self.self).url(forResource: name, withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }

        image.size = NSSize(width: image.size.width, height: image.size.height)
        return image
    }

    private func rebuildFlyers() {
        guard bounds.width > 0, bounds.height > 0 else { return }

        flyers.removeAll(keepingCapacity: true)

        let count = isPreview ? max(5, density / 2) : density

        for i in 0..<count {
            let toast = includesToast && i % 6 == 0
            flyers.append(makeFlyer(kind: toast ? .toast : .toaster, distributed: true))
        }
    }

    private func makeFlyer(kind: Flyer.Kind, distributed: Bool) -> Flyer {
        let baseSize: CGSize

        switch kind {
        case .toaster:
            baseSize = isPreview ? CGSize(width: 48, height: 36) : CGSize(width: 96, height: 72)
        case .toast:
            baseSize = isPreview ? CGSize(width: 30, height: 30) : CGSize(width: 60, height: 60)
        }

        let x: CGFloat
        let y: CGFloat

        if distributed {
            x = CGFloat.random(in: 0...(bounds.width + baseSize.width))
            y = CGFloat.random(in: 0...(bounds.height + baseSize.height))
        } else {
            if Bool.random() {
                x = bounds.width + CGFloat.random(in: 20...220)
                y = CGFloat.random(in: (bounds.height * 0.40)...(bounds.height + 140))
            } else {
                x = CGFloat.random(in: (bounds.width * 0.35)...(bounds.width + 160))
                y = bounds.height + CGFloat.random(in: 20...180)
            }
        }

        return Flyer(
            kind: kind,
            position: CGPoint(x: x, y: y),
            speed: CGFloat.random(in: 2.4...4.6),
            phase: Int.random(in: 0...1),
            size: baseSize
        )
    }

    private func respawn(index: Int) {
        let kind = flyers[index].kind
        flyers[index] = makeFlyer(kind: kind, distributed: false)
    }

    private func makeConfigurationWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 230),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )

        window.title = "Flying Toasters Options"

        let content = NSView(frame: window.contentView?.bounds ?? .zero)
        content.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = content

        let densityLabel = NSTextField(labelWithString: "Toaster density")
        let density = NSSlider(value: Double(self.density), minValue: 4, maxValue: 40, target: nil, action: nil)
        density.isContinuous = true
        self.densitySlider = density

        let speedLabel = NSTextField(labelWithString: "Flight speed")
        let speed = NSSlider(value: Double(speedMultiplier), minValue: 0.35, maxValue: 2.5, target: nil, action: nil)
        speed.isContinuous = true
        self.speedSlider = speed

        let toast = NSButton(checkboxWithTitle: "Include flying toast", target: nil, action: nil)
        toast.state = includesToast ? .on : .off
        self.toastCheckbox = toast

        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelConfiguration(_:)))
        cancel.keyEquivalent = "\u{1b}"

        let save = NSButton(title: "Save", target: self, action: #selector(saveConfiguration(_:)))
        save.keyEquivalent = "\r"

        let buttonRow = NSStackView(views: [cancel, save])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.alignment = .centerY

        let stack = NSStackView(views: [
            densityLabel,
            density,
            speedLabel,
            speed,
            toast,
            buttonRow
        ])

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        density.widthAnchor.constraint(equalToConstant: 360).isActive = true
        speed.widthAnchor.constraint(equalToConstant: 360).isActive = true

        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 26)
        ])

        return window
    }

    @objc private func saveConfiguration(_ sender: Any?) {
        guard let window = configurationWindow else { return }

        defaults?.set(densitySlider?.integerValue ?? density, forKey: "density")
        defaults?.set(speedSlider?.doubleValue ?? Double(speedMultiplier), forKey: "speed")
        defaults?.set(toastCheckbox?.state == .on, forKey: "includesToast")
        defaults?.synchronize()

        rebuildFlyers()
        window.sheetParent?.endSheet(window)
    }

    @objc private func cancelConfiguration(_ sender: Any?) {
        guard let window = configurationWindow else { return }
        window.sheetParent?.endSheet(window)
    }
}
