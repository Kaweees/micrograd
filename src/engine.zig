//! This file provides

const std = @import("std");
const arch = @import("../arch/arch.zig");

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
        /// Value of the register
        value: T,

        /// Initialize the Value
        pub fn init(value: T) @This() {
            return @This(){
                .value = value,
            };
        }

        /// Add two values
        pub fn add(self: @This(), other: @This()) @This() {
            return @This(){
                .value = self.value + other.value,
            };
        }
    };
}
