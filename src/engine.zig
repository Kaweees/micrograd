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
    };
}
