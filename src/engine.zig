//! This file provides engine functionality for micrograd

const std = @import("std");

/// Operations for the engine
pub const Operation = enum(u8) {
    /// Add two values
    ADD = 0x00,
    /// Subtract two values
    SUB = 0x01,
    /// Multiply two values
    MUL = 0x02,
    /// Divide two values
    DIV = 0x03,
};

/// Represents a Scalar value
pub fn Value(comptime T: type) type {
    return struct {
        /// The actual data
        data: T,

        /// Initialize the Value
        pub fn init(
            data: T,
        ) @This() {
            return @This(){
                .data = data,
            };
        }

        /// Convert the Value to a string
        pub fn toString(self: @This()) []const u8 {
            return std.fmt.allocPrint(std.heap.page_allocator, "Value(data={any})", .{self.data}) catch unreachable;
        }

        /// Add two values
        pub fn add(self: @This(), other: @This()) @This() {
            return @This(){
                .data = self.data + other.data,
            };
        }
    };
}
