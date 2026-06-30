import SwiftUI

/// 在摄像头画面上叠加姿态骨架。
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

    private func projected(frame: PoseFrame, into size: CGSize) -> [BodyJoint: CGPoint] {
        // 2D 坐标原点在左下；3D 坐标是相对躯干的米制坐标。
        // 这里统一把关节投影到一个归一化空间，再映射到视图尺寸。
        // 对于 3D，使用简化正交投影（忽略 z，y 向上）。
        var result: [BodyJoint: CGPoint] = [:]

        if frame.is3D {
            // 估算包围盒
            var minX: Float = .greatestFiniteMagnitude
            var maxX: Float = -.greatestFiniteMagnitude
            var minY: Float = .greatestFiniteMagnitude
            var maxY: Float = -.greatestFiniteMagnitude
            for (_, p) in frame.joints {
                minX = min(minX, p.position.x)
                maxX = max(maxX, p.position.x)
                minY = min(minY, p.position.y)
                maxY = max(maxY, p.position.y)
            }
            let rangeX = max(maxX - minX, 0.001)
            let rangeY = max(maxY - minY, 0.001)
            let scale = min(size.width / CGFloat(rangeX), size.height / CGFloat(rangeY)) * 0.7
            let centerX = (minX + maxX) / 2
            let centerY = (minY + maxY) / 2
            for (joint, p) in frame.joints {
                let nx = (p.position.x - centerX) * scale + Float(size.width) / 2
                // y 翻转（Vision 3D 中 y 向上，屏幕 y 向下）
                let ny = Float(size.height) / 2 - (p.position.y - centerY) * scale
                result[joint] = CGPoint(x: CGFloat(nx), y: CGFloat(ny))
            }
        } else {
            // 2D：直接归一化
            var minX: Float = .greatestFiniteMagnitude
            var maxX: Float = -.greatestFiniteMagnitude
            var minY: Float = .greatestFiniteMagnitude
            var maxY: Float = -.greatestFiniteMagnitude
            for (_, p) in frame.joints {
                minX = min(minX, p.position.x)
                maxX = max(maxX, p.position.x)
                minY = min(minY, p.position.y)
                maxY = max(maxY, p.position.y)
            }
            let rangeX = max(maxX - minX, 0.001)
            let rangeY = max(maxY - minY, 0.001)
            let scale = min(size.width / CGFloat(rangeX), size.height / CGFloat(rangeY)) * 0.7
            let centerX = (minX + maxX) / 2
            let centerY = (minY + maxY) / 2
            for (joint, p) in frame.joints {
                let nx = (p.position.x - centerX) * scale + Float(size.width) / 2
                let ny = Float(size.height) / 2 - (p.position.y - centerY) * scale
                result[joint] = CGPoint(x: CGFloat(nx), y: CGFloat(ny))
            }
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