//! This file provides the autograd engine functionality for kiwigrad

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
            .exp => "^",
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

pub const Scalar = @import("scalar.zig").Scalar;
pub const Tensor = @import("tensor.zig").Tensor;
