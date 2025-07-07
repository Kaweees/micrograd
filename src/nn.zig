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

        /// Get all parameters (weights and bias) for optimization
        pub fn parameters(self: *Self) []*ValueType {
            var params = arena.allocator().alloc(*ValueType, self.nin + 1) catch unreachable;

            // Copy weights
            for (self.weights, 0..) |weight, i| {
                params[i] = weight;
            }

            // Add bias
            params[self.nin] = self.bias;
            return params;
        }

        /// Update parameters using gradient descent
        pub fn update_parameters(self: *Self, learning_rate: T) void {
            for (self.weights) |weight| {
                weight.data -= learning_rate * weight.grad;
            }
            self.bias.data -= learning_rate * self.bias.grad;
        }

        /// Get the number of parameters
        pub fn num_parameters(self: *Self) usize {
            return self.nin + 1; // weights + bias
        }

        /// Print neuron information
        pub fn print(self: *Self) void {
            std.debug.print("Neuron({} inputs)\n", .{self.nin});
            std.debug.print("  Weights: ");
            for (self.weights, 0..) |weight, i| {
                std.debug.print("w{}={any} ", .{ i, weight.data });
            }
            std.debug.print("\n  Bias: b={any}\n", .{self.bias.data});
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

        /// Zero gradients for all parameters
        pub fn zero_grad(self: *Self) void {
            for (self.weights) |weight| {
                weight.grad = @as(T, 0);
            }
            self.bias.grad = @as(T, 0);
        }
    };
}

/// Represents a layer of neurons with a configurable input size
///
/// This is a generic type that can be used to create a layer of neurons with configurable input size.
///
/// # Example
/// ```zig
/// const Layer = @import("nn.zig").Layer;
/// const layer = Layer(f32).new(3, 2);
/// const output = try layer.forward(&inputs);
/// ```
pub fn Layer(comptime T: type) type {
    const ValueType = engine.Value(T);
    const NeuronType = Neuron(T);
    return struct {
        const Self = @This();

        /// The number of inputs to the layer
        nin: usize,
        /// The number of neurons in the layer
        nout: usize,
        /// The neurons in the layer
        neurons: []*NeuronType,

        var arena: std.heap.ArenaAllocator = undefined;

        pub fn init(alloc: std.mem.Allocator) void {
            arena = std.heap.ArenaAllocator.init(alloc);
        }

        pub fn deinit() void {
            arena.deinit();
        }

        pub fn new(nin: usize, nout: usize) *Self {
            const layer = arena.allocator().create(Self) catch unreachable;
            const neurons = arena.allocator().alloc(*NeuronType, nout) catch unreachable;

            for (neurons) |*neuron| {
                neuron.* = NeuronType.new(nin);
            }

            layer.* = Self{
                .neurons = neurons[0..],
                .nout = nout,
            };

            return layer;
        }

        /// Forward pass through the layer
        pub fn forward(self: *Self, inputs: []*ValueType) []*ValueType {
            var list = arena.allocator().alloc(*ValueType, self.nout) catch unreachable;
            defer arena.allocator().free(list);
            for (self.neurons, 0..) |neuron, i| {
                list[i] = neuron.forward(inputs);
            }
            return list;
        }
    };
}
