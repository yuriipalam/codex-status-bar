import AppKit

enum StatusIconColorMode: String, CaseIterable {
    case system
    case colorful

    var title: String {
        switch self {
        case .system:
            return "System"
        case .colorful:
            return "Colorful"
        }
    }
}

enum StatusIconAnimationMode: String, CaseIterable {
    case orbit
    case pulse
    case pulsingOrbit

    var title: String {
        switch self {
        case .orbit:
            return "Orbit"
        case .pulse:
            return "Pulse"
        case .pulsingOrbit:
            return "Pulsing Orbit"
        }
    }

    var frameInterval: TimeInterval {
        switch self {
        case .orbit, .pulsingOrbit:
            return 0.12
        case .pulse:
            return 0.24
        }
    }
}

final class StatusIconRenderer {
    private struct RenderKey: Hashable {
        let active: Bool
        let frame: Int
        let colorMode: StatusIconColorMode
        let animationMode: StatusIconAnimationMode
    }

    private let codexTemplate: NSImage?
    private let codexColorful: NSImage?
    private let codexGlyphMask: NSImage?
    private let codexGlyphWhite: NSImage?
    private let frameScales: [CGFloat] = [0.9, 0.96, 1.0, 0.96]
    private let orbitFrameCount = 24
    private let pulsingOrbitFrameCount = 32
    private let pulsingOrbitPulseFrameStride = 2
    private var cache: [RenderKey: NSImage] = [:]

    init() {
        self.codexTemplate = Self.loadCodexImage(svg: Self.systemIconSVG())
        self.codexColorful = Self.loadCodexImage(svg: Self.colorfulIconSVG())
        self.codexGlyphMask = Self.loadCodexImage(svg: Self.glyphIconSVG(fill: "#000000"))
        self.codexGlyphWhite = Self.loadCodexImage(svg: Self.glyphIconSVG(fill: "#FFFFFF"))
        self.codexTemplate?.isTemplate = true
        self.codexColorful?.isTemplate = false
        self.codexGlyphMask?.isTemplate = false
        self.codexGlyphWhite?.isTemplate = false
    }

    func image(
        active: Bool,
        frame: Int,
        colorMode: StatusIconColorMode,
        animationMode: StatusIconAnimationMode,
        appearance _: NSAppearance
    ) -> NSImage {
        let key = RenderKey(
            active: active,
            frame: active ? normalizedFrame(frame, animationMode: animationMode) : 0,
            colorMode: colorMode,
            animationMode: animationMode
        )

        if let image = cache[key] {
            return image
        }

        let image: NSImage
        if active {
            switch animationMode {
            case .orbit:
                image = renderedOrbitIcon(
                    frame: key.frame,
                    frameCount: orbitFrameCount,
                    scale: 1.0,
                    colorMode: colorMode
                )
            case .pulse:
                image = renderedPulseIcon(scale: frameScales[key.frame], colorMode: colorMode)
            case .pulsingOrbit:
                image = renderedOrbitIcon(
                    frame: key.frame,
                    frameCount: pulsingOrbitFrameCount,
                    scale: frameScales[(key.frame / pulsingOrbitPulseFrameStride) % frameScales.count],
                    colorMode: colorMode
                )
            }
        } else {
            image = renderedPulseIcon(scale: 1.0, colorMode: colorMode)
        }

        cache[key] = image
        return image
    }

    private func normalizedFrame(_ frame: Int, animationMode: StatusIconAnimationMode) -> Int {
        switch animationMode {
        case .orbit:
            return frame % orbitFrameCount
        case .pulsingOrbit:
            return frame % pulsingOrbitFrameCount
        case .pulse:
            return frame % frameScales.count
        }
    }

    private func renderedOrbitIcon(frame: Int, frameCount: Int, scale: CGFloat, colorMode: StatusIconColorMode) -> NSImage {
        let angle = frame * 360 / frameCount
        let shell: NSImage?
        let glyph: NSImage?
        let isTemplate = colorMode == .system

        switch colorMode {
        case .system:
            shell = Self.loadCodexImage(svg: Self.systemShellSVG(angleDegrees: angle))
            glyph = codexGlyphMask
        case .colorful:
            shell = Self.loadCodexImage(svg: Self.colorfulShellSVG(angleDegrees: angle))
            glyph = codexGlyphWhite
        }

        guard let shell else {
            return renderedPulseIcon(scale: 1.0, colorMode: colorMode)
        }

        shell.isTemplate = isTemplate
        return renderedSplitIcon(shell: shell, glyph: glyph, isTemplate: isTemplate, scale: scale)
    }

    private func renderedPulseIcon(scale: CGFloat, colorMode: StatusIconColorMode) -> NSImage {
        renderedImage(source: sourceImage(for: colorMode), scale: scale)
    }

    private func renderedImage(source: (image: NSImage?, isTemplate: Bool), scale: CGFloat) -> NSImage {
        let canvasWidth: CGFloat = 18
        let canvasHeight: CGFloat = 18
        let iconSize: CGFloat = 20
        let drawSize = iconSize * min(1.0, max(0.2, scale))
        let target = NSRect(
            x: (canvasWidth - drawSize) / 2,
            y: (canvasHeight - drawSize) / 2,
            width: drawSize,
            height: drawSize
        )
        let image = NSImage(size: NSSize(width: canvasWidth, height: canvasHeight), flipped: false) { _ in
            guard let codexImage = source.image else {
                return Self.drawGlyph(in: target)
            }

            codexImage.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1.0)
            return true
        }
        image.isTemplate = source.isTemplate
        return image
    }

    private func renderedSplitIcon(shell: NSImage, glyph: NSImage?, isTemplate: Bool, scale: CGFloat) -> NSImage {
        let canvasWidth: CGFloat = 18
        let canvasHeight: CGFloat = 18
        let iconSize: CGFloat = 20
        let drawSize = iconSize * min(1.0, max(0.2, scale))
        let target = NSRect(
            x: (canvasWidth - drawSize) / 2,
            y: (canvasHeight - drawSize) / 2,
            width: drawSize,
            height: drawSize
        )
        let image = NSImage(size: NSSize(width: canvasWidth, height: canvasHeight), flipped: false) { _ in
            shell.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1.0)
            glyph?.draw(
                in: target,
                from: .zero,
                operation: isTemplate ? .destinationOut : .sourceOver,
                fraction: 1.0
            )
            return true
        }
        image.isTemplate = isTemplate
        return image
    }

    private func sourceImage(for colorMode: StatusIconColorMode) -> (image: NSImage?, isTemplate: Bool) {
        switch colorMode {
        case .system:
            return (codexTemplate, true)
        case .colorful:
            guard let codexColorful else {
                return (codexTemplate, true)
            }

            return (codexColorful, false)
        }
    }

    private static func loadCodexImage(svg: String) -> NSImage? {
        guard let data = svg.data(using: .utf8) else { return nil }
        return NSImage(data: data)
    }

    private static func drawGlyph(in rect: NSRect) -> Bool {
        guard let symbol = NSImage(systemSymbolName: "terminal", accessibilityDescription: "Codex") else {
            NSColor.labelColor.setStroke()
            let path = NSBezierPath()
            path.lineWidth = 1.8
            path.move(to: NSPoint(x: rect.minX + 5, y: rect.midY + 4))
            path.line(to: NSPoint(x: rect.midX, y: rect.midY))
            path.line(to: NSPoint(x: rect.minX + 5, y: rect.midY - 4))
            path.move(to: NSPoint(x: rect.midX + 3, y: rect.midY - 4))
            path.line(to: NSPoint(x: rect.maxX - 3, y: rect.midY - 4))
            path.stroke()
            return true
        }

        symbol.isTemplate = true
        symbol.draw(in: rect.insetBy(dx: 1, dy: 1), from: .zero, operation: .sourceOver, fraction: 1.0)
        return true
    }

    private static func systemIconSVG() -> String {
        #"""
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="-2 -2 28 28" role="img" aria-labelledby="codex-title">
  <title id="codex-title">Codex</title>
  <path fill="#000000" fill-rule="evenodd" d="\#(codexShellPath) \#(codexChevronPath) \#(codexUnderscorePath)"/>
</svg>
"""#
    }

    private static func colorfulIconSVG() -> String {
        #"""
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="-2 -2 28 28" role="img" aria-labelledby="codex-title">
  <title id="codex-title">Codex</title>
  <defs>
    <linearGradient id="codexGradient" gradientUnits="userSpaceOnUse" x1="2" x2="22" y1="2" y2="22">
      <stop offset="0" stop-color="#AEA7FF"/>
      <stop offset="1" stop-color="#3C46FF"/>
    </linearGradient>
  </defs>
  <path fill="url(#codexGradient)" d="\#(codexShellPath)"/>
  <path fill="#FFFFFF" d="\#(codexChevronPath)"/>
  <path fill="#FFFFFF" d="\#(codexUnderscorePath)"/>
</svg>
"""#
    }

    private static func systemShellSVG(angleDegrees: Int) -> String {
        #"""
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="-2 -2 28 28" role="img" aria-labelledby="codex-title">
  <title id="codex-title">Codex</title>
  <g transform="rotate(\#(angleDegrees) 12 12)">
    <path fill="#000000" d="\#(codexShellPath)"/>
  </g>
</svg>
"""#
    }

    private static func colorfulShellSVG(angleDegrees: Int) -> String {
        #"""
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="-2 -2 28 28" role="img" aria-labelledby="codex-title">
  <title id="codex-title">Codex</title>
  <defs>
    <linearGradient id="codexGradient" gradientUnits="userSpaceOnUse" x1="2" x2="22" y1="2" y2="22">
      <stop offset="0" stop-color="#AEA7FF"/>
      <stop offset="1" stop-color="#3C46FF"/>
    </linearGradient>
  </defs>
  <g transform="rotate(\#(angleDegrees) 12 12)">
    <path fill="url(#codexGradient)" d="\#(codexShellPath)"/>
  </g>
</svg>
"""#
    }

    private static func glyphIconSVG(fill: String) -> String {
        #"""
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="-2 -2 28 28" role="img" aria-labelledby="codex-title">
  <title id="codex-title">Codex</title>
  <path fill="\#(fill)" d="\#(codexChevronPath)"/>
  <path fill="\#(fill)" d="\#(codexUnderscorePath)"/>
</svg>
"""#
    }

    private static let codexShellPath = #"M 8.086 0.457 C 9.04931 0.06111 10.09789 -0.08175 11.132 0.042 C 12.465 0.195 13.653 0.762 14.696 1.742 C 14.72453 1.76902 14.76473 1.77992 14.803 1.771 C 16.211 1.425 17.565 1.547 18.864 2.137 L 18.927 2.167 L 19.081 2.243 C 20.438 2.946 21.411 4.013 21.999 5.441 C 22.277 6.12 22.417 6.829 22.42 7.567 C 22.43962 8.11653 22.37898 8.66598 22.24 9.198 C 22.22609 9.25311 22.24116 9.31151 22.28 9.353 C 23.06616 10.15002 23.61288 11.15166 23.858 12.244 C 24.243 14.145 23.848 15.859 22.675 17.384 L 22.493 17.604 C 21.71616 18.4936 20.69641 19.13693 19.559 19.455 C 19.50861 19.46952 19.46837 19.50753 19.451 19.557 C 19.196 20.293 18.94 20.921 18.464 21.549 C 17.265 23.131 15.502 24.011 13.516 24 C 11.933 23.992 10.53 23.413 9.306 22.264 C 9.26826 22.22935 9.21504 22.21719 9.166 22.232 C 8.648 22.399 8.126 22.423 7.562 22.417 C 6.66095 22.40972 5.77344 22.19699 4.967 21.795 C 4.1229 21.3763 3.38809 20.76648 2.821 20.014 C 2.618 19.745 2.417 19.492 2.27 19.193 C 2.06726 18.78087 1.90161 18.35151 1.775 17.91 C 1.50918 16.90669 1.50333 15.8522 1.758 14.846 C 1.76623 14.82226 1.76897 14.79695 1.766 14.772 C 1.76105 14.74718 1.74804 14.72468 1.729 14.708 C 1.11258 14.08448 0.64137 13.3326 0.349 12.506 C 0.15543 11.99705 0.04305 11.46084 0.016 10.917 C -0.03236 10.20088 0.03107 9.4816 0.204 8.785 C 0.654 7.301 1.513 6.137 2.781 5.292 C 3.063 5.104 3.331 4.958 3.583 4.854 C 3.869 4.734 4.156 4.634 4.444 4.55 C 4.48585 4.53759 4.51859 4.50485 4.531 4.463 C 4.7494 3.67797 5.12499 2.94549 5.635 2.31 C 6.315 1.464 7.132 0.846 8.086 0.457 Z"#

    private static let codexChevronPath = #"M 7.282 8.307 C 7.04949 7.90024 6.53126 7.75899 6.1245 7.9915 C 5.71774 8.22401 5.57649 8.74224 5.809 9.149 L 7.503 12.114 L 5.815 14.962 C 5.59997 15.36297 5.73925 15.86217 6.13082 16.09389 C 6.52238 16.32561 7.027 16.20746 7.275 15.826 L 9.215 12.554 C 9.37076 12.29131 9.37343 11.96521 9.222 11.7 L 7.282 8.307 Z"#

    private static let codexUnderscorePath = #"M 12.728 14.547 C 12.2795 14.5737 11.92945 14.9452 11.92945 15.3945 C 11.92945 15.8438 12.2795 16.2153 12.728 16.242 L 17.576 16.242 C 18.02834 16.22003 18.38381 15.84688 18.38381 15.394 C 18.38381 14.94112 18.02834 14.56797 17.576 14.546 L 12.728 14.546 Z"#
}
