import SwiftUI

struct RobotArmSimulationState: Encodable, Equatable {
    struct Point: Encodable, Equatable {
        let x: Double
        let y: Double
    }

    let status: String
    let stageTitle: String
    let stageID: String
    let targetClass: String
    let destinationBin: String
    let elapsedSeconds: Double
    let stageProgress: Double
    let confidence: Double?
    let targetPoint: Point?
    let hasTarget: Bool
}

struct RobotArmSimulationView: View {
    let state: RobotArmSimulationState

    var body: some View {
        ZStack(alignment: .top) {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                Canvas(rendersAsynchronously: true) { context, size in
                    let layout = Layout(size: size)
                    let pose = desiredPose(at: timeline.date.timeIntervalSinceReferenceDate, layout: layout)

                    drawBackground(in: &context, layout: layout)
                    drawPath(in: &context, from: pose.target, to: pose.destination, isVisible: pose.showPath)
                    drawBins(in: &context, layout: layout)
                    drawTarget(in: &context, pose: pose)
                    drawArm(in: &context, layout: layout, pose: pose)
                }
            }

            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    hudPill
                    Spacer(minLength: 12)
                    executionCard
                }
                .padding(16)

                Spacer()
            }
        }
        .background(simulationBackground)
    }

    private var simulationBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.09, green: 0.13, blue: 0.20),
                Color(red: 0.06, green: 0.09, blue: 0.14),
                Color(red: 0.04, green: 0.06, blue: 0.10)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var hudPill: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(state.stageTitle)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(state.hasTarget ? "\(state.targetClass) -> \(state.destinationBin)" : "Waiting for detection input")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.74))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var executionCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Execution Snapshot")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            roboticsSnapshotRow(label: "Status", value: state.status)
            roboticsSnapshotRow(label: "Target", value: state.hasTarget ? state.targetClass : "-")
            roboticsSnapshotRow(label: "Bin", value: state.destinationBin)
            roboticsSnapshotRow(label: "Confidence", value: state.confidence.map { String(format: "%.3f", $0) } ?? "-")
            roboticsSnapshotRow(label: "Timer", value: String(format: "%.1fs", state.elapsedSeconds))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 176, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func roboticsSnapshotRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
        }
    }

    private func drawBackground(in context: inout GraphicsContext, layout: Layout) {
        let canvasRect = CGRect(origin: .zero, size: layout.size)
        context.fill(Path(canvasRect), with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.13, green: 0.18, blue: 0.28),
                Color(red: 0.06, green: 0.09, blue: 0.14)
            ]),
            startPoint: .zero,
            endPoint: CGPoint(x: layout.size.width, y: layout.size.height)
        ))

        let workspacePath = Path(roundedRect: layout.workspaceRect, cornerRadius: 18)
        context.fill(workspacePath, with: .color(Color(red: 0.24, green: 0.31, blue: 0.46).opacity(0.18)))
        context.stroke(workspacePath, with: .color(.white.opacity(0.12)), lineWidth: 1)

        var grid = Path()
        for x in stride(from: layout.workspaceRect.minX, through: layout.workspaceRect.maxX, by: 28) {
            grid.move(to: CGPoint(x: x, y: layout.workspaceRect.minY))
            grid.addLine(to: CGPoint(x: x, y: layout.workspaceRect.maxY))
        }
        for y in stride(from: layout.workspaceRect.minY, through: layout.workspaceRect.maxY, by: 28) {
            grid.move(to: CGPoint(x: layout.workspaceRect.minX, y: y))
            grid.addLine(to: CGPoint(x: layout.workspaceRect.maxX, y: y))
        }
        context.stroke(grid, with: .color(.white.opacity(0.06)), lineWidth: 1)

        var floor = Path()
        floor.move(to: CGPoint(x: 0, y: layout.floorY))
        floor.addLine(to: CGPoint(x: layout.size.width, y: layout.floorY))
        floor.addLine(to: CGPoint(x: layout.size.width, y: layout.size.height))
        floor.addLine(to: CGPoint(x: 0, y: layout.size.height))
        floor.closeSubpath()
        context.fill(floor, with: .color(Color.black.opacity(0.22)))

        var floorLine = Path()
        floorLine.move(to: CGPoint(x: 0, y: layout.floorY))
        floorLine.addLine(to: CGPoint(x: layout.size.width, y: layout.floorY))
        context.stroke(floorLine, with: .color(.white.opacity(0.10)), lineWidth: 1)
    }

    private func drawBins(in context: inout GraphicsContext, layout: Layout) {
        for (name, rect, color, _) in layout.bins {
            let path = Path(roundedRect: rect, cornerRadius: 18)
            let isActive = name == state.destinationBin
            context.fill(path, with: .color(.white.opacity(isActive ? 0.10 : 0.05)))
            context.stroke(path, with: .color((isActive ? color : .white).opacity(isActive ? 0.8 : 0.16)), lineWidth: 1.2)

            context.draw(
                Text(name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white),
                at: CGPoint(x: rect.midX, y: rect.minY + 22)
            )

            context.draw(
                Text("Sort bin")
                    .font(.caption2)
                    .foregroundStyle(.secondary),
                at: CGPoint(x: rect.midX, y: rect.minY + 44)
            )

            let opening = CGRect(x: rect.minX + 10, y: rect.minY + 10, width: rect.width - 20, height: 16)
            context.fill(
                Path(roundedRect: opening, cornerRadius: 8),
                with: .color((isActive ? color : .white).opacity(isActive ? 0.18 : 0.08))
            )
        }
    }

    private func drawTarget(in context: inout GraphicsContext, pose: Pose) {
        guard state.hasTarget else { return }
        let targetColor = color(for: state.targetClass)

        if let placedPoint = pose.placedPosition {
            let placedRect = CGRect(x: placedPoint.x - 18, y: placedPoint.y - 14, width: 36, height: 28)
            let placedPath = Path(roundedRect: placedRect, cornerRadius: 8)
            context.fill(placedPath, with: .color(targetColor.opacity(0.88)))
            context.stroke(placedPath, with: .color(.white.opacity(0.26)), lineWidth: 1)
            context.draw(
                Text(shortLabel(for: state.targetClass))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.92)),
                at: CGPoint(x: placedRect.midX, y: placedRect.midY)
            )
            return
        }

        if let carriedPoint = pose.carriedObjectPosition {
            let carriedRect = CGRect(x: carriedPoint.x - 16, y: carriedPoint.y - 12, width: 32, height: 24)
            let carriedPath = Path(roundedRect: carriedRect, cornerRadius: 7)
            context.fill(carriedPath, with: .color(targetColor.opacity(0.92)))
            context.stroke(carriedPath, with: .color(.white.opacity(0.24)), lineWidth: 1)
            return
        }

        let targetRect = CGRect(x: pose.target.x - 18, y: pose.target.y - 14, width: 36, height: 28)
        let targetPath = Path(roundedRect: targetRect, cornerRadius: 8)
        context.fill(targetPath, with: .color(targetColor.opacity(0.88)))
        context.stroke(targetPath, with: .color(.white.opacity(0.26)), lineWidth: 1.2)
        context.draw(
            Text(shortLabel(for: state.targetClass))
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.92)),
            at: CGPoint(x: targetRect.midX, y: targetRect.midY)
        )

        context.draw(
            Text(state.targetClass)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92)),
            at: CGPoint(x: pose.target.x, y: pose.target.y + 30)
        )
    }

    private func drawPath(in context: inout GraphicsContext, from start: CGPoint, to end: CGPoint, isVisible: Bool) {
        guard isVisible, state.hasTarget else { return }

        var path = Path()
        path.move(to: start)
        path.addLine(to: CGPoint(x: end.x - 24, y: start.y))
        path.addLine(to: CGPoint(x: end.x - 24, y: end.y - 12))
        context.stroke(
            path,
            with: .color(Color(red: 0.72, green: 0.82, blue: 0.98).opacity(0.62)),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [8, 7])
        )
    }

    private func drawArm(in context: inout GraphicsContext, layout: Layout, pose: Pose) {
        let shoulderPoint = jointPoint(from: layout.base, length: layout.upperLength, angle: pose.shoulder)
        let elbowAngle = pose.shoulder + pose.elbow
        let elbowPoint = jointPoint(from: shoulderPoint, length: layout.forearmLength, angle: elbowAngle)
        let wristAngle = elbowAngle + pose.wrist
        let wristPoint = jointPoint(from: elbowPoint, length: layout.wristLength, angle: wristAngle)

        var armPath = Path()
        armPath.move(to: layout.base)
        armPath.addLine(to: shoulderPoint)
        armPath.addLine(to: elbowPoint)
        armPath.addLine(to: wristPoint)

        context.stroke(armPath, with: .color(Color.black.opacity(0.42)), style: StrokeStyle(lineWidth: 22, lineCap: .round, lineJoin: .round))
        context.stroke(armPath, with: .color(Color(red: 0.88, green: 0.92, blue: 0.98)), style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round))

        for (point, radius) in [
            (layout.base, CGFloat(18)),
            (shoulderPoint, CGFloat(14)),
            (elbowPoint, CGFloat(12)),
            (wristPoint, CGFloat(10))
        ] {
            let outer = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
            let inner = outer.insetBy(dx: 5, dy: 5)
            context.fill(Path(ellipseIn: outer), with: .color(Color.black.opacity(0.56)))
            context.fill(Path(ellipseIn: inner), with: .color(Color(red: 0.88, green: 0.92, blue: 0.98)))
        }

        let gripperAnchor = jointPoint(from: wristPoint, length: 18, angle: wristAngle)
        let gripLeft = jointPoint(from: gripperAnchor, length: pose.gripper, angle: wristAngle + .pi / 2)
        let gripRight = jointPoint(from: gripperAnchor, length: pose.gripper, angle: wristAngle - .pi / 2)

        var gripper = Path()
        gripper.move(to: wristPoint)
        gripper.addLine(to: gripperAnchor)
        gripper.move(to: gripperAnchor)
        gripper.addLine(to: gripLeft)
        gripper.move(to: gripperAnchor)
        gripper.addLine(to: gripRight)
        context.stroke(gripper, with: .color(Color(red: 0.88, green: 0.92, blue: 0.98)), style: StrokeStyle(lineWidth: 6, lineCap: .round))

        let toolCenter = CGRect(x: gripperAnchor.x - 4, y: gripperAnchor.y - 4, width: 8, height: 8)
        context.fill(Path(ellipseIn: toolCenter), with: .color(Color.white.opacity(0.92)))
    }

    private func desiredPose(at time: TimeInterval, layout: Layout) -> Pose {
        let target = targetPosition(in: layout)
        let destination = destinationPosition(in: layout)
        let hoverTarget = CGPoint(x: target.x, y: target.y - 60)
        let hoverDestination = CGPoint(x: destination.x, y: destination.y - 84)
        let depositDestination = CGPoint(x: destination.x, y: destination.y - 12)
        let prePickApproach = CGPoint(x: target.x - 42, y: target.y - 74)
        let targetGripAngle = preferredGripAngle(for: target, layout: layout, placing: false)
        let destinationGripAngle = preferredGripAngle(for: destination, layout: layout, placing: true)
        let progress = clamp(state.stageProgress, min: 0, max: 1)
        let scanStart = CGPoint(
            x: layout.workspaceRect.minX + layout.workspaceRect.width * 0.24,
            y: layout.workspaceRect.minY + layout.workspaceRect.height * 0.22
        )
        let scanEnd = CGPoint(
            x: layout.workspaceRect.minX + layout.workspaceRect.width * 0.62,
            y: layout.workspaceRect.minY + layout.workspaceRect.height * 0.38
        )
        let scanTarget = interpolatedPoint(from: scanStart, to: scanEnd, progress: pingPong(progress))
        switch state.stageID {
        case "detect":
            return solveIK(at: scanTarget, layout: layout, gripper: 18, target: target, destination: destination, desiredGripAngle: targetGripAngle)
        case "target_lock":
            let point = interpolatedPoint(from: scanEnd, to: hoverTarget, progress: easeInOut(progress))
            let angle = interpolatedAngle(from: 0.24 * .pi, to: targetGripAngle, progress: easeInOut(progress))
            return solveIK(at: point, layout: layout, gripper: 18, target: target, destination: destination, desiredGripAngle: angle)
        case "path_plan":
            let settlePoint = interpolatedPoint(
                from: prePickApproach,
                to: hoverTarget,
                progress: easeInOut(progress)
            )
            return solveIK(at: settlePoint, layout: layout, gripper: 18, target: target, destination: destination, showPath: true, desiredGripAngle: targetGripAngle)
        case "pick":
            let approachProgress = segmentedProgress(progress, start: 0.0, end: 0.26)
            let descendProgress = segmentedProgress(progress, start: 0.26, end: 0.56)
            let gripProgress = segmentedProgress(progress, start: 0.56, end: 0.74)
            let liftProgress = segmentedProgress(progress, start: 0.74, end: 1.0)
            let approachPoint = interpolatedPoint(from: prePickApproach, to: hoverTarget, progress: easeInOut(approachProgress))
            let descendPoint = interpolatedPoint(from: hoverTarget, to: target, progress: easeInOut(descendProgress))
            let liftPoint = interpolatedPoint(from: target, to: hoverTarget, progress: easeInOut(liftProgress))
            let point: CGPoint
            if progress < 0.26 {
                point = approachPoint
            } else if progress < 0.74 {
                point = descendPoint
            } else {
                point = liftPoint
            }
            let gripper = progress < 0.56
                ? 18
                : 18 - (10 * easeInOut(gripProgress))
            let pose = solveIK(
                at: point,
                layout: layout,
                gripper: gripper,
                target: target,
                destination: destination,
                showPath: true,
                carrying: progress >= 0.68,
                desiredGripAngle: targetGripAngle
            )
            if progress < 0.68 {
                return pose
            }
            if progress < 0.82 {
                let gripperPoint = objectPointBelowGripper(for: pose)
                let attachProgress = segmentedProgress(progress, start: 0.68, end: 0.82)
                let attachedPoint = interpolatedPoint(from: target, to: gripperPoint, progress: easeInOut(attachProgress))
                return pose.withCarriedObjectPosition(attachedPoint)
            }
            return pose.withCarriedObjectPosition(objectPointBelowGripper(for: pose))
        case "transfer":
            let transportProgress = easeInOut(progress)
            let point = interpolatedPoint(from: hoverTarget, to: hoverDestination, progress: transportProgress)
            let angle = interpolatedAngle(from: targetGripAngle, to: destinationGripAngle, progress: transportProgress)
            let pose = solveIK(at: point, layout: layout, gripper: 8, target: target, destination: destination, showPath: true, carrying: true, desiredGripAngle: angle)
            return pose.withCarriedObjectPosition(objectPointBelowGripper(for: pose))
        case "place":
            let lowerProgress = easeInOut(progress)
            let point = interpolatedPoint(from: hoverDestination, to: depositDestination, progress: lowerProgress)
            let pose = solveIK(at: point, layout: layout, gripper: 8, target: target, destination: destination, showPath: true, carrying: true, desiredGripAngle: destinationGripAngle)
            return pose.withCarriedObjectPosition(objectPointBelowGripper(for: pose))
        case "release":
            let pose = solveIK(
                at: depositDestination,
                layout: layout,
                gripper: 8 + (24 * easeInOut(progress)),
                target: target,
                destination: destination,
                showPath: true,
                carrying: false,
                desiredGripAngle: destinationGripAngle
            )
            let dropStart = objectPointBelowGripper(for: pose)
            if progress < 0.35 {
                return pose.withCarriedObjectPosition(dropStart)
            }
            let dropPhase = segmentedProgress(progress, start: 0.35, end: 1.0)
            let bounce = sin(dropPhase * .pi) * 8 * (1 - dropPhase)
            let placedPoint = CGPoint(
                x: dropStart.x + (destination.x - dropStart.x) * dropPhase,
                y: dropStart.y + (destination.y - dropStart.y) * dropPhase - bounce
            )
            return pose.withPlacedPosition(placedPoint)
        case "complete":
            let point = interpolatedPoint(from: depositDestination, to: hoverDestination, progress: easeInOut(progress))
            let pose = solveIK(at: point, layout: layout, gripper: 22, target: target, destination: destination, showPath: true, placed: true, desiredGripAngle: destinationGripAngle)
            return pose.withPlacedPosition(destination)
        case "ready":
            if state.hasTarget {
                return solveIK(at: hoverTarget, layout: layout, gripper: 18, target: target, destination: destination, desiredGripAngle: targetGripAngle)
            }
            fallthrough
        default:
            return Pose(
                shoulder: -.pi * 0.28,
                elbow: .pi * 0.56,
                wrist: -.pi * 0.12,
                gripper: 18,
                target: target,
                destination: destination,
                showPath: false,
                carrying: false,
                placed: false,
                endEffectorPoint: .zero,
                carriedObjectPosition: nil,
                placedPosition: nil
            )
        }
    }

    private func targetPosition(in layout: Layout) -> CGPoint {
        guard let targetPoint = state.targetPoint else {
            return CGPoint(x: layout.workspaceRect.midX, y: layout.workspaceRect.midY)
        }

        return CGPoint(
            x: layout.workspaceRect.minX + layout.workspaceRect.width * CGFloat(clamp(targetPoint.x, min: 0.05, max: 0.95)),
            y: layout.workspaceRect.minY + layout.workspaceRect.height * CGFloat(clamp(targetPoint.y, min: 0.05, max: 0.95))
        )
    }

    private func destinationPosition(in layout: Layout) -> CGPoint {
        layout.bins.first(where: { $0.name == state.destinationBin })?.dropPoint
            ?? layout.bins.last?.dropPoint
            ?? CGPoint(x: layout.size.width * 0.82, y: layout.size.height * 0.74)
    }

    private func solveIK(
        at point: CGPoint,
        layout: Layout,
        gripper: CGFloat,
        target: CGPoint,
        destination: CGPoint,
        showPath: Bool = false,
        carrying: Bool = false,
        placed: Bool = false,
        desiredGripAngle: Double = .pi / 2
    ) -> Pose {
        let toolReach = Double(layout.wristLength + 18)
        let wristTarget = CGPoint(
            x: point.x - cos(CGFloat(desiredGripAngle)) * CGFloat(toolReach),
            y: point.y - sin(CGFloat(desiredGripAngle)) * CGFloat(toolReach)
        )
        let dx = wristTarget.x - layout.base.x
        let dy = wristTarget.y - layout.base.y
        let upper = Double(layout.upperLength)
        let forearm = Double(layout.forearmLength)
        let distance = clamp(Double(hypot(dx, dy)), min: 24, max: upper + forearm - 8)
        let baseAngle = atan2(Double(dy), Double(dx))
        let elbowCos = clamp(
            (distance * distance - upper * upper - forearm * forearm) / (2 * upper * forearm),
            min: -0.999,
            max: 0.999
        )
        let elbow = acos(elbowCos)
        let shoulder = baseAngle - atan2(forearm * sin(elbow), upper + forearm * cos(elbow))
        let wrist = desiredGripAngle - shoulder - elbow
        let elbowAngle = shoulder + elbow
        let wristPoint = CGPoint(
            x: layout.base.x + cos(CGFloat(shoulder)) * layout.upperLength + cos(CGFloat(elbowAngle)) * layout.forearmLength + cos(CGFloat(elbowAngle + wrist)) * layout.wristLength,
            y: layout.base.y + sin(CGFloat(shoulder)) * layout.upperLength + sin(CGFloat(elbowAngle)) * layout.forearmLength + sin(CGFloat(elbowAngle + wrist)) * layout.wristLength
        )
        let gripCenter = CGPoint(
            x: wristPoint.x + cos(CGFloat(desiredGripAngle)) * 18,
            y: wristPoint.y + sin(CGFloat(desiredGripAngle)) * 18
        )

        return Pose(
            shoulder: shoulder,
            elbow: elbow,
            wrist: wrist,
            gripper: gripper,
            target: target,
            destination: destination,
            showPath: showPath,
            carrying: carrying,
            placed: placed,
            endEffectorPoint: gripCenter,
            carriedObjectPosition: nil,
            placedPosition: nil
        )
    }

    private func objectPointBelowGripper(for pose: Pose) -> CGPoint {
        return CGPoint(
            x: pose.endEffectorPoint.x,
            y: pose.endEffectorPoint.y
        )
    }

    private func preferredGripAngle(for point: CGPoint, layout: Layout, placing: Bool) -> Double {
        let normalizedX = clamp(
            Double((point.x - layout.workspaceRect.midX) / max(layout.workspaceRect.width * 0.5, 1)),
            min: -1,
            max: 1
        )
        let baseAngle = Double.pi * 0.50
        return baseAngle + (normalizedX * (placing ? 0.04 : 0.06))
    }

    private func interpolatedAngle(from start: Double, to end: Double, progress: CGFloat) -> Double {
        start + (end - start) * Double(progress)
    }

    private func jointPoint(from start: CGPoint, length: CGFloat, angle: Double) -> CGPoint {
        CGPoint(
            x: start.x + cos(CGFloat(angle)) * length,
            y: start.y + sin(CGFloat(angle)) * length
        )
    }

    private func clamp(_ value: Double, min: Double, max: Double) -> Double {
        Swift.max(min, Swift.min(max, value))
    }

    private func easeOutCubic(_ value: Double) -> CGFloat {
        let eased = 1 - pow(1 - value, 3)
        return CGFloat(eased)
    }

    private func easeInOut(_ value: Double) -> CGFloat {
        let clamped = clamp(value, min: 0, max: 1)
        let eased = clamped < 0.5
            ? 4 * clamped * clamped * clamped
            : 1 - pow(-2 * clamped + 2, 3) / 2
        return CGFloat(eased)
    }

    private func pingPong(_ value: Double) -> CGFloat {
        let clamped = clamp(value, min: 0, max: 1)
        return CGFloat(clamped <= 0.5 ? clamped * 2 : (1 - clamped) * 2)
    }

    private func interpolatedPoint(from start: CGPoint, to end: CGPoint, progress: CGFloat) -> CGPoint {
        CGPoint(
            x: start.x + (end.x - start.x) * progress,
            y: start.y + (end.y - start.y) * progress
        )
    }

    private func segmentedProgress(_ value: Double, start: Double, end: Double) -> Double {
        guard end > start else { return 1 }
        return clamp((value - start) / (end - start), min: 0, max: 1)
    }

    private func color(for targetClass: String) -> Color {
        switch targetClass.lowercased() {
        case "stroller":
            return Color(red: 0.16, green: 0.73, blue: 0.57)
        case "diaper":
            return Color(red: 0.35, green: 0.57, blue: 0.98)
        case "phone":
            return Color(red: 0.72, green: 0.42, blue: 0.96)
        default:
            return Color(red: 0.93, green: 0.60, blue: 0.24)
        }
    }

    private func shortLabel(for targetClass: String) -> String {
        switch targetClass.lowercased() {
        case "stroller":
            return "STR"
        case "diaper":
            return "DIA"
        case "phone":
            return "PHN"
        default:
            return String(targetClass.prefix(3)).uppercased()
        }
    }
}

private struct Layout {
    let size: CGSize
    let base: CGPoint
    let upperLength: CGFloat
    let forearmLength: CGFloat
    let wristLength: CGFloat
    let workspaceRect: CGRect
    let bins: [(name: String, rect: CGRect, color: Color, dropPoint: CGPoint)]
    let floorY: CGFloat

    init(size: CGSize) {
        self.size = size
        let shortest = min(size.width, size.height)
        self.base = CGPoint(x: size.width * 0.21, y: size.height * 0.77)
        self.upperLength = shortest * 0.34
        self.forearmLength = shortest * 0.31
        self.wristLength = shortest * 0.08
        self.workspaceRect = CGRect(x: size.width * 0.34, y: size.height * 0.16, width: size.width * 0.42, height: size.height * 0.48)
        self.floorY = size.height * 0.81
        let binWidth = max(74, size.width * 0.105)
        let binHeight = max(94, size.height * 0.18)
        let binY = size.height * 0.63
        let binGap = max(12, size.width * 0.025)
        let maxBinBX = size.width - binWidth - 18
        let binAX = min(size.width * 0.60, maxBinBX - binWidth - binGap)
        let binBX = binAX + binWidth + binGap
        let binARect = CGRect(x: binAX, y: binY, width: binWidth, height: binHeight)
        let binBRect = CGRect(x: binBX, y: binY, width: binWidth, height: binHeight)
        self.bins = [
            (
                "bin A",
                binARect,
                Color(red: 0.36, green: 0.53, blue: 0.98),
                CGPoint(x: binARect.midX, y: binARect.minY + binHeight * 0.58)
            ),
            (
                "bin B",
                binBRect,
                Color(red: 0.12, green: 0.70, blue: 0.56),
                CGPoint(x: binBRect.midX, y: binBRect.minY + binHeight * 0.58)
            )
        ]
    }
}

private struct Pose {
    let shoulder: Double
    let elbow: Double
    let wrist: Double
    let gripper: CGFloat
    let target: CGPoint
    let destination: CGPoint
    let showPath: Bool
    let carrying: Bool
    let placed: Bool
    let endEffectorPoint: CGPoint
    let carriedObjectPosition: CGPoint?
    let placedPosition: CGPoint?

    func withCarriedObjectPosition(_ point: CGPoint?) -> Pose {
        Pose(
            shoulder: shoulder,
            elbow: elbow,
            wrist: wrist,
            gripper: gripper,
            target: target,
            destination: destination,
            showPath: showPath,
            carrying: carrying,
            placed: placed,
            endEffectorPoint: endEffectorPoint,
            carriedObjectPosition: point,
            placedPosition: placedPosition
        )
    }

    func withPlacedPosition(_ point: CGPoint?) -> Pose {
        Pose(
            shoulder: shoulder,
            elbow: elbow,
            wrist: wrist,
            gripper: gripper,
            target: target,
            destination: destination,
            showPath: showPath,
            carrying: carrying,
            placed: placed,
            endEffectorPoint: endEffectorPoint,
            carriedObjectPosition: carriedObjectPosition,
            placedPosition: point
        )
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
