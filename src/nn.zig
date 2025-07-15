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

        // /// Get all parameters (weights and bias) for optimization
        // pub fn parameters(self: *Self) []*ValueType {
        //     var params = arena.allocator().alloc(*ValueType, self.nin + 1) catch unreachable;

        //     // Copy weights
        //     for (self.weights, 0..) |weight, i| {
        //         params[i] = weight;
        //     }

        //     // Add bias
        //     params[self.nin] = self.bias;
        //     return params;
        // }

        // /// Update parameters using gradient descent
        // pub fn update_parameters(self: *Self, learning_rate: T) void {
        //     for (self.weights) |weight| {
        //         weight.data -= learning_rate * weight.grad;
        //     }
        //     self.bias.data -= learning_rate * self.bias.grad;
        // }

        // /// Get the number of parameters
        // pub fn num_parameters(self: *Self) usize {
        //     return self.nin + 1; // weights + bias
        // }

        // /// Print neuron information
        // pub fn print(self: *Self) void {
        //     std.debug.print("Neuron({} inputs)\n", .{self.nin});
        //     std.debug.print("  Weights: ");
        //     for (self.weights, 0..) |weight, i| {
        //         std.debug.print("w{}={any} ", .{ i, weight.data });
        //     }
        //     std.debug.print("\n  Bias: b={any}\n", .{self.bias.data});
        // }

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

        /// Get all parameters (weights and bias) for optimization
        pub fn parameters(self: *Self) []*ValueType {
            var list = std.ArrayList(*ValueType).init(arena.allocator());
            defer list.deinit();

            for (self.weights) |w| {
                list.append(w) catch unreachable;
            }
            list.append(self.bias) catch unreachable;

            return list.toOwnedSlice() catch unreachable;
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
                .nin = nin,
                .neurons = neurons[0..],
                .nout = nout,
            };

            return layer;
        }

        /// Forward pass through the layer
        pub fn forward(self: *Self, inputs: []*ValueType) []*ValueType {
            var list = arena.allocator().alloc(*ValueType, self.nout) catch unreachable;
            for (self.neurons, 0..) |neuron, i| {
                list[i] = neuron.forward(inputs);
            }
            return list;
        }

        /// Get all parameters (weights and bias) for optimization
        pub fn parameters(self: *Self) []*ValueType {
            var list = std.ArrayList(*ValueType).init(arena.allocator());
            defer list.deinit();

            for (self.neurons) |neuron| {
                list.append(neuron.parameters()) catch unreachable;
            }
            return list.toOwnedSlice() catch unreachable;
        }

        /// Zero gradients for all parameters
        pub fn zero_grad(self: *Self) void {
            for (self.neurons) |neuron| {
                neuron.zero_grad();
            }
        }
    };
}

/// Represents a layer of neurons with a configurable input size
///
/// This is a generic type that can be used to create a layer of neurons with configurable input size.
///
/// # Example
/// ```zig
/// const MLP = @import("nn.zig").MLP;
/// const mlp = MLP(f32).new(3, 2);
/// const output = try mlp.forward(&inputs);
/// ```
pub fn MLP(comptime T: type) type {
    const ValueType = engine.Value(T);
    const LayerType = Layer(T);
    return struct {
        const Self = @This();

        /// The layers in the MLP
        layers: []*LayerType,

        var arena: std.heap.ArenaAllocator = undefined;

        pub fn init(alloc: std.mem.Allocator) void {
            arena = std.heap.ArenaAllocator.init(alloc);
        }

        pub fn deinit() void {
            arena.deinit();
        }

        pub fn new(nlayers: usize, layer_sizes: []usize) *Self {
            const mlp = arena.allocator().create(Self) catch unreachable;
            const layers = arena.allocator().alloc(*LayerType, nlayers) catch unreachable;

            for (layers, 0..) |*layer, i| {
                layer.* = LayerType.new(layer_sizes[i], layer_sizes[i + 1]);
            }

            mlp.* = Self{
                .layers = layers[0..],
            };

            return mlp;
        }

        /// Forward pass through the layer
        pub fn forward(self: *Self, inputs: []*ValueType) []*ValueType {
            var current_inputs = inputs;
            for (self.layers) |layer| {
                current_inputs = layer.forward(current_inputs);
            }
            return current_inputs;
        }

        /// Get all parameters (weights and bias) for optimization
        pub fn parameters(self: *Self) []*ValueType {
            var list = std.ArrayList(*ValueType).init(arena.allocator());
            defer list.deinit();

            for (self.layers) |layer| {
                list.append(layer.parameters()) catch unreachable;
            }
            return list.toOwnedSlice() catch unreachable;
        }

        /// Zero gradients for all parameters
        pub fn zero_grad(self: *Self) void {
            for (self.layers) |layer| {
                layer.zero_grad();
            }
        }

        /// Draw the neural network topology using Graphviz
        pub fn draw_graph(self: *Self, name: []const u8, writer: anytype) void {
            const dot_name = std.fmt.allocPrint(std.heap.page_allocator, "{s}.dot", .{name}) catch unreachable;
            defer std.heap.page_allocator.free(dot_name);
            const png_name = std.fmt.allocPrint(std.heap.page_allocator, "{s}.png", .{name}) catch unreachable;
            defer std.heap.page_allocator.free(png_name);

            const file = std.fs.cwd().createFile(dot_name, .{}) catch unreachable;
            defer file.close();
            const file_writer = file.writer();
            self.draw_dot(file_writer) catch unreachable;

            writer.print("Neural network topology written to {s}\n", .{dot_name}) catch unreachable;
            writer.print("You can visualize it by running: dot -Tpng {s} -o {s}\n", .{ dot_name, png_name }) catch unreachable;
        }

        /// Generate Graphviz DOT format representation of the neural network topology
        pub fn draw_dot(self: *Self, writer: anytype) !void {
            try writer.writeAll("digraph {\n");
            try writer.writeAll("  rankdir=LR;\n");
            try writer.writeAll("  node [shape=circle, style=filled, fillcolor=lightblue];\n");
            try writer.writeAll("  edge [color=gray];\n");

            // Create input layer nodes
            const first_layer = self.layers[0];
            try writer.writeAll("  // Input layer\n");
            try writer.writeAll("  {rank=same; ");
            for (0..first_layer.nin) |i| {
                try writer.print("input_{} ", .{i});
            }
            try writer.writeAll("}\n");

            for (0..first_layer.nin) |i| {
                try writer.print("  input_{} [label=\"I{}\", fillcolor=lightgreen];\n", .{ i, i });
            }

            // Create hidden and output layer nodes
            for (self.layers, 0..) |layer, layer_idx| {
                try writer.print("  // Layer {}\n", .{layer_idx});
                try writer.writeAll("  {rank=same; ");
                for (0..layer.nout) |i| {
                    try writer.print("L{}_N{} ", .{ layer_idx, i });
                }
                try writer.writeAll("}\n");

                for (0..layer.nout) |neuron_idx| {
                    const fillcolor = if (layer_idx == self.layers.len - 1) "lightcoral" else "lightblue";
                    try writer.print("  L{}_N{} [label=\"N{}\", fillcolor={s}];\n", .{ layer_idx, neuron_idx, neuron_idx, fillcolor });
                }
            }

            // Create connections
            for (self.layers, 0..) |layer, layer_idx| {
                if (layer_idx == 0) {
                    // Connect input layer to first hidden layer
                    try writer.writeAll("  // Input to first layer connections\n");
                    for (0..layer.nin) |input_idx| {
                        for (0..layer.nout) |neuron_idx| {
                            try writer.print("  input_{} -> L{}_N{};\n", .{ input_idx, layer_idx, neuron_idx });
                        }
                    }
                } else {
                    // Connect previous layer to current layer
                    try writer.print("  // Layer {} to Layer {} connections\n", .{ layer_idx - 1, layer_idx });
                    const prev_layer = self.layers[layer_idx - 1];
                    for (0..prev_layer.nout) |prev_neuron_idx| {
                        for (0..layer.nout) |neuron_idx| {
                            try writer.print("  L{}_N{} -> L{}_N{};\n", .{ layer_idx - 1, prev_neuron_idx, layer_idx, neuron_idx });
                        }
                    }
                }
            }

            try writer.writeAll("}\n");
        }
    };
}
