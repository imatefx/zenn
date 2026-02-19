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

    /// Resize the split ratio between a window and its sibling.
    /// - Parameters:
    ///   - delta: The amount to change the ratio by (positive = grow, negative = shrink).
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

        // Determine which neighbor to resize against
        let neighborIdx: Int
        if direction.isPositive {
            neighborIdx = idx + 1
        } else {
            neighborIdx = idx - 1
        }

        guard neighborIdx >= 0, neighborIdx < container.ratios.count else {
            return false
        }

        // Clamp delta so neither ratio goes below a minimum
        let minRatio: CGFloat = 0.1
        let actualDelta = min(
            max(delta, minRatio - container.ratios[idx]),
            container.ratios[neighborIdx] - minRatio
        )

        container.ratios[idx] += actualDelta
        container.ratios[neighborIdx] -= actualDelta

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
