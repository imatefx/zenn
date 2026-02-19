import Foundation
import ZennShared

/// Operations that mutate the tiling tree.
public enum TreeOperations {
    /// Insert a new window into the tree. If the tree is empty, creates a root container.
    /// If a focused window exists, splits the focused window's space.
    /// - Parameters:
    ///   - root: The current root container (may be nil if tree is empty).
    ///   - window: The window node to insert.
    ///   - focusedWindowID: The currently focused window to split next to.
    ///   - axis: The split axis for the new container.
    /// - Returns: The (possibly new) root container.
    @discardableResult
    public static func insertWindow(
        root: ContainerNode?,
        window: WindowNode,
        nearWindowID focusedWindowID: WindowID?,
        axis: SplitAxis = .horizontal
    ) -> ContainerNode {
        // Empty tree: create root container with just this window
        if root == nil {
            let newRoot = ContainerNode(axis: axis)
            newRoot.appendChild(.window(window))
            return newRoot
        }

        let rootContainer = root!

        // No focused window or focused window not found: append to root
        guard let focusedID = focusedWindowID,
              let (parentContainer, childIndex) = TreeTraversal.findWindowLocation(
                  in: rootContainer, windowID: focusedID
              ) else {
            rootContainer.appendChild(.window(window))
            return rootContainer
        }

        // If same axis as parent, just insert next to focused window
        if parentContainer.axis == axis {
            parentContainer.insertChild(.window(window), at: childIndex + 1)
            return rootContainer
        }

        // Different axis: need to create a new sub-container
        // But check depth limit first
        if parentContainer.depth + 1 >= ContainerNode.maxDepth {
            // At max depth, just insert next to focused in current container
            parentContainer.insertChild(.window(window), at: childIndex + 1)
            return rootContainer
        }

        // Replace the focused window with a new container holding both
        let existingChild = parentContainer.removeChild(at: childIndex)
        let newContainer = ContainerNode(axis: axis, parent: parentContainer)
        newContainer.appendChild(existingChild)
        newContainer.appendChild(.window(window))
        parentContainer.insertChild(.container(newContainer), at: childIndex)

        return rootContainer
    }

    /// Remove a window from the tree.
    /// - Returns: The updated root (may be nil if tree is now empty), and the removed window node.
    public static func removeWindow(
        root: ContainerNode,
        windowID: WindowID
    ) -> (root: ContainerNode?, removed: WindowNode?) {
        guard let (parentContainer, childIndex) = TreeTraversal.findWindowLocation(
            in: root, windowID: windowID
        ) else {
            return (root, nil)
        }

        guard case .window(let windowNode) = parentContainer.children[childIndex] else {
            return (root, nil)
        }

        parentContainer.removeChild(at: childIndex)

        // Normalize: if this container now has zero children, remove it from its parent
        // If it has one child, collapse it
        let normalizedRoot = TreeNormalization.normalize(root: root)
        return (normalizedRoot, windowNode)
    }

    /// Swap two windows in the tree.
    public static func swapWindows(
        root: ContainerNode,
        windowA: WindowID,
        windowB: WindowID
    ) -> Bool {
        guard let (parentA, indexA) = TreeTraversal.findWindowLocation(in: root, windowID: windowA),
              let (parentB, indexB) = TreeTraversal.findWindowLocation(in: root, windowID: windowB)
        else {
            return false
        }

        let childA = parentA.children[indexA]
        let childB = parentB.children[indexB]

        parentA.replaceChild(at: indexA, with: childB)
        parentB.replaceChild(at: indexB, with: childA)

        return true
    }

    /// Resize the focused window along an axis.
    /// - right/up = grow, left/down = shrink.
    /// - The direction's axis determines which container to resize in.
    /// - delta is always positive; the direction determines sign.
    public static func resizeWindow(
        root: ContainerNode,
        windowID: WindowID,
        direction: Direction,
        delta: CGFloat
    ) -> Bool {
        guard let (parentContainer, childIndex) = TreeTraversal.findWindowLocation(
            in: root, windowID: windowID
        ) else {
            return false
        }

        // Find the container whose axis matches the direction
        var container = parentContainer
        var idx = childIndex

        // Walk up the tree to find a container with the matching axis
        while container.axis != direction.axis {
            guard let grandparent = container.parent,
                  let containerIdx = grandparent.indexOfChild(id: container.id) else {
                return false
            }
            container = grandparent
            idx = containerIdx
        }

        // right/up = grow (+delta), left/down = shrink (-delta)
        let isGrow = (direction == .right || direction == .up)
        let effectiveDelta = isGrow ? delta : -delta

        // Pick a neighbor to exchange ratio with (prefer idx+1, fall back to idx-1)
        var neighborIdx = idx + 1
        if neighborIdx >= container.ratios.count {
            neighborIdx = idx - 1
        }
        guard neighborIdx >= 0, neighborIdx < container.ratios.count else {
            return false
        }

        // Clamp so neither ratio goes below a minimum
        let minRatio: CGFloat = 0.1
        let actualDelta = min(
            max(effectiveDelta, minRatio - container.ratios[idx]),
            container.ratios[neighborIdx] - minRatio
        )

        container.ratios[idx] += actualDelta
        container.ratios[neighborIdx] -= actualDelta

        return true
    }

    /// Merge a window with a neighbor into a new sub-container.
    /// The focused window is removed from its position and placed alongside
    /// the neighbor in a new sub-container with perpendicular axis.
    ///
    /// Example: Given `H[A, B, C]` with C focused, mergeLeft produces `H[A, V[B, C]]`.
    public static func mergeWindows(
        root: ContainerNode,
        sourceWindowID: WindowID,
        targetWindowID: WindowID
    ) -> Bool {
        // Find both windows in the tree
        guard let (sourceParent, sourceIndex) = TreeTraversal.findWindowLocation(
            in: root, windowID: sourceWindowID
        ) else { return false }

        guard let (targetParent, _) = TreeTraversal.findWindowLocation(
            in: root, windowID: targetWindowID
        ) else { return false }

        // Check depth limit at the target location
        if targetParent.depth + 1 >= ContainerNode.maxDepth {
            print("[Zenn] Merge: at max depth, cannot create sub-container")
            return false
        }

        // Remove the source window from its current position
        let sourceChild = sourceParent.removeChild(at: sourceIndex)

        // Re-find target after removal (indices may have shifted if same parent)
        guard let (newTargetParent, newTargetIndex) = TreeTraversal.findWindowLocation(
            in: root, windowID: targetWindowID
        ) else {
            // Put source back if we can't find target anymore
            sourceParent.insertChild(sourceChild, at: min(sourceIndex, sourceParent.children.count))
            return false
        }

        // Create a new sub-container with the perpendicular axis
        let perpendicularAxis: SplitAxis = newTargetParent.axis == .horizontal ? .vertical : .horizontal

        // Remove the target window, replace with sub-container holding both
        let targetChild = newTargetParent.removeChild(at: newTargetIndex)
        let newContainer = ContainerNode(axis: perpendicularAxis, parent: newTargetParent)
        newContainer.appendChild(targetChild)
        newContainer.appendChild(sourceChild)
        newTargetParent.insertChild(.container(newContainer), at: newTargetIndex)

        // Normalize the tree
        _ = TreeNormalization.normalize(root: root)

        return true
    }

    /// Eject a window from its sub-container up to the grandparent level.
    /// This is the inverse of merge — it promotes a window out of a nested split.
    ///
    /// Example: Given `H[A, V[B, C]]` with C focused, eject produces `H[A, B, C]`.
    /// Returns false if the window is already at the root level (no sub-container to eject from).
    public static func ejectWindow(
        root: ContainerNode,
        windowID: WindowID
    ) -> Bool {
        guard let (parentContainer, childIndex) = TreeTraversal.findWindowLocation(
            in: root, windowID: windowID
        ) else { return false }

        // If parent is the root, there's nowhere to eject to
        guard let grandparent = parentContainer.parent else {
            print("[Zenn] Eject: window is already at root level")
            return false
        }

        // Find where the parent container sits in the grandparent
        guard let parentIndex = grandparent.indexOfChild(id: parentContainer.id) else {
            return false
        }

        // Remove the window from its current parent
        let child = parentContainer.removeChild(at: childIndex)

        // Insert it into the grandparent right after the parent container
        grandparent.insertChild(child, at: parentIndex + 1)

        // Normalize — this will collapse the parent container if it now has only one child
        _ = TreeNormalization.normalize(root: root)

        return true
    }

    /// Apply a resize preset to the root container's ratios.
    public static func applyPreset(root: ContainerNode, preset: ResizePreset) {
        guard root.children.count == 2 else { return }

        switch preset {
        case .equal:
            root.ratios = [0.5, 0.5]
        case .masterLg:
            root.ratios = [0.6, 0.4]
        case .masterXl:
            root.ratios = [0.7, 0.3]
        }
    }
}
