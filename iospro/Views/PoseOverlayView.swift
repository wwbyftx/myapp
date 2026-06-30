import SwiftUI

/// 在摄像头画面上叠加姿态骨架。
@MainActor
struct PoseOverlayView: View {

    let frame: PoseFrame?
    let boundsSize: CGSize

    var body: some View {
        Canvas { context, size in
            guard let frame else { return }
            let points = projected(frame: frame, into: size)
            drawBones(context: context, points: points)
            drawJoints(context: context, points: points)
        }
        .allowsHitTesting(false)
    }

    // MARK: - 投影

    /// 把 2D 关节坐标归一化并映射到视图尺寸。
    /// 输入是像素坐标（Vision 2D），需要按包围盒缩放到视图内。
    private func projected(frame: PoseFrame, into size: CGSize) -> [BodyJoint: CGPoint] {
        var result: [BodyJoint: CGPoint] = [:]
        guard !frame.joints.isEmpty else { return result }

        // 计算包围盒。
        var minX: Float = .greatestFiniteMagnitude
        var maxX: Float = -.greatestFiniteMagnitude
        var minY: Float = .greatestFiniteMagnitude
        var maxY: Float = -.greatestFiniteMagnitude
        for (_, p) in frame.joints {
            let px: Float = p.position.x
            let py: Float = p.position.y
            if px < minX { minX = px }
            if px > maxX { maxX = px }
            if py < minY { minY = py }
            if py > maxY { maxY = py }
        }

        // 避免除零。
        var rangeX: Float = maxX - minX
        var rangeY: Float = maxY - minY
        if rangeX < 0.001 { rangeX = 0.001 }
        if rangeY < 0.001 { rangeY = 0.001 }

        // 缩放比例，留 30% 边距。
        let sizeW: CGFloat = size.width
        let sizeH: CGFloat = size.height
        let scaleX: CGFloat = sizeW / CGFloat(rangeX)
        let scaleY: CGFloat = sizeH / CGFloat(rangeY)
        let scale: CGFloat = (scaleX < scaleY ? scaleX : scaleY) * 0.7

        // 视图中心。
        let halfW: CGFloat = sizeW / 2
        let halfH: CGFloat = sizeH / 2
        // 包围盒中心。
        let centerX: Float = (minX + maxX) / 2
        let centerY: Float = (minY + maxY) / 2
        // 把 scale 降为 Float 参与算术。
        let scaleF: Float = Float(scale)

        for (joint, p) in frame.joints {
            let dx: Float = p.position.x - centerX
            let dy: Float = p.position.y - centerY
            let scaledX: Float = dx * scaleF
            let scaledY: Float = dy * scaleF
            // y 翻转：Vision 2D 坐标原点在左下，屏幕坐标原点在左上。
            let nx: CGFloat = CGFloat(scaledX) + halfW
            let ny: CGFloat = halfH - CGFloat(scaledY)
            result[joint] = CGPoint(x: nx, y: ny)
        }
        return result
    }

    // MARK: - 绘制

    private static let bones: [(BodyJoint, BodyJoint)] = [
        (.leftShoulder, .rightShoulder),
        (.leftShoulder, .leftElbow),
        (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow),
        (.rightElbow, .rightWrist),
        (.leftShoulder, .leftHip),
        (.rightShoulder, .rightHip),
        (.leftHip, .rightHip),
        (.leftHip, .leftKnee),
        (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee),
        (.rightKnee, .rightAnkle),
        (.neck, .nose)
    ]

    private func drawBones(context: GraphicsContext, points: [BodyJoint: CGPoint]) {
        var path = Path()
        for (a, b) in Self.bones {
            guard let pa = points[a], let pb = points[b] else { continue }
            path.move(to: pa)
            path.addLine(to: pb)
        }
        context.stroke(path,
                       with: .color(.orange.opacity(0.9)),
                       style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }

    private func drawJoints(context: GraphicsContext, points: [BodyJoint: CGPoint]) {
        for (_, p) in points {
            let r: CGFloat = 4
            let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
            context.fill(Path(ellipseIn: rect), with: .color(.white))
            context.stroke(Path(ellipseIn: rect), with: .color(.orange), lineWidth: 2)
        }
    }
}
