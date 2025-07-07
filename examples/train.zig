//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");
/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const kiwigrad = @import("kiwigrad");

/// Write the computational graph to a Graphviz file
pub fn draw_graph(comptime T: type, graph: *kiwigrad.engine.Value(T), name: []const u8, writer: anytype) !void {
    const dot_name = try std.fmt.allocPrint(std.heap.page_allocator, "{s}.dot", .{name});
    defer std.heap.page_allocator.free(dot_name);
    const png_name = try std.fmt.allocPrint(std.heap.page_allocator, "{s}.png", .{name});
    defer std.heap.page_allocator.free(png_name);

    const file = try std.fs.cwd().createFile(dot_name, .{});
    defer file.close();
    const file_writer = file.writer();
    try graph.draw_dot(file_writer, std.heap.page_allocator);

    try writer.print("Computational graph written to {s}\n", .{dot_name});
    try writer.print("You can visualize it by running: dot -Tpng {s} -o {s}\n", .{ dot_name, png_name });
}

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    const alloc = std.heap.page_allocator;

    // Initialize the required components
    const ValueType = kiwigrad.engine.Value(f64);
    const NeuronType = kiwigrad.nn.Neuron(f64);
    const LayerType = kiwigrad.nn.Layer(f64);
    // const MLPType = kiwigrad.nn.MLP;

    // Initialize allocators and components
    ValueType.init(alloc);
    NeuronType.init(alloc);
    LayerType.init(alloc);
    defer {
        ValueType.deinit();
        NeuronType.deinit();
        LayerType.deinit();
        // MLPType.deinit();
    }

    // Initialize the neuron
    const neuron = NeuronType.new(3);

    // Create sample input data
    var input_data = [_]*ValueType{
        ValueType.new(1.0),
        ValueType.new(2.0),
        ValueType.new(3.0),
    };

    // Forward pass through the layer
    const output = neuron.forward(input_data[0..]);

    // outputs now contains 2 ValueType pointers (one for each neuron)
    std.debug.print("Layer output: {d}\n", .{output.data});

    try draw_graph(f64, output, "n_f64", stdout);
    try bw.flush(); // Don't forget to flush!
}
