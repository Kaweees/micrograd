//! This file provides the autograd engine functionality for micrograd

const std = @import("std");

/// The type of expression
pub const ExprType = enum {
    nop,
    unary,
    binary,
};

pub const UnaryType = enum {
    tanh,
    exp,
    relu,
    softmax,

    pub fn toString(self: UnaryType) []const u8 {
        return switch (self) {
            .tanh => "tanh",
            .exp => "exp",
            .relu => "ReLU",
            .softmax => "Softmax",
        };
    }
};

pub const BinaryType = enum {
    add,
    sub,
    mul,
    div,

    pub fn toString(self: BinaryType) []const u8 {
        return switch (self) {
            .add => "+",
            .sub => "-",
            .mul => "*",
            .div => "/",
        };
    }
};

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
/// - Subtraction
/// - Multiplication
/// - Division
/// - Rectified Linear Unit (ReLU)
/// - Softmax
pub fn Value(comptime T: type) type {
    // Check that T is a valid type
    if (@typeInfo(T) != .int and @typeInfo(T) != .float) {
        @compileError("Expected @int or @float type, got: " ++ @typeName(T));
    }

    return struct {
        const Self = @This();
        const BackpropFn = *const fn (*Self) void;
        // const BackpropFn = *const fn (self: *Self) void;

        const Expr = union(ExprType) {
            nop: void,
            unary: struct {
                /// The unary operation that produced the value
                op: UnaryType,
                backprop_fn: BackpropFn,
                /// The children used to compute the value
                prev: [1]*Self,
            },
            binary: struct {
                /// The binary operation that produced the value
                op: BinaryType,
                backprop_fn: BackpropFn,
                /// The children used to compute the value
                prev: [2]*Self,
            },
        };

        /// The value
        data: T,
        /// The gradient
        grad: T,
        /// The expression that produced the value
        expr: Expr,

        /// The arena allocator
        var arena: std.heap.ArenaAllocator = undefined;

        /// Initialize the arena allocator
        pub fn init(alloc: std.mem.Allocator) void {
            arena = std.heap.ArenaAllocator.init(alloc);
        }

        /// Deinitialize the arena allocator
        pub fn deinit() void {
            arena.deinit();
        }

        /// Create a new Value with no expression
        pub fn new(value: T) *Self {
            return create(value, .{ .nop = {} });
        }

        /// Create a new Value with an expression
        fn create(value: T, expr: Expr) *Self {
            const v = arena.allocator().create(Self) catch unreachable;
            v.* = Self{ .data = value, .grad = @as(T, 0), .expr = expr };
            return v;
        }

        // Create a new Value with an unary expression
        fn unary(value: T, op: UnaryType, backprop_fn: BackpropFn, arg0: *Self) *Self {
            return create(value, Expr{
                .unary = .{
                    .op = op,
                    .backprop_fn = backprop_fn,
                    .prev = [1]*Self{arg0},
                },
            });
        }

        // Create a new Value with a binary expression
        fn binary(value: T, op: BinaryType, backprop_fn: BackpropFn, arg0: *Self, arg1: *Self) *Self {
            return create(value, Expr{
                .binary = .{
                    .op = op,
                    .backprop_fn = backprop_fn,
                    .prev = [2]*Self{ arg0, arg1 },
                },
            });
        }

        /// Call the backpropagation function (if any)
        pub fn backprop(self: *Self) void {
            switch (self.expr) {
                .nop => {},
                .unary => |u| u.backprop_fn(self),
                .binary => |b| b.backprop_fn(self),
            }
        }

        /// Add two values
        pub inline fn add(self: *Self, other: *Self) *Self {
            return binary(self.data + other.data, .add, add_back, self, other);
        }

        /// Backpropagation function for addition
        fn add_back(self: *Self) void {
            self.expr.binary.prev[0].grad += self.grad;
            self.expr.binary.prev[1].grad += self.grad;
        }

        /// Multiply two values
        pub inline fn mul(self: *Self, other: *Self) *Self {
            return binary(self.data * other.data, .mul, mul_back, self, other);
        }

        /// Backpropagation function for multiplication
        fn mul_back(self: *Self) void {
            self.expr.binary.prev[0].grad += self.grad * self.expr.binary.prev[1].data;
            self.expr.binary.prev[1].grad += self.grad * self.expr.binary.prev[0].data;
        }

        /// Subtract two values
        pub inline fn sub(self: *Self, other: *Self) *Self {
            return binary(self.data - other.data, .sub, sub_back, self, other);
        }

        /// Backpropagation function for subtraction
        fn sub_back(self: *Self) void {
            self.expr.binary.prev[0].grad += self.grad;
            self.expr.binary.prev[1].grad -= self.grad;
        }

        /// Divide two values
        pub inline fn div(self: *Self, other: *Self) *Self {
            return binary(self.data / other.data, .div, div_back, self, other);
        }

        /// Backpropagation function for division
        fn div_back(self: *Self) void {
            self.expr.binary.prev[0].grad += self.grad / self.expr.binary.prev[1].data;
            self.expr.binary.prev[1].grad -= self.grad * self.expr.binary.prev[0].data / (self.expr.binary.prev[1].data * self.expr.binary.prev[1].data);
        }

        /// Apply the ReLU function to a value
        pub inline fn relu(self: *Self) *Self {
            return unary(if (self.data > 0) self.data else @as(T, 0), .relu, relu_back, self);
        }

        /// Backpropagation function for ReLU
        fn relu_back(self: *Self) void {
            self.expr.unary.prev[0].grad += if (self.data > 0) self.grad else @as(T, 0);
        }

        /// Apply the softmax function to a value
        pub inline fn softmax(self: *Self) *Self {
            return unary(std.math.exp(self.data), .softmax, softmax_back, self);
        }

        /// Backpropagation function for softmax
        fn softmax_back(self: *Self) void {
            self.expr.unary.prev[0].grad += self.grad * std.math.exp(self.data);
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
                const data_str = try std.fmt.allocPrint(allocator, "{d:.4}", .{node.data});
                const grad_str = try std.fmt.allocPrint(allocator, "{d:.4}", .{node.grad});
                defer allocator.free(data_str);
                defer allocator.free(grad_str);

                try writer.print("  \"{}\" [label=\"data {s} | grad {s}\", shape=record];\n", .{ node_id, data_str, grad_str });

                // If this value is a result of some operation, create an op node for it
                switch (node.expr) {
                    .nop => {},
                    .unary, .binary => {
                        const op_id = try std.fmt.allocPrint(allocator, "{}op", .{node_id});
                        defer allocator.free(op_id);
                        try writer.print("  \"{s}\" [label=\"{s}\"];\n", .{ op_id, switch (node.expr) {
                            .unary => node.expr.unary.op.toString(),
                            .binary => node.expr.binary.op.toString(),
                            .nop => unreachable,
                        } });
                        try writer.print("  \"{s}\" -> \"{}\";\n", .{ op_id, node_id });
                    },
                }
            }

            // Create edges
            for (edges.items) |edge| {
                const n1_id = @intFromPtr(edge[0]);
                const n2_id = @intFromPtr(edge[1]);
                const op_id = try std.fmt.allocPrint(allocator, "{}op", .{n2_id});
                defer allocator.free(op_id);
                try writer.print("  \"{}\" -> \"{s}\";\n", .{ n1_id, op_id });
            }

            try writer.writeAll("}\n");
        }

        /// Helper function to trace all nodes and edges in the computational graph
        fn trace(root: *Self, visited: *std.AutoHashMap(*Self, bool), nodes: *std.ArrayList(*Self), edges: *std.ArrayList([2]*Self)) !void {
            if (visited.contains(root)) return;

            try visited.put(root, true);
            try nodes.append(root);

            switch (root.expr) {
                .nop => {},
                .unary, .binary => {
                    for (switch (root.expr) {
                        .unary => &root.expr.unary.prev,
                        .binary => &root.expr.binary.prev,
                        .nop => unreachable,
                    }) |prev| {
                        try edges.append(.{ prev, root });
                        try trace(prev, visited, nodes, edges);
                    }
                },
            }
        }

        /// Build a topological ordering of the computational graph using Depth-First Search (DFS)
        fn buildTopo(self: *Self, topo: *std.ArrayList(*Self), visited: *std.AutoHashMap(*Self, void)) !void {
            if (visited.contains(self)) {
                return;
            }

            try visited.put(self, {});

            const prevNodes = switch (self.expr) {
                .nop => &[_]*Self{},
                .unary => |u| &u.prev,
                .binary => |b| &b.prev,
            };

            for (prevNodes) |prev| {
                try prev.buildTopo(topo, visited);
            }

            try topo.append(self);
        }

        /// Backward pass - topological sort and gradient computation
        pub fn backwardPass(self: *Self, allocator: std.mem.Allocator) void {
            // Topological ordering
            var topo = std.ArrayList(*Self).init(allocator);
            defer topo.deinit();

            var visited = std.AutoHashMap(*Self, void).init(allocator);
            defer visited.deinit();

            self.buildTopo(&topo, &visited) catch unreachable;

            // Apply chain rule
            self.grad = @as(T, 1);

            // Reverse the topo list and call backward on each node
            const items = topo.items;
            var i = items.len;
            while (i > 0) {
                i -= 1;
                items[i].backprop();
            }
        }
    };
}
