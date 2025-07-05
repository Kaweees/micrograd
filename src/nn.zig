//! Neural network components built on top of the scalar engine

const std = @import("std");
const engine = @import("engine.zig");
const zprob = @import("zprob");

/// Represents a neuron with a configurable input size
///
/// This is a generic type that can be used to create a neuron with configurable input size.
///
/// # Example
/// ```zig
/// const Neuron = @import("nn.zig").Neuron;
/// const neuron = Neuron(f32).new(3);
/// const output = try neuron.forward(&inputs);
/// ```
pub fn Neuron(comptime T: type) type {
    const ValueType = engine.Value(T);
    return struct {
        const Self = @This();

        /// The number of inputs
        nin: usize,
        /// The weights of the neuron
        weights: []*ValueType,
        /// The bias of the neuron
        bias: *ValueType,

        var arena: std.heap.ArenaAllocator = undefined;
        var env: zprob.RandomEnvironment = undefined;

        pub fn init(alloc: std.mem.Allocator) void {
            arena = std.heap.ArenaAllocator.init(alloc);
            env = zprob.RandomEnvironment.init(arena.allocator()) catch unreachable;
        }

        /// Cleanup allocated memory
        pub fn deinit() void {
            arena.deinit();
        }

        pub fn new(nin: usize) *Self {
            const n = arena.allocator().create(Self) catch unreachable;
            const w = arena.allocator().alloc(*ValueType, nin) catch unreachable;

            for (w) |*v| {
                v.* = ValueType.new(generate());
            }

            n.* = Self{
                .weights = w[0..],
                .bias = ValueType.new(generate()),
                .nin = nin,
            };

            return n;
        }

        /// Generate a random value appropriate for the type T
        pub fn generate() T {
            return env.rNormal(@as(T, -1), @as(T, 1)) catch @as(T, 0);
        }

        /// Forward pass through the neuron
        pub fn forward(self: *Self, inputs: []*ValueType) *ValueType {
            if (inputs.len != self.nin) {
                std.debug.panic("Input size mismatch: {d} != {d}", .{ inputs.len, self.nin });
            }

            var sum = self.bias;
            for (self.weights, inputs) |w, x| {
                sum = sum.add(w.mul(x));
            }
            // Apply activation function (ReLU)
            return sum.relu();
        }
    };
}
