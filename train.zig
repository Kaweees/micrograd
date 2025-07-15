//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");
const kiwigrad = @import("kiwigrad");
const zbench = @import("zbench");

const print = std.debug.print;

fn myBenchmark(allocator: std.mem.Allocator) void {
    for (0..1000) |_| {
        const buf = allocator.alloc(u8, 512) catch @panic("Out of memory");
        defer allocator.free(buf);
    }
}

pub fn main() !void {
    // const stdout_file = std.io.getStdOut().writer();
    // var bw = std.io.bufferedWriter(stdout_file);
    // const stdout = bw.writer();

    // const alloc = std.heap.page_allocator;

    // // Initialize the required components
    // const ValueType = kiwigrad.engine.Value(f64);
    // const NeuronType = kiwigrad.nn.Neuron(f64);
    // const LayerType = kiwigrad.nn.Layer(f64);
    // // const MLPType = kiwigrad.nn.MLP;

    // // Initialize allocators and components
    // ValueType.init(alloc);
    // NeuronType.init(alloc);
    // LayerType.init(alloc);
    // defer {
    //     ValueType.deinit();
    //     NeuronType.deinit();
    //     LayerType.deinit();
    //     // MLPType.deinit();
    // }

    // // Initialize the neuron
    // const neuron = NeuronType.new(3);

    // // Create sample input data
    // var input_data = [_]*ValueType{
    //     ValueType.new(1.0),
    //     ValueType.new(2.0),
    //     ValueType.new(3.0),
    // };

    // // Forward pass through the layer
    // const output = neuron.forward(input_data[0..]);

    // // outputs now contains 2 ValueType pointers (one for each neuron)
    // print("Layer output: {d:.4}\n", .{output.data});

    // print("output.data: {d:.4}\n", .{output.data});
    // print("output.grad: {d:.4}\n", .{output.grad});

    // output.backwardPass(alloc);

    // print("output.data: {d:.4}\n", .{output.data});
    // print("output.grad: {d:.4}\n", .{output.grad});

    // output.draw_graph("assets/img/train", stdout);
    // try bw.flush(); // Don't forget to flush!

    const stdout = std.io.getStdOut().writer();

    // Configure zbench to track memory allocations
    var bench = zbench.Benchmark.init(std.heap.page_allocator, .{
        .track_allocations = true,
    });
    defer bench.deinit();

    try bench.add("My Benchmark", myBenchmark, .{});

    try stdout.writeAll("\n");
    try bench.run(stdout);
}

test "bench test" {
    var bench = zbench.Benchmark.init(std.testing.allocator, .{});
    defer bench.deinit();
    try bench.add("My Benchmark", myBenchmark, .{});
    try bench.run(std.io.getStdOut().writer());
}
