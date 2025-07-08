//! A scalar-valued automatic differentiation (autograd) engine for deep learning written in Zig.

const std = @import("std");
const testing = std.testing;

pub const engine = @import("engine.zig");
pub const nn = @import("nn.zig");
