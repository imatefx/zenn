import Foundation
import ZennShared

/// Normalization rules applied after every tree mutation to keep the tree clean.
public enum TreeNormalization {
    /// Normalize the tree by applying all rules. Returns the new root (may differ from input).
    public static func normalize(root: ContainerNode) -> ContainerNode? {
        // 1. Remove empty containers
        removeEmptyContainers(in: root)

        // 2. Flatten single-child containers
        let newRoot = flattenSingleChildContainers(root: root)

        // 3. Merge same-axis nested containers
        if let r = newRoot {
            mergeSameAxisContainers(in: r)
            r.fixupChildParents()
            return r
        }

        return newRoot
    }

    /// Remove containers that have no children.
    private static func removeEmptyContainers(in container: ContainerNode) {
        // Process children first (bottom-up)
        for child in container.children {
            if case .container(let childContainer) = child {
                removeEmptyContainers(in: childContainer)
            }
        }

        // Remove empty container children
        var indicesToRemove: [Int] = []
        for (index, child) in container.children.enumerated() {
            if case .container(let childContainer) = child, childContainer.children.isEmpty {
                indicesToRemove.append(index)
            }
        }

        // Remove in reverse order to maintain indices
        if !indicesToRemove.isEmpty {
            for index in indicesToRemove.reversed() {
                container.children.remove(at: index)
            }
            if !container.children.isEmpty {
                container.equalizeRatios()
            }
        }
    }

    /// Flatten containers that have exactly one child — replace the container with its child.
    /// Returns the new root (may be the same or different).
    private static func flattenSingleChildContainers(root: ContainerNode) -> ContainerNode? {
        // If root has no children, tree is empty
        if root.children.isEmpty {
            return nil
        }

        // If root has exactly one child that is a container, promote it
        if root.children.count == 1, case .container(let onlyChild) = root.children[0] {
            onlyChild.parent = root.parent
            return flattenSingleChildContainers(root: onlyChild)
        }

        // Process children recursively
        for (index, child) in root.children.enumerated() {
            if case .container(let childContainer) = child {
                if childContainer.children.count == 1 {
                    // Replace this container with its only child
                    let grandchild = childContainer.children[0]
                    root.replaceChild(at: index, with: grandchild)
                } else {
                    _ = flattenSingleChildContainers(root: childContainer)
                }
            }
        }

        return root
    }

    /// Merge containers that have the same axis as their parent.
    /// e.g., H[H[a, b], c] → H[a, b, c]
    private static func mergeSameAxisContainers(in container: ContainerNode) {
        var merged = true

        // Keep merging until no more changes
        while merged {
            merged = false
            var newChildren: [TreeNode] = []
            var newRatios: [CGFloat] = []

            for (index, child) in container.children.enumerated() {
                if case .container(let childContainer) = child,
                   childContainer.axis == container.axis {
                    // Merge this child's children into our level
                    let parentRatio = container.ratios.indices.contains(index) ? container.ratios[index] : (1.0 / CGFloat(container.children.count))
                    for (subIndex, grandchild) in childContainer.children.enumerated() {
                        var mutableGrandchild = grandchild
                        mutableGrandchild.setParent(container)
                        newChildren.append(mutableGrandchild)
                        let subRatio = childContainer.ratios.indices.contains(subIndex) ? childContainer.ratios[subIndex] : (1.0 / CGFloat(childContainer.children.count))
                        newRatios.append(parentRatio * subRatio)
                    }
                    merged = true
                } else {
                    newChildren.append(child)
                    let ratio = container.ratios.indices.contains(index) ? container.ratios[index] : (1.0 / CGFloat(container.children.count))
                    newRatios.append(ratio)
                }
            }

            container.children = newChildren
            container.ratios = newRatios
        }

        // Normalize ratios to sum to 1.0
        let total = container.ratios.reduce(0, +)
        if total > 0 && abs(total - 1.0) > 0.001 {
            container.ratios = container.ratios.map { $0 / total }
        }

        // Recursively process children
        for child in container.children {
            if case .container(let childContainer) = child {
                mergeSameAxisContainers(in: childContainer)
            }
        }
    }
}
