//! This file provides the autograd engine functionality for micrograd

const std = @import("std");

/// Represents an auto-differentiable Scalar value
///
/// This is a generic type that can be used to create a scalar-valued value.
///
/// # Example
/// ```zig
/// const Value = @import("engine").Value;
/// const value = Value(f32).new(2.0);
/// ```
///
/// # Operations
///
/// The Value type supports the following operations:
///
/// - Addition
pub fn Value(comptime T: type) type {
    if (@typeInfo(T) != .int and @typeInfo(T) != .float) {
        @compileError("Expected @int or @float type, got: " ++ @typeName(T));
    }

    return struct {
        const Self = @This();
        /// The value
        data: T,
        /// The gradient
        grad: T,
        /// Function for backpropagation
        backward: *const fn (self: *Self) void,
        /// The children used to compute the value
        prev: ?[]*Self,
        /// The operation that produced the value
        op: ?[]const u8,
        /// The label of the value
        label: ?[]const u8,

        /// Initialize the Value
        pub fn init(data: T, prev: ?[]*Self, op: ?[]const u8, label: ?[]const u8) Self {
            return Self{
                .data = data,
                .grad = @as(T, 0),
                .backward = &noOpBackward,
                .prev = prev,
                .op = op,
                .label = label,
            };
        }

        /// No-op backward function
        fn noOpBackward(self: *Self) void {
            _ = self;
        }

        /// Convert the Value to a string
        pub fn toString(self: Self) []const u8 {
            const op_name = if (self.op) |op| op else "null";
            const label_name = if (self.label) |label| label else "null";

            const prev_str = if (self.prev) |children| blk: {
                var result = std.ArrayList(u8).init(std.heap.page_allocator);
                result.appendSlice("[") catch unreachable;

                for (children, 0..) |child, i| {
                    if (i > 0) result.appendSlice(", ") catch unreachable;
                    result.appendSlice(child.toString()) catch unreachable;
                }

                result.appendSlice("]") catch unreachable;
                break :blk result.toOwnedSlice() catch unreachable;
            } else "null";

            return std.fmt.allocPrint(std.heap.page_allocator, "Value(data={any}, grad={any}, prev={s}, op={s}, label={s})", .{ self.data, self.grad, prev_str, op_name, label_name }) catch unreachable;
        }

        pub fn add(self: *Self, other: *Self, allocator: std.mem.Allocator, label: ?[]const u8) !Self {
            return Self{
                .data = self.data + other.data,
                .grad = @as(T, 0),
                .backward = struct {
                    fn call(result: *Self) void {
                        if (result.prev) |children| {
                            children[0].grad += result.grad;
                            children[1].grad += result.grad;
                        }
                    }
                }.call,
                .prev = try allocator.dupe(*Self, &.{ self, other }),
                .op = "+",
                .label = label,
            };
        }

        pub fn mul(self: *Self, other: *Self, allocator: std.mem.Allocator, label: ?[]const u8) !Self {
            return Self{
                .data = self.data * other.data,
                .grad = @as(T, 0),
                .backward = struct {
                    fn call(result: *Self) void {
                        if (result.prev) |children| {
                            children[0].grad += children[1].data * result.grad;
                            children[1].grad += children[0].data * result.grad;
                        }
                    }
                }.call,
                .prev = try allocator.dupe(*Self, &.{ self, other }),
                .op = "*",
                .label = label,
            };
        }

        /// Subtract two values
        pub fn sub(self: *Self, other: *Self, allocator: std.mem.Allocator, label: ?[]const u8) !Self {
            return Self{
                .data = self.data - other.data,
                .grad = @as(T, 0),
                .backward = struct {
                    fn call(result: *Self) void {
                        if (result.prev) |children| {
                            children[0].grad += result.grad;
                            children[1].grad -= result.grad;
                        }
                    }
                }.call,
                .prev = try allocator.dupe(*Self, &.{ self, other }),
                .op = "-",
                .label = label,
            };
        }

        /// Divide two values
        pub fn div(self: *Self, other: *Self, allocator: std.mem.Allocator, label: ?[]const u8) !Self {
            return Self{
                .data = self.data / other.data,
                .grad = @as(T, 0),
                .backward = struct {
                    fn call(result: *Self) void {
                        if (result.prev) |children| {
                            children[0].grad += result.grad / other.data;
                            children[1].grad -= result.grad * self.data / (other.data * other.data);
                        }
                    }
                }.call,
                .prev = try allocator.dupe(*Self, &.{ self, other }),
                .op = "/",
                .label = label,
            };
        }

        pub fn relu(self: *Self, allocator: std.mem.Allocator, label: ?[]const u8) !Self {
            return Self{
                .data = if (self.data > 0) self.data else @as(T, 0),
                .grad = @as(T, 0),
                .backward = struct {
                    fn call(result: *Self) void {
                        if (result.prev) |children| {
                            children[0].grad += result.grad * (self.data > @as(T, 0));
                        }
                    }
                }.call,
                .prev = try allocator.dupe(*Self, &.{self}),
                .op = "ReLU",
                .label = label,
            };
        }

        pub fn softmax(self: *Self, allocator: std.mem.Allocator, label: ?[]const u8) !Self {
            return Self{
                .data = std.math.exp(self.data),
                .grad = @as(T, 0),
                .backward = struct {
                    fn call(result: *Self) void {
                        if (result.prev) |children| {
                            children[0].grad += result.grad;
                        }
                    }
                }.call,
                .prev = try allocator.dupe(*Self, &.{self}),
                .op = "Softmax",
                .label = label,
            };
        }

        /// Generate Graphviz DOT format representation of the computational graph
        pub fn draw_dot(self: *Self, writer: anytype, allocator: std.mem.Allocator) !void {
            // First, trace all nodes and edges in the graph
            var visited = std.AutoHashMap(*Self, bool).init(allocator);
            defer visited.deinit();

            var nodes = std.ArrayList(*Self).init(allocator);
            defer nodes.deinit();

            var edges = std.ArrayList([2]*Self).init(allocator);
            defer edges.deinit();

            try trace(self, &visited, &nodes, &edges);

            // Write DOT format
            try writer.writeAll("digraph {\n");
            try writer.writeAll("  rankdir=LR;\n");

            // Create nodes
            for (nodes.items) |node| {
                const node_id = @intFromPtr(node);
                const label_str = if (node.label) |label| label else "";
                const data_str = try std.fmt.allocPrint(allocator, "{d:.4}", .{node.data});
                const grad_str = try std.fmt.allocPrint(allocator, "{d:.4}", .{node.grad});
                defer allocator.free(data_str);
                defer allocator.free(grad_str);

                try writer.print("  \"{}\" [label=\"{{{s} | data {s} | grad {s}}}\", shape=record];\n", .{ node_id, label_str, data_str, grad_str });

                // If this value is a result of some operation, create an op node for it
                if (node.op) |op| {
                    const op_id = try std.fmt.allocPrint(allocator, "{}op", .{node_id});
                    defer allocator.free(op_id);
                    try writer.print("  \"{s}\" [label=\"{s}\"];\n", .{ op_id, op });
                    try writer.print("  \"{s}\" -> \"{}\";\n", .{ op_id, node_id });
                }
            }

            // Create edges
            for (edges.items) |edge| {
                const n1_id = @intFromPtr(edge[0]);
                const n2_id = @intFromPtr(edge[1]);
                if (edge[1].op) |_| {
                    const op_id = try std.fmt.allocPrint(allocator, "{}op", .{n2_id});
                    defer allocator.free(op_id);
                    try writer.print("  \"{}\" -> \"{s}\";\n", .{ n1_id, op_id });
                }
            }

            try writer.writeAll("}\n");
        }

        /// Helper function to trace all nodes and edges in the computational graph
        fn trace(root: *Self, visited: *std.AutoHashMap(*Self, bool), nodes: *std.ArrayList(*Self), edges: *std.ArrayList([2]*Self)) !void {
            if (visited.contains(root)) return;

            try visited.put(root, true);
            try nodes.append(root);

            if (root.prev) |children| {
                for (children) |child| {
                    try edges.append(.{ child, root });
                    try trace(child, visited, nodes, edges);
                }
            }
        }

        /// Build a topological ordering of the computational graph using Depth-First Search (DFS)
        fn buildTopo(self: *Self, topo: *std.ArrayList(*Self), visited: *std.AutoHashMap(*Self, void)) !void {
            if (visited.contains(self)) {
                return;
            }

            try visited.put(self, {});

            if (self.prev) |children| {
                for (children) |child| {
                    try child.buildTopo(topo, visited);
                }
            }

            try topo.append(self);
        }

        /// Backward pass - topological sort and gradient computation
        pub fn backwardPass(self: *Self, allocator: std.mem.Allocator) !void {
            // Topological ordering
            var topo = std.ArrayList(*Self).init(allocator);
            defer topo.deinit();

            var visited = std.AutoHashMap(*Self, void).init(allocator);
            defer visited.deinit();

            try self.buildTopo(&topo, &visited);

            // Apply chain rule
            self.grad = @as(T, 1);

            // Reverse the topo list and call backward on each node
            const items = topo.items;
            var i = items.len;
            while (i > 0) {
                i -= 1;
                items[i].backward(items[i]);
            }
        }
    };
}
