import Foundation
import ZennShared

/// An internal node in the tiling tree that contains children arranged along an axis.
public class ContainerNode {
    public let id: NodeID

    /// The axis along which children are arranged.
    public var axis: SplitAxis

    /// The proportion of space each child occupies. Must sum to ~1.0 and have same count as children.
    public var ratios: [CGFloat]

    /// The child nodes (containers or windows).
    public var children: [TreeNode]

    /// Weak reference to the parent container (nil for root).
    public weak var parent: ContainerNode?

    /// Maximum allowed depth for the tree.
    public static let maxDepth = 5

    public init(
        id: NodeID = NodeID(),
        axis: SplitAxis = .horizontal,
        ratios: [CGFloat] = [],
        children: [TreeNode] = [],
        parent: ContainerNode? = nil
    ) {
        self.id = id
        self.axis = axis
        self.ratios = ratios
        self.children = children
        self.parent = parent
    }

    /// The depth of this container in the tree.
    public var depth: Int {
        var d = 0
        var current = parent
        while let p = current {
            d += 1
            current = p.parent
        }
        return d
    }

    /// Whether adding another level of nesting would exceed the max depth.
    public var isAtMaxDepth: Bool {
        depth >= ContainerNode.maxDepth
    }

    /// Find the index of a child node by its ID.
    public func indexOfChild(id: NodeID) -> Int? {
        children.firstIndex(where: { $0.id == id })
    }

    /// Find the index of a child that contains the given window ID.
    public func indexOfChildContaining(windowID: WindowID) -> Int? {
        children.firstIndex(where: { $0.allWindowIDs.contains(windowID) })
    }

    /// Insert a child at the given index, with equal ratio redistribution.
    public func insertChild(_ child: TreeNode, at index: Int) {
        var mutableChild = child
        mutableChild.setParent(self)
        children.insert(mutableChild, at: index)
        equalizeRatios()
    }

    /// Append a child, with equal ratio redistribution.
    public func appendChild(_ child: TreeNode) {
        var mutableChild = child
        mutableChild.setParent(self)
        children.append(mutableChild)
        equalizeRatios()
    }

    /// Remove the child at the given index, with ratio redistribution.
    @discardableResult
    public func removeChild(at index: Int) -> TreeNode {
        var child = children.remove(at: index)
        child.setParent(nil)
        if !children.isEmpty {
            equalizeRatios()
        } else {
            ratios = []
        }
        return child
    }

    /// Remove a child by its node ID.
    @discardableResult
    public func removeChild(id: NodeID) -> TreeNode? {
        guard let index = indexOfChild(id: id) else { return nil }
        return removeChild(at: index)
    }

    /// Replace the child at the given index with a new node.
    public func replaceChild(at index: Int, with newChild: TreeNode) {
        var mutableChild = newChild
        mutableChild.setParent(self)
        children[index] = mutableChild
    }

    /// Redistribute ratios equally among all children.
    public func equalizeRatios() {
        let count = children.count
        guard count > 0 else {
            ratios = []
            return
        }
        let ratio = 1.0 / CGFloat(count)
        ratios = Array(repeating: ratio, count: count)
    }

    /// All window IDs in this container's subtree.
    public var allWindowIDs: [WindowID] {
        TreeNode.container(self).allWindowIDs
    }

    /// Count of all windows in this container's subtree.
    public var windowCount: Int {
        TreeNode.container(self).windowCount
    }

    /// All window nodes in this container's subtree.
    public var allWindowNodes: [WindowNode] {
        TreeNode.container(self).allWindowNodes
    }

    /// Update parent references for all children to point to this container.
    public func fixupChildParents() {
        for i in children.indices {
            children[i].setParent(self)
        }
    }
}

extension ContainerNode: CustomStringConvertible {
    public var description: String {
        "ContainerNode(\(id), \(axis), children=\(children.count), depth=\(depth))"
    }
}
