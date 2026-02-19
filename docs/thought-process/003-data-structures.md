# Thought Process: Data Structures

## The Tiling Tree

The central data structure in Zenn is the tiling tree: a rooted tree where internal nodes are containers (splits) and leaf nodes are windows. Every workspace has its own tree.

### Options Considered

1. **Fixed layout algorithms** (master-stack, columns, grid). Like Amethyst. Simple to implement but inflexible. Users cannot arrange windows in arbitrary configurations.

2. **Binary split tree (strict binary).** Every container has exactly 2 children. Each split divides space in two. Like i3's approach.

3. **N-ary split tree.** Containers can hold N children along an axis, each with its own ratio. This is what Zenn implements.

4. **Constraint-based layout.** Define relationships between windows (e.g., "A is left of B, B is above C") and solve for positions. Powerful but complex and hard to make interactive.

### Decision: N-ary Split Tree

The N-ary tree generalizes the binary split: a horizontal container with 3 children produces a 3-column layout, which is a natural and common arrangement. If the tree were strictly binary, 3 columns would require a nested structure like `H[A, H[B, C]]`, which complicates ratio management and user comprehension.

However, nesting is still supported. A horizontal container can contain a vertical sub-container:

```
H[A, V[B, C]]
```

This produces:

```
+-------+-------+
|       |   B   |
|   A   +-------+
|       |   C   |
+-------+-------+
```

## Node Types

### TreeNode (Enum)

```swift
public indirect enum TreeNode {
    case container(ContainerNode)
    case window(WindowNode)
}
```

Using an `indirect enum` for the tree node type was a deliberate choice over a protocol-based approach (`protocol TreeNodeProtocol`). The enum provides exhaustive switch matching, which ensures every traversal and mutation handles both cases. A protocol would allow adding new node types (questionable value) but would require dynamic dispatch and `as?` casts.

The `indirect` keyword is required because `TreeNode.container` holds a `ContainerNode` which holds `[TreeNode]`, creating a recursive type. Swift's `indirect enum` handles this by heap-allocating the enum payload.

### ContainerNode (Class)

```swift
public class ContainerNode {
    public let id: NodeID
    public var axis: SplitAxis        // horizontal or vertical
    public var ratios: [CGFloat]      // one per child, sum to 1.0
    public var children: [TreeNode]   // ordered list of children
    public weak var parent: ContainerNode?
}
```

`ContainerNode` is a `class` (reference type) because:
- Nodes need parent pointers for upward traversal (resize walks up to find a matching axis). Parent pointers require reference semantics; value types cannot have `weak` references to themselves.
- Tree mutations are in-place. `insertChild`, `removeChild`, and `replaceChild` modify the container's `children` array directly. With value types, every mutation would require rebuilding the tree from the root.

### WindowNode (Class)

```swift
public class WindowNode {
    public let id: NodeID
    public let windowID: WindowID
    public let appBundleID: String
    public let appName: String
    public var windowTitle: String
    public weak var parent: ContainerNode?
}
```

Window nodes are leaves. They store just enough identity information to map back to the full `WindowState` in the `WindowRegistry`. The `windowTitle` is mutable because window titles change frequently (e.g., a browser tab title).

## Ratios

Each `ContainerNode` stores a `ratios` array with one entry per child. The ratios represent the fraction of the container's dimension (width for horizontal, height for vertical) that each child occupies.

**Invariant:** `ratios.count == children.count` and `sum(ratios) ~= 1.0`.

When a child is added or removed, `equalizeRatios()` redistributes ratios equally. The user can then adjust ratios via the resize operation.

**Why not store absolute pixel sizes?** Ratios are resolution-independent. When a monitor's frame changes (e.g., resolution change, display reconfiguration), the layout engine recalculates pixel positions from ratios without needing to update the tree.

**Minimum ratio:** 0.1 (10%). This prevents a window from being resized to zero width/height.

## Depth Cap

```swift
public static let maxDepth = 5
```

The tree has a maximum depth of 5 levels. This is enforced in `TreeOperations.insertWindow`: when the target container is at or beyond `maxDepth`, the new window is inserted as a sibling instead of creating a new sub-container.

**Why 5?** At depth 5, the tree can theoretically represent up to 2^5 = 32 windows in a fully balanced binary configuration. In practice, most users have 3-8 windows per workspace. Depth 5 allows for complex layouts (e.g., 3 columns with 2 rows each) without permitting degenerate structures that would produce invisible slivers.

**What happens at the cap?** If the user tries to split a window at depth 5, the new window becomes a sibling of the focused window in the same container. The split axis matches the current container's axis rather than the requested axis. This is a graceful degradation: the window still appears, it just does not create a new nesting level.

## Normalization

After every tree mutation (insert, remove, swap), the `TreeNormalization` pass runs. It applies three rules in order:

### Rule 1: Remove Empty Containers

A container with zero children is removed from its parent. This happens when all windows in a sub-tree are closed.

```
Before: H[A, V[]]  ->  After: H[A]  ->  (further normalized to just A)
```

### Rule 2: Flatten Single-Child Containers

A container with exactly one child is replaced by that child. The container serves no structural purpose.

```
Before: H[V[A]]  ->  After: A
```

For the root: if the root container has exactly one child that is also a container, the child is promoted to root:

```
Before: Root=H[V[A, B]]  ->  After: Root=V[A, B]
```

### Rule 3: Merge Same-Axis Containers

A container whose child has the same axis is merged: the grandchildren are promoted to be direct children of the parent.

```
Before: H[H[A, B], C]  ->  After: H[A, B, C]
```

Ratios are proportionally adjusted. If the parent had ratios `[0.5, 0.5]` and the child had `[0.6, 0.4]`, the merged ratios become `[0.3, 0.2, 0.5]` (the child's ratios are scaled by its parent ratio).

**Why merge?** Without merging, repeated splits in the same direction would create unnecessary nesting. For example, opening 4 terminals side-by-side would create `H[A, H[B, H[C, D]]]` (depth 3) instead of `H[A, B, C, D]` (depth 1). Merging keeps the tree flat when possible.

## Traversal

`TreeTraversal` provides read-only search operations:

- `findWindowLocation(in:windowID:)` -> `(ContainerNode, Int)?`: Find the parent container and child index for a window. Used by all mutation operations.
- `findWindowNode(in:windowID:)` -> `WindowNode?`: Find a window node by ID.
- `allWindows(in:)` -> `[WindowNode]`: In-order traversal for cycle navigation.
- `findNeighbor(in:from:direction:frames:)` -> `WindowNode?`: Geometric nearest-neighbor search for directional focus.

### Directional Focus Algorithm

The `findNeighbor` function uses geometric position rather than tree structure to determine neighbors. This is important because the tree structure does not always correspond to visual adjacency (after swaps or complex nesting).

For each candidate window:
1. Check if the candidate's center is in the correct direction from the source window's center.
2. Calculate a weighted Manhattan distance. For horizontal directions (left/right), horizontal distance is weighted 1x and vertical distance is weighted 0.5x. This biases toward windows that are directly to the left/right rather than diagonally offset.
3. The candidate with the smallest weighted distance wins.

This is the same approach used by i3 and sway. Tree-based traversal (sibling, uncle, cousin) was considered but rejected because it produces unintuitive results when the tree structure diverges from the visual layout.

## Frame Calculation

`FrameCalculator` recursively walks the tree and divides space according to each container's axis and ratios.

For a horizontal container with available frame `(x, y, w, h)` and ratios `[r0, r1, r2]`:
- Child 0 gets `(x, y, w*r0, h)`
- Child 1 gets `(x + w*r0, y, w*r1, h)`
- Child 2 gets `(x + w*r0 + w*r1, y, w*r2, h)`

For vertical containers, the same logic applies along the Y axis.

At leaf nodes (windows), the `GapCalculator` insets the frame by half the inner gap on each side, producing the final window frame.

The outer gap is applied once at the top level: the available frame passed to `FrameCalculator` is already inset from the monitor's visible frame by the outer gap amounts.

## WorldState Hierarchy

```
WorldState
  +-- monitors: OrderedDictionary<DisplayID, Monitor>
  |     +-- Monitor
  |           +-- displayID: DisplayID
  |           +-- frame: Rect
  |           +-- visibleFrame: Rect
  |           +-- gaps: GapConfig
  |           +-- workspaces: OrderedDictionary<Int, Workspace>
  |                 +-- Workspace
  |                       +-- id: WorkspaceID
  |                       +-- tileRoot: ContainerNode?
  |                       |     +-- (recursive tree)
  |                       +-- focusedWindowID: WindowID?
  |                       +-- layoutMode: LayoutMode
  |                       +-- gapOverride: GapConfig?
  |                       +-- defaultSplitAxis: SplitAxis
  +-- windowRegistry: WindowRegistry
  |     +-- windows: [WindowID: WindowState]
  +-- focusedWindowID: WindowID?
  +-- globalGaps: GapConfig
  +-- windowRules: [WindowRule]
```

`OrderedDictionary` (from swift-collections) is used for monitors and workspaces to maintain insertion/creation order while providing O(1) key lookup. Monitors are ordered by `DisplayID` (primary monitor first). Workspaces are ordered by number (1 through 9).

The `WindowRegistry` provides a flat O(1) lookup by `WindowID` that is independent of which workspace/tree the window is in. This is essential for event handling: when an Accessibility callback fires with a `CGWindowID`, we need to immediately find the `WindowState` without traversing all trees on all workspaces.
