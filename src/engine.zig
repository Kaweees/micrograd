//! This file provides the autograd engine functionality for micrograd

const std = @import("std");

/// Operations supported by the engine
pub const Operation = enum(u8) {
    /// Add two values
    ADD,
    /// Subtract two values
    SUB,
    /// Multiply two values
    MUL,
    /// Divide two values
    DIV,

    /// Convert the Operation to its mathematical symbol
    pub fn toString(self: Operation) []const u8 {
        return switch (self) {
            .ADD => "+",
            .SUB => "-",
            .MUL => "*",
            .DIV => "/",
        };
    }
};

pub fn info(T: type) std.builtin.Type.Vector {
    if (@typeInfo(T) != .vector) @compileError("Expected a @Vector type got: " ++ @typeName(T));
    return @typeInfo(T).vector;
}

/// Represents a singular Scalar value
pub fn Value(comptime T: type) type {
    return struct {
        const Self = @This();
        /// The value
        data: T,
        /// The gradient
        grad: T,
        /// Function for backpropagation
        backprop: ?*const fn (self: *Self) void,
        /// The children used to compute the value
        prev: ?[]*Self,
        /// The operation that produced the value
        operation: ?Operation,
        /// The label of the value
        label: ?[]const u8,

        /// Initialize the Value
        pub fn init(data: T, prev: ?[]*Self, operation: ?Operation, label: ?[]const u8) Self {
            return Self{
                .data = data,
                .grad = 0,
                .backprop = null,
                .prev = prev,
                .operation = operation,
                .label = label,
            };
        }

        pub fn add(self: *Self, other: *Self, allocator: std.mem.Allocator) !Self {
            const children = try allocator.dupe(*Self, &.{ self, other });
            const AddBackward = struct {
                fn call(result: *Self) void {
                    if (result.prev) |prev_children| {
                        prev_children[0].grad += result.grad;
                        prev_children[1].grad += result.grad;
                    }
                }
            }.call;

            return Self{
                .data = self.data + other.data,
                .grad = 0,
                .backprop = AddBackward,
                .prev = children,
                .operation = Operation.ADD,
                .label = null,
            };
        }

        pub fn mul(self: *Self, other: *Self, allocator: std.mem.Allocator) !Self {
            const children = try allocator.dupe(*Self, &.{ self, other });
            const MulBackward = struct {
                fn call(result: *Self) void {
                    if (result.prev) |prev_children| {
                        prev_children[0].grad += prev_children[1].data * result.grad;
                        prev_children[1].grad += prev_children[0].data * result.grad;
                    }
                }
            }.call;

            return Self{
                .data = self.data * other.data,
                .grad = 0,
                .backprop = MulBackward,
                .prev = children,
                .operation = Operation.MUL,
                .label = null,
            };
        }

        pub fn backward(self: *Self) void {
            if (self.backprop) |bp| bp(self);
        }

        /// Convert the Value to a string
        pub fn toString(self: Self) []const u8 {
            const op_name = if (self.operation) |op| @tagName(op) else "null";
            const label_name = if (self.label) |label| label else "null";

            const prev_str = if (self.prev) |prev_children| blk: {
                var result = std.ArrayList(u8).init(std.heap.page_allocator);
                result.appendSlice("[") catch unreachable;

                for (prev_children, 0..) |child, i| {
                    if (i > 0) result.appendSlice(", ") catch unreachable;
                    result.appendSlice(child.toString()) catch unreachable;
                }

                result.appendSlice("]") catch unreachable;
                break :blk result.toOwnedSlice() catch unreachable;
            } else "null";

            return std.fmt.allocPrint(std.heap.page_allocator, "Value(data={any}, grad={any}, prev={s}, operation={s}, label={s})", .{ self.data, self.grad, prev_str, op_name, label_name }) catch unreachable;
        }

        /// Subtract two values
        pub fn sub(self: *Self, other: *Self, allocator: std.mem.Allocator) !Self {
            const children = try allocator.dupe(*Self, &.{ self, other });
            const SubBackward = struct {
                fn call(result: *Self) void {
                    if (result.prev) |prev_children| {
                        prev_children[0].grad += result.grad;
                        prev_children[1].grad -= result.grad;
                    }
                }
            }.call;

            return Self{
                .data = self.data - other.data,
                .grad = 0,
                .backprop = SubBackward,
                .prev = children,
                .operation = Operation.SUB,
                .label = null,
            };
        }

        /// Divide two values
        pub fn div(self: *Self, other: *Self, allocator: std.mem.Allocator) !Self {
            const children = try allocator.dupe(*Self, &.{ self, other });
            const DivBackward = struct {
                fn call(result: *Self) void {
                    if (result.prev) |prev_children| {
                        prev_children[0].grad += result.grad / other.data;
                        prev_children[1].grad -= result.grad * self.data / (other.data * other.data);
                    }
                }
            }.call;

            return Self{
                .data = self.data / other.data,
                .grad = 0,
                .backprop = DivBackward,
                .prev = children,
                .operation = Operation.DIV,
                .label = null,
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
                defer allocator.free(data_str);

                try writer.print("  \"{}\" [label=\"{{{s} | data {s}}}\", shape=record];\n", .{ node_id, label_str, data_str });

                // If this value is a result of some operation, create an op node for it
                if (node.operation) |op| {
                    const op_id = try std.fmt.allocPrint(allocator, "{}op", .{node_id});
                    defer allocator.free(op_id);
                    try writer.print("  \"{s}\" [label=\"{s}\"];\n", .{ op_id, op.toString() });
                    try writer.print("  \"{s}\" -> \"{}\";\n", .{ op_id, node_id });
                }
            }

            // Create edges
            for (edges.items) |edge| {
                const n1_id = @intFromPtr(edge[0]);
                const n2_id = @intFromPtr(edge[1]);
                if (edge[1].operation) |_| {
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
    };
}
